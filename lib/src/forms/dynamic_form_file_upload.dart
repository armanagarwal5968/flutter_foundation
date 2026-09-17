import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../media/storage_upload_stub.dart'
    if (dart.library.io) '../media/storage_upload_io.dart'
    as platform_upload;

typedef DynamicFormFileUploader =
    Future<Map<String, Object?>?> Function({
      required String formId,
      required String fieldId,
      String? category,
    });

/// Uploads a patient-selected image or PDF and returns response-safe metadata.
class FirebaseDynamicFormFileUploader {
  FirebaseDynamicFormFileUploader({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<Map<String, Object?>?> upload({
    required String formId,
    required String fieldId,
    String? category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before uploading a file.');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return null;
    if (file.bytes == null && file.path == null) {
      throw StateError('The selected file could not be read.');
    }
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final uploadId = DateTime.now().microsecondsSinceEpoch.toString();
    final path =
        'form_uploads/${user.uid}/$formId/$fieldId/$uploadId/$safeName';
    final contentType = _contentType(file.extension);
    await platform_upload.uploadPlatformFile(
      _storage.ref(path),
      file,
      SettableMetadata(contentType: contentType),
    );
    return {
      'storagePath': path,
      'fileName': file.name,
      'contentType': contentType,
      'sizeBytes': file.size,
      if (category != null) 'category': category,
    };
  }

  String _contentType(String? extension) => switch (extension?.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}
