import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';

class CreateEventScreen extends StatefulWidget {
  final bool hasExistingEvent;
  final String? previousEventName;
  final List<String>? previousParticipants;
  final int? previousAudienceCount;
  final int? previousJudgeCount;

  const CreateEventScreen({
    super.key,
    this.hasExistingEvent = false,
    this.previousEventName,
    this.previousParticipants,
    this.previousAudienceCount,
    this.previousJudgeCount,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _eventNameController;
  late final TextEditingController _audienceCountController;
  late final TextEditingController _judgeCountController;
  final List<TextEditingController> _participantControllers = [];

  @override
  void initState() {
    super.initState();

    // Pre-populate from previous event or use defaults
    _eventNameController = TextEditingController(
      text: widget.previousEventName ?? "Theatre 121",
    );
    _audienceCountController = TextEditingController(
      text: (widget.previousAudienceCount ?? 100).toString(),
    );
    _judgeCountController = TextEditingController(
      text: (widget.previousJudgeCount ?? 5).toString(),
    );

    if (widget.previousParticipants != null &&
        widget.previousParticipants!.isNotEmpty) {
      // Randomize previous participants
      final shuffled = List<String>.from(widget.previousParticipants!)
        ..shuffle(Random());
      for (final name in shuffled) {
        _participantControllers.add(TextEditingController(text: name));
      }
    } else {
      // Start with 10 empty participant slots
      for (int i = 0; i < 10; i++) {
        _participantControllers.add(TextEditingController());
      }
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _audienceCountController.dispose();
    _judgeCountController.dispose();
    for (final controller in _participantControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addParticipantField() {
    setState(() {
      _participantControllers.add(TextEditingController());
    });
  }

  void _removeParticipantField(int index) {
    if (_participantControllers.length > 1) {
      setState(() {
        _participantControllers[index].dispose();
        _participantControllers.removeAt(index);
      });
    }
  }

  void _createEvent() {
    if (!_formKey.currentState!.validate()) return;

    final emptyParticipantIndices = <int>[];
    for (int i = 0; i < _participantControllers.length; i++) {
      if (_participantControllers[i].text.trim().isEmpty) {
        emptyParticipantIndices.add(i + 1);
      }
    }

    if (emptyParticipantIndices.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all participant names (missing: ${emptyParticipantIndices.join(", ")})',
          ),
        ),
      );
      return;
    }

    final participantNames = _participantControllers
        .map((c) => c.text.trim())
        .toList();

    if (widget.hasExistingEvent) {
      _confirmCreateEvent(participantNames);
    } else {
      _submitEvent(participantNames);
    }
  }

  void _confirmCreateEvent(List<String> participantNames) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Event?'),
        content: const Text(
          "This will start a new event and generate new ballots. The previous event's data, including ballots, will be archived and no longer active.",
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
                    _submitEvent(participantNames);
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

  void _submitEvent(List<String> participantNames) {
    context.read<AdminBloc>().add(
          CreateEvent(
            name: _eventNameController.text.trim(),
            participantNames: participantNames,
            audienceBallotCount: int.parse(_audienceCountController.text),
            judgeBallotCount: int.parse(_judgeCountController.text),
          ),
        );
  }

  Widget _buildParticipantsList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _participantControllers.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final adjustedIndex =
              newIndex > oldIndex ? newIndex - 1 : newIndex;
          final controller = _participantControllers.removeAt(oldIndex);
          _participantControllers.insert(adjustedIndex, controller);
        });
      },
      itemBuilder: (context, index) => _buildParticipantRow(context, index),
    );
  }

  Widget _buildParticipantRow(BuildContext context, int index) {
    return Padding(
      key: ValueKey(index),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _participantControllers[index],
              decoration: InputDecoration(
                hintText: 'Participant ${index + 1} name',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeParticipantField(index),
            icon: const Icon(Icons.delete_outline),
            color: context.colorScheme.error,
            tooltip: 'Remove participant',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: null,
          onPressed: () => context.go(AppRoutes.admin),
        ),
        titleSpacing: 0,
        title: const Text('Create Event'),
      ),
      body: BlocListener<AdminBloc, AdminState>(
        listenWhen: (previous, current) {
          // Navigate when event creation completes
          final wasCreating =
              previous is AdminLoaded && previous.isCreatingEvent;
          final nowLoaded = current is AdminLoaded &&
              !current.isCreatingEvent &&
              current.currentEvent != null;
          return wasCreating && nowLoaded;
        },
        listener: (context, state) {
          context.go(AppRoutes.adminBallots);
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _eventNameController,
                decoration: const InputDecoration(
                  labelText: 'Event Name',
                  hintText: "Come Out Singin'",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _audienceCountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Audience Ballots',
                        hintText: '100',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _judgeCountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Judge Ballots',
                        hintText: '5',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Participants (in order of performance)',
                    style: context.textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _addParticipantField,
                    icon: const Icon(Icons.add_circle),
                    color: context.colorScheme.primary,
                    tooltip: 'Add participant'
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildParticipantsList(),
              const SizedBox(height: 32),
              BlocBuilder<AdminBloc, AdminState>(
                builder: (context, state) {
                  final isLoading =
                      state is AdminLoaded && state.isCreatingEvent;
                  return ElevatedButton(
                    onPressed: isLoading ? null : _createEvent,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Event & Generate Ballots'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
