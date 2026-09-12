import 'package:flutter/material.dart';
import '../models/gamer_user_model.dart';
import 'clip_upload_modal.dart';

export 'clip_upload_modal.dart';

/// Alias widget in case referenced as ClipPostModalSheet
class ClipPostModalSheet extends StatelessWidget {
  final GamerUser? currentGamer;
  final VoidCallback? onUploadSuccess;

  const ClipPostModalSheet({
    super.key,
    this.currentGamer,
    this.onUploadSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ClipUploadModalSheet(
      currentGamer: currentGamer,
      onUploadSuccess: onUploadSuccess,
    );
  }
}
