import 'dart:io';

import 'package:flutter/material.dart';

class MediaImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  const MediaImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  static bool isRemote(String? source) {
    final value = source?.trim().toLowerCase() ?? '';
    return value.startsWith('https://') || value.startsWith('http://');
  }

  static bool isAvailable(String? source) {
    if (source == null || source.trim().isEmpty) return false;
    return isRemote(source) || File(source).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final Image image = isRemote(source)
        ? Image.network(
            source,
            fit: fit,
            errorBuilder: errorBuilder ?? (_, __, ___) => _error(context),
          )
        : Image.file(
            File(source),
            fit: fit,
            errorBuilder: errorBuilder ?? (_, __, ___) => _error(context),
          );
    return image;
  }

  Widget _error(BuildContext context) {
    return const Icon(Icons.broken_image_outlined);
  }
}
