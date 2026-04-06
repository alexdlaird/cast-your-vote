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
              return BlocBuilder<AdminBloc, AdminState>(
                buildWhen: (previous, current) {
                  if (current is! AdminLoaded) return false;
                  // Already built with fully-loaded data — don't rebuild.
                  if (previous is AdminLoaded &&
                      (previous.currentEvent == null || previous.ballotsInitialized)) {
                    return false;
                  }
                  // Wait until ballots have arrived (or there's no event yet).
                  return current.currentEvent == null || current.ballotsInitialized;
                },
                builder: (context, adminState) {
                  if (adminState is! AdminLoaded) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  String? editEventId;
                  String? previousEventName;
                  List<ParticipantModel>? previousParticipants;
                  List<JudgeModel>? previousJudges;
                  int? previousAudienceCount;

                  if (adminState.currentEvent != null) {
                    final currentEvent = adminState.currentEvent!;
                    editEventId = currentEvent.id;
                    previousEventName = currentEvent.name;
                    previousParticipants = List<ParticipantModel>.from(
                      currentEvent.participants,
                    )..sort((a, b) => a.order.compareTo(b.order));
                    previousJudges = currentEvent.judges;
                    previousAudienceCount = adminState.audienceBallotCount;
                  }

                  return CreateEventScreen(
                    editEventId: editEventId,
                    previousEventName: previousEventName,
                    previousParticipants: previousParticipants,
                    previousJudges: previousJudges,
                    previousAudienceCount: previousAudienceCount,
                    previousLogoUrl: adminState.currentEvent?.logoUrl,
                    previousRounds: adminState.currentEvent?.rounds ?? const [],
                  );
                },
              );
            },
          ),
          GoRoute(
            path: AppRoutes.adminRounds,
            builder: (context, state) => const RoundsScreen(),
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
