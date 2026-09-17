import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/gamer_theme.dart';

class GamerAvatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  final double radius;
  final bool hasGlow;
  final Color? borderColor;
  final String? frameId;
  final File? imageFile;
  final VoidCallback? onTap;

  const GamerAvatar({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 24,
    this.hasGlow = false,
    this.borderColor,
    this.frameId,
    this.imageFile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? GamerTheme.accentBlue;

    Widget avatarContent;
    if (imageFile != null) {
      avatarContent = Image.file(
        imageFile!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      );
    } else if (photoUrl.startsWith('data:image')) {
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

    final hasFrame = frameId != null && frameId!.isNotEmpty;
    final frameData = hasFrame ? _getFrameDecoration(frameId!) : null;

    Widget core;
    if (frameData != null) {
      final borderWidth = radius >= 36 ? 3.5 : 2.5;
      core = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Frame outer glow & ring
          Container(
            width: (radius * 2) + (borderWidth * 2) + 2,
            height: (radius * 2) + (borderWidth * 2) + 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: frameData.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: frameData.glowColor.withOpacity(0.65),
                  blurRadius: radius >= 36 ? 14 : 8,
                  spreadRadius: radius >= 36 ? 3 : 1.5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: GamerTheme.bgDark,
                ),
                child: ClipOval(child: avatarContent),
              ),
            ),
          ),

          // Frame badge / crown ornament
          if (frameData.ornamentEmoji != null)
            Positioned(
              top: frameData.ornamentTopOffset(radius),
              right: frameData.ornamentRightOffset(radius),
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(color: frameData.glowColor, width: 1.0),
                ),
                child: Text(
                  frameData.ornamentEmoji!,
                  style: TextStyle(fontSize: radius * 0.42),
                ),
              ),
            ),
        ],
      );
    } else {
      core = Container(
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
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: core);
    }
    return core;
  }

  _FrameDecoration? _getFrameDecoration(String id) {
    switch (id) {
      case 'neon_fire':
        return _FrameDecoration(
          gradientColors: const [
            Color(0xFFFF1744),
            Color(0xFFFF9100),
            Color(0xFFFFEA00),
            Color(0xFFFF3D00),
            Color(0xFFFF1744),
          ],
          glowColor: const Color(0xFFFF5722),
          ornamentEmoji: '🔥',
          ornamentTopOffset: (r) => -2,
          ornamentRightOffset: (r) => -2,
        );
      case 'royal_crown':
        return _FrameDecoration(
          gradientColors: const [
            Color(0xFFFFD700),
            Color(0xFFFFA000),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFFFD700),
          ],
          glowColor: const Color(0xFFFFD700),
          ornamentEmoji: '👑',
          ornamentTopOffset: (r) => -r * 0.35,
          ornamentRightOffset: (r) => r * 0.7,
        );
      case 'cyber_glitch':
        return _FrameDecoration(
          gradientColors: const [
            Color(0xFF00FF66),
            Color(0xFF00E5FF),
            Color(0xFF38BDF8),
            Color(0xFF00FF66),
          ],
          glowColor: const Color(0xFF00FF66),
          ornamentEmoji: '⚡',
          ornamentTopOffset: (r) => -2,
          ornamentRightOffset: (r) => -2,
        );
      case 'cosmic_void':
        return _FrameDecoration(
          gradientColors: const [
            Color(0xFF9333EA),
            Color(0xFFEC4899),
            Color(0xFF6366F1),
            Color(0xFFC084FC),
            Color(0xFF9333EA),
          ],
          glowColor: const Color(0xFFC084FC),
          ornamentEmoji: '🌌',
          ornamentTopOffset: (r) => -2,
          ornamentRightOffset: (r) => -2,
        );
      default:
        return null;
    }
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

class _FrameDecoration {
  final List<Color> gradientColors;
  final Color glowColor;
  final String? ornamentEmoji;
  final double Function(double radius) ornamentTopOffset;
  final double Function(double radius) ornamentRightOffset;

  const _FrameDecoration({
    required this.gradientColors,
    required this.glowColor,
    this.ornamentEmoji,
    required this.ornamentTopOffset,
    required this.ornamentRightOffset,
  });
}

class GamerBadgeWidget extends StatelessWidget {
  final String badgeId;
  final double scale;

  const GamerBadgeWidget({
    super.key,
    required this.badgeId,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeId.isEmpty) return const SizedBox.shrink();

    String title;
    IconData icon;
    Color primaryColor;
    List<Color> gradientColors;

    switch (badgeId) {
      case 'pro_elite':
        title = 'PRO ELITE';
        icon = Icons.verified_rounded;
        primaryColor = GamerTheme.accentBlue;
        gradientColors = const [Color(0xFF1E3A8A), Color(0xFF2563EB)];
        break;
      case 'kd_assassin':
        title = 'ASSASSIN 💀';
        icon = Icons.dangerous_rounded;
        primaryColor = GamerTheme.redAccent;
        gradientColors = const [Color(0xFF7F1D1D), Color(0xFFDC2626)];
        break;
      case 'room_champion':
        title = 'CHAMPION 🏆';
        icon = Icons.emoji_events_rounded;
        primaryColor = Colors.amber;
        gradientColors = const [Color(0xFF78350F), Color(0xFFD97706)];
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(left: 4 * scale),
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: primaryColor.withOpacity(0.8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 6 * scale,
            spreadRadius: 1 * scale,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11 * scale),
          SizedBox(width: 3 * scale),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 9.5 * scale,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

