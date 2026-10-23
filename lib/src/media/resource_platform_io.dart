import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget resourceImage({
  required String url,
  String? localPath,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) =>
    localPath == null
        ? Image.network(url, fit: fit, errorBuilder: errorBuilder)
        : Image.file(File(localPath), fit: fit, errorBuilder: errorBuilder);

VideoPlayerController resourceVideoController({
  required String url,
  String? localPath,
}) =>
    localPath == null
        ? VideoPlayerController.networkUrl(Uri.parse(url))
        : VideoPlayerController.file(File(localPath));
