import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> isResourceDownloaded(String fileName) async {
  final file = await _resourceFile(fileName);
  return await file.exists() && await file.length() > 0;
}

Future<void> downloadAndOpenResource({
  required String url,
  required String fileName,
}) async {
  final file = await _resourceFile(fileName);
  if (!await file.exists() || await file.length() == 0) {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Download failed (${response.statusCode}).');
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
  }
  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done) {
    throw StateError(result.message);
  }
}

Future<File> _resourceFile(String fileName) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory('${root.path}/ooru_resources');
  await directory.create(recursive: true);
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return File('${directory.path}/$safeName');
}
