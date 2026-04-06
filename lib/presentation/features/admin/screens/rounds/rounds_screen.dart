// Copyright (c) 2024 Cast Your Vote. MIT License.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:cast_your_vote/presentation/ui/utils/snack_bar_helper.dart';
import 'package:cast_your_vote/presentation/features/admin/bloc/admin_bloc.dart';

/// Data passed from CreateEventScreen to RoundsScreen via GoRouter extra.
class RoundsScreenArgs {
  final String? editEventId;
  final String name;
  final List<ParticipantModel> participants;
  final List<JudgeModel> judges;
  final int audienceBallotCount;
  final String? previousLogoUrl;
  final Uint8List? logoBytes;
  final String? logoMimeType;
  final String? logoFileName;
  final bool hasExistingEvent;
  final List<RoundModel> previousRounds;

  const RoundsScreenArgs({
    this.editEventId,
    required this.name,
    required this.participants,
    required this.judges,
    required this.audienceBallotCount,
    this.previousLogoUrl,
    this.logoBytes,
    this.logoMimeType,
    this.logoFileName,
    this.hasExistingEvent = false,
    this.previousRounds = const [],
  });
}

class RoundsScreen extends StatefulWidget {
  final RoundsScreenArgs args;

  const RoundsScreen({super.key, required this.args});

  @override
  State<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends State<RoundsScreen> {
  // _roundEntries[roundIndex][participantIndex] = TextEditingController
  late List<List<TextEditingController>> _roundEntries;
  int _roundCount = 1;

  @override
  void initState() {
    super.initState();
    _initRounds();
  }

  void _initRounds() {
    final previous = widget.args.previousRounds;
    _roundCount = previous.isNotEmpty ? previous.length : 1;
    _roundEntries = List.generate(_roundCount, (ri) {
      final round = ri < previous.length ? previous[ri] : null;
      return List.generate(widget.args.participants.length, (pi) {
        final participantId = widget.args.participants[pi].id;
        final title = round?.entryForParticipant(participantId)?.title ?? '';
        return TextEditingController(text: title);
      });
    });
  }

  @override
  void dispose() {
    for (final round in _roundEntries) {
      for (final controller in round) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _addRound() {
    setState(() {
      _roundCount++;
      _roundEntries.add(
        List.generate(
          widget.args.participants.length,
          (_) => TextEditingController(),
        ),
      );
    });
  }

  void _removeLastRound() {
    if (_roundCount <= 1) return;
    setState(() {
      for (final controller in _roundEntries.last) {
        controller.dispose();
      }
      _roundEntries.removeLast();
      _roundCount--;
    });
  }

  bool _validate() {
    for (var ri = 0; ri < _roundCount; ri++) {
      for (var pi = 0; pi < _roundEntries[ri].length; pi++) {
        if (_roundEntries[ri][pi].text.trim().isEmpty) {
          SnackBarHelper.show(
            context,
            'Fill in all entry titles (Round ${ri + 1}, ${widget.args.participants[pi].name})',
            type: SnackType.error,
          );
          return false;
        }
      }
    }
    return true;
  }

  List<RoundModel> _buildRounds() {
    return List.generate(_roundCount, (ri) {
      final roundId = 'r${ri + 1}';
      return RoundModel(
        id: roundId,
        order: ri + 1,
        entries: List.generate(widget.args.participants.length, (pi) {
          return EntryModel(
            participantId: widget.args.participants[pi].id,
            title: _roundEntries[ri][pi].text.trim(),
          );
        }),
      );
    });
  }

  void _submit() {
    if (!_validate()) return;
    final rounds = _buildRounds();
    final args = widget.args;

    if (args.editEventId != null) {
      context.read<AdminBloc>().add(UpdateEvent(
            eventId: args.editEventId!,
            name: args.name,
            participants: args.participants,
            judges: args.judges,
            rounds: rounds,
            audienceBallotCount: args.audienceBallotCount,
            logoBytes: args.logoBytes,
            logoMimeType: args.logoMimeType,
            logoFileName: args.logoFileName,
          ));
    } else {
      context.read<AdminBloc>().add(CreateEvent(
            name: args.name,
            participantNames: args.participants.map((p) => p.name).toList(),
            audienceBallotCount: args.audienceBallotCount,
            judges: args.judges,
            rounds: rounds,
            previousLogoUrl: args.previousLogoUrl,
            logoBytes: args.logoBytes,
            logoMimeType: args.logoMimeType,
            logoFileName: args.logoFileName,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.args.editEventId != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            '${AppRoutes.adminCreateEvent}${isEdit ? '?edit=true' : ''}',
          ),
        ),
        titleSpacing: 0,
        title: Text(isEdit ? 'Edit Rounds' : 'Configure Rounds'),
      ),
      body: BlocListener<AdminBloc, AdminState>(
        listenWhen: (previous, current) {
          if (previous is! AdminLoaded || current is! AdminLoaded) return false;
          final doneCreating =
              previous.isCreatingEvent && !current.isCreatingEvent;
          final doneUpdating =
              previous.isUpdatingEvent && !current.isUpdatingEvent;
          return (doneCreating || doneUpdating) && current.currentEvent != null;
        },
        listener: (context, state) {
          if (isEdit) {
            context.go(AppRoutes.admin);
          } else {
            context.go(AppRoutes.adminBallots);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var ri = 0; ri < _roundCount; ri++) ...[
              _buildRoundSection(context, ri),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addRound,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Round'),
                  ),
                ),
                if (_roundCount > 1) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removeLastRound,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colorScheme.error,
                        side: BorderSide(color: context.colorScheme.error),
                      ),
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text('Remove Last Round'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            BlocBuilder<AdminBloc, AdminState>(
              builder: (context, state) {
                final isLoading = state is AdminLoaded &&
                    (state.isCreatingEvent || state.isUpdatingEvent);
                return ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit
                          ? 'Update Event'
                          : 'Create Event & Generate Ballots'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundSection(BuildContext context, int roundIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Round ${roundIndex + 1}',
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (var pi = 0; pi < widget.args.participants.length; pi++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    widget.args.participants[pi].name,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _roundEntries[roundIndex][pi],
                    decoration: const InputDecoration(
                      hintText: 'Song title',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
