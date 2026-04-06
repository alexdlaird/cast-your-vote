import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:cast_your_vote/presentation/ui/utils/snack_bar_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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

    final adminState = context.watch<AdminBloc>().state;
    final eventName = adminState is AdminLoaded
        ? adminState.currentEvent?.name
        : null;

    return Title(
      color: Theme.of(context).primaryColor,
      title: eventName != null ? 'Admin | $eventName' : 'Cast Your Vote!',
      child: Scaffold(
        appBar: AppBar(
          title: Text(eventName ?? 'Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
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
        SnackBarHelper.show(context, 'Refetched results from spreadsheet');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    SnackBarHelper.show(context, message, type: SnackType.error);
  }

  void _showExportSuccess(BuildContext context, String spreadsheetUrl) {
    SnackBarHelper.show(
      context,
      'Spreadsheet generated successfully & results fetched',
      seconds: 6,
      type: SnackType.info,
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
          _buildDonationWinnersCard(
            context,
            event,
            isEditable: event.isVotingOpen && !state.isBusy,
          ),
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
        Text('No Active Event', style: context.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Create your first event to start accepting votes',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _navigateToCreateEvent(context),
          icon: const Icon(Icons.add),
          label: const Text('New Event'),
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
                  child: Text(event.name, style: context.textTheme.titleLarge),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
              '${event.participantCount} Performers',
              style: context.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  (List.of(event.participants)
                        ..sort((a, b) => a.order.compareTo(b.order)))
                      .map<Widget>(
                        (p) => _ParticipantChip(
                          participant: p,
                          isEditable: event.isVotingOpen && !state.isBusy,
                          onDonationTap: () => context.read<AdminBloc>().add(
                            UpdateParticipantDonation(
                              participantId: p.id,
                              hasDonation: !p.hasDonation,
                            ),
                          ),
                          onDropoutTap: () => context.read<AdminBloc>().add(
                            UpdateParticipantDropout(
                              participantId: p.id,
                              droppedOut: !p.droppedOut,
                            ),
                          ),
                        ),
                      )
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
            Text('Ballot Statistics', style: context.textTheme.titleMedium),
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
                if (state.judgeBallotCount > 0)
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
        Text(value, style: context.textTheme.headlineSmall),
        Text(label, style: context.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildVotingResultsCard(BuildContext context, AdminLoaded state) {
    final results = state.votingResults!;
    final eliminated = results.eliminatedParticipant;
    final tiedParticipants = results.tiedParticipants;
    final isRefetching =
        state.closingProgress == ClosingProgress.refetchingResults;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Voting Results', style: context.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: state.isClosingVoting
                      ? null
                      : () => context.read<AdminBloc>().add(
                          const RefetchResults(),
                        ),
                  icon: isRefetching || state.isClosingVoting
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
                    final url = state.currentEvent?.spreadsheetUrl;
                    if (url != null) launchUrl(Uri.parse(url));
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
                    Icon(Icons.person_remove, color: Colors.red.shade700),
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
            _buildRankingsColumns(context, results),
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
              onPressed: state.isBusy
                  ? null
                  : () => context.go(AppRoutes.adminBallots),
              icon: const Icon(Icons.qr_code),
              label: const Text('View Ballot Codes'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: state.isClosingVoting
                  ? null
                  : () => isVotingOpen
                        ? _confirmCloseVoting(context, event!)
                        : _confirmReExport(context, event!),
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
              label: Text(
                state.isClosingVoting
                    ? state.closingProgressText
                    : isVotingOpen
                    ? 'Lock Voting'
                    : 'Re-Export Ballots',
              ),
            ),
            if (isVotingOpen) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.isBusy
                    ? null
                    : () =>
                          context.go('${AppRoutes.adminCreateEvent}?edit=true'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Event'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => _navigateToCreateEvent(context),
              icon: const Icon(Icons.add),
              label: const Text('New Event'),
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
            Text('Bonus Points', style: context.textTheme.titleMedium),
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
                  UpdateDonationWinner(largestDonationWinnerId: value),
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
                  UpdateDonationWinner(mostDonationsWinnerId: value),
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
            isExpanded: true,
            initialValue: selectedId,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('Select performer', overflow: TextOverflow.ellipsis),
            items: participants
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                  ),
                )
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

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: context.colorScheme.error, size: 24),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.error,
                    foregroundColor: context.colorScheme.onError,
                  ),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      context.go(AppRoutes.adminLogin);
                    }
                  },
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmCloseVoting(BuildContext context, EventModel event) {
    final state = context.read<AdminBloc>().state;
    if (state is! AdminLoaded) return;

    final errors = <String>[];
    if (state.submittedAudienceCount == 0) {
      errors.add('at least one audience ballot');
    }
    if (state.judgeBallotCount > 0 && state.submittedJudgeCount == 0) {
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
    if (event.largestDonationWinnerId == null) {
      missingBonusPoints.add('Largest Donation');
    }
    if (event.mostDonationsWinnerId == null) {
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
        title: const Text('Lock Voting?'),
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
                  child: const Text('Lock'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankingsColumns(BuildContext context, VotingResults results) {
    final rankings = results.rankings;
    final half = (rankings.length / 2).ceil();
    final leftColumn = rankings.sublist(0, half);
    final rightColumn = rankings.sublist(half);

    Widget rankingItem(int index, ParticipantResult result) {
      final isEliminated = result.id == results.eliminatedParticipantId;
      final isTied = results.tiedParticipantIds.contains(result.id);
      final highlightColor = isTied
          ? Colors.orange.shade700
          : isEliminated
          ? Colors.red.shade700
          : null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
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
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                result.name,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: highlightColor,
                  decoration: isEliminated ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < leftColumn.length; i++)
                rankingItem(i, leftColumn[i]),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rightColumn.length; i++)
                rankingItem(half + i, rightColumn[i]),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmReExport(BuildContext context, EventModel event) {
    final hasExisting = event.spreadsheetUrl != null;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Re-Export Ballots?'),
        content: Text(
          hasExisting
              ? "This will re-export ballot data and overwrite any custom changes you've made to the Google Sheet for this event. Do you want to continue?"
              : 'This will export ballot data to a new Google Sheet and calculate results.',
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
                  child: Text(hasExisting ? 'Overwrite' : 'Export'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final ParticipantModel participant;
  final bool isEditable;
  final VoidCallback onDonationTap;
  final VoidCallback onDropoutTap;

  const _ParticipantChip({
    required this.participant,
    required this.isEditable,
    required this.onDonationTap,
    required this.onDropoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDroppedOut = participant.droppedOut;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isDroppedOut
            ? context.colorScheme.errorContainer.withValues(alpha: 0.3)
            : context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDroppedOut
              ? context.colorScheme.error.withValues(alpha: 0.3)
              : context.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${participant.order}. ${participant.displayName}',
            style: context.textTheme.bodyMedium?.copyWith(
              decoration: isDroppedOut ? TextDecoration.lineThrough : null,
              color: isDroppedOut ? context.colorScheme.onSurfaceVariant : null,
            ),
          ),
          const SizedBox(width: 4),
          Opacity(
            opacity: isEditable ? 1.0 : 0.4,
            child: Tooltip(
              message: (isEditable && !isDroppedOut)
                  ? (participant.hasDonation
                        ? 'Remove donation'
                        : 'Mark donation received')
                  : '',
              child: InkWell(
                onTap: (isEditable && !isDroppedOut) ? onDonationTap : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.attach_money,
                    size: 18,
                    color: participant.hasDonation
                        ? Colors.green.shade600
                        : context.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: isEditable ? 1.0 : 0.4,
            child: Tooltip(
              message: isEditable
                  ? (isDroppedOut ? 'Restore performer' : 'Mark as dropped out')
                  : '',
              child: InkWell(
                onTap: isEditable ? onDropoutTap : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.exit_to_app,
                    size: 18,
                    color: isDroppedOut
                        ? context.colorScheme.error
                        : context.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
