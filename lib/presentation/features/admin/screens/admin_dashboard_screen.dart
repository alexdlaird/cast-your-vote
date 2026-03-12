import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:theatre_121/config/app_routes.dart';

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
        listenWhen: (previous, current) {
          if (current is AdminError) return true;

          if (previous is AdminLoaded &&
              previous.isClosingVoting &&
              current is AdminLoaded &&
              !current.isClosingVoting &&
              current.currentEvent != null &&
              !current.currentEvent!.isVotingOpen) {
            return true;
          }
          return false;
        },
        listener: (context, state) {
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is AdminLoaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voting closed. Google Sheets export coming soon.'),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminInitial || state is AdminLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AdminLoaded) {
            return _buildDashboard(context, state);
          }

          return const Center(child: Text('Something went wrong'));
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, AdminLoaded state) {
    final event = state.currentEvent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event == null) ...[
            _buildNoEventCard(context),
          ] else ...[
            _buildCurrentEventCard(context, event, state),
            const SizedBox(height: 16),
            _buildBallotStatsCard(context, state),
            const SizedBox(height: 16),
            _buildActionsCard(context, state),
          ],
        ],
      ),
    );
  }

  Widget _buildNoEventCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
              'Create a new event to start accepting votes',
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
        ),
      ),
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

  Widget _buildActionsCard(BuildContext context, AdminLoaded state) {
    final event = state.currentEvent;

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
            if (event?.isVotingOpen == true)
              ElevatedButton.icon(
                onPressed: state.isClosingVoting
                    ? null
                    : () => _confirmCloseVoting(context),
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
                    : const Icon(Icons.lock),
                label: Text(state.isClosingVoting
                    ? ''
                    : 'Close Voting & Export to Sheets'),
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

  void _navigateToCreateEvent(BuildContext context) {
    context.go(AppRoutes.adminCreateEvent);
  }

  void _confirmCloseVoting(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close Voting?'),
        content: const Text(
          'This will close voting and export results to Google Sheets. No more votes will be accepted.',
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
                  child: const Text('Close & Export'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
