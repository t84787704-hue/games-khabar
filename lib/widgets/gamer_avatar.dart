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
    } else if (photoUrl.startsWith('preset:')) {
      final preset = photoUrl.replaceFirst('preset:', '');
      avatarContent = _buildPresetAvatar(preset);
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

  Widget _buildPresetAvatar(String preset) {
    IconData icon;
    Color iconColor;
    List<Color> gradientColors;

    switch (preset) {
      case 'helmet':
        icon = Icons.sports_motorsports_rounded;
        iconColor = const Color(0xFF60A5FA);
        gradientColors = const [Color(0xFF1E293B), Color(0xFF0F172A)];
        break;
      case 'skull':
        icon = Icons.dangerous_rounded;
        iconColor = const Color(0xFFFF5252);
        gradientColors = const [Color(0xFF3B0764), Color(0xFF180322)];
        break;
      case 'ninja':
        icon = Icons.masks_rounded;
        iconColor = const Color(0xFFC084FC);
        gradientColors = const [Color(0xFF1E1B4B), Color(0xFF0F0E2A)];
        break;
      case 'crown':
        icon = Icons.workspace_premium_rounded;
        iconColor = const Color(0xFFFFD700);
        gradientColors = const [Color(0xFF312E81), Color(0xFF18181B)];
        break;
      case 'crosshair':
        icon = Icons.filter_center_focus_rounded;
        iconColor = const Color(0xFF00E676);
        gradientColors = const [Color(0xFF064E3B), Color(0xFF022C22)];
        break;
      default:
        icon = Icons.sports_esports_rounded;
        iconColor = GamerTheme.accentOrange;
        gradientColors = const [Color(0xFF1E293B), Color(0xFF0F172A)];
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: radius * 1.1,
        ),
      ),
    );
  }

  Widget _fallbackWidget() {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFFF5200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
