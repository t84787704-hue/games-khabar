import 'package:share_plus/share_plus.dart';

/// Centralized Share Service ensuring every shared content across the app
/// directs recipients directly to the application on Google Play Store.
class AppShareService {
  static const String appName = 'Gamers ID';
  static const String packageName = 'com.gameskhabar.games_khabar';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  /// 📲 Direct App Share - shares the app with description and Play Store link
  static Future<void> shareApp() async {
    const text = '🎮 *Gamers ID* - Pakistan\'s #1 Gaming & Esports App!\n\n'
        '🔥 Rozana BGMI aur Free Fire tournaments khelein, unique Gamer ID banayein, doston ke sath feed share karein aur real coins jeetein!\n\n'
        '📲 Abhi Google Play Store se download karein:\n'
        '$playStoreUrl';

    await Share.share(text);
  }

  /// Share Gaming News article with Play Store download link
  static Future<void> shareNews({
    required String title,
    String? description,
    String? gameName,
    String? sourceUrl,
  }) async {
    final buffer = StringBuffer();
    final gameTag = (gameName != null && gameName.trim().isNotEmpty)
        ? ' [$gameName]'
        : '';
    buffer.writeln('🎮 $title$gameTag');

    if (description != null && description.trim().isNotEmpty) {
      final cleanDesc = description.trim();
      final snippet = cleanDesc.length > 200
          ? '${cleanDesc.substring(0, 200)}...'
          : cleanDesc;
      buffer.writeln();
      buffer.writeln(snippet);
    }

    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🔗 Source: $sourceUrl');
    }

    buffer.writeln();
    buffer.writeln('📲 Puri gaming news, updates aur esports matches ke liye Gamers ID download karein:');
    buffer.writeln(playStoreUrl);

    await Share.share(buffer.toString().trim());
  }

  /// Share community post with Play Store link
  static Future<void> sharePost({
    required String authorName,
    String? username,
    required String content,
    String? gameTag,
    String? videoUrl,
    String? imageUrl,
  }) async {
    final buffer = StringBuffer();
    final handle = (username != null && username.isNotEmpty) ? ' (@$username)' : '';
    buffer.writeln('🎮 $authorName$handle on Gamers ID');
    if (gameTag != null && gameTag.isNotEmpty) {
      buffer.writeln('🕹️ Game: $gameTag');
    }
    if (content.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(content);
    }
    if (videoUrl != null && videoUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🎬 Video: $videoUrl');
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🖼️ Image: $imageUrl');
    }

    buffer.writeln();
    buffer.writeln('📲 Gamers ID App Play Store se download karein:');
    buffer.writeln(playStoreUrl);

    await Share.share(buffer.toString().trim());
  }

  /// Share tournament challenge with Play Store link
  static Future<void> shareTournament({
    required String title,
    required String game,
    required String prize,
    required String fee,
    String? map,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🏆 *Tournament Challenge on Gamers ID!*');
    buffer.writeln('⚔️ $title ($game)');
    if (map != null && map.isNotEmpty) {
      buffer.writeln('🗺️ Map: $map');
    }
    buffer.writeln('💰 Prize: $prize | 🎟️ Entry: $fee');
    buffer.writeln();
    buffer.writeln('Hamare sath tournament khelein aur real coins jeetein! Abhi Gamers ID download karein:');
    buffer.writeln(playStoreUrl);

    await Share.share(buffer.toString().trim());
  }

  /// Share gamer profile with Play Store link
  static Future<void> shareProfile({
    required String displayName,
    required String username,
    String? game,
    String? rank,
    int? followersCount,
    int? postsCount,
    String? bio,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🎮 Gamer Profile: $displayName (@$username)');
    if (game != null && game.isNotEmpty) {
      buffer.writeln('🕹️ Game: $game ${rank != null ? "($rank)" : ""}');
    }
    if (followersCount != null || postsCount != null) {
      buffer.writeln('👥 Followers: ${followersCount ?? 0} | 📝 Posts: ${postsCount ?? 0}');
    }
    if (bio != null && bio.isNotEmpty) {
      buffer.writeln('💬 "$bio"');
    }

    buffer.writeln();
    buffer.writeln('Mera profile dekhein aur mere sath khelein! Gamers ID download karein:');
    buffer.writeln(playStoreUrl);

    await Share.share(buffer.toString().trim());
  }

  /// Share esports team with Play Store link
  static Future<void> shareTeam({
    required String teamName,
    required String teamTag,
    required String game,
    String? leaderName,
    int? wins,
    int? points,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🛡️ Team $teamName [$teamTag]');
    buffer.writeln('🎮 Game: $game');
    if (leaderName != null && leaderName.isNotEmpty) {
      buffer.writeln('👑 Leader: $leaderName');
    }
    if (wins != null || points != null) {
      buffer.writeln('🏆 Wins: ${wins ?? 0} | 🏅 Points: ${points ?? 0}');
    }

    buffer.writeln();
    buffer.writeln('Hamari team ko challenge karein ya join karein! Gamers ID download karein:');
    buffer.writeln(playStoreUrl);

    await Share.share(buffer.toString().trim());
  }

  /// Share referral / invite code with Play Store link
  static Future<void> shareInviteCode({required String inviteCode}) async {
    final text = '🎮 Gamers ID par aao aur Free 200 G-Coins pao!\n\n'
        'Mera referral code lagao: $inviteCode\n\n'
        '📲 Play Store se abhi Gamers ID download karein:\n'
        '$playStoreUrl';

    await Share.share(text);
  }

  /// Share tournament victory
  static Future<void> shareVictory({
    required String tournamentTitle,
    required String winningTeamName,
    required int prizeCoins,
  }) async {
    final text = '🏆 CHAMPIONS ALERT! 🏆\n\n'
        'Squad "$winningTeamName" has won the $tournamentTitle!\n'
        '💰 Prize Won: $prizeCoins Coins\n\n'
        '📲 Gamers ID par tournament battles khelein aur rewards jeetein:\n'
        '$playStoreUrl';

    await Share.share(text);
  }
}
