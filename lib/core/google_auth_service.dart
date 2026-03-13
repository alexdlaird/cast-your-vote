import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('google_auth_service');

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  factory GoogleAuthService() => _instance;

  GoogleAuthService._internal();

  static const driveFileScope = 'https://www.googleapis.com/auth/drive.file';

  final googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      driveFileScope,
    ],
  );

  AuthClient? _cachedClient;

  /// Whether an auth client is currently cached and available.
  bool get hasAuthClient => _cachedClient != null;

  /// Signs in the user and initializes the auth client in a single flow.
  /// Returns the signed-in account, or null if sign-in was cancelled.
  /// This requests all required scopes (email + drive.file) in one OAuth prompt.
  Future<GoogleSignInAccount?> signInAndInitClient() async {
    // Sign in and request all scopes in one flow
    final account = await googleSignIn.signIn();
    if (account == null) {
      return null;
    }

    // Get authentication - on web with FedCM, this might only have ID token
    var auth = await account.authentication;

    // If no access token, explicitly request scopes to get one
    if (auth.accessToken == null) {
      final hasScope = await googleSignIn.requestScopes([driveFileScope]);
      if (!hasScope) {
        throw StateError('Google Sheets access denied. Please grant permission to continue.');
      }
      auth = await account.authentication;
    }

    if (auth.accessToken == null) {
      throw StateError('Unable to get Google access token. Please sign out and sign back in.');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        auth.accessToken!,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      [driveFileScope],
    );

    _cachedClient = authenticatedClient(http.Client(), credentials);
    _log.info('Auth client initialized and cached');
    return account;
  }

  /// Returns the cached auth client, or re-authenticates if needed.
  /// Uses the same unified OAuth flow as [signInAndInitClient].
  Future<AuthClient> getAuthClient() async {
    // Return cached client if available
    if (_cachedClient != null) {
      return _cachedClient!;
    }

    _log.info('No cached auth client, re-authenticating...');

    // Try silent sign-in first
    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    // If no account, do full sign-in (same flow as initial login)
    if (account == null) {
      account = await googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google sign-in required. Please try again.');
      }
    }

    // Get authentication - on web with FedCM, this might only have ID token
    var auth = await account.authentication;

    // If no access token, explicitly request scopes to get one
    if (auth.accessToken == null) {
      final hasScope = await googleSignIn.requestScopes([driveFileScope]);
      if (!hasScope) {
        throw StateError('Google Sheets access denied. Please grant permission to continue.');
      }
      auth = await account.authentication;
    }

    if (auth.accessToken == null) {
      throw StateError('Unable to get Google access token. Please sign out and sign back in.');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        auth.accessToken!,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      [driveFileScope],
    );

    _cachedClient = authenticatedClient(http.Client(), credentials);
    _log.info('Auth client re-authenticated and cached');
    return _cachedClient!;
  }

  /// Clears the cached auth client, forcing re-authentication on next request.
  void clearCache() {
    _cachedClient?.close();
    _cachedClient = null;
  }
}
