import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget resourceImage({
  required String url,
  String? localPath,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) => Image.network(
  url,
  width: double.infinity,
  height: double.infinity,
  fit: fit,
  errorBuilder: errorBuilder,
  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
);

VideoPlayerController resourceVideoController({
  required String url,
  String? localPath,
}) => VideoPlayerController.networkUrl(Uri.parse(url));
