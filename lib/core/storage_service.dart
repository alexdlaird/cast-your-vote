// Copyright (c) 2024 Cast Your Vote. MIT License.

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadEventLogo(
    String eventId,
    Uint8List bytes,
    String mimeType, {
    required String eventName,
    String? fileName,
  }) async {
    final ext = _extForMime(mimeType);
    final slug = eventName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '')
        .toLowerCase();
    final prefix = fileName?.replaceAll(RegExp(r'\.[^.]+$'), '');
    final name = prefix != null ? '$prefix-$slug' : slug;
    final ref = _storage.ref('logos/$name.$ext');
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
