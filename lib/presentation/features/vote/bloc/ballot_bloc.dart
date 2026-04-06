// Copyright (c) 2024 Cast Your Vote. MIT License.

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
  final String roundId;
  final String participantId;
  final int? rank;

  const UpdateAudienceVote({
    required this.roundId,
    required this.participantId,
    this.rank,
  });

  @override
  List<Object?> get props => [roundId, participantId, rank];
}

class UpdateJudgeVote extends BallotEvent {
  final String roundId;
  final String participantId;
  final JudgeVote vote;

  const UpdateJudgeVote({
    required this.roundId,
    required this.participantId,
    required this.vote,
  });

  @override
  List<Object?> get props => [roundId, participantId, vote];
}

class AdvanceRound extends BallotEvent {
  const AdvanceRound();
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
  final bool isAdvancingRound;

  const BallotLoaded({
    required this.ballot,
    required this.event,
    this.isSubmitting = false,
    this.isAdvancingRound = false,
  });

  RoundModel get currentRound => event.rounds[ballot.currentRoundIndex];

  int get totalRounds => event.rounds.length;

  bool get isOnLastRound =>
      ballot.currentRoundIndex == event.rounds.length - 1;

  @override
  List<Object?> get props => [ballot, event, isSubmitting, isAdvancingRound];
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

  Timer? _persistTimer;
  static const _persistDelay = Duration(milliseconds: 500);

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
    on<AdvanceRound>(_onAdvanceRound);
    on<SubmitBallot>(_onSubmitBallot);
    on<ClearBallot>(_onClearBallot);
    on<_PersistError>(_onPersistError);
  }

  void _onPersistError(_PersistError event, Emitter<BallotState> emit) {
    emit(BallotError(event.message));
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDelay, () => _executePersist());
  }

  Future<void> _executePersist() async {
    if (_isWriting) {
      _schedulePersist();
      return;
    }

    final currentState = state;
    if (currentState is! BallotLoaded) return;

    final ballotToWrite = currentState.ballot;
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

    final allVotes = Map<String, Map<String, int>>.from(
      currentState.ballot.audienceVotes.map(
        (k, v) => MapEntry(k, Map<String, int>.from(v)),
      ),
    );

    final roundVotes = Map<String, int>.from(allVotes[event.roundId] ?? {});

    if (event.rank == null) {
      roundVotes.remove(event.participantId);
    } else {
      roundVotes.removeWhere((_, rank) => rank == event.rank);
      roundVotes[event.participantId] = event.rank!;
    }

    allVotes[event.roundId] = roundVotes;

    final updatedBallot =
        currentState.ballot.copyWith(audienceVotes: allVotes);
    emit(BallotLoaded(ballot: updatedBallot, event: currentState.event));
    _schedulePersist();
  }

  Future<void> _onUpdateJudgeVote(
    UpdateJudgeVote event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;

    final allVotes = Map<String, Map<String, JudgeVote>>.from(
      currentState.ballot.judgeVotes.map(
        (k, v) => MapEntry(k, Map<String, JudgeVote>.from(v)),
      ),
    );

    final roundVotes = Map<String, JudgeVote>.from(allVotes[event.roundId] ?? {});
    roundVotes[event.participantId] = event.vote;
    allVotes[event.roundId] = roundVotes;

    final updatedBallot =
        currentState.ballot.copyWith(judgeVotes: allVotes);
    emit(BallotLoaded(ballot: updatedBallot, event: currentState.event));
    _schedulePersist();
  }

  Future<void> _onAdvanceRound(
    AdvanceRound event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;
    if (currentState.isOnLastRound) return;

    _persistTimer?.cancel();

    emit(BallotLoaded(
      ballot: currentState.ballot,
      event: currentState.event,
      isAdvancingRound: true,
    ));

    try {
      while (_isWriting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final advanced = currentState.ballot.copyWith(
        currentRoundIndex: currentState.ballot.currentRoundIndex + 1,
      );
      await _ballotRepository.updateBallot(advanced);
      _lastWrittenBallot = advanced;

      emit(BallotLoaded(ballot: advanced, event: currentState.event));
    } catch (e, stackTrace) {
      _log.severe('Failed to advance round', e, stackTrace);
      emit(BallotError(e.toString()));
    }
  }

  Future<void> _onSubmitBallot(
    SubmitBallot event,
    Emitter<BallotState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BallotLoaded) return;

    _persistTimer?.cancel();

    emit(BallotLoaded(
      ballot: currentState.ballot,
      event: currentState.event,
      isSubmitting: true,
    ));

    try {
      while (_isWriting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final eventModel = await _eventRepository.getCurrentEvent();
      if (eventModel == null ||
          eventModel.id != currentState.ballot.eventId) {
        emit(const BallotVotingClosed());
        return;
      }

      if (!eventModel.isVotingOpen) {
        emit(const BallotVotingClosed());
        return;
      }

      final ballotToSubmit =
          _fillDroppedOutScores(currentState.ballot, eventModel);

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

    _persistTimer?.cancel();

    var clearedBallot = currentState.ballot.copyWith(
      audienceVotes: const {},
      judgeVotes: const {},
    );
    clearedBallot = _fillDroppedOutScores(clearedBallot, currentState.event);

    emit(BallotLoaded(ballot: clearedBallot, event: currentState.event));
    _schedulePersist();
  }

  /// Pre-fills worst scores for dropped-out participants across all rounds.
  BallotModel _fillDroppedOutScores(BallotModel ballot, EventModel event) {
    final droppedOut = event.participants.where((p) => p.droppedOut).toList();
    if (droppedOut.isEmpty || event.rounds.isEmpty) return ballot;

    if (ballot.isAudience) {
      final allVotes = Map<String, Map<String, int>>.from(
        ballot.audienceVotes.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      );
      final participantCount = event.participants.length;

      for (final round in event.rounds) {
        final votes = Map<String, int>.from(allVotes[round.id] ?? {});
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
        allVotes[round.id] = votes;
      }
      return ballot.copyWith(audienceVotes: allVotes);
    }

    if (ballot.isJudge) {
      final allVotes = Map<String, Map<String, JudgeVote>>.from(
        ballot.judgeVotes
            .map((k, v) => MapEntry(k, Map<String, JudgeVote>.from(v))),
      );
      for (final round in event.rounds) {
        final votes = Map<String, JudgeVote>.from(allVotes[round.id] ?? {});
        for (final p in droppedOut) {
          votes[p.id] = const JudgeVote(singing: 1, performance: 1, songFit: 1);
        }
        allVotes[round.id] = votes;
      }
      return ballot.copyWith(judgeVotes: allVotes);
    }

    return ballot;
  }

  @override
  Future<void> close() {
    _persistTimer?.cancel();
    return super.close();
  }
}

class _PersistError extends BallotEvent {
  final String message;

  const _PersistError(this.message);

  @override
  List<Object?> get props => [message];
}
