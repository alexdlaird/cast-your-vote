import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cast_your_vote/presentation/ui/layout/app_scaffold.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:cast_your_vote/presentation/ui/utils/snack_bar_helper.dart';
import 'package:cast_your_vote/presentation/ui/components/stepper_field.dart';
import 'package:cast_your_vote/presentation/features/vote/bloc/ballot_bloc.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/data/repositories/ballot_repository_impl.dart';
import 'package:cast_your_vote/data/repositories/event_repository_impl.dart';

class JudgeBallotScreen extends StatelessWidget {
  final String ballotCode;

  const JudgeBallotScreen({
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
      child: const _JudgeBallotView(),
    );
  }
}

class _JudgeBallotView extends StatefulWidget {
  const _JudgeBallotView();

  @override
  State<_JudgeBallotView> createState() => _JudgeBallotViewState();
}

class _JudgeBallotViewState extends State<_JudgeBallotView> {
  int _currentParticipantIndex = 0;
  final PageController _pageController = PageController();
  String? _openCommentCategory;
  int _lastRoundIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToParticipant(int index) {
    setState(() {
      _currentParticipantIndex = index;
      _openCommentCategory = null;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onVoteAndNext(
    BuildContext context,
    List<ParticipantModel> participants,
    Map<String, JudgeVote> votes,
  ) {
    if (_currentParticipantIndex < participants.length - 1) {
      _goToParticipant(_currentParticipantIndex + 1);
    }
  }

  bool _canSubmit(Map<String, JudgeVote> votes, int participantCount) {
    if (votes.length != participantCount) return false;
    for (final vote in votes.values) {
      if (!_isVoteComplete(vote)) {
        return false;
      }
    }
    return true;
  }

  bool _isVoteComplete(JudgeVote vote) {
    return vote.singing != 0 && vote.performance != 0 && vote.songFit != 0;
  }

  bool _isVotePartial(JudgeVote vote) {
    final filledCount = (vote.singing != 0 ? 1 : 0) +
        (vote.performance != 0 ? 1 : 0) +
        (vote.songFit != 0 ? 1 : 0);
    return filledCount > 0 && filledCount < 3;
  }

  void _onRoundChanged(BallotLoaded state) {
    if (state.ballot.currentRoundIndex != _lastRoundIndex) {
      _lastRoundIndex = state.ballot.currentRoundIndex;
      setState(() {
        _currentParticipantIndex = 0;
        _openCommentCategory = null;
      });
      _pageController.jumpToPage(0);
    }
  }

  void _confirmAdvanceRound(BuildContext context, BallotLoaded state) {
    final roundNum = state.ballot.currentRoundIndex + 1;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lock Votes?'),
        content: Text(
          'Once you advance to the next round, your Round $roundNum votes will be locked in. Continue?',
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
                    context.read<BallotBloc>().add(const AdvanceRound());
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BallotBloc, BallotState>(
      listenWhen: (_, current) =>
          current is BallotError || current is BallotLoaded,
      listener: (context, state) {
        if (state is BallotError) {
          SnackBarHelper.show(context, state.message, type: SnackType.error);
        } else if (state is BallotLoaded) {
          _onRoundChanged(state);
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
        title: const Text('Votes Submitted'),
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
              'Thank you for judging!',
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
    final round = state.currentRound!;
    final votes = state.ballot.judgeVotesForRound(round.id);
    final canSubmit = _canSubmit(votes, participants.length);
    final isLastParticipant = _currentParticipantIndex == participants.length - 1;
    final judgeName = state.ballot.judgeName;
    final isMultiRound = state.event.isMultiRound;

    return AppScaffold(
      title: 'Judge Ballot',
      eventName: state.event.name,
      actions: [
        if (isMultiRound)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Round ${round.order} of ${state.totalRounds}',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (isMultiRound && judgeName != null) const SizedBox(width: 8),
        if (judgeName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              judgeName,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          _buildProgressIndicator(context, participants.length, votes),
          _buildParticipantPages(participants, votes, round),
          _buildNavigationControls(
            context,
            state,
            participants,
            votes,
            canSubmit,
            isLastParticipant,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    BuildContext context,
    int participantCount,
    Map<String, JudgeVote> votes,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performer ${_currentParticipantIndex + 1} of $participantCount',
                style: context.textTheme.bodySmall,
              ),
              Text(
                '${votes.values.where(_isVoteComplete).length}/$participantCount scored',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentParticipantIndex + 1) / participantCount,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantPages(
    List<ParticipantModel> participants,
    Map<String, JudgeVote> votes,
    RoundModel round,
  ) {
    return Expanded(
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentParticipantIndex = index;
            _openCommentCategory = null;
          });
        },
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          final vote = votes[participant.id] ??
              const JudgeVote(singing: 0, performance: 0, songFit: 0);
          final entryTitle = round.entryForParticipant(participant.id)?.title;
          return _buildParticipantPage(
            context,
            participant,
            vote,
            index,
            participants.length,
            entryTitle: entryTitle,
          );
        },
      ),
    );
  }

  Widget _buildNavigationControls(
    BuildContext context,
    BallotLoaded state,
    List<ParticipantModel> participants,
    Map<String, JudgeVote> votes,
    bool canSubmit,
    bool isLastParticipant,
  ) {
    final isMultiRound = state.event.isMultiRound;
    final isLastRound = state.isOnLastRound;
    final isBusy = state.isSubmitting || state.isAdvancingRound;

    Widget primaryButton;
    if (isBusy) {
      primaryButton = const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (isLastParticipant && isMultiRound && !isLastRound) {
      primaryButton = ElevatedButton(
        onPressed: canSubmit ? () => _confirmAdvanceRound(context, state) : null,
        child: Text(canSubmit ? 'Submit & Continue' : 'Rank all performers to continue'),
      );
    } else if (isLastParticipant) {
      // Last participant of the final round (or single-round) → "Submit"
      primaryButton = ElevatedButton(
        onPressed: canSubmit
            ? () => context.read<BallotBloc>().add(const SubmitBallot())
            : null,
        child: Text(canSubmit ? 'Submit All Votes' : 'Rank all performers to continue'),
      );
    } else {
      primaryButton = ElevatedButton(
        onPressed: () => _onVoteAndNext(context, participants, votes),
        child: const Text('Next'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNavigationDots(context, participants, votes),
          const SizedBox(height: 16),
          primaryButton,
          if (_currentParticipantIndex > 0) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _goToParticipant(_currentParticipantIndex - 1),
              child: const Text('Previous'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationDots(
    BuildContext context,
    List<ParticipantModel> participants,
    Map<String, JudgeVote> votes,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(
        participants.length,
        (index) {
          final participant = participants[index];
          final vote = votes[participant.id];
          Color dotColor;
          if (participant.droppedOut) {
            dotColor = index == _currentParticipantIndex
                ? context.colorScheme.error
                : context.colorScheme.errorContainer;
          } else if (index == _currentParticipantIndex) {
            dotColor = context.colorScheme.primary;
          } else if (vote != null && _isVoteComplete(vote)) {
            dotColor = context.colorScheme.primaryContainer;
          } else if (vote != null && _isVotePartial(vote)) {
            dotColor = context.colorScheme.tertiaryContainer;
          } else {
            dotColor = context.colorScheme.surfaceContainerHighest;
          }
          return GestureDetector(
            onTap: () => _goToParticipant(index),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticipantPage(
    BuildContext context,
    ParticipantModel participant,
    JudgeVote vote,
    int index,
    int total, {
    String? entryTitle,
  }) {
    if (participant.droppedOut) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              participant.displayName,
              style: context.textTheme.titleLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 56,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This performer dropped out',
                    style: context.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            children: [
              Text(
                participant.displayName,
                style: context.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (entryTitle != null && entryTitle.isNotEmpty)
                Text(
                  entryTitle,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildCategoryRow(
                  context,
                  label: 'Singing',
                  icon: Icons.mic,
                  value: vote.singing,
                  comment: vote.singingComments,
                  isCommentOpen: _openCommentCategory == 'singing',
                  onCommentToggle: () => setState(() => _openCommentCategory =
                      _openCommentCategory == 'singing' ? null : 'singing'),
                  onScoreChanged: (v) => _updateVote(
                      context, participant.id, vote.copyWith(singing: v)),
                  onCommentSaved: (v) => _updateVote(context, participant.id,
                      vote.copyWith(singingComments: v)),
                ),
                const SizedBox(height: 24),
                _buildCategoryRow(
                  context,
                  label: 'Performance',
                  icon: Icons.theater_comedy,
                  value: vote.performance,
                  comment: vote.performanceComments,
                  isCommentOpen: _openCommentCategory == 'performance',
                  onCommentToggle: () => setState(() => _openCommentCategory =
                      _openCommentCategory == 'performance'
                          ? null
                          : 'performance'),
                  onScoreChanged: (v) => _updateVote(
                      context, participant.id, vote.copyWith(performance: v)),
                  onCommentSaved: (v) => _updateVote(context, participant.id,
                      vote.copyWith(performanceComments: v)),
                ),
                const SizedBox(height: 24),
                _buildCategoryRow(
                  context,
                  label: 'Song Fit',
                  icon: Icons.people,
                  value: vote.songFit,
                  comment: vote.songFitComments,
                  isCommentOpen: _openCommentCategory == 'songFit',
                  onCommentToggle: () => setState(() => _openCommentCategory =
                      _openCommentCategory == 'songFit'
                          ? null
                          : 'songFit'),
                  onScoreChanged: (v) => _updateVote(context, participant.id,
                      vote.copyWith(songFit: v)),
                  onCommentSaved: (v) => _updateVote(context, participant.id,
                      vote.copyWith(songFitComments: v)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int value,
    required String comment,
    required bool isCommentOpen,
    required VoidCallback onCommentToggle,
    required ValueChanged<int> onScoreChanged,
    required ValueChanged<String> onCommentSaved,
  }) {
    final hasComment = comment.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: context.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: context.textTheme.titleMedium),
                ),
                IconButton(
                  icon: Icon(
                    Icons.comment,
                    size: 20,
                    color: hasComment || isCommentOpen
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: isCommentOpen ? 'Close comment' : 'Add comment',
                  onPressed: onCommentToggle,
                ),
              ],
            ),
            const SizedBox(height: 16),
            StepperField(
              value: value,
              min: 1,
              max: 5,
              onChanged: onScoreChanged,
            ),
            if (isCommentOpen) ...[
              const SizedBox(height: 12),
              _CategoryCommentField(
                key: ValueKey('comment_$label'),
                initialValue: comment,
                onSave: onCommentSaved,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateVote(
    BuildContext context,
    String participantId,
    JudgeVote vote,
  ) {
    final state = context.read<BallotBloc>().state;
    if (state is! BallotLoaded) return;
    context.read<BallotBloc>().add(UpdateJudgeVote(
          roundId: state.currentRound!.id,
          participantId: participantId,
          vote: vote,
        ));
  }
}

class _CategoryCommentField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onSave;

  const _CategoryCommentField({
    super.key,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_CategoryCommentField> createState() => _CategoryCommentFieldState();
}

class _CategoryCommentFieldState extends State<_CategoryCommentField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _lastSavedValue = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSavedValue = widget.initialValue;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_CategoryCommentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _lastSavedValue = widget.initialValue;
    }
  }

  @override
  void dispose() {
    // Save on dispose so closing the field persists whatever was typed
    if (_controller.text != _lastSavedValue) {
      widget.onSave(_controller.text);
    }
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _controller.text != _lastSavedValue) {
      _lastSavedValue = _controller.text;
      widget.onSave(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      maxLines: 2,
      decoration: const InputDecoration(
        hintText: 'Optional comments for the performer ...',
        isDense: true,
      ),
    );
  }
}
