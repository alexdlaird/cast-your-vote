// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/data/repositories/event_repository_impl.dart';
import 'package:cast_your_vote/presentation/ui/layout/app_scaffold.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:cast_your_vote/presentation/ui/utils/snack_bar_helper.dart';
import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/data/repositories/ballot_repository_impl.dart';

final _log = Logger('ballot_entry_screen');

class BallotEntryScreen extends StatefulWidget {
  final String? errorMessage;

  const BallotEntryScreen({
    super.key,
    this.errorMessage,
  });

  @override
  State<BallotEntryScreen> createState() => _BallotEntryScreenState();
}

class _BallotEntryScreenState extends State<BallotEntryScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ballotRepository = BallotRepositoryImpl();
  final _eventRepository = EventRepositoryImpl();
  bool _isValidating = false;
  late final Future<String?> _logoUrlFuture;

  @override
  void initState() {
    super.initState();
    _logoUrlFuture = _fetchLogoUrl();
    if (widget.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackBarHelper.show(context, widget.errorMessage!, type: SnackType.error);
      });
    }
  }

  Future<String?> _fetchLogoUrl() async {
    try {
      final event = await _eventRepository.getCurrentEvent();
      return event?.logoUrl;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isValidating) return;

    final code = _codeController.text.trim().toUpperCase();

    setState(() => _isValidating = true);

    try {
      final ballot = await _ballotRepository.getBallot(code);

      if (!mounted) return;

      if (ballot == null) {
        SnackBarHelper.show(
          context,
          'Not found—enter the code from your ballot slip',
          type: SnackType.error,
        );
        setState(() => _isValidating = false);
        return;
      }

      context.go('${AppRoutes.vote}?ballot=$code');
    } catch (e, stackTrace) {
      _log.severe('Failed to validate ballot code', e, stackTrace);
      if (!mounted) return;
      SnackBarHelper.show(context, 'Error: $e', type: SnackType.error);
      setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showBottomNav: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FutureBuilder<String?>(
                    future: _logoUrlFuture,
                    builder: (context, snapshot) {
                      final url = snapshot.data;
                      if (url == null) return const SizedBox.shrink();
                      return Image.network(url, height: 120);
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Enter Your Ballot Code',
                    style: context.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the code from your ballot slip',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => newValue.copyWith(
                            text: newValue.text.toUpperCase(),
                          ),
                        ),
                      ],
                      style: context.textTheme.headlineMedium?.copyWith(
                        letterSpacing: 8,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'ABC123',
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a valid ballot code';
                        }
                        final code = value.trim().toUpperCase();
                        if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
                          return null;
                        }
                        if (RegExp(r'^J-[A-Z0-9]{6}$').hasMatch(code)) {
                          return null;
                        }
                        return 'Invalid ballot code';
                      },
                      onFieldSubmitted: (_) => _submitCode(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isValidating ? null : _submitCode,
                    child: _isValidating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
