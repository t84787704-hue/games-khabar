import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Renders the verified influencer Blue Tick icon (✓)
/// ONLY IF the user document has isBlueTickVerified == true AND blueTickStatus == 'approved'.
class UserBlueTickBadge extends StatelessWidget {
  final String userId;
  final double size;
  final EdgeInsetsGeometry padding;

  const UserBlueTickBadge({
    super.key,
    required this.userId,
    this.size = 15,
    this.padding = const EdgeInsets.only(left: 3),
  });

  /// Static helper to check raw firestore user document data
  static bool isApproved(Map<String, dynamic>? data) {
    if (data == null) return false;
    final bool isBlue = data['isBlueTickVerified'] == true ||
        data['blueTickVerified'] == true;
    final String status = data['blueTickStatus']?.toString().toLowerCase().trim() ?? '';
    return isBlue && status == 'approved';
  }

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (!isApproved(data)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: padding,
          child: Icon(
            Icons.verified,
            color: const Color(0xFF1D9BF0),
            size: size,
          ),
        );
      },
    );
  }
}

/// Standalone icon widget for when verified status is already known
class BlueTickIcon extends StatelessWidget {
  final double size;
  const BlueTickIcon({super.key, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.verified,
      color: const Color(0xFF1D9BF0),
      size: size,
    );
  }
}
