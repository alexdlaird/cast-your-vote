import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/ui/utils/snack_bar_helper.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/data/models/models.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.adminLogin);
      });
      return const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.go(AppRoutes.adminLogin);
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: BlocConsumer<AdminBloc, AdminState>(
        listenWhen: _shouldListen,
        listener: _onStateChanged,
        builder: (context, state) {
          if (state is AdminInitial || state is AdminLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AdminLoaded) {
            return _buildDashboard(context, state);
          }

          if (state is AdminError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: context.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: context.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      state.message,
                      style: context.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<AdminBloc>().add(const StartWatching());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const Center(child: Text('Something went wrong'));
        },
      ),
    );
  }

  bool _shouldListen(AdminState previous, AdminState current) {
    if (current is AdminError) return true;

    // Show snackbar when export or refetch completes
    if (current is AdminLoaded &&
        (current.closingProgress == ClosingProgress.exportComplete ||
            current.closingProgress == ClosingProgress.refetchComplete)) {
      return true;
    }
    return false;
  }

  void _onStateChanged(BuildContext context, AdminState state) {
    if (state is AdminError) {
      _showError(context, state.message);
    } else if (state is AdminLoaded) {
      if (state.closingProgress == ClosingProgress.exportComplete) {
        final spreadsheetUrl = state.currentEvent?.spreadsheetUrl;
        if (spreadsheetUrl != null) {
          _showExportSuccess(context, spreadsheetUrl);
        }
      } else if (state.closingProgress == ClosingProgress.refetchComplete) {
        SnackBarHelper.show(context, 'Calculated results refetched from spreadsheet');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    SnackBarHelper.show(context, message, type: SnackType.error);
  }

  void _showExportSuccess(BuildContext context, String spreadsheetUrl) {
    SnackBarHelper.show(
      context,
      'Spreadsheet generated successfully',
      seconds: 6,
      type: SnackType.success,
      action: SnackBarAction(
        label: 'Open Sheet',
        onPressed: () => launchUrl(Uri.parse(spreadsheetUrl)),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, AdminLoaded state) {
    final event = state.currentEvent;

    if (event == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildNoEventCard(context),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCurrentEventCard(context, event, state),
          const SizedBox(height: 16),
          if (state.votingResults != null) ...[
            _buildVotingResultsCard(context, state),
            const SizedBox(height: 16),
          ],
          _buildBallotStatsCard(context, state),
          const SizedBox(height: 16),
          _buildDonationWinnersCard(context, event, isEditable: event.isVotingOpen),
          const SizedBox(height: 16),
          _buildActionsCard(context, state),
        ],
      ),
    );
  }

  Widget _buildNoEventCard(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.event_busy,
          size: 64,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'No Active Event',
          style: context.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Create a first event to start accepting votes',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _navigateToCreateEvent(context),
          icon: const Icon(Icons.add),
          label: const Text('Create New Event'),
        ),
      ],
    );
  }

  Widget _buildCurrentEventCard(
    BuildContext context,
    event,
    AdminLoaded state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: context.textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: event.isVotingOpen
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    event.isVotingOpen ? 'Voting Open' : 'Voting Closed',
                    style: TextStyle(
                      color: event.isVotingOpen
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${event.participantCount} Participants',
              style: context.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (List.of(event.participants)
                    ..sort((a, b) => a.order.compareTo(b.order)))
                  .map<Widget>((p) => Chip(
                        label: Text('${p.order}. ${p.displayName}'),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBallotStatsCard(BuildContext context, AdminLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ballot Statistics',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Audience',
                    '${state.submittedAudienceCount}/${state.audienceBallotCount}',
                    Icons.people,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Judges',
                    '${state.submittedJudgeCount}/${state.judgeBallotCount}',
                    Icons.gavel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.ballots.isEmpty
                  ? 0
                  : state.ballots.where((b) => b.submitted).length /
                      state.ballots.length,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              '${state.ballots.where((b) => b.submitted).length} of ${state.ballots.length} ballots submitted',
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32, color: context.colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: context.textTheme.headlineSmall,
        ),
        Text(
          label,
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildVotingResultsCard(BuildContext context, AdminLoaded state) {
    final results = state.votingResults!;
    final eliminated = results.eliminatedParticipant;
    final tiedParticipants = results.tiedParticipants;
    final isRefetching = state.closingProgress == ClosingProgress.refetchingResults;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Voting Results',
                  style: context.textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: state.isClosingVoting
                      ? null
                      : () => context.read<AdminBloc>().add(const RefetchResults()),
                  icon: isRefetching
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refetch results',
                ),
                TextButton.icon(
                  onPressed: () {
                    launchUrl(Uri.parse(results.spreadsheetUrl));
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Sheet'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (results.hasTie) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tie - Judge Decision Required',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tiedParticipants.map((p) => p.name).join(', '),
                            style: context.textTheme.titleMedium?.copyWith(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${tiedParticipants.first.combinedScore} pts each',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (eliminated != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eliminated',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            eliminated.name,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${eliminated.combinedScore} pts',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Rankings',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...results.rankings.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              final isEliminated = result.id == results.eliminatedParticipantId;
              final isTied = results.tiedParticipantIds.contains(result.id);
              final highlightColor = isTied
                  ? Colors.orange.shade700
                  : isEliminated
                      ? Colors.red.shade700
                      : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: highlightColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        result.name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: highlightColor,
                          decoration: isEliminated
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      'A: ${result.audiencePoints}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'J: ${result.judgeTotal}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${result.combinedScore}',
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isEliminated ? Colors.red.shade700 : null,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, AdminLoaded state) {
    final event = state.currentEvent;
    final isVotingOpen = event?.isVotingOpen ?? true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.adminBallots),
              icon: const Icon(Icons.qr_code),
              label: const Text('View Ballot Codes'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: state.isClosingVoting
                  ? null
                  : () => isVotingOpen
                      ? _confirmCloseVoting(context, event!)
                      : context.read<AdminBloc>().add(const CloseVoting()),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.error,
                foregroundColor: context.colorScheme.onError,
              ),
              icon: state.isClosingVoting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isVotingOpen ? Icons.lock : Icons.refresh),
              label: Text(state.isClosingVoting
                  ? state.closingProgressText
                  : isVotingOpen
                      ? 'Close Voting'
                      : 'Re-Export Ballots'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _navigateToCreateEvent(context),
              icon: const Icon(Icons.add),
              label: const Text('Create New Event'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationWinnersCard(
    BuildContext context,
    EventModel event, {
    required bool isEditable,
  }) {
    final participants = List<ParticipantModel>.from(event.participants)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonus Points',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildDonationDropdown(
              context,
              label: 'Largest Donation',
              icon: Icons.attach_money,
              participants: participants,
              selectedId: event.largestDonationWinnerId,
              isEditable: isEditable,
              onChanged: (value) {
                context.read<AdminBloc>().add(
                      UpdateDonationWinner(largestDonationWinnerId: value ?? ''),
                    );
              },
            ),
            const SizedBox(height: 16),
            _buildDonationDropdown(
              context,
              label: 'Most Donations',
              icon: Icons.favorite,
              participants: participants,
              selectedId: event.mostDonationsWinnerId,
              isEditable: isEditable,
              onChanged: (value) {
                context.read<AdminBloc>().add(
                      UpdateDonationWinner(mostDonationsWinnerId: value ?? ''),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationDropdown(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<ParticipantModel> participants,
    required String? selectedId,
    required bool isEditable,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: context.colorScheme.primary),
        const SizedBox(width: 12),
        Text(label, style: context.textTheme.bodyLarge),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('Select participant'),
            items: participants
                .map((p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.displayName),
                    ))
                .toList(),
            onChanged: isEditable ? onChanged : null,
          ),
        ),
      ],
    );
  }

  void _navigateToCreateEvent(BuildContext context) {
    context.go(AppRoutes.adminCreateEvent);
  }

  void _confirmCloseVoting(BuildContext context, EventModel event) {
    final state = context.read<AdminBloc>().state;
    if (state is! AdminLoaded) return;

    // Validate at least one audience and one judge ballot submitted
    final errors = <String>[];
    if (state.submittedAudienceCount == 0) {
      errors.add('at least one audience ballot');
    }
    if (state.submittedJudgeCount == 0) {
      errors.add('at least one judge ballot');
    }

    if (errors.isNotEmpty) {
      SnackBarHelper.show(
        context,
        'Need ${errors.join(" and ")} submitted before closing voting.',
        type: SnackType.error,
      );
      return;
    }

    // Validate bonus points are selected
    final missingBonusPoints = <String>[];
    if (event.largestDonationWinnerId == null ||
        event.largestDonationWinnerId!.isEmpty) {
      missingBonusPoints.add('Largest Donation');
    }
    if (event.mostDonationsWinnerId == null ||
        event.mostDonationsWinnerId!.isEmpty) {
      missingBonusPoints.add('Most Donations');
    }

    if (missingBonusPoints.isNotEmpty) {
      SnackBarHelper.show(
        context,
        'Select ${missingBonusPoints.join(" and ")} before closing voting.',
        type: SnackType.error,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close Voting?'),
        content: const Text(
          'This will close voting and export ballot data to Google Sheets. No more votes will be accepted. The results from the Google Sheets formulas will then be shown here.',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.read<AdminBloc>().add(const CloseVoting());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.error,
                    foregroundColor: context.colorScheme.onError,
                  ),
                  child: const Text('Close Voting'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
