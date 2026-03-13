import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/ui/utils/snack_bar_helper.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';

class CreateEventScreen extends StatefulWidget {
  final bool hasExistingEvent;
  final String? previousEventName;
  final List<String>? previousParticipants;
  final List<String>? previousJudges;
  final int? previousAudienceCount;

  const CreateEventScreen({
    super.key,
    this.hasExistingEvent = false,
    this.previousEventName,
    this.previousParticipants,
    this.previousJudges,
    this.previousAudienceCount,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _eventNameController;
  late final TextEditingController _audienceCountController;
  final List<TextEditingController> _judgeControllers = [];
  final List<FocusNode> _judgeFocusNodes = [];
  final List<TextEditingController> _participantControllers = [];
  final List<FocusNode> _participantFocusNodes = [];

  @override
  void initState() {
    super.initState();

    // Pre-populate from previous event or use defaults
    _eventNameController = TextEditingController(
      text: widget.previousEventName ?? 'Theatre 121',
    );
    _audienceCountController = TextEditingController(
      text: (widget.previousAudienceCount ?? 100).toString(),
    );

    // Initialize judges
    if (widget.previousJudges != null && widget.previousJudges!.isNotEmpty) {
      for (final name in widget.previousJudges!) {
        _judgeControllers.add(TextEditingController(text: name));
        _judgeFocusNodes.add(FocusNode());
      }
    } else {
      // Start with 5 empty judge slots
      for (int i = 0; i < 5; i++) {
        _judgeControllers.add(TextEditingController());
        _judgeFocusNodes.add(FocusNode());
      }
    }

    // Initialize participants
    if (widget.previousParticipants != null &&
        widget.previousParticipants!.isNotEmpty) {
      // Randomize previous participants
      final shuffled = List<String>.from(widget.previousParticipants!)
        ..shuffle(Random());
      for (final name in shuffled) {
        _participantControllers.add(TextEditingController(text: name));
        _participantFocusNodes.add(FocusNode());
      }
    } else {
      // Start with 10 empty participant slots
      for (int i = 0; i < 10; i++) {
        _participantControllers.add(TextEditingController());
        _participantFocusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _audienceCountController.dispose();
    for (final controller in _judgeControllers) {
      controller.dispose();
    }
    for (final node in _judgeFocusNodes) {
      node.dispose();
    }
    for (final controller in _participantControllers) {
      controller.dispose();
    }
    for (final node in _participantFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _addJudgeField() {
    setState(() {
      _judgeControllers.add(TextEditingController());
      _judgeFocusNodes.add(FocusNode());
    });
  }

  void _removeJudgeField(int index) {
    if (_judgeControllers.length > 1) {
      setState(() {
        _judgeControllers[index].dispose();
        _judgeControllers.removeAt(index);
        _judgeFocusNodes[index].dispose();
        _judgeFocusNodes.removeAt(index);
      });
    }
  }

  void _addParticipantField() {
    setState(() {
      _participantControllers.add(TextEditingController());
      _participantFocusNodes.add(FocusNode());
    });
  }

  void _removeParticipantField(int index) {
    if (_participantControllers.length > 1) {
      setState(() {
        _participantControllers[index].dispose();
        _participantControllers.removeAt(index);
        _participantFocusNodes[index].dispose();
        _participantFocusNodes.removeAt(index);
      });
    }
  }

  void _createEvent() {
    if (!_formKey.currentState!.validate()) return;

    // Validate judges
    final emptyJudgeIndices = <int>[];
    for (int i = 0; i < _judgeControllers.length; i++) {
      if (_judgeControllers[i].text.trim().isEmpty) {
        emptyJudgeIndices.add(i + 1);
      }
    }

    if (emptyJudgeIndices.isNotEmpty) {
      SnackBarHelper.show(
        context,
        'Fill in all judge names (missing: ${emptyJudgeIndices.join(", ")})',
        type: SnackType.error,
      );
      return;
    }

    // Validate participants
    final emptyParticipantIndices = <int>[];
    for (int i = 0; i < _participantControllers.length; i++) {
      if (_participantControllers[i].text.trim().isEmpty) {
        emptyParticipantIndices.add(i + 1);
      }
    }

    if (emptyParticipantIndices.isNotEmpty) {
      SnackBarHelper.show(
        context,
        'Fill in all participant names (missing: ${emptyParticipantIndices.join(", ")})',
        type: SnackType.error,
      );
      return;
    }

    final judgeNames = _judgeControllers
        .map((c) => c.text.trim())
        .toList();
    final participantNames = _participantControllers
        .map((c) => c.text.trim())
        .toList();

    if (widget.hasExistingEvent) {
      _confirmCreateEvent(judgeNames, participantNames);
    } else {
      _submitEvent(judgeNames, participantNames);
    }
  }

  void _confirmCreateEvent(List<String> judgeNames, List<String> participantNames) {
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
                    _submitEvent(judgeNames, participantNames);
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

  void _submitEvent(List<String> judgeNames, List<String> participantNames) {
    context.read<AdminBloc>().add(
          CreateEvent(
            name: _eventNameController.text.trim(),
            participantNames: participantNames,
            audienceBallotCount: int.parse(_audienceCountController.text),
            judgeNames: judgeNames,
          ),
        );
  }

  Widget _buildJudgesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _judgeControllers.length,
      itemBuilder: (context, index) => _buildJudgeRow(context, index),
    );
  }

  Widget _buildJudgeRow(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _judgeControllers[index],
              focusNode: _judgeFocusNodes[index],
              decoration: InputDecoration(
                hintText: 'Judge ${index + 1} name',
                isDense: true,
              ),
              onFieldSubmitted: (_) {
                if (index < _judgeFocusNodes.length - 1) {
                  _judgeFocusNodes[index + 1].requestFocus();
                } else if (_participantFocusNodes.isNotEmpty) {
                  _participantFocusNodes.first.requestFocus();
                }
              },
            ),
          ),
          IconButton(
            onPressed: () => _removeJudgeField(index),
            icon: const Icon(Icons.delete_outline),
            color: context.colorScheme.error,
            tooltip: 'Remove judge',
            focusNode: FocusNode(skipTraversal: true),
          ),
        ],
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
              focusNode: _participantFocusNodes[index],
              decoration: InputDecoration(
                hintText: 'Participant ${index + 1} name',
                isDense: true,
              ),
              onFieldSubmitted: (_) {
                if (index < _participantFocusNodes.length - 1) {
                  _participantFocusNodes[index + 1].requestFocus();
                }
              },
            ),
          ),
          IconButton(
            onPressed: () => _removeParticipantField(index),
            icon: const Icon(Icons.delete_outline),
            color: context.colorScheme.error,
            tooltip: 'Remove participant',
            focusNode: FocusNode(skipTraversal: true),
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
              TextFormField(
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
                onFieldSubmitted: (_) {
                  if (_judgeFocusNodes.isNotEmpty) {
                    _judgeFocusNodes.first.requestFocus();
                  }
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Judges',
                    style: context.textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _addJudgeField,
                    icon: const Icon(Icons.add_circle),
                    color: context.colorScheme.primary,
                    tooltip: 'Add judge',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildJudgesList(),
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
                    tooltip: 'Add participant',
                    focusNode: FocusNode(skipTraversal: true),
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
