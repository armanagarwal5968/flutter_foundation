import 'package:url_launcher/url_launcher.dart';

Future<bool> isResourceDownloaded(String fileName) async => false;

Future<void> downloadAndOpenResource({
  required String url,
  required String fileName,
}) async {
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
    throw StateError('The file could not be opened.');
  }
}
