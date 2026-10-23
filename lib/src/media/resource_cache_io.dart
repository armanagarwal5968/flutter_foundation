import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final Map<String, Future<String?>> _activeDownloads = {};

Future<String?> cachedResourcePath(String cacheKey, String fileName) async {
  final file = await _resourceFile(cacheKey, fileName);
  return await file.exists() && await file.length() > 0 ? file.path : null;
}

Future<String?> cacheResource({
  required String url,
  required String cacheKey,
  required String fileName,
}) => _activeDownloads.putIfAbsent(cacheKey, () async {
  try {
    final file = await _resourceFile(cacheKey, fileName);
    if (await file.exists() && await file.length() > 0) return file.path;
    final temporary = File('${file.path}.download');
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Download failed (${response.statusCode}).');
    }
    final sink = temporary.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
    await temporary.rename(file.path);
    return file.path;
  } finally {
    _activeDownloads.remove(cacheKey);
  }
});

Future<File> _resourceFile(String cacheKey, String fileName) async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/ooru_resource_cache');
  await directory.create(recursive: true);
  final safeKey = cacheKey.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return File('${directory.path}/${safeKey}_$safeName');
}
