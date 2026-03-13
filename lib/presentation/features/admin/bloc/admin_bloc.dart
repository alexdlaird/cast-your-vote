import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/domain/repositories/event_repository.dart';
import 'package:theatre_121/domain/repositories/ballot_repository.dart';
import 'package:theatre_121/domain/services/google_sheets_service.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class StartWatching extends AdminEvent {
  const StartWatching();
}

class _EventUpdated extends AdminEvent {
  final EventModel? event;

  const _EventUpdated(this.event);

  @override
  List<Object?> get props => [event];
}

class _BallotsUpdated extends AdminEvent {
  final List<BallotModel> ballots;

  const _BallotsUpdated(this.ballots);

  @override
  List<Object?> get props => [ballots];
}

class _StreamError extends AdminEvent {
  final String message;

  const _StreamError(this.message);

  @override
  List<Object?> get props => [message];
}

class CreateEvent extends AdminEvent {
  final String name;
  final List<String> participantNames;
  final int audienceBallotCount;
  final List<String> judgeNames;

  const CreateEvent({
    required this.name,
    required this.participantNames,
    required this.audienceBallotCount,
    required this.judgeNames,
  });

  @override
  List<Object?> get props =>
      [name, participantNames, audienceBallotCount, judgeNames];
}

class CloseVoting extends AdminEvent {
  const CloseVoting();
}

class RefetchResults extends AdminEvent {
  const RefetchResults();
}

class UpdateDonationWinner extends AdminEvent {
  final String? largestDonationWinnerId;
  final String? mostDonationsWinnerId;

  const UpdateDonationWinner({
    this.largestDonationWinnerId,
    this.mostDonationsWinnerId,
  });

  @override
  List<Object?> get props => [largestDonationWinnerId, mostDonationsWinnerId];
}

enum ClosingProgress {
  none,
  closingVoting,
  exportingBallots,
  fetchingResults,
  refetchingResults,
  exportComplete,       // Export finished - show export success snackbar
  refetchComplete,      // Refetch finished - show refetch success snackbar
}

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminLoaded extends AdminState {
  final EventModel? currentEvent;
  final List<BallotModel> ballots;
  final bool isCreatingEvent;
  final ClosingProgress closingProgress;

  const AdminLoaded({
    this.currentEvent,
    this.ballots = const [],
    this.isCreatingEvent = false,
    this.closingProgress = ClosingProgress.none,
  });

  // Get votingResults from currentEvent (persisted in Firestore)
  VotingResults? get votingResults => currentEvent?.votingResults;

  bool get isClosingVoting => closingProgress != ClosingProgress.none &&
      closingProgress != ClosingProgress.exportComplete &&
      closingProgress != ClosingProgress.refetchComplete;

  int get audienceBallotCount => ballots.where((b) => b.isAudience).length;
  int get judgeBallotCount => ballots.where((b) => b.isJudge).length;
  int get submittedAudienceCount =>
      ballots.where((b) => b.isAudience && b.submitted).length;
  int get submittedJudgeCount =>
      ballots.where((b) => b.isJudge && b.submitted).length;

  String get closingProgressText {
    switch (closingProgress) {
      case ClosingProgress.closingVoting:
        return 'Closing voting ...';
      case ClosingProgress.exportingBallots:
        return 'Exporting ballots ...';
      case ClosingProgress.fetchingResults:
      case ClosingProgress.refetchingResults:
        return 'Fetching results ...';
      case ClosingProgress.none:
      case ClosingProgress.exportComplete:
      case ClosingProgress.refetchComplete:
        return '';
    }
  }

  @override
  List<Object?> get props =>
      [currentEvent, ballots, isCreatingEvent, closingProgress];

  AdminLoaded copyWith({
    EventModel? currentEvent,
    List<BallotModel>? ballots,
    bool? isCreatingEvent,
    ClosingProgress? closingProgress,
    bool clearEvent = false,
  }) {
    return AdminLoaded(
      currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      ballots: ballots ?? this.ballots,
      isCreatingEvent: isCreatingEvent ?? this.isCreatingEvent,
      closingProgress: closingProgress ?? this.closingProgress,
    );
  }
}

class AdminError extends AdminState {
  final String message;

  const AdminError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final EventRepository _eventRepository;
  final BallotRepository _ballotRepository;
  final GoogleSheetsService _sheetsService;

  StreamSubscription<EventModel?>? _eventSubscription;
  StreamSubscription<List<BallotModel>>? _ballotsSubscription;
  String? _currentEventId;

  AdminBloc({
    required EventRepository eventRepository,
    required BallotRepository ballotRepository,
    required GoogleSheetsService sheetsService,
  })  : _eventRepository = eventRepository,
        _ballotRepository = ballotRepository,
        _sheetsService = sheetsService,
        super(const AdminInitial()) {
    on<StartWatching>(_onStartWatching);
    on<_EventUpdated>(_onEventUpdated);
    on<_BallotsUpdated>(_onBallotsUpdated);
    on<_StreamError>(_onStreamError);
    on<CreateEvent>(_onCreateEvent);
    on<CloseVoting>(_onCloseVoting);
    on<RefetchResults>(_onRefetchResults);
    on<UpdateDonationWinner>(_onUpdateDonationWinner);
  }

  void _onStartWatching(
    StartWatching event,
    Emitter<AdminState> emit,
  ) {
    emit(const AdminLoading());

    // Reset all subscriptions and state to force full reload
    _eventSubscription?.cancel();
    _ballotsSubscription?.cancel();
    _currentEventId = null;

    _eventSubscription = _eventRepository.watchCurrentEvent().listen(
      (event) => add(_EventUpdated(event)),
      onError: (e) => add(_StreamError(e.toString())),
    );
  }

  void _onStreamError(
    _StreamError event,
    Emitter<AdminState> emit,
  ) {
    emit(AdminError(event.message));
  }

  void _onEventUpdated(
    _EventUpdated event,
    Emitter<AdminState> emit,
  ) {
    final currentState = state;
    final newEvent = event.event;

    // Update ballots subscription if event changed
    if (newEvent?.id != _currentEventId) {
      _currentEventId = newEvent?.id;
      _ballotsSubscription?.cancel();

      if (newEvent != null) {
        _ballotsSubscription =
            _ballotRepository.watchEventBallots(newEvent.id).listen(
                  (ballots) => add(_BallotsUpdated(ballots)),
                  onError: (e) => add(_StreamError(e.toString())),
                );
      }
    }

    if (currentState is AdminLoaded) {
      emit(currentState.copyWith(
        currentEvent: newEvent,
        clearEvent: newEvent == null,
      ));
    } else {
      emit(AdminLoaded(currentEvent: newEvent));
    }
  }

  void _onBallotsUpdated(
    _BallotsUpdated event,
    Emitter<AdminState> emit,
  ) {
    final currentState = state;
    if (currentState is AdminLoaded) {
      // Only emit if ballots actually changed
      if (!const DeepCollectionEquality()
          .equals(currentState.ballots, event.ballots)) {
        emit(currentState.copyWith(ballots: event.ballots));
      }
    }
  }

  Future<void> _onCreateEvent(
    CreateEvent event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    if (currentState is AdminLoaded) {
      emit(currentState.copyWith(isCreatingEvent: true));
    }

    try {
      final participants = event.participantNames.asMap().entries.map((entry) {
        return ParticipantModel(
          id: 'p${entry.key + 1}',
          name: entry.value,
          order: entry.key + 1,
        );
      }).toList();

      final newEvent = await _eventRepository.createEvent(
        EventModel(
          id: '',
          name: event.name,
          participants: participants,
          judges: event.judgeNames,
          status: EventStatus.open,
          createdAt: DateTime.now(),
        ),
      );

      final ballots = await _ballotRepository.createBallotsAndReturn(
        eventId: newEvent.id,
        audienceCount: event.audienceBallotCount,
        judgeNames: event.judgeNames,
      );

      // Emit AdminLoaded directly - streams will update with any changes
      emit(AdminLoaded(currentEvent: newEvent, ballots: ballots));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onCloseVoting(
    CloseVoting event,
    Emitter<AdminState> emit,
  ) async {
    var currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    final eventData = currentState.currentEvent!;
    final ballotData = currentState.ballots;
    final isAlreadyClosed = !eventData.isVotingOpen;

    try {
      // Step 1: Close voting (skip if already closed)
      if (!isAlreadyClosed) {
        currentState = currentState.copyWith(closingProgress: ClosingProgress.closingVoting);
        emit(currentState);
        await _eventRepository.closeVoting(eventData.id);

        // Update local state immediately so UI shows "Voting Closed"
        final closedEvent = eventData.copyWith(status: EventStatus.closed);
        currentState = currentState.copyWith(currentEvent: closedEvent);
        emit(currentState);
      }

      // Step 2: Export ballots to Google Sheets
      currentState = currentState.copyWith(closingProgress: ClosingProgress.exportingBallots);
      emit(currentState);
      final spreadsheetUrl = await _sheetsService.createResultsSpreadsheet(
        event: eventData,
        ballots: ballotData,
      );
      await _eventRepository.updateSpreadsheetUrl(eventData.id, spreadsheetUrl);

      // Step 3: Fetch results from spreadsheet
      currentState = currentState.copyWith(closingProgress: ClosingProgress.fetchingResults);
      emit(currentState);
      final results = await _fetchResults(
        event: eventData,
        spreadsheetUrl: spreadsheetUrl,
      );

      // Step 4: Save results to Firestore
      await _eventRepository.updateVotingResults(eventData.id, results);

      // Step 5: Update local state immediately and complete (stream will eventually sync)
      final updatedEvent = eventData.copyWith(
        status: EventStatus.closed,
        spreadsheetUrl: spreadsheetUrl,
        votingResults: results,
      );
      emit(currentState.copyWith(
        currentEvent: updatedEvent,
        closingProgress: ClosingProgress.exportComplete,
      ));
    } catch (e) {
      if (state is AdminLoaded) {
        emit((state as AdminLoaded).copyWith(closingProgress: ClosingProgress.none));
      }
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onRefetchResults(
    RefetchResults event,
    Emitter<AdminState> emit,
  ) async {
    var currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    final eventData = currentState.currentEvent!;
    final spreadsheetUrl = eventData.spreadsheetUrl;

    if (spreadsheetUrl == null) {
      emit(const AdminError('No spreadsheet URL found.'));
      return;
    }

    try {
      // Show loading indicator
      currentState = currentState.copyWith(closingProgress: ClosingProgress.refetchingResults);
      emit(currentState);

      // Fetch results from spreadsheet
      final results = await _fetchResults(
        event: eventData,
        spreadsheetUrl: spreadsheetUrl,
      );

      // Save to Firestore
      await _eventRepository.updateVotingResults(eventData.id, results);

      // Update local state immediately (stream will eventually sync)
      final updatedEvent = eventData.copyWith(votingResults: results);
      emit(currentState.copyWith(
        currentEvent: updatedEvent,
        closingProgress: ClosingProgress.refetchComplete,
      ));
    } catch (e) {
      if (state is AdminLoaded) {
        emit((state as AdminLoaded).copyWith(closingProgress: ClosingProgress.none));
      }
      emit(AdminError(e.toString()));
    }
  }

  Future<VotingResults> _fetchResults({
    required EventModel event,
    required String spreadsheetUrl,
  }) async {
    final fetchedResults = await _sheetsService.fetchResultsFromSpreadsheet(
      spreadsheetUrl: spreadsheetUrl,
    );

    // Match fetched results to participant IDs by name
    final participants = event.participants;
    final rankings = fetchedResults.map((result) {
      final participant = participants.firstWhere(
        (p) => p.displayName == result.name,
        orElse: () => ParticipantModel(id: result.id, name: result.name, order: 0),
      );
      return ParticipantResult(
        id: participant.id,
        name: result.name,
        audienceTotal: result.audienceTotal,
        judgeTotal: result.judgeTotal,
        combinedScore: result.combinedScore,
      );
    }).toList();

    // Determine eliminated/tied participants
    String? eliminatedId;
    List<String> tiedIds = [];
    if (rankings.isNotEmpty) {
      final lowestScore = rankings.last.combinedScore;
      final lowestScorers = rankings
          .where((r) => r.combinedScore == lowestScore)
          .map((r) => r.id)
          .toList();

      if (lowestScorers.length > 1) {
        tiedIds = lowestScorers;
      } else {
        eliminatedId = lowestScorers.first;
      }
    }

    return VotingResults(
      rankings: rankings,
      eliminatedParticipantId: eliminatedId,
      tiedParticipantIds: tiedIds,
    );
  }

  Future<void> _onUpdateDonationWinner(
    UpdateDonationWinner event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    try {
      await _eventRepository.updateDonationWinners(
        currentState.currentEvent!.id,
        largestDonationWinnerId: event.largestDonationWinnerId,
        mostDonationsWinnerId: event.mostDonationsWinnerId,
      );
      // Stream will automatically update the state
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _ballotsSubscription?.cancel();
    return super.close();
  }
}
