import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

UploadTask uploadPlatformFile(
  Reference reference,
  PlatformFile file,
  SettableMetadata metadata,
) {
  final bytes = file.bytes;
  if (bytes == null) {
    throw StateError('The selected file could not be read.');
  }
  return reference.putData(bytes, metadata);
}
