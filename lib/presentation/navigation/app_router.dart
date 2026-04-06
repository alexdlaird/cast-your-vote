import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/presentation/features/vote/screens/ballot_entry_screen.dart';
import 'package:cast_your_vote/presentation/features/vote/screens/ballot_validator_screen.dart';
import 'package:cast_your_vote/presentation/features/admin/screens/admin_login_screen.dart';
import 'package:cast_your_vote/presentation/features/admin/screens/admin_dashboard_screen.dart';
import 'package:cast_your_vote/presentation/features/admin/screens/ballot_codes_screen.dart';
import 'package:cast_your_vote/presentation/features/admin/screens/create_event_screen.dart';
import 'package:cast_your_vote/presentation/features/admin/screens/rounds/rounds_screen.dart';
import 'package:cast_your_vote/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:cast_your_vote/data/repositories/event_repository_impl.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/data/repositories/ballot_repository_impl.dart';
import 'package:cast_your_vote/data/services/google_sheets_service_impl.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          final error = state.uri.queryParameters['error'];
          return BallotEntryScreen(errorMessage: error);
        },
      ),
      GoRoute(
        path: AppRoutes.vote,
        builder: (context, state) {
          final ballotCode = state.uri.queryParameters['ballot'];
          if (ballotCode != null && ballotCode.isNotEmpty) {
            return BallotValidatorScreen(
              ballotCode: ballotCode.toUpperCase(),
            );
          }
          return const BallotEntryScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.adminLogin,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      // Admin shell route with shared bloc
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => AdminBloc(
              eventRepository: EventRepositoryImpl(),
              ballotRepository: BallotRepositoryImpl(),
              sheetsService: GoogleSheetsServiceImpl(),
            )..add(const StartWatching()),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.admin,
            builder: (context, state) => const AdminDashboardView(),
          ),
          GoRoute(
            path: AppRoutes.adminBallots,
            builder: (context, state) => const BallotCodesScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminCreateEvent,
            builder: (context, state) {
              final isEditMode = state.uri.queryParameters['edit'] == 'true';
              final adminState = context.read<AdminBloc>().state;

              String? editEventId;
              String? previousEventName;
              List<ParticipantModel>? previousParticipants;
              List<JudgeModel>? previousJudges;
              int? previousAudienceCount;
              bool hasExistingEvent = false;

              if (adminState is AdminLoaded && adminState.currentEvent != null) {
                final currentEvent = adminState.currentEvent!;

                if (isEditMode) {
                  // Edit mode: preserve participant order and IDs.
                  editEventId = currentEvent.id;
                  previousEventName = currentEvent.name;
                  previousParticipants = List<ParticipantModel>.from(
                    currentEvent.participants,
                  )..sort((a, b) => a.order.compareTo(b.order));
                  previousJudges = currentEvent.judges;
                  previousAudienceCount = adminState.audienceBallotCount;
                } else {
                  // Create new mode: shuffle participants, reset IDs for the new event.
                  hasExistingEvent = true;
                  previousEventName = currentEvent.name;

                  final eliminatedId =
                      adminState.votingResults?.eliminatedParticipantId;
                  final filtered = currentEvent.participants
                      .where((p) => eliminatedId == null || p.id != eliminatedId)
                      .toList()
                    ..shuffle(Random());

                  previousParticipants = filtered
                      .asMap()
                      .entries
                      .map((entry) => ParticipantModel(
                            id: '',
                            name: entry.value.name,
                            order: entry.key + 1,
                          ))
                      .toList();

                  previousJudges = currentEvent.judges;
                  previousAudienceCount = adminState.audienceBallotCount;
                }
              }

              return CreateEventScreen(
                editEventId: editEventId,
                hasExistingEvent: hasExistingEvent,
                previousEventName: previousEventName,
                previousParticipants: previousParticipants,
                previousJudges: previousJudges,
                previousAudienceCount: previousAudienceCount,
                previousLogoUrl: adminState is AdminLoaded
                    ? adminState.currentEvent?.logoUrl
                    : null,
                previousRounds: isEditMode &&
                        adminState is AdminLoaded &&
                        adminState.currentEvent != null
                    ? adminState.currentEvent!.rounds
                    : const [],
              );
            },
          ),
          GoRoute(
            path: AppRoutes.adminRounds,
            builder: (context, state) {
              final args = state.extra as RoundsScreenArgs?;
              if (args == null) {
                return const SizedBox.shrink();
              }
              return RoundsScreen(args: args);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
