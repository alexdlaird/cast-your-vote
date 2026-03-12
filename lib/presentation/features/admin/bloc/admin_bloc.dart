import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/domain/repositories/event_repository.dart';
import 'package:theatre_121/domain/repositories/ballot_repository.dart';

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

class CreateEvent extends AdminEvent {
  final String name;
  final List<String> participantNames;
  final int audienceBallotCount;
  final int judgeBallotCount;

  const CreateEvent({
    required this.name,
    required this.participantNames,
    required this.audienceBallotCount,
    required this.judgeBallotCount,
  });

  @override
  List<Object?> get props =>
      [name, participantNames, audienceBallotCount, judgeBallotCount];
}

class CloseVoting extends AdminEvent {
  const CloseVoting();
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
  final bool isClosingVoting;

  const AdminLoaded({
    this.currentEvent,
    this.ballots = const [],
    this.isCreatingEvent = false,
    this.isClosingVoting = false,
  });

  int get audienceBallotCount => ballots.where((b) => b.isAudience).length;
  int get judgeBallotCount => ballots.where((b) => b.isJudge).length;
  int get submittedAudienceCount =>
      ballots.where((b) => b.isAudience && b.submitted).length;
  int get submittedJudgeCount =>
      ballots.where((b) => b.isJudge && b.submitted).length;

  @override
  List<Object?> get props =>
      [currentEvent, ballots, isCreatingEvent, isClosingVoting];

  AdminLoaded copyWith({
    EventModel? currentEvent,
    List<BallotModel>? ballots,
    bool? isCreatingEvent,
    bool? isClosingVoting,
    bool clearEvent = false,
  }) {
    return AdminLoaded(
      currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      ballots: ballots ?? this.ballots,
      isCreatingEvent: isCreatingEvent ?? this.isCreatingEvent,
      isClosingVoting: isClosingVoting ?? this.isClosingVoting,
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

  StreamSubscription<EventModel?>? _eventSubscription;
  StreamSubscription<List<BallotModel>>? _ballotsSubscription;
  String? _currentEventId;

  AdminBloc({
    required EventRepository eventRepository,
    required BallotRepository ballotRepository,
  })  : _eventRepository = eventRepository,
        _ballotRepository = ballotRepository,
        super(const AdminInitial()) {
    on<StartWatching>(_onStartWatching);
    on<_EventUpdated>(_onEventUpdated);
    on<_BallotsUpdated>(_onBallotsUpdated);
    on<CreateEvent>(_onCreateEvent);
    on<CloseVoting>(_onCloseVoting);
  }

  void _onStartWatching(
    StartWatching event,
    Emitter<AdminState> emit,
  ) {
    emit(const AdminLoading());

    _eventSubscription?.cancel();
    _eventSubscription = _eventRepository.watchCurrentEvent().listen(
      (event) => add(_EventUpdated(event)),
      onError: (e) => emit(AdminError(e.toString())),
    );
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
                  onError: (e) => emit(AdminError(e.toString())),
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
          status: EventStatus.open,
          createdAt: DateTime.now(),
        ),
      );

      final ballots = await _ballotRepository.createBallotsAndReturn(
        eventId: newEvent.id,
        audienceCount: event.audienceBallotCount,
        judgeCount: event.judgeBallotCount,
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
    final currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    emit(currentState.copyWith(isClosingVoting: true));

    try {
      await _eventRepository.closeVoting(currentState.currentEvent!.id);
      await _exportResultsToSheets(currentState.currentEvent!, currentState.ballots);
      // Stream will automatically update the state
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  /// Exports voting results to Google Sheets.
  Future<void> _exportResultsToSheets(
    EventModel event,
    List<BallotModel> ballots,
  ) async {
    // TODO: Implement Google Sheets export using googleapis package.
    // Create a new spreadsheet with event results, including:
    // - Participant rankings from audience votes
    // - Judge scores (singing, performance, audience participation)
    // - Calculated totals and final standings
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _ballotsSubscription?.cancel();
    return super.close();
  }
}
