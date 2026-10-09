class TournamentRoom {
  final String id;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  final String gameType; // 'BGMI', 'PUBG Mobile', 'Free Fire', 'Free Fire MAX', 'COD Mobile', 'Valorant', 'Ludo King', '8 Ball Pool'
  String get gameName => gameType;
  final String gameMode; // Mode within game (e.g. 'TDM 1v1', 'Clash Squad 4v4', etc.)
  final String roomType; // 'TDM 1v1', 'TDM 4v4', 'Classic Scrim', 'Custom Room' (kept for backward compatibility)
  final String title;
  final String map; // 'Erangel', 'Warehouse', 'Bermuda', 'Crash', etc.
  final String entryFee; // 'FREE' or '50 Coins'
  final String prize; // '💰 500 Coins Prize'
  final int prizePoolCoins;
  int get prizeCoins => prizePoolCoins;
  final int entryFeeCoins;
  final int escrowCoins;
  final String status; // 'OPEN', 'IN_PROGRESS', 'COMPLETED', 'EXPIRED', 'CANCELED'
  final String? winnerUid;
  final String? winnerName;
  final Map<String, dynamic> resultSubmissions; // uid -> {screenshotUrl, submittedAt, ocrText, isVictory}
  final String roomId; // Room ID or Invite Link
  final String password; // Password (optional/hidden for link games)
  final DateTime startTime;
  final int maxSlots;
  final int currentSlots;
  final int totalSlots;
  final String prizePool;
  final List<String> joinedPlayers; // List of userIds
  final Map<String, String> joinedPlayerNames; // Map of userId -> displayName
  final String platform; // 'Mobile', 'PC', 'Console', 'Cross-Platform'
  final String serverRegion; // 'Asia / India', 'Middle East', 'Europe', etc.
  final String rules; // Custom or standard rules
  final bool isLive;
  final bool isRoomRevealed; // reveal Room ID/Pass to joined players
  final DateTime? createdAt;
  final String? winProofUrl;
  final DateTime? winProofUploadedAt;
  final String rewardStatus; // 'idle', 'pending', 'sent'
  final DateTime? completedAt;
  final DateTime? autoApproveAt;
  final bool disputed;
  final String? disputedBy;
  final String? disputedByName;
  final String? disputeReason;
  final String? disputeProofUrl;
  final DateTime? disputedAt;

  const TournamentRoom({
    required this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatar = '',
    this.gameType = 'BGMI',
    this.gameMode = 'TDM 1v1',
    this.roomType = 'TDM 1v1',
    required this.title,
    this.map = 'Erangel',
    this.platform = 'Mobile',
    this.serverRegion = 'Asia / India',
    this.rules = 'Fair play only. No emulators or hacks allowed.',
    this.entryFee = 'FREE',
    this.prize = '💰 500 Coins Prize',
    this.prizePool = '',
    this.prizePoolCoins = 500,
    this.entryFeeCoins = 0,
    this.escrowCoins = 500,
    this.status = 'active',
    this.winnerUid,
    this.winnerName,
    this.resultSubmissions = const {},
    this.roomId = '',
    this.password = '',
    required this.startTime,
    this.maxSlots = 2,
    this.currentSlots = 1,
    this.totalSlots = 2,
    this.joinedPlayers = const [],
    this.joinedPlayerNames = const {},
    this.isLive = true,
    this.isRoomRevealed = false,
    this.createdAt,
    this.winProofUrl,
    this.winProofUploadedAt,
    this.rewardStatus = 'idle',
    this.completedAt,
    this.autoApproveAt,
    this.disputed = false,
    this.disputedBy,
    this.disputedByName,
    this.disputeReason,
    this.disputeProofUrl,
    this.disputedAt,
  });

  String getPlayerName(String uid) {
    if (uid == hostId && hostName.isNotEmpty) return hostName;
    if (joinedPlayerNames.containsKey(uid) && joinedPlayerNames[uid]!.trim().isNotEmpty) {
      return joinedPlayerNames[uid]!.trim();
    }
    final sub = resultSubmissions[uid] as Map<String, dynamic>?;
    if (sub != null && sub['playerName'] != null && sub['playerName'].toString().trim().isNotEmpty) {
      return sub['playerName'].toString().trim();
    }
    return uid == hostId ? 'Host' : 'Player';
  }

  List<String> get joinedUserIds => joinedPlayers;

  int get availableSlots => (totalSlots > 0 ? totalSlots : maxSlots) - (currentSlots > 0 ? currentSlots : joinedPlayers.length);
  bool get isFull => (currentSlots > 0 ? currentSlots : joinedPlayers.length) >= (totalSlots > 0 ? totalSlots : maxSlots);
  bool get isCompleted => status.toLowerCase() == 'completed' || rewardStatus.toLowerCase() == 'sent';
  bool get isDisputed => disputed || status.toLowerCase() == 'disputed' || status.toLowerCase() == 'under_review';
  bool get isUnderReview => status.toLowerCase() == 'under_review' || isDisputed;
  bool get isProofRejected =>
      !isCompleted &&
      (status.toLowerCase() == 'proof_rejected' ||
          rewardStatus.toLowerCase() == 'rejected_by_app' ||
          rewardStatus.toLowerCase() == 'rejected');
  bool get isRewardWaiting =>
      !isCompleted &&
      !isProofRejected &&
      !isDisputed &&
      (status.toLowerCase() == 'reward_waiting' ||
          rewardStatus.toLowerCase() == 'pending' ||
          rewardStatus.toLowerCase() == 'pending_host' ||
          (winProofUrl != null && winProofUrl!.isNotEmpty));
  bool get isExpired => status.toUpperCase() == 'EXPIRED' || status.toUpperCase() == 'CANCELED';
  bool get isActive => !isCompleted && !isRewardWaiting && !isProofRejected && (status.toLowerCase() == 'active' || status.toUpperCase() == 'OPEN');
  bool get isInProgress => !isCompleted && !isRewardWaiting && !isProofRejected && (status.toUpperCase() == 'IN_PROGRESS' || status.toUpperCase() == 'STARTED' || status.toUpperCase() == 'MATCH_STARTED');
  bool get isExpiredCompleted {
    if (!isCompleted || completedAt == null) return false;
    return DateTime.now().difference(completedAt!).inMinutes >= 5;
  }
  String get displayPrizePool => prizePool.isNotEmpty ? prizePool : (prizePoolCoins > 0 ? '💰 $prizePoolCoins Coins' : prize);

  String get gameIcon {
    switch (gameType) {
      case 'BGMI':
        return '🪖';
      case 'PUBG Mobile':
        return '🪂';
      case 'Garena Free Fire':
      case 'Free Fire':
        return '🔥';
      case 'Free Fire Max':
      case 'Free Fire MAX':
        return '⚡';
      case 'COD Mobile':
        return '🎖️';
      case 'COD Warzone':
        return '🎯';
      case 'Valorant':
        return '⚔️';
      case 'Fortnite':
        return '⛏️';
      case 'Apex Legends':
        return '🏹';
      case 'Counter-Strike 2':
      case 'CS2':
        return '💣';
      case 'Mobile Legends Bang Bang':
      case 'MLBB':
        return '🛡️';
      case 'League of Legends':
      case 'LoL':
        return '🧙‍♂️';
      case 'Clash Royale':
        return '👑';
      case 'Brawl Stars':
        return '🥊';
      case 'Minecraft':
        return '🧱';
      case 'Roblox':
        return '🕹️';
      case 'EA Sports FC 25':
      case 'FC 25':
        return '⚽';
      case '8 Ball Pool':
        return '🎱';
      case 'Ludo King':
        return '🎲';
      case 'Among Us':
        return '🚀';
      default:
        return '🎮';
    }
  }

  /// Whether this game uses invite link instead of Room ID + Password
  bool get isLinkOnlyGame =>
      gameType == 'Ludo King' ||
      gameType == '8 Ball Pool' ||
      gameType == 'Clash Royale' ||
      gameType == 'Brawl Stars';

  /// Whether this game uses Lobby Code
  bool get isLobbyCodeGame =>
      gameType == 'Valorant' ||
      gameType == 'Counter-Strike 2' ||
      gameType == 'Fortnite' ||
      gameType == 'Apex Legends' ||
      gameType == 'League of Legends' ||
      gameType == 'Among Us' ||
      gameType == 'Roblox';

  String get credentialLabel {
    if (isLinkOnlyGame) return 'INVITE LINK / CODE';
    if (isLobbyCodeGame) return 'LOBBY CODE';
    return 'ROOM ID';
  }

  String get copyLabel {
    if (isLinkOnlyGame) return 'COPY LINK';
    if (isLobbyCodeGame) return 'COPY CODE';
    return 'COPY ID';
  }
  String get launchAppLabel {
    switch (gameType) {
      case 'BGMI':
        return 'ENTER BGMI 🎮';
      case 'PUBG Mobile':
        return 'ENTER PUBG 🪂';
      case 'Free Fire':
      case 'Free Fire MAX':
        return 'ENTER FREE FIRE 🔥';
      case 'COD Mobile':
        return 'ENTER COD MOBILE 🎖️';
      case 'Valorant':
        return 'ENTER VALORANT ⚔️';
      case 'Ludo King':
        return 'OPEN LUDO KING 🎲';
      case '8 Ball Pool':
        return 'OPEN 8 BALL POOL 🎱';
      default:
        return 'ENTER GAME 🎮';
    }
  }

  static DateTime _parseDateTime(dynamic raw, [DateTime? fallback]) {
    if (raw == null) return fallback ?? DateTime.now();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    try {
      final dt = (raw as dynamic)?.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    try {
      final dt = (raw as dynamic)?.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }

  factory TournamentRoom.fromFirestore(dynamic doc) => TournamentRoom.fromSupabase(doc);
  factory TournamentRoom.fromSupabase(dynamic doc) {
    if (doc == null) return TournamentRoom.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return TournamentRoom.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return TournamentRoom.fromMap(doc, doc['id']?.toString());
    }
    return TournamentRoom.fromMap({}, '');
  }

  factory TournamentRoom.fromMap(Map<String, dynamic> data, [String? docId]) {
    DateTime start = _parseDateTime(data['startTime'] ?? data['start_time'], DateTime.now().add(const Duration(hours: 1)));
    DateTime? created = _parseNullableDateTime(data['createdAt'] ?? data['created_at']);

    final prizeCoins = (data['prizePoolCoins'] ?? data['prize_pool_coins'] as num?)?.toInt() ?? 500;
    final feeCoins = (data['entryFeeCoins'] ?? data['entry_fee_coins'] as num?)?.toInt() ?? 0;
    final rawPrize = data['prize']?.toString() ?? data['prizePool']?.toString() ?? data['prize_pool']?.toString() ?? '💰 $prizeCoins Coins Prize';
    final cleanPrize = rawPrize.replaceAll('₹', '💰 ').replaceAll('Cash', 'Coins');
    final gType = data['gameName']?.toString() ?? data['game_name']?.toString() ?? data['gameType']?.toString() ?? data['game_type']?.toString() ?? 'BGMI';
    final gMode = data['gameMode']?.toString() ?? data['game_mode']?.toString() ?? (data['roomType'] ?? data['room_type'] ?? 'TDM 1v1');
    final joined = List<String>.from(data['joinedPlayers'] ?? data['joined_players'] ?? []);
    final pNames = Map<String, String>.from(data['joinedPlayerNames'] ?? data['joined_player_names'] ?? data['playerNames'] ?? {});
    final cSlots = (data['currentSlots'] ?? data['current_slots'] as num?)?.toInt() ?? (joined.isNotEmpty ? joined.length : 1);
    final tSlots = (data['totalSlots'] ?? data['total_slots'] as num?)?.toInt() ?? (data['maxSlots'] ?? data['max_slots'] as num?)?.toInt() ?? 2;
    final pPool = data['prizePool']?.toString() ?? data['prize_pool']?.toString() ?? cleanPrize;
    final statusStr = (data['status']?.toString() ?? 'active');
    final winProofUrl = data['winProofUrl']?.toString() ?? data['win_proof_url']?.toString() ?? data['proofUrl']?.toString() ?? data['proof_url']?.toString();
    DateTime? winProofUploadedAt = _parseNullableDateTime(data['winProofUploadedAt'] ?? data['win_proof_uploaded_at']);
    final rewardStatus = (data['rewardStatus'] ?? data['reward_status'] ?? (statusStr.toLowerCase() == 'completed' ? 'sent' : 'idle')).toString();
    DateTime? completedAt = _parseNullableDateTime(data['completedAt'] ?? data['completed_at']);
    DateTime? autoApproveAt = _parseNullableDateTime(data['autoApproveAt'] ?? data['auto_approve_at']);

    final bool disputed = data['disputed'] == true || statusStr.toLowerCase() == 'disputed' || statusStr.toLowerCase() == 'under_review';
    final String? disputedBy = (data['disputedBy'] ?? data['disputed_by'])?.toString();
    final String? disputedByName = (data['disputedByName'] ?? data['disputed_by_name'])?.toString();
    final String? disputeReason = (data['disputeReason'] ?? data['dispute_reason'])?.toString();
    final String? disputeProofUrl = (data['disputeProofUrl'] ?? data['dispute_proof_url'])?.toString();
    DateTime? disputedAt = _parseNullableDateTime(data['disputedAt'] ?? data['disputed_at']);

    String resolvedHostName = (data['hostName'] ?? data['host_name'] ?? data['host'] ?? data['hostUsername'] ?? '').toString().trim();
    if (resolvedHostName.isEmpty || resolvedHostName.toLowerCase() == 'host') {
      final hId = (data['hostId'] ?? data['host_id'] ?? '').toString();
      if (pNames.containsKey(hId) && pNames[hId]!.trim().isNotEmpty && pNames[hId]!.trim().toLowerCase() != 'host') {
        resolvedHostName = pNames[hId]!.trim();
      }
    }
    if (resolvedHostName.isEmpty) resolvedHostName = 'Host';

    final id = (data['id'] ?? docId ?? '').toString();

    return TournamentRoom(
      id: id,
      hostId: (data['hostId'] ?? data['host_id'] ?? '').toString(),
      hostName: resolvedHostName,
      hostAvatar: (data['hostAvatar'] ?? data['host_avatar'] ?? '').toString(),
      gameType: gType,
      gameMode: gMode,
      roomType: data['roomType'] ?? data['room_type'] ?? gMode,
      title: data['title'] ?? '$gType Match',
      map: data['map'] ?? 'Default',
      platform: data['platform'] ?? 'Mobile',
      serverRegion: data['serverRegion'] ?? data['server_region'] ?? 'Asia / India',
      rules: data['rules'] ?? 'Fair play only. No emulators or hacks allowed.',
      entryFee: data['entryFee']?.toString().replaceAll('₹', '') ?? (feeCoins > 0 ? '$feeCoins Coins' : 'FREE'),
      prize: cleanPrize,
      prizePool: pPool,
      prizePoolCoins: prizeCoins,
      entryFeeCoins: feeCoins,
      escrowCoins: (data['escrowCoins'] ?? data['escrow_coins'] as num?)?.toInt() ?? prizeCoins,
      status: statusStr.toUpperCase() == 'OPEN' ? 'active' : statusStr,
      winnerUid: data['winnerUid'] ?? data['winner_uid'],
      winnerName: data['winnerName'] ?? data['winner_name'],
      resultSubmissions: Map<String, dynamic>.from(data['resultSubmissions'] ?? data['result_submissions'] ?? {}),
      roomId: data['roomId'] ?? data['room_id'] ?? '',
      password: data['password'] ?? '',
      startTime: start,
      maxSlots: tSlots,
      currentSlots: cSlots,
      totalSlots: tSlots,
      joinedPlayers: joined,
      joinedPlayerNames: pNames,
      isLive: data['isLive'] ?? data['is_live'] ?? true,
      isRoomRevealed: data['isRoomRevealed'] == true || data['is_room_revealed'] == true,
      createdAt: created,
      winProofUrl: winProofUrl,
      winProofUploadedAt: winProofUploadedAt,
      rewardStatus: rewardStatus,
      completedAt: completedAt,
      autoApproveAt: autoApproveAt,
      disputed: disputed,
      disputedBy: disputedBy,
      disputedByName: disputedByName,
      disputeReason: disputeReason,
      disputeProofUrl: disputeProofUrl,
      disputedAt: disputedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final nowStr = (createdAt ?? DateTime.now()).toIso8601String();
    return {
      'id': id,
      'hostId': hostId,
      'host_id': hostId,
      'hostName': hostName,
      'host_name': hostName,
      'hostAvatar': hostAvatar,
      'host_avatar': hostAvatar,
      'gameName': gameType,
      'game_name': gameType,
      'gameType': gameType,
      'game_type': gameType,
      'gameMode': gameMode,
      'game_mode': gameMode,
      'roomType': roomType,
      'room_type': roomType,
      'title': title.trim(),
      'map': map,
      'platform': platform,
      'serverRegion': serverRegion,
      'server_region': serverRegion,
      'rules': rules,
      'entryFee': entryFee.trim(),
      'entry_fee': entryFee.trim(),
      'prize': prize.trim(),
      'prizePool': prizePool.isNotEmpty ? prizePool : (prizePoolCoins > 0 ? '💰 $prizePoolCoins Coins' : prize),
      'prize_pool': prizePool.isNotEmpty ? prizePool : (prizePoolCoins > 0 ? '💰 $prizePoolCoins Coins' : prize),
      'prizePoolCoins': prizePoolCoins,
      'prize_pool_coins': prizePoolCoins,
      'entryFeeCoins': entryFeeCoins,
      'entry_fee_coins': entryFeeCoins,
      'escrowCoins': escrowCoins,
      'escrow_coins': escrowCoins,
      'status': status.toUpperCase() == 'OPEN' ? 'active' : status,
      'winnerUid': winnerUid,
      'winner_uid': winnerUid,
      'winnerName': winnerName,
      'winner_name': winnerName,
      'resultSubmissions': resultSubmissions,
      'result_submissions': resultSubmissions,
      'roomId': roomId.trim(),
      'room_id': roomId.trim(),
      'password': password.trim(),
      'startTime': startTime.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'maxSlots': totalSlots > 0 ? totalSlots : maxSlots,
      'max_slots': totalSlots > 0 ? totalSlots : maxSlots,
      'totalSlots': totalSlots > 0 ? totalSlots : maxSlots,
      'total_slots': totalSlots > 0 ? totalSlots : maxSlots,
      'currentSlots': currentSlots > 0 ? currentSlots : (joinedPlayers.isNotEmpty ? joinedPlayers.length : 1),
      'current_slots': currentSlots > 0 ? currentSlots : (joinedPlayers.isNotEmpty ? joinedPlayers.length : 1),
      'slots': '${currentSlots > 0 ? currentSlots : (joinedPlayers.isNotEmpty ? joinedPlayers.length : 1)}/${totalSlots > 0 ? totalSlots : maxSlots}',
      'joinedPlayers': joinedPlayers,
      'joined_players': joinedPlayers,
      'joinedPlayerNames': joinedPlayerNames,
      'joined_player_names': joinedPlayerNames,
      'isLive': isLive,
      'is_live': isLive,
      'isRoomRevealed': isRoomRevealed,
      'is_room_revealed': isRoomRevealed,
      'createdAt': nowStr,
      'created_at': nowStr,
      'winProofUrl': winProofUrl,
      'win_proof_url': winProofUrl,
      'winProofUploadedAt': winProofUploadedAt?.toIso8601String(),
      'win_proof_uploaded_at': winProofUploadedAt?.toIso8601String(),
      'rewardStatus': rewardStatus,
      'reward_status': rewardStatus,
      'completedAt': completedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'autoApproveAt': autoApproveAt?.toIso8601String(),
      'auto_approve_at': autoApproveAt?.toIso8601String(),
      'disputed': disputed,
      'disputedBy': disputedBy,
      'disputed_by': disputedBy,
      'disputedByName': disputedByName,
      'disputed_by_name': disputedByName,
      'disputeReason': disputeReason,
      'dispute_reason': disputeReason,
      'disputeProofUrl': disputeProofUrl,
      'dispute_proof_url': disputeProofUrl,
      'disputedAt': disputedAt?.toIso8601String(),
      'disputed_at': disputedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'gameName': gameType,
      'gameType': gameType,
      'gameMode': gameMode,
      'roomType': roomType,
      'title': title.trim(),
      'map': map,
      'platform': platform,
      'serverRegion': serverRegion,
      'rules': rules,
      'entryFee': entryFee.trim(),
      'prize': prize.trim(),
      'prizePool': prizePool.isNotEmpty ? prizePool : (prizePoolCoins > 0 ? '💰 $prizePoolCoins Coins' : prize),
      'prizePoolCoins': prizePoolCoins,
      'entryFeeCoins': entryFeeCoins,
      'escrowCoins': escrowCoins,
      'status': status,
      'winnerUid': winnerUid,
      'winnerName': winnerName,
      'resultSubmissions': resultSubmissions,
      'roomId': roomId.trim(),
      'password': password.trim(),
      'startTime': startTime.toIso8601String(),
      'maxSlots': totalSlots > 0 ? totalSlots : maxSlots,
      'totalSlots': totalSlots > 0 ? totalSlots : maxSlots,
      'currentSlots': currentSlots > 0 ? currentSlots : (joinedPlayers.isNotEmpty ? joinedPlayers.length : 1),
      'joinedPlayers': joinedPlayers,
      'joinedPlayerNames': joinedPlayerNames,
      'isLive': isLive,
      'isRoomRevealed': isRoomRevealed,
      'createdAt': createdAt?.toIso8601String(),
      'winProofUrl': winProofUrl,
      'winProofUploadedAt': winProofUploadedAt?.toIso8601String(),
      'rewardStatus': rewardStatus,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TournamentRoom.fromJson(Map<String, dynamic> json) {
    DateTime start = DateTime.now().add(const Duration(hours: 1));
    final rawStart = json['startTime'];
    if (rawStart != null) {
      start = DateTime.tryParse(rawStart.toString()) ?? start;
    }

    DateTime? created;
    final rawCreated = json['createdAt'];
    if (rawCreated != null) {
      created = DateTime.tryParse(rawCreated.toString());
    }

    final prizeCoins = (json['prizePoolCoins'] as num?)?.toInt() ?? 500;
    final feeCoins = (json['entryFeeCoins'] as num?)?.toInt() ?? 0;
    final rawPrize = json['prize']?.toString() ?? json['prizePool']?.toString() ?? '💰 $prizeCoins Coins Prize';
    final cleanPrize = rawPrize.replaceAll('₹', '💰 ').replaceAll('Cash', 'Coins');
    final gType = json['gameName']?.toString() ?? json['gameType']?.toString() ?? 'BGMI';
    final gMode = json['gameMode']?.toString() ?? (json['roomType'] ?? 'TDM 1v1');
    final joined = List<String>.from(json['joinedPlayers'] ?? []);
    final pNames = Map<String, String>.from(json['joinedPlayerNames'] ?? json['playerNames'] ?? {});
    final cSlots = (json['currentSlots'] as num?)?.toInt() ?? (joined.isNotEmpty ? joined.length : 1);
    final tSlots = (json['totalSlots'] as num?)?.toInt() ?? (json['maxSlots'] as num?)?.toInt() ?? 2;
    final pPool = json['prizePool']?.toString() ?? cleanPrize;

    return TournamentRoom(
      id: json['id'] ?? '',
      hostId: json['hostId'] ?? '',
      hostName: json['hostName'] ?? 'Host',
      hostAvatar: json['hostAvatar'] ?? '',
      gameType: gType,
      gameMode: gMode,
      roomType: json['roomType'] ?? gMode,
      title: json['title'] ?? 'Custom Tournament',
      map: json['map'] ?? 'Default',
      platform: json['platform'] ?? 'Mobile',
      serverRegion: json['serverRegion'] ?? 'Asia / India',
      rules: json['rules'] ?? 'Fair play only. No emulators or hacks allowed.',
      entryFee: json['entryFee']?.toString().replaceAll('₹', '') ?? (feeCoins > 0 ? '$feeCoins Coins' : 'FREE'),
      prize: cleanPrize,
      prizePool: pPool,
      prizePoolCoins: prizeCoins,
      entryFeeCoins: feeCoins,
      escrowCoins: (json['escrowCoins'] as num?)?.toInt() ?? prizeCoins,
      status: json['status'] ?? 'active',
      winnerUid: json['winnerUid'],
      winnerName: json['winnerName'],
      resultSubmissions: Map<String, dynamic>.from(json['resultSubmissions'] ?? {}),
      roomId: json['roomId'] ?? '',
      password: json['password'] ?? '',
      startTime: start,
      maxSlots: tSlots,
      currentSlots: cSlots,
      totalSlots: tSlots,
      joinedPlayers: joined,
      joinedPlayerNames: pNames,
      isLive: json['isLive'] ?? true,
      isRoomRevealed: json['isRoomRevealed'] == true,
      createdAt: created,
      winProofUrl: json['winProofUrl'] ?? json['proofUrl'],
      winProofUploadedAt: json['winProofUploadedAt'] != null ? DateTime.tryParse(json['winProofUploadedAt']) : null,
      rewardStatus: json['rewardStatus'] ?? 'idle',
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
    );
  }

  TournamentRoom copyWith({
    String? id,
    String? hostId,
    String? hostName,
    String? hostAvatar,
    String? gameType,
    String? gameMode,
    String? roomType,
    String? title,
    String? map,
    String? platform,
    String? serverRegion,
    String? rules,
    String? entryFee,
    String? prize,
    String? prizePool,
    int? prizePoolCoins,
    int? entryFeeCoins,
    int? escrowCoins,
    String? status,
    String? winnerUid,
    String? winnerName,
    Map<String, dynamic>? resultSubmissions,
    String? roomId,
    String? password,
    DateTime? startTime,
    int? maxSlots,
    int? currentSlots,
    int? totalSlots,
    List<String>? joinedPlayers,
    Map<String, String>? joinedPlayerNames,
    bool? isLive,
    bool? isRoomRevealed,
    DateTime? createdAt,
    String? winProofUrl,
    DateTime? winProofUploadedAt,
    String? rewardStatus,
    DateTime? completedAt,
  }) {
    return TournamentRoom(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      gameType: gameType ?? this.gameType,
      gameMode: gameMode ?? this.gameMode,
      roomType: roomType ?? this.roomType,
      title: title ?? this.title,
      map: map ?? this.map,
      platform: platform ?? this.platform,
      serverRegion: serverRegion ?? this.serverRegion,
      rules: rules ?? this.rules,
      entryFee: entryFee ?? this.entryFee,
      prize: prize ?? this.prize,
      prizePool: prizePool ?? this.prizePool,
      prizePoolCoins: prizePoolCoins ?? this.prizePoolCoins,
      entryFeeCoins: entryFeeCoins ?? this.entryFeeCoins,
      escrowCoins: escrowCoins ?? this.escrowCoins,
      status: status ?? this.status,
      winnerUid: winnerUid ?? this.winnerUid,
      winnerName: winnerName ?? this.winnerName,
      resultSubmissions: resultSubmissions ?? this.resultSubmissions,
      roomId: roomId ?? this.roomId,
      password: password ?? this.password,
      startTime: startTime ?? this.startTime,
      maxSlots: totalSlots ?? maxSlots ?? this.maxSlots,
      currentSlots: currentSlots ?? this.currentSlots,
      totalSlots: totalSlots ?? this.totalSlots,
      joinedPlayers: joinedPlayers ?? this.joinedPlayers,
      joinedPlayerNames: joinedPlayerNames ?? this.joinedPlayerNames,
      isLive: isLive ?? this.isLive,
      isRoomRevealed: isRoomRevealed ?? this.isRoomRevealed,
      createdAt: createdAt ?? this.createdAt,
      winProofUrl: winProofUrl ?? this.winProofUrl,
      winProofUploadedAt: winProofUploadedAt ?? this.winProofUploadedAt,
      rewardStatus: rewardStatus ?? this.rewardStatus,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
