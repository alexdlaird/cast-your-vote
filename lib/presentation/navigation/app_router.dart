import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/presentation/features/vote/screens/ballot_entry_screen.dart';
import 'package:theatre_121/presentation/features/vote/screens/ballot_validator_screen.dart';
import 'package:theatre_121/presentation/features/admin/screens/admin_login_screen.dart';
import 'package:theatre_121/presentation/features/admin/screens/admin_dashboard_screen.dart';
import 'package:theatre_121/presentation/features/admin/screens/ballot_codes_screen.dart';
import 'package:theatre_121/presentation/features/admin/screens/create_event_screen.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:theatre_121/data/repositories/event_repository_impl.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/data/repositories/ballot_repository_impl.dart';
import 'package:theatre_121/data/services/google_sheets_service_impl.dart';

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
              final adminState = context.read<AdminBloc>().state;
              String? previousEventName;
              List<String>? previousParticipants;
              List<JudgeModel>? previousJudges;
              int? previousAudienceCount;
              bool hasExistingEvent = false;

              if (adminState is AdminLoaded && adminState.currentEvent != null) {
                hasExistingEvent = true;
                previousEventName = adminState.currentEvent!.name;

                // Filter out eliminated participant if there's a clear elimination (no tie)
                final eliminatedId = adminState.votingResults?.eliminatedParticipantId;
                previousParticipants = adminState.currentEvent!.participants
                    .where((p) => eliminatedId == null || p.id != eliminatedId)
                    .map((p) => p.name)
                    .toList();

                previousJudges = adminState.currentEvent!.judges;
                previousAudienceCount = adminState.audienceBallotCount;
              }

              return CreateEventScreen(
                hasExistingEvent: hasExistingEvent,
                previousEventName: previousEventName,
                previousParticipants: previousParticipants,
                previousJudges: previousJudges,
                previousAudienceCount: previousAudienceCount,
              );
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
