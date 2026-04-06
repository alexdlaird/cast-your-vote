import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/domain/repositories/ballot_repository.dart';
import 'package:cast_your_vote/domain/repositories/event_repository.dart';

final _log = Logger('ballot_bloc');

abstract class BallotEvent extends Equatable {
  const BallotEvent();

  @override
  List<Object?> get props => [];
}

class LoadBallot extends BallotEvent {
  final String code;

  const LoadBallot(this.code);

  @override
  List<Object?> get props => [code];
}

class UpdateAudienceVote extends BallotEvent {
  final String participantId;
  final int? rank;

  const UpdateAudienceVote({required this.participantId, this.rank});

  @override
  List<Object?> get props => [participantId, rank];
}

class UpdateJudgeVote extends BallotEvent {
  final String participantId;
  final JudgeVote vote;

  const UpdateJudgeVote({required this.participantId, required this.vote});

  @override
  List<Object?> get props => [participantId, vote];
}

class SubmitBallot extends BallotEvent {
  const SubmitBallot();
}

class ClearBallot extends BallotEvent {
  const ClearBallot();
}

abstract class BallotState extends Equatable {
  const BallotState();

  @override
  List<Object?> get props => [];
}

class BallotInitial extends BallotState {
  const BallotInitial();
}

class BallotLoading extends BallotState {
  const BallotLoading();
}

class BallotLoaded extends BallotState {
  final BallotModel ballot;
  final EventModel event;
  final bool isSubmitting;

  const BallotLoaded({
    required this.ballot,
    required this.event,
    this.isSubmitting = false,
  });

  @override
  List<Object?> get props => [ballot, event, isSubmitting];
}

class BallotSubmitted extends BallotState {
  const BallotSubmitted();
}

class BallotError extends BallotState {
  final String message;

  const BallotError(this.message);

  @override
  List<Object?> get props => [message];
}

class BallotNotFound extends BallotState {
  const BallotNotFound();
}

class BallotVotingClosed extends BallotState {
  const BallotVotingClosed();
}

class BallotAlreadySubmitted extends BallotState {
  const BallotAlreadySubmitted();
}

class BallotBloc extends Bloc<BallotEvent, BallotState> {
  final BallotRepository _ballotRepository;
  final EventRepository _eventRepository;

  // Debounce timer for persisting votes
  Timer? _persistTimer;
  static const _persistDelay = Duration(milliseconds: 500);

  // Write queue to prevent race conditions
  bool _isWriting = false;
  BallotModel? _lastWrittenBallot;

  BallotBloc({
    required BallotRepository ballotRepository,
    required EventRepository eventRepository,
  })  : _ballotRepository = ballotRepository,
        _eventRepository = eventRepository,
        super(const BallotInitial()) {
    on<LoadBallot>(_onLoadBallot);
    on<UpdateAudienceVote>(_onUpdateAudienceVote);
    on<UpdateJudgeVote>(_onUpdateJudgeVote);
    on<SubmitBallot>(_onSubmitBallot);
    on<ClearBallot>(_onClearBallot);
    on<_PersistError>(_onPersistError);
  }

  void _onPersistError(_PersistError event, Emitter<BallotState> emit) {
    emit(BallotError(event.message));
  }

  /// Debounced persist - cancels any pending write and schedules a new one.
  /// Uses write queue to prevent race conditions.
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDelay, () => _executePersist());
  }

  /// Execute the persist, ensuring only one write at a time.
  /// If state changed during write, writes again.
  Future<void> _executePersist() async {
    if (_isWriting) {
      _schedulePersist();
      return;
    }

    final currentState = state;
    if (currentState is! BallotLoaded) return;

    final ballotToWrite = currentState.ballot;

    // Skip if we already wrote this exact ballot
    if (_lastWrittenBallot == ballotToWrite) return;

    _isWriting = true;
    try {
      await _ballotRepository.updateBallot(ballotToWrite);
      _lastWrittenBallot = ballotToWrite;
    } catch (e, stackTrace) {
      _log.severe('Failed to persist ballot', e, stackTrace);
      add(_PersistError(e.toString()));
    } finally {
      _isWriting = false;

      // Check if state changed while we were writing, rewrite if so
      final newState = state;
      if (newState is BallotLoaded && newState.ballot != ballotToWrite) {
        _schedulePersist();
      }
    }
  }

  Future<void> _onLoadBallot(
    LoadBallot event,
    Emitter<BallotState> emit,
  ) async {
    emit(const BallotLoading());

    try {
      final loadedBallot = await _ballotRepository.getBallot(event.code);
      if (loadedBallot == null) {
        emit(const BallotNotFound());
        return;
      }

      if (loadedBallot.submitted) {
        emit(const BallotAlreadySubmitted());
        return;
      }

      final eventModel = await _eventRepository.getCurrentEvent();
      if (eventModel == null || eventModel.id != loadedBallot.eventId) {
        emit(const BallotVotingClosed());
        return;
      }

      if (!eventModel.isVotingOpen) {
        emit(const BallotVotingClosed());
        return;
      }

      final ballot = _fillDroppedOutScores(loadedBallot, eventModel);
      emit(BallotLoaded(ballot: ballot, event: eventModel));

      // If dropout pre-filling changed anything, persist immediately
      if (ballot != loadedBallot) _schedulePersist();
    } catch (e, stackTrace) {
      _log.severe('Failed to load ballot', e, stackTrace);
      emit(BallotError(e.toString()));
    }
  }

  Future<void> _onUpdateAudienceVote(
    UpdateAudienceVote event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;

    final votes = Map<String, int>.from(currentState.ballot.audienceVotes);

    if (event.rank == null) {
      votes.remove(event.participantId);
    } else {
      // Remove this rank from any other participant
      votes.removeWhere((_, rank) => rank == event.rank);
      votes[event.participantId] = event.rank!;
    }

    final updatedBallot = currentState.ballot.copyWith(audienceVotes: votes);

    // Optimistic update - show new state immediately
    emit(BallotLoaded(ballot: updatedBallot, event: currentState.event));

    // Schedule debounced persist
    _schedulePersist();
  }

  Future<void> _onUpdateJudgeVote(
    UpdateJudgeVote event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;

    final votes = Map<String, JudgeVote>.from(currentState.ballot.judgeVotes);
    votes[event.participantId] = event.vote;

    final updatedBallot = currentState.ballot.copyWith(judgeVotes: votes);

    // Optimistic update - show new state immediately
    emit(BallotLoaded(ballot: updatedBallot, event: currentState.event));

    // Schedule debounced persist
    _schedulePersist();
  }

  Future<void> _onSubmitBallot(
    SubmitBallot event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;

    // Cancel any pending debounce timer
    _persistTimer?.cancel();

    emit(BallotLoaded(
      ballot: currentState.ballot,
      event: currentState.event,
      isSubmitting: true,
    ));

    try {
      // Wait for any in-progress write to complete
      while (_isWriting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Re-check event status before submitting
      final eventModel = await _eventRepository.getCurrentEvent();
      if (eventModel == null || eventModel.id != currentState.ballot.eventId) {
        emit(const BallotVotingClosed());
        return;
      }

      if (!eventModel.isVotingOpen) {
        emit(const BallotVotingClosed());
        return;
      }

      // Apply fresh dropout scores before final write (handles dropouts added mid-session)
      final ballotToSubmit = _fillDroppedOutScores(currentState.ballot, eventModel);

      // Write final state and submit
      await _ballotRepository.updateBallot(ballotToSubmit);
      _lastWrittenBallot = ballotToSubmit;
      await _ballotRepository.submitBallot(ballotToSubmit.code);
      emit(const BallotSubmitted());
    } catch (e, stackTrace) {
      _log.severe('Failed to submit ballot', e, stackTrace);
      emit(BallotError(e.toString()));
    }
  }

  Future<void> _onClearBallot(
    ClearBallot event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;

    // Cancel any pending persist
    _persistTimer?.cancel();

    var clearedBallot = currentState.ballot.copyWith(
      audienceVotes: const {},
      judgeVotes: const {},
    );
    clearedBallot = _fillDroppedOutScores(clearedBallot, currentState.event);

    // Optimistic update - show cleared state immediately
    emit(BallotLoaded(ballot: clearedBallot, event: currentState.event));

    // Schedule debounced persist
    _schedulePersist();
  }

  /// Pre-fills worst scores for dropped-out participants:
  /// - Audience: assigns ranks from the bottom (N, N-1, …) to any unranked dropout
  /// - Judge: sets all categories to 1 (worst) for every dropout
  BallotModel _fillDroppedOutScores(BallotModel ballot, EventModel event) {
    final droppedOut = event.participants.where((p) => p.droppedOut).toList();
    if (droppedOut.isEmpty) return ballot;

    if (ballot.isAudience) {
      final votes = Map<String, int>.from(ballot.audienceVotes);
      final participantCount = event.participants.length;
      final usedRanks = votes.values.toSet();
      var rank = participantCount;
      for (final p in droppedOut) {
        if (!votes.containsKey(p.id)) {
          while (usedRanks.contains(rank) && rank >= 1) {
            rank--;
          }
          if (rank >= 1) {
            votes[p.id] = rank;
            usedRanks.add(rank);
            rank--;
          }
        }
      }
      return ballot.copyWith(audienceVotes: votes);
    }

    if (ballot.isJudge) {
      final judgeVotes = Map<String, JudgeVote>.from(ballot.judgeVotes);
      for (final p in droppedOut) {
        judgeVotes[p.id] = const JudgeVote(
          singing: 1,
          performance: 1,
          audienceParticipation: 1,
        );
      }
      return ballot.copyWith(judgeVotes: judgeVotes);
    }

    return ballot;
  }

  @override
  Future<void> close() {
    _persistTimer?.cancel();
    return super.close();
  }
}

// Internal event for persist errors
class _PersistError extends BallotEvent {
  final String message;

  const _PersistError(this.message);

  @override
  List<Object?> get props => [message];
}
