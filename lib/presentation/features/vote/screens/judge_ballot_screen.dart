import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:theatre_121/presentation/ui/layout/app_scaffold.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/ui/utils/snack_bar_helper.dart';
import 'package:theatre_121/presentation/ui/components/stepper_field.dart';
import 'package:theatre_121/presentation/features/vote/bloc/ballot_bloc.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/data/repositories/ballot_repository_impl.dart';
import 'package:theatre_121/data/repositories/event_repository_impl.dart';

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
    return vote.singing != 0 &&
        vote.performance != 0 &&
        vote.audienceParticipation != 0;
  }

  bool _isVotePartial(JudgeVote vote) {
    final filledCount = (vote.singing != 0 ? 1 : 0) +
        (vote.performance != 0 ? 1 : 0) +
        (vote.audienceParticipation != 0 ? 1 : 0);
    return filledCount > 0 && filledCount < 3;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BallotBloc, BallotState>(
      listenWhen: (_, current) => current is BallotError,
      listener: (context, state) {
        if (state is BallotError) {
          SnackBarHelper.show(context, state.message, type: SnackType.error);
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
    final votes = state.ballot.judgeVotes;
    final canSubmit = _canSubmit(votes, participants.length);
    final isLastParticipant =
        _currentParticipantIndex == participants.length - 1;
    final judgeName = state.ballot.judgeName;

    return AppScaffold(
      title: 'Judge Ballot for "${state.event.name}"',
      actions: judgeName != null
          ? [
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
            ]
          : null,
      body: Column(
        children: [
          _buildProgressIndicator(context, participants.length, votes),
          _buildParticipantPages(participants, votes),
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
                'Participant ${_currentParticipantIndex + 1} of $participantCount',
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
              const JudgeVote(
                singing: 0,
                performance: 0,
                audienceParticipation: 0,
              );
          return _buildParticipantPage(
            context,
            participant,
            vote,
            index,
            participants.length,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNavigationDots(context, participants, votes),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLastParticipant
                ? (canSubmit && !state.isSubmitting
                    ? () =>
                        context.read<BallotBloc>().add(const SubmitBallot())
                    : null)
                : () => _onVoteAndNext(context, participants, votes),
            child: state.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isLastParticipant
                        ? (canSubmit
                            ? 'Submit All Votes'
                            : 'Score All Participants')
                        : 'Next',
                  ),
          ),
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
    int total,
  ) {
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
                    'This participant dropped out',
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
          child: Text(
            participant.displayName,
            style: context.textTheme.titleLarge,
            textAlign: TextAlign.center,
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
                  value: vote.audienceParticipation,
                  comment: vote.audienceParticipationComments,
                  isCommentOpen: _openCommentCategory == 'audienceParticipation',
                  onCommentToggle: () => setState(() => _openCommentCategory =
                      _openCommentCategory == 'audienceParticipation'
                          ? null
                          : 'audienceParticipation'),
                  onScoreChanged: (v) => _updateVote(context, participant.id,
                      vote.copyWith(audienceParticipation: v)),
                  onCommentSaved: (v) => _updateVote(context, participant.id,
                      vote.copyWith(audienceParticipationComments: v)),
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
    context.read<BallotBloc>().add(
          UpdateJudgeVote(participantId: participantId, vote: vote),
        );
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
        hintText: 'Optional comments for participant ...',
        isDense: true,
      ),
    );
  }
}
