// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/core/google_auth_service.dart';
import 'package:cast_your_vote/data/repositories/event_repository_impl.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';
import 'package:cast_your_vote/presentation/ui/utils/snack_bar_helper.dart';
import 'package:cast_your_vote/data/repositories/admin_repository.dart';
import 'package:cast_your_vote/config/app_routes.dart';

final _log = Logger('admin_login_screen');

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _adminRepository = AdminRepository();
  final _authService = GoogleAuthService();
  final _eventRepository = EventRepositoryImpl();
  bool _isLoading = false;
  late final Future<String?> _logoUrlFuture;

  @override
  void initState() {
    super.initState();
    _logoUrlFuture = _fetchLogoUrl();
  }

  Future<String?> _fetchLogoUrl() async {
    try {
      final event = await _eventRepository.getCurrentEvent();
      return event?.logoUrl;
    } catch (_) {
      return null;
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    SnackBarHelper.show(context, message, type: SnackType.error);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Sign in and initialize auth client in one OAuth flow
      final googleUser = await _authService.signInAndInitClient();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final email = googleUser.email;
      final isAdmin = await _adminRepository.isAdmin(email);
      if (!isAdmin) {
        await _authService.googleSignIn.signOut();
        _authService.clearCache();
        setState(() => _isLoading = false);
        _showErrorSnackbar('You are not authorized as an admin.');
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        context.go(AppRoutes.admin);
      }
    } catch (e, stackTrace) {
      _log.severe('Failed to sign in with Google', e, stackTrace);
      setState(() => _isLoading = false);
      _showErrorSnackbar('An error occurred while trying to log in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Title(
      color: Theme.of(context).primaryColor,
      title: 'Admin Login | Cast Your Vote!',
      child: Scaffold(
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
                      return Image.network(url, height: 100);
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Admin Portal',
                    style: context.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with your authorized Google account',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_isLoading ? '' : 'Sign in with Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
