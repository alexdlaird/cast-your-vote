import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:theatre_121/presentation/ui/layout/app_scaffold.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/features/vote/bloc/ballot_bloc.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/data/repositories/ballot_repository_impl.dart';
import 'package:theatre_121/data/repositories/event_repository_impl.dart';

class AudienceBallotScreen extends StatelessWidget {
  final String ballotCode;

  const AudienceBallotScreen({
    super.key,
    required this.ballotCode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BallotBloc(
        ballotRepository: BallotRepositoryImpl(),
        eventRepository: EventRepositoryImpl(),
      )..add(LoadBallot(ballotCode)),
      child: const _AudienceBallotView(),
    );
  }
}

class _AudienceBallotView extends StatefulWidget {
  const _AudienceBallotView();

  @override
  State<_AudienceBallotView> createState() => _AudienceBallotViewState();
}

class _AudienceBallotViewState extends State<_AudienceBallotView> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String participantId, int? currentRank) {
    if (!_controllers.containsKey(participantId)) {
      _controllers[participantId] = TextEditingController(
        text: currentRank?.toString() ?? '',
      );
    }
    return _controllers[participantId]!;
  }

  void _onParticipantTap(
    BuildContext context,
    ParticipantModel participant,
    Map<String, int> currentVotes,
    int participantCount,
  ) {
    final currentRank = currentVotes[participant.id];

    if (currentRank != null) {
      return;
    }

    final usedRanks = currentVotes.values.toSet();
    int rank = 1;
    while (usedRanks.contains(rank) && rank <= participantCount) {
      rank++;
    }

    if (rank <= participantCount) {
      context.read<BallotBloc>().add(
            UpdateAudienceVote(participantId: participant.id, rank: rank),
          );
      _controllers[participant.id]?.text = rank.toString();
    }
  }

  void _onRankChanged(
    BuildContext context,
    String participantId,
    String value,
    int participantCount,
  ) {
    if (value.isEmpty) {
      context.read<BallotBloc>().add(
            UpdateAudienceVote(participantId: participantId, rank: null),
          );
      return;
    }

    final rank = int.tryParse(value);
    if (rank != null && rank >= 1 && rank <= participantCount) {
      context.read<BallotBloc>().add(
            UpdateAudienceVote(participantId: participantId, rank: rank),
          );
    } else {
      _controllers[participantId]?.clear();
      context.read<BallotBloc>().add(
            UpdateAudienceVote(participantId: participantId, rank: null),
          );
    }
  }

  bool _canSubmit(Map<String, int> votes, int participantCount) {
    if (votes.length != participantCount) return false;
    final ranks = votes.values.toSet();
    if (ranks.length != participantCount) return false;
    for (int i = 1; i <= participantCount; i++) {
      if (!ranks.contains(i)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BallotBloc, BallotState>(
      listener: (context, state) {
        if (state is BallotError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is BallotInitial || state is BallotLoading) {
          return _buildLoadingView(context);
        }
        if (state is BallotAlreadySubmitted || state is BallotSubmitted) {
          return _buildSubmittedView(context);
        }
        if (state is BallotVotingClosed) {
          return _buildVotingClosedView(context);
        }
        if (state is BallotLoaded) {
          return _buildBallotView(context, state);
        }
        return _buildErrorView(context);
      },
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return const AppScaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSubmittedView(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Vote Submitted'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: context.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you for voting!',
              style: context.textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingClosedView(BuildContext context) {
    return AppScaffold(
      title: 'Voting Closed',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Voting has closed',
              style: context.textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return const AppScaffold(
      title: 'Error',
      body: Center(child: Text('Something went wrong')),
    );
  }

  Widget _buildBallotView(BuildContext context, BallotLoaded state) {
    final participants = List<ParticipantModel>.from(state.event.participants)
      ..sort((a, b) => a.order.compareTo(b.order));
    final votes = state.ballot.audienceVotes;
    final canSubmit = _canSubmit(votes, participants.length);

    for (final participant in participants) {
      final rank = votes[participant.id];
      final controller = _getController(participant.id, rank);
      if (rank != null && controller.text != rank.toString()) {
        controller.text = rank.toString();
      } else if (rank == null && controller.text.isNotEmpty) {
        controller.text = '';
      }
    }

    return AppScaffold(
      title: "Ballot for '${state.event.name}'",
      actions: [
        if (votes.isNotEmpty)
          TextButton(
            onPressed: () => _confirmClearBallot(context),
            child: const Text('Reset Ballot'),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tap names in order to rank participants',
                    style: context.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '1 = Favorite, ${participants.length} = Least favorite',
                    style: context.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildParticipantGrid(
                    context,
                    participants,
                    votes,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: canSubmit && !state.isSubmitting
                  ? () => context.read<BallotBloc>().add(const SubmitBallot())
                  : null,
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(canSubmit
                      ? 'Submit Vote'
                      : 'Rank all ${participants.length} participants'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantGrid(
    BuildContext context,
    List<ParticipantModel> participants,
    Map<String, int> votes,
  ) {
    final rows = <Widget>[];

    for (int i = 0; i < participants.length; i += 2) {
      final left = participants[i];
      final right = i + 1 < participants.length ? participants[i + 1] : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildParticipantCard(
                  context,
                  left,
                  votes[left.id],
                  votes,
                  participants.length,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: right != null
                    ? _buildParticipantCard(
                        context,
                        right,
                        votes[right.id],
                        votes,
                        participants.length,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildParticipantCard(
    BuildContext context,
    ParticipantModel participant,
    int? rank,
    Map<String, int> allVotes,
    int participantCount,
  ) {
    final controller = _getController(participant.id, rank);
    final hasRank = rank != null;

    return Card(
      color: hasRank
          ? context.colorScheme.primaryContainer
          : context.colorScheme.surfaceContainerHighest,
      elevation: hasRank ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasRank
              ? context.colorScheme.primary
              : context.colorScheme.outlineVariant,
          width: hasRank ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onParticipantTap(
          context,
          participant,
          allVotes,
          participantCount,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    participant.displayName,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: hasRank ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: participantCount >= 10 ? 2 : 1,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: context.colorScheme.surface,
                  ),
                  style: context.textTheme.titleMedium,
                  onChanged: (value) => _onRankChanged(
                    context,
                    participant.id,
                    value,
                    participantCount,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearBallot(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Ballot?'),
        content: const Text('This will clear all your rankings, if  you want start over.'),
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
                    context.read<BallotBloc>().add(const ClearBallot());
                    for (final controller in _controllers.values) {
                      controller.text = '';
                    }
                  },
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
