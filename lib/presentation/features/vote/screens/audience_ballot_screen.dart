import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/data/repositories/ballot_repository_impl.dart';
import 'package:cast_your_vote/data/repositories/event_repository_impl.dart';
import 'package:cast_your_vote/presentation/features/vote/bloc/ballot_bloc.dart';
import 'package:cast_your_vote/presentation/ui/layout/app_scaffold.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:cast_your_vote/presentation/ui/utils/snack_bar_helper.dart';

class AudienceBallotScreen extends StatelessWidget {
  final String ballotCode;

  const AudienceBallotScreen({super.key, required this.ballotCode});

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
  List<ParticipantModel> _unranked = [];
  List<ParticipantModel> _ranked = [];
  bool _initialized = false;

  void _initFromState(BallotLoaded state) {
    final active = state.event.participants.where((p) => !p.droppedOut).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final votes = state.ballot.audienceVotes;
    final ranked = active.where((p) => votes.containsKey(p.id)).toList()
      ..sort((a, b) => votes[a.id]!.compareTo(votes[b.id]!));
    final unranked = active.where((p) => !votes.containsKey(p.id)).toList();

    setState(() {
      _ranked = ranked;
      _unranked = unranked;
      _initialized = true;
    });
  }

  /// Inserts [participant] before the ranked card at [dropIndex].
  /// Adjusts for the case where the item was already in [_ranked] —
  /// removing it shifts subsequent indices by 1.
  void _dropAt(
    BuildContext context,
    ParticipantModel participant,
    int dropIndex,
  ) {
    final fromRankedIndex = _ranked.indexOf(participant);
    final wasInRanked = fromRankedIndex != -1;
    setState(() {
      _ranked.remove(participant);
      _unranked.remove(participant);
      final adjusted = (wasInRanked && fromRankedIndex < dropIndex)
          ? (dropIndex - 1).clamp(0, _ranked.length)
          : dropIndex.clamp(0, _ranked.length);
      _ranked.insert(adjusted, participant);
    });
    _syncVotes(context);
  }

  void _moveToUnranked(BuildContext context, ParticipantModel participant) {
    if (!_ranked.contains(participant)) return;
    setState(() {
      _ranked.remove(participant);
      final insertAt = _unranked.indexWhere((p) => p.order > participant.order);
      if (insertAt == -1) {
        _unranked.add(participant);
      } else {
        _unranked.insert(insertAt, participant);
      }
    });
    _syncVotes(context);
  }

  void _syncVotes(BuildContext context) {
    for (final p in _unranked) {
      context.read<BallotBloc>().add(
        UpdateAudienceVote(participantId: p.id, rank: null),
      );
    }
    for (var i = 0; i < _ranked.length; i++) {
      context.read<BallotBloc>().add(
        UpdateAudienceVote(participantId: _ranked[i].id, rank: i + 1),
      );
    }
  }

  void _resetBallot(BuildContext context, BallotLoaded state) {
    context.read<BallotBloc>().add(const ClearBallot());
    final active = state.event.participants.where((p) => !p.droppedOut).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    setState(() {
      _unranked = List.from(active);
      _ranked = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BallotBloc, BallotState>(
      listenWhen: (previous, current) =>
          current is BallotError ||
          (current is BallotLoaded && previous is! BallotLoaded),
      listener: (context, state) {
        if (state is BallotError) {
          SnackBarHelper.show(context, state.message, type: SnackType.error);
        } else if (state is BallotLoaded && !_initialized) {
          _initFromState(state);
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
    return const AppScaffold(body: Center(child: CircularProgressIndicator()));
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
            Text('Voting has closed', style: context.textTheme.headlineSmall),
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
    final droppedOut =
        state.event.participants.where((p) => p.droppedOut).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final canSubmit = _unranked.isEmpty && !state.isSubmitting;

    return AppScaffold(
      title: 'Ballot for "${state.event.name}"',
      actions: [
        if (_ranked.isNotEmpty)
          TextButton(
            onPressed: () => _confirmReset(context, state),
            child: const Text('Reset'),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildColumnHeader(
                    context,
                    'Unranked',
                    _unranked.length,
                    context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColumnHeader(
                    context,
                    'Your Ranking',
                    null,
                    context.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildUnrankedColumn(context)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildRankedColumn(context, droppedOut)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: canSubmit
                  ? () => context.read<BallotBloc>().add(const SubmitBallot())
                  : null,
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _unranked.isEmpty
                          ? 'Submit Vote'
                          : 'Rank all performers to submit',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(
    BuildContext context,
    String label,
    int? count,
    Color color,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: context.textTheme.labelLarge?.copyWith(color: color),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: context.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUnrankedColumn(BuildContext context) {
    return DragTarget<ParticipantModel>(
      onWillAcceptWithDetails: (details) => _ranked.contains(details.data),
      onAcceptWithDetails: (details) => _moveToUnranked(context, details.data),
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isHovered
                ? context.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            border: isHovered
                ? Border.all(
                    color: context.colorScheme.outlineVariant,
                    width: 1.5,
                  )
                : null,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (final p in _unranked)
                  _buildDraggableCard(context, p, isRanked: false),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankedColumn(
    BuildContext context,
    List<ParticipantModel> droppedOut,
  ) {
    if (_ranked.isEmpty) {
      return DragTarget<ParticipantModel>(
        onWillAcceptWithDetails: (d) => !d.data.droppedOut,
        onAcceptWithDetails: (d) => _dropAt(context, d.data, 0),
        builder: (ctx, candidates, _) {
          final isHovered = candidates.isNotEmpty;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isHovered
                  ? ctx.colorScheme.primary.withValues(alpha: 0.08)
                  : ctx.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
              border: Border.all(
                color: isHovered
                    ? ctx.colorScheme.primary
                    : ctx.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: isHovered ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Drag performers here to rank',
                    style: ctx.textTheme.bodySmall?.copyWith(
                      color: ctx.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                for (final p in droppedOut)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: _buildDroppedOutCard(ctx, p),
                  ),
                if (droppedOut.isNotEmpty) const SizedBox(height: 4),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _ranked.length; i++)
                  _buildRankedSlot(context, i),
                _buildTailDropZone(context),
              ],
            ),
          ),
        ),
        for (final p in droppedOut) _buildDroppedOutCard(context, p),
        if (droppedOut.isNotEmpty) const SizedBox(height: 4),
      ],
    );
  }

  /// A [DragTarget] wrapping a single ranked card. When any other card hovers
  /// over it, a thin insertion indicator appears above it, signalling that the
  /// dragged item will be placed before this one.
  Widget _buildRankedSlot(BuildContext context, int index) {
    final participant = _ranked[index];
    return DragTarget<ParticipantModel>(
      key: ValueKey('slot_${participant.id}'),
      onWillAcceptWithDetails: (d) =>
          !d.data.droppedOut && d.data.id != participant.id,
      onAcceptWithDetails: (d) => _dropAt(context, d.data, index),
      builder: (ctx, candidates, _) {
        final isHovered = candidates.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isHovered) _buildInsertionIndicator(ctx),
            _buildDraggableCard(ctx, participant, isRanked: true),
          ],
        );
      },
    );
  }

  /// Drop zone below all ranked cards — appends the dragged item at the end.
  Widget _buildTailDropZone(BuildContext context) {
    return DragTarget<ParticipantModel>(
      onWillAcceptWithDetails: (d) => !d.data.droppedOut,
      onAcceptWithDetails: (d) => _dropAt(context, d.data, _ranked.length),
      builder: (ctx, candidates, _) {
        final isHovered = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: isHovered ? 52 : 20,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: isHovered
              ? BoxDecoration(
                  color: ctx.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ctx.colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: isHovered
              ? Center(
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: ctx.colorScheme.primary,
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildInsertionIndicator(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: context.colorScheme.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDraggableCard(
    BuildContext context,
    ParticipantModel participant, {
    required bool isRanked,
  }) {
    return Draggable<ParticipantModel>(
      key: ValueKey(participant.id),
      data: participant,
      feedback: _buildDragFeedback(context, participant),
      childWhenDragging: _buildDragPlaceholder(context, participant),
      child: _buildCard(context, participant, isRanked: isRanked),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ParticipantModel participant, {
    required bool isRanked,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isRanked ? 1 : 0,
        color: isRanked
            ? context.colorScheme.primaryContainer
            : context.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isRanked
                ? context.colorScheme.primary.withValues(alpha: 0.4)
                : context.colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.drag_handle,
                size: 18,
                color: isRanked
                    ? context.colorScheme.primary.withValues(alpha: 0.6)
                    : context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  participant.displayName,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: isRanked ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragFeedback(
    BuildContext context,
    ParticipantModel participant,
  ) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: context.colorScheme.primaryContainer,
      child: Container(
        width: (MediaQuery.of(context).size.width / 2) - 24,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.drag_handle,
              size: 18,
              color: context.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                participant.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragPlaceholder(
    BuildContext context,
    ParticipantModel participant,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                participant.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDroppedOutCard(
    BuildContext context,
    ParticipantModel participant,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.person_off,
              size: 16,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                participant.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, BallotLoaded state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Ballot?'),
        content: const Text(
          'This will move all performers back to the unranked column.',
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
                    _resetBallot(context, state);
                  },
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
