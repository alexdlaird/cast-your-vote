// Copyright (c) 2024 Cast Your Vote. MIT License.

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads a logo for [eventId] and returns the public download URL.
  /// The file is stored at `logos/<eventId>.<ext>` and overwrites any prior
  /// upload for the same event.
  Future<String> uploadEventLogo(
    String eventId,
    Uint8List bytes,
    String mimeType,
  ) async {
    final ext = _extForMime(mimeType);
    final ref = _storage.ref('logos/$eventId.$ext');
    final metadata = SettableMetadata(contentType: mimeType);
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  String _extForMime(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'img';
    }
  }
}
