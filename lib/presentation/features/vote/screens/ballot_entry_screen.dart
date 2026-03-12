import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:theatre_121/presentation/ui/layout/app_scaffold.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/data/repositories/ballot_repository_impl.dart';

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
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.errorMessage!)),
        );
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not found—enter the code from your ballot slip')),
        );
        setState(() => _isValidating = false);
        return;
      }

      context.go('${AppRoutes.vote}?ballot=$code');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
                  Image.asset(
                    'assets/img/cos-logo.webp',
                    height: 120,
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
