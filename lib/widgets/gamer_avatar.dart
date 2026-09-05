import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/gamer_theme.dart';

class GamerAvatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  final double radius;
  final bool hasGlow;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GamerAvatar({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 24,
    this.hasGlow = false,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? GamerTheme.accentBlue;

    Widget avatarContent;
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        avatarContent = Image.memory(
          base64Decode(base64String),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackWidget(),
        );
      } catch (_) {
        avatarContent = _fallbackWidget();
      }
    } else if (photoUrl.isNotEmpty && (photoUrl.startsWith('http') || photoUrl.startsWith('https'))) {
      avatarContent = CachedNetworkImage(
        imageUrl: photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: GamerTheme.cardElevated,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentBlue),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _fallbackWidget(),
      );
    } else {
      avatarContent = _fallbackWidget();
    }

    Widget core = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveBorder,
          width: hasGlow ? 2.5 : 1.5,
        ),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: effectiveBorder.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: ClipOval(child: avatarContent),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: core);
    }
    return core;
  }

  Widget _fallbackWidget() {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: GamerTheme.electricBlueGradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: radius * 0.9,
          ),
        ),
      ),
    );
  }
}
