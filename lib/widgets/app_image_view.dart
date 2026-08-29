import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppImageView extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImageView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  static bool isBase64(String str) {
    if (str.startsWith('data:image')) return true;
    if (str.startsWith('http://') || str.startsWith('https://')) return false;
    return str.length > 50 && !str.contains(' ') && !str.contains('\n');
  }

  static Uint8List? decodeBase64(String str) {
    try {
      String cleanStr = str;
      if (cleanStr.contains(',')) {
        cleanStr = cleanStr.split(',').last;
      }
      cleanStr = cleanStr.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(cleanStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    if (isBase64(trimmed)) {
      final bytes = decodeBase64(trimmed);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => errorWidget ?? _defaultErrorWidget(),
        );
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => placeholder ?? _defaultPlaceholder(),
        errorWidget: (_, __, ___) => errorWidget ?? _defaultErrorWidget(),
      );
    }

    return errorWidget ?? _defaultErrorWidget();
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E1E24),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
          ),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E1E24),
      child: const Center(
        child: Icon(Icons.videogame_asset, color: Color(0xFF9E9EA7), size: 28),
      ),
    );
  }
}
