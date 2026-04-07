// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  // Cache the admin emails to avoid repeated Firestore queries
  List<String>? _cachedAdminEmails;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<String>> getAdminEmails() async {
    // Return cached value if still valid
    if (_cachedAdminEmails != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedAdminEmails!;
    }

    final doc = await _firestore.collection('config').doc('admins').get();

    if (!doc.exists) {
      // Document must be created via Firebase Console
      _cachedAdminEmails = [];
      _cacheTime = DateTime.now();
      return _cachedAdminEmails!;
    }
    final emails = doc.data()!['emails'] as List<dynamic>;
    _cachedAdminEmails = emails.map((e) => e.toString().toLowerCase()).toList();

    _cacheTime = DateTime.now();
    return _cachedAdminEmails!;
  }

  Future<bool> isAdmin(String? email) async {
    if (email == null) return false;
    final adminEmails = await getAdminEmails();
    return adminEmails.contains(email.toLowerCase());
  }

  void clearCache() {
    _cachedAdminEmails = null;
    _cacheTime = null;
  }
}
