import '../services/supabase_service.dart';

class TeamModel {
  static const int maxMembers = 4;

  final String id;
  final String name;
  final String tag;
  final String logo;
  final String game;
  final String description;
  final String requirements;
  final String leaderId;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final DateTime createdAt;

  // Optional fields (populated from joins if needed)
  final String leaderName;
  final String leaderAvatar;
  final List<String> members;
  final Map<String, String> memberNames;
  final List<Map<String, dynamic>> memberDetails;
  final List<String> pendingJoinRequests;

  // Weekly Team Coins tracking fields (up to 4 members, tracked per game)
  final int weeklyCoins;
  final int weeklyRank;
  final Map<String, int> memberWeeklyCoins;

  const TeamModel({
    required this.id,
    required this.name,
    required this.tag,
    this.logo = '',
    required this.game,
    this.description = '',
    this.requirements = '',
    required this.leaderId,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    required this.createdAt,
    this.leaderName = '',
    this.leaderAvatar = '',
    this.members = const [],
    this.memberNames = const {},
    this.memberDetails = const [],
    this.pendingJoinRequests = const [],
    this.weeklyCoins = 0,
    this.weeklyRank = 0,
    this.memberWeeklyCoins = const {},
  });

  /// Enforces up to 4 active members per team
  List<String> get cappedMembers =>
      members.length > maxMembers ? members.sublist(0, maxMembers) : members;

  int get memberCount => cappedMembers.length;
  bool get isFull => memberCount >= maxMembers;
  int get totalMatches => wins + losses + draws;
  double get winRate => totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;

  /// Normalizes game labels so PUBG / BGMI / pubg_mobile always display as 'PUBG Mobile'
  /// and free_fire / Free Fire always display as 'Free Fire'.
  static String normalizeDisplayGameName(String? rawGame) {
    final clean = (rawGame ?? '').trim();
    if (clean.isEmpty) return 'Free Fire';
    final lower = clean.toLowerCase();
    if (lower == 'bgmi' ||
        lower == 'pubg' ||
        lower == 'pubg mobile' ||
        lower == 'pubg_mobile' ||
        lower.contains('battlegrounds mobile')) {
      return 'PUBG Mobile';
    }
    if (lower == 'free fire' ||
        lower == 'free_fire' ||
        lower == 'free fire max' ||
        lower == 'garena free fire') {
      return 'Free Fire';
    }
    return clean;
  }

  /// Normalizes game name to canonical storage key: 'free_fire' or 'pubg_mobile'
  static String normalizeGameKey(String? rawGame) {
    final display = normalizeDisplayGameName(rawGame);
    if (display == 'PUBG Mobile') return 'pubg_mobile';
    if (display == 'Free Fire') return 'free_fire';
    return display.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  /// Privacy & Data Minimization (Play Policy):
  /// Sanitizes a display name/handle so emails, phone numbers, or sensitive data are never exposed.
  static String sanitizePublicHandle(String? raw, {String fallback = 'Gamer'}) {
    if (raw == null) return fallback;
    var cleaned = raw.trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') return fallback;

    // Never expose email addresses: strip @domain
    if (cleaned.contains('@')) {
      final beforeAt = cleaned.split('@').first.trim();
      cleaned = beforeAt.isNotEmpty ? beforeAt : fallback;
    }

    // Never expose phone numbers (7+ digits sequence)
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 7 && digitsOnly.length >= (cleaned.length * 0.6)) {
      final suffix = digitsOnly.length >= 4
          ? digitsOnly.substring(digitsOnly.length - 4)
          : digitsOnly;
      return 'Gamer_$suffix';
    }

    if (cleaned.toLowerCase().startsWith('user_') && cleaned.length > 12) {
      return 'Gamer_${cleaned.substring(5, 9).toUpperCase()}';
    }

    return cleaned;
  }

  bool isLeader(String userId) {
    if (userId.isEmpty || leaderId.isEmpty) return false;
    final cleanLeader = leaderId.trim().toLowerCase();
    final cleanUser = userId.trim().toLowerCase();
    if (cleanLeader == cleanUser) return true;
    try {
      return SupabaseService.toUuid(cleanLeader) == SupabaseService.toUuid(cleanUser);
    } catch (_) {
      return false;
    }
  }

  bool isMember(String userId) {
    if (userId.isEmpty) return false;
    if (isLeader(userId)) return true;
    final cleanUser = userId.trim().toLowerCase();
    for (final m in cappedMembers) {
      final cleanM = m.trim().toLowerCase();
      if (cleanM == cleanUser) return true;
      try {
        if (SupabaseService.toUuid(cleanM) == SupabaseService.toUuid(cleanUser)) return true;
      } catch (_) {}
    }
    return false;
  }

  bool hasRequestedJoin(String userId) => pendingJoinRequests.contains(userId);

  factory TeamModel.fromSupabase(Map<String, dynamic> row) {
    final rawMembers = row['members'];
    final List<String> membersList = [];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m != null) {
          final uid = m.toString().trim();
          if (uid.isNotEmpty && !membersList.contains(uid) && membersList.length < maxMembers) {
            membersList.add(uid);
          }
        }
      }
    }

    final rawRequests = row['pendingJoinRequests'] ?? row['pending_join_requests'];
    final List<String> reqList = [];
    if (rawRequests is List) {
      for (final r in rawRequests) {
        if (r != null) reqList.add(r.toString());
      }
    }

    final rawMemberDetails = row['memberDetails'];
    final List<Map<String, dynamic>> detailsList = [];
    final Map<String, String> namesMap = {};
    if (rawMemberDetails is List) {
      for (final item in rawMemberDetails) {
        if (item is Map && detailsList.length < maxMembers) {
          final mapItem = Map<String, dynamic>.from(item);
          if (mapItem['name'] != null) {
            final cleanName = sanitizePublicHandle(mapItem['name']?.toString());
            mapItem['name'] = cleanName;
            final uid = (mapItem['id'] ?? mapItem['uid'] ?? mapItem['userId'] ?? '').toString().trim();
            if (uid.isNotEmpty) {
              namesMap[uid] = cleanName;
            }
          }
          detailsList.add(mapItem);
        }
      }
    }

    final rawMemberNames = row['member_names'] ?? row['memberNames'];
    if (rawMemberNames is Map) {
      rawMemberNames.forEach((k, v) {
        final key = k.toString().trim();
        if (key.isNotEmpty) {
          namesMap[key] = sanitizePublicHandle(v?.toString(), fallback: 'Gamer');
        }
      });
    }

    final rawWeeklyMap = row['member_weekly_coins'] ?? row['memberWeeklyCoins'];
    final Map<String, int> weeklyMap = {};
    if (rawWeeklyMap is Map) {
      rawWeeklyMap.forEach((k, v) {
        weeklyMap[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    final rawLeaderName = (row['leader_name'] ?? row['leaderName'] ?? '').toString();
    final cleanLeaderName = sanitizePublicHandle(rawLeaderName, fallback: 'Leader');
    final leaderIdStr = (row['leader_id'] ?? '').toString().trim();
    if (leaderIdStr.isNotEmpty && !namesMap.containsKey(leaderIdStr)) {
      namesMap[leaderIdStr] = cleanLeaderName;
    }

    return TeamModel(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? 'Gamer Team').toString(),
      tag: (row['tag'] ?? 'TEAM').toString().toUpperCase(),
      logo: (row['logo_url'] ?? '').toString(),
      game: normalizeDisplayGameName(row['game']?.toString()),
      description: (row['description'] ?? '').toString(),
      requirements: (row['requirements'] ?? '').toString(),
      leaderId: leaderIdStr,
      wins: (row['wins'] as num?)?.toInt() ?? 0,
      losses: (row['losses'] as num?)?.toInt() ?? 0,
      draws: (row['draws'] as num?)?.toInt() ?? 0,
      points: (row['points'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
      leaderName: cleanLeaderName,
      leaderAvatar: (row['leader_avatar'] ?? '').toString(),
      members: membersList,
      memberNames: namesMap,
      memberDetails: detailsList,
      pendingJoinRequests: reqList,
      weeklyCoins: (row['weekly_coins'] as num?)?.toInt() ?? 0,
      weeklyRank: (row['weekly_rank'] as num?)?.toInt() ?? 0,
      memberWeeklyCoins: weeklyMap,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'name': name.trim(),
      'tag': tag.trim().toUpperCase(),
      'logo_url': logo,
      'game': normalizeDisplayGameName(game),
      'description': description.trim(),
      'requirements': requirements.trim(),
      'leader_id': leaderId,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'points': points,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TeamModel copyWith({
    String? name,
    String? tag,
    String? logo,
    String? game,
    String? description,
    String? requirements,
    int? wins,
    int? losses,
    int? draws,
    int? points,
    String? leaderName,
    String? leaderAvatar,
    List<String>? members,
    Map<String, String>? memberNames,
    List<Map<String, dynamic>>? memberDetails,
    List<String>? pendingJoinRequests,
    int? weeklyCoins,
    int? weeklyRank,
    Map<String, int>? memberWeeklyCoins,
  }) {
    final nextMembers = members ?? this.members;
    final capped = nextMembers.length > maxMembers
        ? nextMembers.sublist(0, maxMembers)
        : nextMembers;
    return TeamModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      logo: logo ?? this.logo,
      game: game != null ? normalizeDisplayGameName(game) : this.game,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      leaderId: leaderId,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      points: points ?? this.points,
      createdAt: createdAt,
      leaderName: leaderName != null
          ? sanitizePublicHandle(leaderName, fallback: 'Leader')
          : this.leaderName,
      leaderAvatar: leaderAvatar ?? this.leaderAvatar,
      members: capped,
      memberNames: memberNames ?? this.memberNames,
      memberDetails: memberDetails ?? this.memberDetails,
      pendingJoinRequests: pendingJoinRequests ?? this.pendingJoinRequests,
      weeklyCoins: weeklyCoins ?? this.weeklyCoins,
      weeklyRank: weeklyRank ?? this.weeklyRank,
      memberWeeklyCoins: memberWeeklyCoins ?? this.memberWeeklyCoins,
    );
  }
}