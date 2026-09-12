import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';

class DemoAccountsService {
  static final DemoAccountsService _instance = DemoAccountsService._internal();
  factory DemoAccountsService() => _instance;
  DemoAccountsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> demoUsersConfig = [
    {
      'uid': 'demo_01',
      'username': 'kiro_yt',
      'displayName': 'Kiro_YT',
      'avatarSeed': 'kiro_yt',
      'coverUrl': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80',
      'bio': 'BGMI Conqueror | 5.4 K/D | GodLike ESPORTS | DM for Tier-1 Scrims 🎯🔥',
      'game': 'BGMI',
      'gameId': '5182947102',
      'claimedRank': 'Conqueror',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 5.4,
      'followers': 3420,
      'coins': 2400,
      'level': 35,
      'daysAgo': 24,
      'recruitmentPost': '🚨 Looking for Tier-1 Assaulter & IGL for upcoming BGMI PMCO qualifiers. Need 5.0+ K/D, 22%+ Headshot rate. Active daily 8 PM to 12 AM for scrims. DM stats or drop in-game UID below! 🎯🔥',
      'achievementPost': 'Finally hit CONQUEROR this season after 16 hours of continuous rank push! Huge shoutout to my squad for holding the compound in final circles. 👑🏆 GGWP!',
      'achievementImage': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop&q=80',
      'clipTitle': '1v4 Clutch in Final Zone with M416 6x Spray 🔥',
      'clipThumb': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_02',
      'username': 'shadow_nova',
      'displayName': 'ShadowNova',
      'avatarSeed': 'shadow_nova',
      'coverUrl': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=1200&auto=format&fit=crop&q=80',
      'bio': 'PUBG Mobile Conqueror S18-C5S13 | Competitive Fragger | Team Soul ⚡',
      'game': 'PUBG Mobile',
      'gameId': '5291840291',
      'claimedRank': 'Conqueror',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 5.1,
      'followers': 2150,
      'coins': 1850,
      'level': 30,
      'daysAgo': 19,
      'recruitmentPost': '🏆 Need 1 Sniper/Support for PUBG Mobile Weekend Tournament! Entry fee sponsored by me. Microphone mandatory on Discord. Let\'s conquer the lobby! 💣',
      'achievementPost': 'New Personal Record: 23 Kills in Erangel Bootcamp drop with squad wipeout solo! 🎯🔥 Rate the DMR spam.',
      'achievementImage': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Insane AWM Quickscope in Pochinki 🎯',
      'clipThumb': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_03',
      'username': 'ghost_gamer',
      'displayName': 'GhostRider',
      'avatarSeed': 'ghost_gamer',
      'coverUrl': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=1200&auto=format&fit=crop&q=80',
      'bio': 'Free Fire Grandmaster | Sniper Specialist 🎯 | 6.1 K/D | Guild: GHOST_ELITE',
      'game': 'Free Fire',
      'gameId': '1938204918',
      'claimedRank': 'Grandmaster',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 6.1,
      'followers': 4120,
      'coins': 3200,
      'level': 42,
      'daysAgo': 28,
      'recruitmentPost': '🔥 GHOST_ELITE Guild recruiting top rushers for CS Rank Season 24! Need Grandmaster or Master tier. Daily custom rooms with cash prizes! 💎',
      'achievementPost': 'Unlocked Grandmaster with 85% Win Rate in Free Fire CS Ranked! 🏆 Double AWM gameplay highlights coming soon.',
      'achievementImage': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=800&auto=format&fit=crop&q=80',
      'clipTitle': '1v3 Double AWM Quick Switch Headshot Montage ⚡',
      'clipThumb': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_04',
      'username': 'hydra_soul',
      'displayName': 'HydraSoul',
      'avatarSeed': 'hydra_soul',
      'coverUrl': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1200&auto=format&fit=crop&q=80',
      'bio': 'BGMI ACE Dominator | Hydra Clan Official | 4.8 K/D | Support & IGL 🛡️',
      'game': 'BGMI',
      'gameId': '5391028491',
      'claimedRank': 'ACE Dominator',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 4.8,
      'followers': 1890,
      'coins': 1500,
      'level': 28,
      'daysAgo': 14,
      'recruitmentPost': '🛡️ Hydra Squad recruiting 1 Entry Fragger. Must have good game sense, rotation knowledge, and minimum 4.5 K/D. Drop IDs in replies! 👇',
      'achievementPost': 'Back-to-back 5 Chicken Dinners in BGMI Ace Dominator lobby! The team rotation in Georgopol bridge was legendary. 🍗🔥',
      'achievementImage': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Perfect Grenade Cook Wipes Whole Squad in Building 💥',
      'clipThumb': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_05',
      'username': 'mortal_squad',
      'displayName': 'Mortal',
      'avatarSeed': 'mortal_squad',
      'coverUrl': 'https://images.unsplash.com/photo-1560253023-3ec5d502959f?w=1200&auto=format&fit=crop&q=80',
      'bio': 'Soul Mortal | BGMI Legend & Content Creator | S2 Conqueror | Naman Mathur 👑',
      'game': 'BGMI',
      'gameId': '5123456789',
      'claimedRank': 'Conqueror',
      'isRankVerified': true,
      'blueTick': true, // Verified Pro
      'kd': 5.8,
      'followers': 14850,
      'coins': 5000,
      'level': 50,
      'daysAgo': 30,
      'recruitmentPost': '👑 Team Soul community scrims open today! Who is ready to drop into School Apartments? Tag your ultimate squad mates below! 🎮🔥',
      'achievementPost': 'Completed 5 years of competitive esports journey! Grateful for every fan, player, and supporter who believed from day one. Soul forever! ❤️🏆',
      'achievementImage': 'https://images.unsplash.com/photo-1560253023-3ec5d502959f?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Mortal Legendary 1v3 Clutch with AKM Iron Sight 👑',
      'clipThumb': 'https://images.unsplash.com/photo-1560253023-3ec5d502959f?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_06',
      'username': 'scout_op',
      'displayName': 'Scout',
      'avatarSeed': 'scout_op',
      'coverUrl': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&auto=format&fit=crop&q=80',
      'bio': 'ScoutOP | Tanmay Singh | Esports Athlete | 4-Finger Claw Full Gyro | 6.5 K/D 🚀',
      'game': 'PUBG Mobile',
      'gameId': '5234567890',
      'claimedRank': 'Conqueror',
      'isRankVerified': true,
      'blueTick': true, // Verified Pro
      'kd': 6.5,
      'followers': 13600,
      'coins': 4800,
      'level': 48,
      'daysAgo': 29,
      'recruitmentPost': '🚀 Hosting a 1v1 M416 TDM Tournament today on Gamers ID! 10,000 Coins prize pool. Comment your BGMI ID to enter the bracket! 🎯',
      'achievementPost': 'Peak aim training routine pays off: 400m DMR laser spray on moving Dacia! Never stop grinding your mechanics. ⚡🔥',
      'achievementImage': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Scout 400-Meter Laser Spray in PMCO Finals 🎯⚡',
      'clipThumb': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_07',
      'username': 'jonathan_godl',
      'displayName': 'Jonathan',
      'avatarSeed': 'jonathan_godl',
      'coverUrl': 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?w=1200&auto=format&fit=crop&q=80',
      'bio': 'Jonathan Gaming | GodLike Esports Assaulter | 2-Time MVP | JONNY ON FIRE 🔥',
      'game': 'BGMI',
      'gameId': '5345678901',
      'claimedRank': 'ACE Dominator',
      'isRankVerified': true,
      'blueTick': true, // Verified Pro
      'kd': 6.3,
      'followers': 15200,
      'coins': 5000,
      'level': 49,
      'daysAgo': 27,
      'recruitmentPost': '🔥 Looking for aggressive rushers to test new Miramar drop routes. Minimum 5.5 K/D. Drop your Gamers ID tag below! 🏆',
      'achievementPost': 'GodLike takes another official match win with 18 team kills! Personal 11 frags in final circle. Keep pushing your limits! 💪🏆',
      'achievementImage': 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Jonathan GodL 1v4 Hacker-level Jiggle & Headshots 🔥',
      'clipThumb': 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_08',
      'username': 'payal_gaming',
      'displayName': 'Payal',
      'avatarSeed': 'payal_gaming',
      'coverUrl': 'https://images.unsplash.com/photo-1534423861386-85a16f5d13fd?w=1200&auto=format&fit=crop&q=80',
      'bio': 'Payal Gaming | S8 Conqueror | S8UL Creator | Casual Streamer & Competitive Player 🌸🎮',
      'game': 'PUBG Mobile',
      'gameId': '5456789012',
      'claimedRank': 'Crown I',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 4.4,
      'followers': 8920,
      'coins': 3600,
      'level': 38,
      'daysAgo': 22,
      'recruitmentPost': '🌸 Fun squad streams tonight! Looking for 2 chill teammates who play safe and communicate well. Drop your IDs! ✨',
      'achievementPost': 'Hit Crown I today with 7 Chicken Dinners in a row! Thank you everyone who watched the live stream today! 💖🍗',
      'achievementImage': 'https://images.unsplash.com/photo-1534423861386-85a16f5d13fd?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Last Second Glider Drive-by Wipeout 🚀✨',
      'clipThumb': 'https://images.unsplash.com/photo-1534423861386-85a16f5d13fd?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_09',
      'username': 'kaashplays',
      'displayName': 'Kaash',
      'avatarSeed': 'kaashplays',
      'coverUrl': 'https://images.unsplash.com/photo-1542751110-97427bbecf20?w=1200&auto=format&fit=crop&q=80',
      'bio': 'Kaashvi Hiranandani | Free Fire Pro & Streamer | S8UL Content Creator 🌟',
      'game': 'Free Fire',
      'gameId': '1849203851',
      'claimedRank': 'Heroic',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 4.6,
      'followers': 6450,
      'coins': 2800,
      'level': 34,
      'daysAgo': 17,
      'recruitmentPost': '🎯 Recruiting 2 girls for all-female Free Fire squad championship next month. Must have Heroic rank + good comms! DM me! 💜',
      'achievementPost': 'Heroic 50 Stars reached! MP40 close range meta is unbeatable right now. What is your favorite weapon combo? 🔫✨',
      'achievementImage': 'https://images.unsplash.com/photo-1542751110-97427bbecf20?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Kaashvi Clean MP40 Squad Wipe in Clock Tower 🌟',
      'clipThumb': 'https://images.unsplash.com/photo-1542751110-97427bbecf20?w=800&auto=format&fit=crop&q=80',
    },
    {
      'uid': 'demo_10',
      'username': 'regaltos',
      'displayName': 'Regaltos',
      'avatarSeed': 'regaltos',
      'coverUrl': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1200&auto=format&fit=crop&q=80',
      'bio': 'Regaltos | Parv Singh | Soul Esports Champion | Rush Gameplay 💥 | COD Mobile & BGMI',
      'game': 'COD Mobile',
      'gameId': '6829401928',
      'claimedRank': 'Legendary',
      'isRankVerified': true,
      'blueTick': false,
      'kd': 5.2,
      'followers': 7830,
      'coins': 3400,
      'level': 40,
      'daysAgo': 25,
      'recruitmentPost': '💥 Need 2 aggressive SMG players for COD Mobile Search & Destroy rank push. Must know smoke lineups and bomb spots! Drop tags. 💣',
      'achievementPost': 'Legendary rank achieved in COD Mobile Ranked Multiplayer with 3.8 K/D! That final round 1v3 clutch on Crash was intense! 🏆⚡',
      'achievementImage': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&auto=format&fit=crop&q=80',
      'clipTitle': 'Regaltos 1v3 Clutch in Search & Destroy Final Round 💥',
      'clipThumb': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&auto=format&fit=crop&q=80',
    },
  ];

  /// Checks if demo accounts currently exist in Firestore
  Future<int> getDemoAccountsCount() async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('isDemoAccount', isEqualTo: true)
          .get();
      return snap.docs.length;
    } catch (e) {
      debugPrint('[DemoAccountsService] Error checking demo count: $e');
      return 0;
    }
  }

  /// Generates the 10 professional pro demo accounts, their posts, clips, and follows.
  Future<void> seedDemoAccounts() async {
    debugPrint('[DemoAccountsService] Starting seeding of 10 Pro Demo Accounts...');

    final now = DateTime.now();

    for (final cfg in demoUsersConfig) {
      final String uid = cfg['uid'];
      final String username = cfg['username'];
      final String displayName = cfg['displayName'];
      final String avatarSeed = cfg['avatarSeed'];
      // Reliable avatar URL from DiceBear PNG format (works seamlessly with CachedNetworkImage)
      final String photoUrl = 'https://api.dicebear.com/7.x/avataaars/png?seed=$avatarSeed&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf';
      final String coverUrl = cfg['coverUrl'];
      final String bio = cfg['bio'];
      final String game = cfg['game'];
      final String gameId = cfg['gameId'];
      final String claimedRank = cfg['claimedRank'];
      final bool isRankVerified = cfg['isRankVerified'] == true;
      final bool blueTick = cfg['blueTick'] == true;
      final double kd = (cfg['kd'] as num).toDouble();
      final int followers = cfg['followers'] as int;
      final int coins = cfg['coins'] as int;
      final int level = cfg['level'] as int;
      final int daysAgo = cfg['daysAgo'] as int;
      final DateTime createdAt = now.subtract(Duration(days: daysAgo, hours: 3));

      // Build verified game rank
      final verifiedGame = UserGameRank(
        id: 'rank_${uid}',
        gameName: game,
        gameId: gameId,
        claimedRank: claimedRank,
        verifiedRank: claimedRank,
        isVerified: isRankVerified,
        screenshotUrl: cfg['achievementImage'],
        status: 'approved',
        submittedAt: createdAt,
        ownerUid: uid,
      );

      // Rank Badge Type based on kd and rank
      RankBadgeType badgeType = RankBadgeType.ace;
      if (kd > 5.0) {
        badgeType = RankBadgeType.kdKing;
      } else if (claimedRank.toLowerCase().contains('conqueror')) {
        badgeType = RankBadgeType.conqueror;
      }

      // App rank points
      final int appPoints = (level * 100) + coins + (2 * 10);
      final String appRank = GamerUser.calculateAppRank(appPoints);

      final userDoc = GamerUser(
        uid: uid,
        username: username,
        displayName: displayName,
        photoUrl: photoUrl,
        coverUrl: coverUrl,
        bio: bio,
        favoriteGame: game,
        rank: claimedRank,
        kdRatio: kd,
        rankBadgeType: badgeType,
        followersCount: followers,
        followingCount: 18,
        postsCount: 2,
        clipsCount: 0,
        likesReceived: (followers * 1.8).round(),
        isVerified: blueTick,
        verificationStatus: blueTick ? 'verified' : (uid == 'demo_01' || uid == 'demo_02' ? 'pending' : 'none'),
        isVerifiedBlue: blueTick,
        isBlueTickVerified: blueTick,
        blueTickStatus: blueTick ? 'approved' : (uid == 'demo_01' || uid == 'demo_02' ? 'pending' : 'none'),
        isRankVerified: isRankVerified,
        isAdmin: false,
        isBanned: false,
        isDemoAccount: true,
        gameId: gameId,
        coins: coins,
        level: level,
        games: [verifiedGame],
        createdAt: createdAt,
      );

      // 1. Write User Document
      await _firestore.collection('users').doc(uid).set(userDoc.toMap(), SetOptions(merge: true));

      // 2. Write Post 1: Squad Recruitment Post
      final post1Id = 'post_${uid}_recruit';
      final post1 = GamerPost(
        postId: post1Id,
        userId: uid,
        username: username,
        displayName: displayName,
        userPhoto: photoUrl,
        text: cfg['recruitmentPost'],
        gameTag: game,
        userRank: claimedRank,
        userKd: kd,
        likesCount: 65 + (uid.hashCode % 180).abs(),
        commentsCount: 8 + (uid.hashCode % 25).abs(),
        isVerified: blueTick,
        isDemoAccount: true,
        createdAt: createdAt.add(const Duration(days: 2, hours: 4)),
      );
      await _firestore.collection('posts').doc(post1Id).set(post1.toMap(), SetOptions(merge: true));

      // 3. Write Post 2: Achievement Post with Unsplash Gaming Image
      final post2Id = 'post_${uid}_achieve';
      final post2 = GamerPost(
        postId: post2Id,
        userId: uid,
        username: username,
        displayName: displayName,
        userPhoto: photoUrl,
        text: cfg['achievementPost'],
        imageUrl: cfg['achievementImage'],
        gameTag: game,
        userRank: claimedRank,
        userKd: kd,
        likesCount: 220 + (uid.hashCode % 650).abs(),
        commentsCount: 24 + (uid.hashCode % 70).abs(),
        isVerified: blueTick,
        isDemoAccount: true,
        createdAt: createdAt.add(const Duration(days: 5, hours: 7)),
      );
      await _firestore.collection('posts').doc(post2Id).set(post2.toMap(), SetOptions(merge: true));
    }

    // 4. Follows System: Make demo accounts follow each other
    debugPrint('[DemoAccountsService] Setting up mutual follows between demo accounts...');
    for (int i = 0; i < demoUsersConfig.length; i++) {
      final current = demoUsersConfig[i]['uid'] as String;
      // Follow the next 4 demo accounts cyclically
      for (int step = 1; step <= 4; step++) {
        final targetIndex = (i + step) % demoUsersConfig.length;
        final target = demoUsersConfig[targetIndex]['uid'] as String;
        final followDocId = '${current}_$target';

        await _firestore.collection('follows').doc(followDocId).set({
          'followerId': current,
          'followingId': target,
          'isDemoFollow': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    debugPrint('[DemoAccountsService] Successfully seeded 10 Pro Demo Accounts!');
  }

  /// Deletes all demo accounts where isDemoAccount == true,
  /// along with their posts, clips, and follows.
  Future<int> deleteAllDemoAccounts() async {
    debugPrint('[DemoAccountsService] Deleting all demo accounts...');
    int deletedCount = 0;

    try {
      // 1. Find all demo users
      final userSnap = await _firestore
          .collection('users')
          .where('isDemoAccount', isEqualTo: true)
          .get();

      final demoUids = <String>{};
      for (final doc in userSnap.docs) {
        demoUids.add(doc.id);
      }

      // Also include demo_01 to demo_10 explicitly just in case
      for (final cfg in demoUsersConfig) {
        demoUids.add(cfg['uid'] as String);
      }

      // 2. Delete demo users
      for (final uid in demoUids) {
        await _firestore.collection('users').doc(uid).delete();
        deletedCount++;
      }

      // 3. Delete demo posts
      final postsSnap = await _firestore
          .collection('posts')
          .where('isDemoAccount', isEqualTo: true)
          .get();
      for (final doc in postsSnap.docs) {
        await doc.reference.delete();
      }
      // Also delete by known ids
      for (final uid in demoUids) {
        await _firestore.collection('posts').doc('post_${uid}_recruit').delete();
        await _firestore.collection('posts').doc('post_${uid}_achieve').delete();
      }

      // 4. Delete demo follows
      final followsSnap = await _firestore
          .collection('follows')
          .where('isDemoFollow', isEqualTo: true)
          .get();
      for (final doc in followsSnap.docs) {
        await doc.reference.delete();
      }

      debugPrint('[DemoAccountsService] Deleted $deletedCount demo accounts and cleanups.');
      return deletedCount;
    } catch (e) {
      debugPrint('[DemoAccountsService] Error deleting demo accounts: $e');
      return deletedCount;
    }
  }
}
