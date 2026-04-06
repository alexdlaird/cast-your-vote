import 'dart:async';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/core/storage_service.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/domain/repositories/event_repository.dart';
import 'package:cast_your_vote/domain/repositories/ballot_repository.dart';
import 'package:cast_your_vote/domain/services/google_sheets_service.dart';

final _log = Logger('admin_bloc');

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
  final List<JudgeModel> judges;
  final String? previousLogoUrl;
  final Uint8List? logoBytes;
  final String? logoMimeType;

  const CreateEvent({
    required this.name,
    required this.participantNames,
    required this.audienceBallotCount,
    required this.judges,
    this.previousLogoUrl,
    this.logoBytes,
    this.logoMimeType,
  });

  @override
  List<Object?> get props =>
      [name, participantNames, audienceBallotCount, judges, previousLogoUrl];
}

class UpdateParticipantDonation extends AdminEvent {
  final String participantId;
  final bool hasDonation;

  const UpdateParticipantDonation({
    required this.participantId,
    required this.hasDonation,
  });

  @override
  List<Object?> get props => [participantId, hasDonation];
}

class UpdateEvent extends AdminEvent {
  final String eventId;
  final String name;
  final List<ParticipantModel> participants;
  final List<JudgeModel> judges;
  final int audienceBallotCount;
  final Uint8List? logoBytes;
  final String? logoMimeType;

  const UpdateEvent({
    required this.eventId,
    required this.name,
    required this.participants,
    required this.judges,
    required this.audienceBallotCount,
    this.logoBytes,
    this.logoMimeType,
  });

  @override
  List<Object?> get props => [eventId, name, participants, judges, audienceBallotCount];
}

class UpdateParticipantDropout extends AdminEvent {
  final String participantId;
  final bool droppedOut;

  const UpdateParticipantDropout({
    required this.participantId,
    required this.droppedOut,
  });

  @override
  List<Object?> get props => [participantId, droppedOut];
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
  final bool isUpdatingEvent;
  final ClosingProgress closingProgress;

  const AdminLoaded({
    this.currentEvent,
    this.ballots = const [],
    this.isCreatingEvent = false,
    this.isUpdatingEvent = false,
    this.closingProgress = ClosingProgress.none,
  });

  // Get votingResults from currentEvent (persisted in Firestore)
  VotingResults? get votingResults => currentEvent?.votingResults;

  bool get isClosingVoting => closingProgress != ClosingProgress.none &&
      closingProgress != ClosingProgress.exportComplete &&
      closingProgress != ClosingProgress.refetchComplete;

  bool get isBusy => isCreatingEvent || isUpdatingEvent || isClosingVoting;

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
      [currentEvent, ballots, isCreatingEvent, isUpdatingEvent, closingProgress];

  AdminLoaded copyWith({
    EventModel? currentEvent,
    List<BallotModel>? ballots,
    bool? isCreatingEvent,
    bool? isUpdatingEvent,
    ClosingProgress? closingProgress,
    bool clearEvent = false,
  }) {
    return AdminLoaded(
      currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      ballots: ballots ?? this.ballots,
      isCreatingEvent: isCreatingEvent ?? this.isCreatingEvent,
      isUpdatingEvent: isUpdatingEvent ?? this.isUpdatingEvent,
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
  final StorageService _storageService;

  StreamSubscription<EventModel?>? _eventSubscription;
  StreamSubscription<List<BallotModel>>? _ballotsSubscription;
  String? _currentEventId;

  AdminBloc({
    required EventRepository eventRepository,
    required BallotRepository ballotRepository,
    required GoogleSheetsService sheetsService,
    StorageService? storageService,
  })  : _eventRepository = eventRepository,
        _ballotRepository = ballotRepository,
        _sheetsService = sheetsService,
        _storageService = storageService ?? StorageService(),
        super(const AdminInitial()) {
    on<StartWatching>(_onStartWatching);
    on<_EventUpdated>(_onEventUpdated);
    on<_BallotsUpdated>(_onBallotsUpdated);
    on<_StreamError>(_onStreamError);
    on<CreateEvent>(_onCreateEvent);
    on<UpdateEvent>(_onUpdateEvent);
    on<CloseVoting>(_onCloseVoting);
    on<RefetchResults>(_onRefetchResults);
    on<UpdateDonationWinner>(_onUpdateDonationWinner);
    on<UpdateParticipantDonation>(_onUpdateParticipantDonation);
    on<UpdateParticipantDropout>(_onUpdateParticipantDropout);
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

      final judgesWithIds = event.judges.asMap().entries.map((entry) {
        return entry.value.copyWith(id: 'j${entry.key + 1}');
      }).toList();

      var newEvent = await _eventRepository.createEvent(
        EventModel(
          id: '',
          name: event.name,
          participants: participants,
          judges: judgesWithIds,
          status: EventStatus.open,
          createdAt: DateTime.now(),
          logoUrl: event.previousLogoUrl,
        ),
      );

      // Upload new logo if provided; otherwise previousLogoUrl is already set.
      if (event.logoBytes != null && event.logoMimeType != null) {
        final logoUrl = await _storageService.uploadEventLogo(
          newEvent.id,
          event.logoBytes!,
          event.logoMimeType!,
        );
        newEvent = newEvent.copyWith(logoUrl: logoUrl);
        await _eventRepository.updateEvent(newEvent);
      }

      final ballots = await _ballotRepository.createBallotsAndReturn(
        eventId: newEvent.id,
        audienceCount: event.audienceBallotCount,
        judges: judgesWithIds,
      );

      // Emit AdminLoaded directly - streams will update with any changes
      emit(AdminLoaded(currentEvent: newEvent, ballots: ballots));
    } catch (e, stackTrace) {
      _log.severe('Failed to create event', e, stackTrace);
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onUpdateEvent(
    UpdateEvent event,
    Emitter<AdminState> emit,
  ) async {
    var currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) return;

    final existingEvent = currentState.currentEvent!;
    emit(currentState.copyWith(isUpdatingEvent: true));

    try {
      // Assign IDs to new participants (empty id = new), preserving existing IDs.
      final existingParticipants = existingEvent.participants;
      final usedPIds = existingParticipants.map((p) => p.id).toSet();
      int nextPNum = existingParticipants.length + 1;
      String nextParticipantId() {
        while (usedPIds.contains('p$nextPNum')) {
          nextPNum++;
        }
        final id = 'p${nextPNum++}';
        usedPIds.add(id);
        return id;
      }

      final updatedParticipants = event.participants.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final id = p.id.isEmpty ? nextParticipantId() : p.id;
        final existing = existingParticipants.firstWhereOrNull((ep) => ep.id == id);
        return ParticipantModel(
          id: id,
          name: p.name,
          order: i + 1,
          hasDonation: existing?.hasDonation ?? false,
          droppedOut: existing?.droppedOut ?? false,
        );
      }).toList();

      // Assign IDs to new judges (empty id = new), preserving existing IDs.
      final usedJIds = existingEvent.judges.map((j) => j.id).toSet();
      int nextJNum = existingEvent.judges.length + 1;
      String nextJudgeId() {
        while (usedJIds.contains('j$nextJNum')) {
          nextJNum++;
        }
        final id = 'j${nextJNum++}';
        usedJIds.add(id);
        return id;
      }

      final updatedJudges = event.judges.map((j) {
        return j.id.isEmpty ? j.copyWith(id: nextJudgeId()) : j;
      }).toList();

      // Upload new logo if provided.
      String? logoUrl = existingEvent.logoUrl;
      if (event.logoBytes != null && event.logoMimeType != null) {
        logoUrl = await _storageService.uploadEventLogo(
          existingEvent.id,
          event.logoBytes!,
          event.logoMimeType!,
        );
      }

      // Persist updated event document.
      final updatedEvent = existingEvent.copyWith(
        name: event.name,
        participants: updatedParticipants,
        judges: updatedJudges,
        logoUrl: logoUrl,
      );
      await _eventRepository.updateEvent(updatedEvent);

      // Add audience ballots if count increased (cannot remove existing).
      final existingAudienceCount = currentState.audienceBallotCount;
      if (event.audienceBallotCount > existingAudienceCount) {
        await _ballotRepository.createBallotsAndReturn(
          eventId: existingEvent.id,
          audienceCount: event.audienceBallotCount - existingAudienceCount,
          judges: [],
        );
      }

      // Sync judge ballots by judgeId.
      final existingJudgeBallots =
          currentState.ballots.where((b) => b.isJudge).toList();

      for (final judge in updatedJudges) {
        final existing = existingJudgeBallots
            .firstWhereOrNull((b) => b.judgeId == judge.id);
        if (existing != null) {
          if (existing.judgeName != judge.name ||
              existing.judgeWeight != judge.weight) {
            await _ballotRepository.updateBallot(
              existing.copyWith(judgeName: judge.name, judgeWeight: judge.weight),
            );
          }
        } else {
          await _ballotRepository.createBallotsAndReturn(
            eventId: existingEvent.id,
            audienceCount: 0,
            judges: [judge],
          );
        }
      }

      // Delete unsubmitted ballots for removed judges.
      final updatedJudgeIds = updatedJudges.map((j) => j.id).toSet();
      for (final ballot in existingJudgeBallots) {
        if (ballot.judgeId != null &&
            !updatedJudgeIds.contains(ballot.judgeId) &&
            !ballot.submitted) {
          await _ballotRepository.deleteBallot(ballot.code);
        }
      }

      currentState = state as AdminLoaded;
      emit(currentState.copyWith(
        currentEvent: updatedEvent,
        isUpdatingEvent: false,
      ));
    } catch (e, stackTrace) {
      _log.severe('Failed to update event', e, stackTrace);
      if (state is AdminLoaded) {
        emit((state as AdminLoaded).copyWith(isUpdatingEvent: false));
      }
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

      // Step 2: Fetch all ballots AFTER voting is closed to ensure we capture
      // any last-second submissions (no new submissions possible after close)
      final ballotData = await _ballotRepository.getEventBallots(eventData.id);

      // Step 3: Export ballots to Google Sheets
      currentState = currentState.copyWith(closingProgress: ClosingProgress.exportingBallots);
      emit(currentState);
      final spreadsheetUrl = await _sheetsService.createResultsSpreadsheet(
        event: eventData,
        ballots: ballotData,
      );
      await _eventRepository.updateSpreadsheetUrl(eventData.id, spreadsheetUrl);

      // Step 4: Fetch results from spreadsheet
      currentState = currentState.copyWith(closingProgress: ClosingProgress.fetchingResults);
      emit(currentState);
      final results = await _fetchResults(
        event: eventData,
        spreadsheetUrl: spreadsheetUrl,
      );

      // Step 5: Save results to Firestore
      await _eventRepository.updateVotingResults(eventData.id, results);

      // Step 6: Update local state immediately and complete (stream will eventually sync)
      final updatedEvent = eventData.copyWith(
        status: EventStatus.closed,
        spreadsheetUrl: spreadsheetUrl,
        votingResults: results,
      );
      emit(currentState.copyWith(
        currentEvent: updatedEvent,
        closingProgress: ClosingProgress.exportComplete,
      ));
    } catch (e, stackTrace) {
      _log.severe('Failed to close voting', e, stackTrace);
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
    } catch (e, stackTrace) {
      _log.severe('Failed to refetch results', e, stackTrace);
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
    } catch (e, stackTrace) {
      _log.severe('Failed to update donation winners', e, stackTrace);
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onUpdateParticipantDropout(
    UpdateParticipantDropout event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    final currentEvent = currentState.currentEvent!;
    final updatedParticipants = currentEvent.participants.map((p) {
      if (p.id != event.participantId) return p;
      // Clearing donation when marking as dropped out
      return p.copyWith(
        droppedOut: event.droppedOut,
        hasDonation: event.droppedOut ? false : p.hasDonation,
      );
    }).toList();

    try {
      await _eventRepository.updateParticipants(
        currentEvent.id,
        updatedParticipants,
      );

      if (!event.droppedOut) {
        await _ballotRepository.clearParticipantVotes(
          currentEvent.id,
          event.participantId,
        );
      }
    } catch (e, stackTrace) {
      _log.severe('Failed to update participant dropout', e, stackTrace);
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onUpdateParticipantDonation(
    UpdateParticipantDonation event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    final currentEvent = currentState.currentEvent!;
    final updatedParticipants = currentEvent.participants.map((p) {
      return p.id == event.participantId
          ? p.copyWith(hasDonation: event.hasDonation)
          : p;
    }).toList();

    try {
      await _eventRepository.updateParticipants(
        currentEvent.id,
        updatedParticipants,
      );
      // Stream will automatically update state
    } catch (e, stackTrace) {
      _log.severe('Failed to update participant donation', e, stackTrace);
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
