// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RoundsScreen extends StatefulWidget {
  const RoundsScreen({super.key});

  @override
  State<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends State<RoundsScreen> {
  final _formKey = GlobalKey<FormState>();

  late List<ParticipantModel> _participants;

  // _roundEntries[roundIndex][participantIndex] = TextEditingController
  late List<List<TextEditingController>> _roundEntries;
  int _roundCount = 1;

  late bool _donationsEnabled;
  late final TextEditingController _donationBonusController;
  late final TextEditingController _highestDonationBonusController;
  late final TextEditingController _mostDonationsBonusController;
  late final TextEditingController _audienceScoreMultiplierController;
  late final TextEditingController _judgeScoreMultiplierController;
  late bool _hasJudges;

  @override
  void initState() {
    super.initState();
    _initRounds();
  }

  void _initRounds() {
    final adminState = context.read<AdminBloc>().state;
    final event = adminState is AdminLoaded ? adminState.currentEvent : null;

    final config = event?.scoringConfig ?? const ScoringConfigModel();
    _donationsEnabled = config.donationsEnabled;
    _donationBonusController =
        TextEditingController(text: config.donationBonus.toString());
    _highestDonationBonusController =
        TextEditingController(text: config.highestDonationBonus.toString());
    _mostDonationsBonusController =
        TextEditingController(text: config.mostDonationsBonus.toString());
    _audienceScoreMultiplierController =
        TextEditingController(text: config.audienceScoreMultiplier.toString());
    _judgeScoreMultiplierController =
        TextEditingController(text: config.judgeScoreMultiplier.toString());
    _hasJudges = event?.judges.isNotEmpty ?? false;

    _participants = List<ParticipantModel>.from(event?.participants ?? [])
      ..sort((a, b) => a.order.compareTo(b.order));

    final previous = event?.rounds ?? [];
    _roundCount = previous.isNotEmpty ? previous.length : 1;
    _roundEntries = List.generate(_roundCount, (ri) {
      final round = ri < previous.length ? previous[ri] : null;
      return List.generate(_participants.length, (pi) {
        final title =
            round?.entryForParticipant(_participants[pi].id)?.title ?? '';
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
    _donationBonusController.dispose();
    _highestDonationBonusController.dispose();
    _mostDonationsBonusController.dispose();
    _audienceScoreMultiplierController.dispose();
    _judgeScoreMultiplierController.dispose();
    super.dispose();
  }

  void _addRound() {
    setState(() {
      _roundCount++;
      _roundEntries.add(
        List.generate(_participants.length, (_) => TextEditingController()),
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
    return _formKey.currentState!.validate();
  }

  bool get _anyTitleFilled =>
      _roundEntries.any((round) => round.any((c) => c.text.trim().isNotEmpty));

  List<RoundModel> _buildRounds() {
    return List.generate(_roundCount, (ri) {
      return RoundModel(
        id: 'r${ri + 1}',
        order: ri + 1,
        entries: List.generate(_participants.length, (pi) {
          return EntryModel(
            participantId: _participants[pi].id,
            title: _roundEntries[ri][pi].text.trim(),
          );
        }),
      );
    });
  }

  ScoringConfigModel _buildScoringConfig() {
    return ScoringConfigModel(
      donationsEnabled: _donationsEnabled,
      donationBonus:
          double.tryParse(_donationBonusController.text) ?? 0.5,
      highestDonationBonus:
          double.tryParse(_highestDonationBonusController.text) ?? 0.25,
      mostDonationsBonus:
          double.tryParse(_mostDonationsBonusController.text) ?? 0.25,
      audienceScoreMultiplier:
          int.tryParse(_audienceScoreMultiplierController.text) ?? 1,
      judgeScoreMultiplier:
          int.tryParse(_judgeScoreMultiplierController.text) ?? 3,
    );
  }

  void _submit() {
    if (!_validate()) return;

    final adminState = context.read<AdminBloc>().state;
    if (adminState is! AdminLoaded || adminState.currentEvent == null) return;
    final event = adminState.currentEvent!;

    context.read<AdminBloc>().add(
      UpdateEvent(
        eventId: event.id,
        name: event.name,
        participants: event.participants,
        judges: event.judges,
        rounds: _buildRounds(),
        scoringConfig: _buildScoringConfig(),
        audienceBallotCount: adminState.audienceBallotCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = context.watch<AdminBloc>().state;
    final eventName = adminState is AdminLoaded
        ? adminState.currentEvent?.name
        : null;
    return Title(
      color: Theme.of(context).primaryColor,
      title: eventName != null ? 'Edit Rounds & Scoring | $eventName' : 'Edit Rounds & Scoring',
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.go('${AppRoutes.adminCreateEvent}?edit=true'),
          ),
          titleSpacing: 0,
          title: const Text('Edit Rounds & Scoring'),
        ),
        body: BlocListener<AdminBloc, AdminState>(
          listenWhen: (previous, current) {
            if (previous is! AdminLoaded || current is! AdminLoaded) {
              return false;
            }
            return previous.isUpdatingEvent &&
                !current.isUpdatingEvent &&
                current.currentEvent != null;
          },
          listener: (context, state) {
            context.go(AppRoutes.adminBallots);
          },
          child: Form(
            key: _formKey,
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
                      label: const Text('Round'),
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
                        label: const Text('Last Round'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              _buildScoringSection(context),
              const SizedBox(height: 32),
              BlocBuilder<AdminBloc, AdminState>(
                builder: (context, state) {
                  final isLoading =
                      state is AdminLoaded && state.isUpdatingEvent;
                  return ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  );
                },
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundSection(BuildContext context, int roundIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Round ${roundIndex + 1}', style: context.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var pi = 0; pi < _participants.length; pi++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    _participants[pi].name,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _roundEntries[roundIndex][pi],
                    decoration: const InputDecoration(
                      hintText: 'Entry title',
                      isDense: true,
                    ),
                    validator: (value) {
                      if (_anyTitleFilled && (value == null || value.trim().isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScoringSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scoring', style: context.textTheme.titleMedium),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Donation Bonuses'),
          value: _donationsEnabled,
          onChanged: (v) => setState(() => _donationsEnabled = v),
        ),
        if (_donationsEnabled) ...[
          const SizedBox(height: 8),
          _buildScoringField(
            controller: _donationBonusController,
            label: 'Donation Points',
            decimal: true,
          ),
          const SizedBox(height: 12),
          _buildScoringField(
            controller: _highestDonationBonusController,
            label: 'Largest Donation Bonus',
            decimal: true,
          ),
          const SizedBox(height: 12),
          _buildScoringField(
            controller: _mostDonationsBonusController,
            label: 'Most Donations Bonus',
            decimal: true,
          ),
        ],
        if (_hasJudges) ...[
        const SizedBox(height: 12),
        _buildScoringField(
          controller: _audienceScoreMultiplierController,
          label: 'Audience Score Multiplier',
        ),
        const SizedBox(height: 12),
        _buildScoringField(
          controller: _judgeScoreMultiplierController,
          label: 'Judge Score Multiplier',
        ),
        ],
      ],
    );
  }

  Widget _buildScoringField({
    required TextEditingController controller,
    required String label,
    bool decimal = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (decimal) {
          if (double.tryParse(value) == null) return 'Invalid number';
        } else {
          final n = int.tryParse(value);
          if (n == null || n < 1) return 'Must be at least 1';
        }
        return null;
      },
    );
  }
}
