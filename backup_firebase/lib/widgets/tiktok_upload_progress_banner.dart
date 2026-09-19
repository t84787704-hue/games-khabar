import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../services/background_upload_manager.dart';

/// TikTok-style Floating Upload Progress Banner
/// Floats at the top or bottom of the screen while user browses feeds.
class TikTokUploadProgressBanner extends StatelessWidget {
  const TikTokUploadProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UploadTaskState?>(
      valueListenable: BackgroundUploadManager().activeTask,
      builder: (context, task, _) {
        if (task == null) return const SizedBox.shrink();

        final bool isSuccess = task.isCompleted;
        final bool isError = task.hasError;

        return GestureDetector(
          onTap: isError
              ? () {
                  if (task.errorMessage != null && task.errorMessage!.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: GamerTheme.cardDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: GamerTheme.redAccent),
                            SizedBox(width: 8),
                            Text("Upload Error", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text(
                          task.errorMessage!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              BackgroundUploadManager().dismissTask();
                            },
                            child: const Text("Dismiss", style: TextStyle(color: GamerTheme.accentBlue)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    BackgroundUploadManager().dismissTask();
                  }
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: GamerTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSuccess
                    ? GamerTheme.neonGreen
                    : isError
                        ? GamerTheme.redAccent
                        : GamerTheme.accentBlue.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSuccess
                          ? GamerTheme.neonGreen
                          : isError
                              ? GamerTheme.redAccent
                              : GamerTheme.accentBlue)
                      .withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Spinning / status icon
                    if (!isSuccess && !isError)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: GamerTheme.accentBlue,
                        ),
                      )
                    else if (isSuccess)
                      const Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen, size: 20)
                    else
                      const Icon(Icons.error_outline_rounded, color: GamerTheme.redAccent, size: 20),
                    const SizedBox(width: 10),

                    // Status Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.statusText,
                            style: TextStyle(
                              color: isSuccess
                                  ? GamerTheme.neonGreen
                                  : isError
                                      ? GamerTheme.redAccent
                                      : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (task.title.isNotEmpty && !isSuccess && !isError)
                            Text(
                              task.title,
                              style: const TextStyle(
                                color: GamerTheme.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (isError)
                            const Text(
                              'Tap to dismiss and try again',
                              style: TextStyle(
                                color: GamerTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Progress percentage or Dismiss
                  if (!isSuccess && !isError)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: GamerTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(task.progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: GamerTheme.accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => BackgroundUploadManager().dismissTask(),
                    ),
                ],
              ),
              if (!isSuccess && !isError) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    minHeight: 4,
                    backgroundColor: GamerTheme.surfaceDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(GamerTheme.accentBlue),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  }
}
