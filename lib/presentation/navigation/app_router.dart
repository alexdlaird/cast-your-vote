// Copyright (c) 2026 Alex Laird. MIT License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/data/repositories/ballot_repository_impl.dart';
import 'package:cast_your_vote/data/repositories/event_repository_impl.dart';
import 'package:cast_your_vote/data/services/google_sheets_service_impl.dart';
import 'package:cast_your_vote/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:cast_your_vote/presentation/features/admin/screens/screens.dart';
import 'package:cast_your_vote/presentation/features/vote/screens/screens.dart';

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
              final editRequested = state.uri.queryParameters['edit'] == 'true';
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

                  final currentEvent = adminState.currentEvent;
                  // Edit mode only when explicitly requested and there is an
                  // open event to edit; otherwise fall back to create mode.
                  final isEditMode = editRequested &&
                      currentEvent != null &&
                      currentEvent.isVotingOpen;

                  List<ParticipantModel>? previousParticipants;
                  if (currentEvent != null) {
                    if (isEditMode) {
                      previousParticipants =
                          List<ParticipantModel>.from(currentEvent.participants)
                            ..sort((a, b) => a.order.compareTo(b.order));
                    } else {
                      // Create new: exclude eliminated performer, shuffle
                      // order, and reset IDs so new records are created.
                      final eliminatedId =
                          adminState.votingResults?.eliminatedParticipantId;
                      previousParticipants = (currentEvent.participants
                              .where((p) =>
                                  eliminatedId == null || p.id != eliminatedId)
                              .toList()
                            ..shuffle(Random()))
                          .asMap()
                          .entries
                          .map((e) => ParticipantModel(
                                id: '',
                                name: e.value.name,
                                order: e.key + 1,
                              ))
                          .toList();
                    }
                  }

                  return CreateEventScreen(
                    editEventId: isEditMode ? currentEvent.id : null,
                    hasExistingEvent: !isEditMode && currentEvent != null,
                    previousEventName: currentEvent?.name,
                    previousParticipants: previousParticipants,
                    previousJudges: currentEvent?.judges,
                    previousAudienceCount: adminState.audienceBallotCount,
                    previousLogoUrl: currentEvent?.logoUrl,
                    previousRounds: isEditMode ? currentEvent.rounds : const [],
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
