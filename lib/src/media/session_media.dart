import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'storage_upload_stub.dart'
    if (dart.library.io) 'storage_upload_io.dart'
    as platform_upload;

enum SessionMediaType {
  image,
  video,
  pdf;

  static SessionMediaType fromName(String? value) => values.firstWhere(
    (type) => type.name == value,
    orElse: () => SessionMediaType.pdf,
  );

  IconData get icon => switch (this) {
    SessionMediaType.image => Icons.image_outlined,
    SessionMediaType.video => Icons.video_library_outlined,
    SessionMediaType.pdf => Icons.picture_as_pdf_outlined,
  };
}

class SessionMediaAsset {
  const SessionMediaAsset({
    required this.id,
    required this.title,
    required this.type,
    required this.storagePath,
    this.description,
    this.fileName,
    this.contentType,
    this.sizeBytes,
    this.sortOrder = 0,
    this.visibleToPatient = true,
    this.status = 'ready',
  });

  factory SessionMediaAsset.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return SessionMediaAsset(
      id: document.id,
      title: data['title'] as String? ?? data['fileName'] as String? ?? 'File',
      description: data['description'] as String?,
      type: SessionMediaType.fromName(data['mediaType'] as String?),
      storagePath: data['storagePath'] as String? ?? '',
      fileName: data['fileName'] as String?,
      contentType: data['contentType'] as String?,
      sizeBytes: (data['sizeBytes'] as num?)?.toInt(),
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      visibleToPatient: data['visibleToPatient'] as bool? ?? true,
      status: data['status'] as String? ?? 'ready',
    );
  }

  final String id;
  final String title;
  final String? description;
  final SessionMediaType type;
  final String storagePath;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
  final int sortOrder;
  final bool visibleToPatient;
  final String status;
}

class SessionMediaRepository {
  SessionMediaRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  Stream<List<SessionMediaAsset>> watchStandardMedia(String sessionId) =>
      _firestore
          .collection('programme_sessions')
          .doc(sessionId)
          .collection('media')
          .where('status', isEqualTo: 'published')
          .orderBy('sortOrder')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(SessionMediaAsset.fromDocument).toList(),
          );

  Stream<List<SessionMediaAsset>> watchAllStandardMedia(String sessionId) =>
      _firestore
          .collection('programme_sessions')
          .doc(sessionId)
          .collection('media')
          .orderBy('sortOrder')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(SessionMediaAsset.fromDocument).toList(),
          );

  Stream<List<SessionMediaAsset>> watchPatientMedia({
    required String patientId,
    required String sessionId,
    bool onlyPatientVisible = false,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('patient_records')
        .doc(patientId)
        .collection('sessions')
        .doc(sessionId)
        .collection('attachments')
        .where('status', isEqualTo: 'ready');
    if (onlyPatientVisible) {
      query = query.where('visibleToPatient', isEqualTo: true);
    }
    return query
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SessionMediaAsset.fromDocument).toList(),
        );
  }

  Future<void> uploadStandardMedia({
    required String sessionId,
    required String title,
    required SessionMediaType type,
    String? description,
    int sortOrder = 0,
    void Function(double progress)? onProgress,
  }) async {
    final mediaId =
        _firestore
            .collection('programme_sessions')
            .doc(sessionId)
            .collection('media')
            .doc()
            .id;
    final picked = await _pick(type);
    if (picked == null) return;
    final path = 'standard_session_media/$sessionId/$mediaId/${picked.name}';
    await _upload(path, picked, onProgress);
    try {
      await _functions.httpsCallable('registerStandardSessionMedia').call({
        'sessionId': sessionId,
        'mediaId': mediaId,
        'title': title.trim(),
        'description': description?.trim(),
        'mediaType': type.name,
        'storagePath': path,
        'fileName': picked.name,
        'contentType': _contentType(type, picked.extension),
        'sizeBytes': picked.size,
        'sortOrder': sortOrder,
      });
    } catch (_) {
      await _storage.ref(path).delete().catchError((_) {});
      rethrow;
    }
  }

  Future<void> uploadPatientMedia({
    required String patientId,
    required String sessionId,
    required String title,
    required SessionMediaType type,
    String? description,
    bool visibleToPatient = true,
    void Function(double progress)? onProgress,
  }) async {
    final attachmentId =
        _firestore
            .collection('patient_records')
            .doc(patientId)
            .collection('sessions')
            .doc(sessionId)
            .collection('attachments')
            .doc()
            .id;
    final picked = await _pick(type);
    if (picked == null) return;
    final path =
        'patient_session_media/$patientId/$sessionId/$attachmentId/${picked.name}';
    await _upload(path, picked, onProgress);
    try {
      await _functions.httpsCallable('registerPatientSessionMedia').call({
        'patientId': patientId,
        'sessionId': sessionId,
        'attachmentId': attachmentId,
        'title': title.trim(),
        'description': description?.trim(),
        'mediaType': type.name,
        'storagePath': path,
        'fileName': picked.name,
        'contentType': _contentType(type, picked.extension),
        'sizeBytes': picked.size,
        'visibleToPatient': visibleToPatient,
      });
    } catch (_) {
      await _storage.ref(path).delete().catchError((_) {});
      rethrow;
    }
  }

  Future<void> archiveStandardMedia({
    required String sessionId,
    required String mediaId,
  }) => _functions.httpsCallable('archiveStandardSessionMedia').call({
    'sessionId': sessionId,
    'mediaId': mediaId,
  });

  Future<void> archivePatientMedia({
    required String patientId,
    required String sessionId,
    required String attachmentId,
  }) => _functions.httpsCallable('archivePatientSessionMedia').call({
    'patientId': patientId,
    'sessionId': sessionId,
    'attachmentId': attachmentId,
  });

  Future<String> downloadUrl(SessionMediaAsset asset) async {
    final result = await _functions.httpsCallable('getSessionMediaUrl').call({
      'storagePath': asset.storagePath,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['url'] as String;
  }

  Future<PlatformFile?> _pick(SessionMediaType type) async {
    final extensions = switch (type) {
      SessionMediaType.image => ['jpg', 'jpeg', 'png', 'webp'],
      SessionMediaType.video => ['mp4', 'webm', 'mov'],
      SessionMediaType.pdf => ['pdf'],
    };
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null || (file.bytes == null && file.path == null)) return null;
    return file;
  }

  Future<void> _upload(
    String path,
    PlatformFile file,
    void Function(double progress)? onProgress,
  ) async {
    final type = SessionMediaType.fromName(
      file.extension?.toLowerCase() == 'pdf'
          ? 'pdf'
          : ['mp4', 'webm', 'mov'].contains(file.extension?.toLowerCase())
          ? 'video'
          : 'image',
    );
    final task = platform_upload.uploadPlatformFile(
      _storage.ref(path),
      file,
      SettableMetadata(contentType: _contentType(type, file.extension)),
    );
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      await task;
    } finally {
      await subscription.cancel();
    }
  }

  String _contentType(SessionMediaType type, String? extension) =>
      switch (type) {
        SessionMediaType.image =>
          extension?.toLowerCase() == 'png'
              ? 'image/png'
              : extension?.toLowerCase() == 'webp'
              ? 'image/webp'
              : 'image/jpeg',
        SessionMediaType.video =>
          extension?.toLowerCase() == 'webm' ? 'video/webm' : 'video/mp4',
        SessionMediaType.pdf => 'application/pdf',
      };
}

class SessionMediaSection extends StatelessWidget {
  const SessionMediaSection({
    required this.title,
    required this.stream,
    required this.repository,
    this.emptyMessage = 'No files have been added.',
    this.onArchive,
    super.key,
  });

  final String title;
  final Stream<List<SessionMediaAsset>> stream;
  final SessionMediaRepository repository;
  final String emptyMessage;
  final Future<void> Function(SessionMediaAsset asset)? onArchive;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<SessionMediaAsset>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(title),
            subtitle: Text('Unable to load files: ${snapshot.error}'),
          ),
        );
      }
      final assets = snapshot.data ?? const <SessionMediaAsset>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (!snapshot.hasData) const LinearProgressIndicator(),
          if (snapshot.hasData && assets.isEmpty)
            Card(child: ListTile(title: Text(emptyMessage))),
          for (final asset in assets)
            Card(
              child: ListTile(
                leading: Icon(asset.type.icon),
                title: Text(asset.title),
                subtitle: Text(
                  [
                    if (asset.description?.isNotEmpty == true)
                      asset.description!,
                    if (!asset.visibleToPatient) 'Staff only',
                    if (asset.status != 'ready' && asset.status != 'published')
                      asset.status,
                  ].join('\n'),
                ),
                trailing:
                    onArchive == null
                        ? const Icon(Icons.open_in_new)
                        : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'open') _open(context, asset);
                            if (value == 'archive') onArchive!(asset);
                          },
                          itemBuilder:
                              (_) => const [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text('Open'),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text('Archive'),
                                ),
                              ],
                        ),
                onTap: onArchive == null ? () => _open(context, asset) : null,
              ),
            ),
        ],
      );
    },
  );

  Future<void> _open(BuildContext context, SessionMediaAsset asset) async {
    try {
      final url = await repository.downloadUrl(asset);
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('The file could not be opened.');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open file: $error')));
      }
    }
  }
}
