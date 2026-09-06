import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentRoom {
  final String id;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  final String gameType; // 'BGMI', 'PUBG Mobile', 'Free Fire', 'Free Fire MAX', 'COD Mobile', 'Valorant', 'Ludo King', '8 Ball Pool'
  final String gameMode; // Mode within game (e.g. 'TDM 1v1', 'Clash Squad 4v4', etc.)
  final String roomType; // 'TDM 1v1', 'TDM 4v4', 'Classic Scrim', 'Custom Room' (kept for backward compatibility)
  final String title;
  final String map; // 'Erangel', 'Warehouse', 'Bermuda', 'Crash', etc.
  final String entryFee; // 'FREE' or '50 Coins'
  final String prize; // '💰 500 Coins Prize'
  final int prizePoolCoins;
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
  final List<String> joinedPlayers; // List of userIds
  final bool isLive;
  final bool isRoomRevealed; // reveal Room ID/Pass to joined players
  final DateTime? createdAt;

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
    this.entryFee = 'FREE',
    this.prize = '💰 500 Coins Prize',
    this.prizePoolCoins = 500,
    this.entryFeeCoins = 0,
    this.escrowCoins = 500,
    this.status = 'OPEN',
    this.winnerUid,
    this.winnerName,
    this.resultSubmissions = const {},
    this.roomId = '',
    this.password = '',
    required this.startTime,
    this.maxSlots = 2,
    this.joinedPlayers = const [],
    this.isLive = true,
    this.isRoomRevealed = false,
    this.createdAt,
  });

  int get availableSlots => maxSlots - joinedPlayers.length;
  bool get isFull => joinedPlayers.length >= maxSlots;
  bool get isCompleted => status == 'COMPLETED';
  bool get isExpired => status == 'EXPIRED' || status == 'CANCELED';

  String get gameIcon {
    switch (gameType) {
      case 'BGMI':
        return '🪖';
      case 'PUBG Mobile':
        return '🪂';
      case 'Free Fire':
        return '🔥';
      case 'Free Fire MAX':
        return '⚡';
      case 'COD Mobile':
        return '🎖️';
      case 'Valorant':
        return '⚔️';
      case 'Ludo King':
        return '🎲';
      case '8 Ball Pool':
        return '🎱';
      default:
        return '🎮';
    }
  }

  /// Whether this game uses invite link instead of Room ID + Password
  bool get isLinkOnlyGame => gameType == 'Ludo King' || gameType == '8 Ball Pool';

  String get credentialLabel => isLinkOnlyGame ? 'INVITE LINK / CODE' : 'ROOM ID';
  String get copyLabel => isLinkOnlyGame ? 'COPY LINK' : 'COPY ID';
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

  factory TournamentRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime start = DateTime.now().add(const Duration(hours: 1));
    final rawStart = data['startTime'];
    if (rawStart is Timestamp) {
      start = rawStart.toDate();
    } else if (rawStart is String) {
      start = DateTime.tryParse(rawStart) ?? start;
    }

    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    final prizeCoins = (data['prizePoolCoins'] as num?)?.toInt() ?? 500;
    final feeCoins = (data['entryFeeCoins'] as num?)?.toInt() ?? 0;
    final rawPrize = data['prize']?.toString() ?? '💰 $prizeCoins Coins Prize';
    // Clean up any old rupee signs
    final cleanPrize = rawPrize.replaceAll('₹', '💰 ').replaceAll('Cash', 'Coins');
    final gType = data['gameType']?.toString() ?? 'BGMI';
    final gMode = data['gameMode']?.toString() ?? (data['roomType'] ?? 'TDM 1v1');

    return TournamentRoom(
      id: data['id'] ?? doc.id,
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? 'Host',
      hostAvatar: data['hostAvatar'] ?? '',
      gameType: gType,
      gameMode: gMode,
      roomType: data['roomType'] ?? gMode,
      title: data['title'] ?? 'Custom Tournament',
      map: data['map'] ?? 'Erangel',
      entryFee: data['entryFee']?.toString().replaceAll('₹', '') ?? (feeCoins > 0 ? '$feeCoins Coins' : 'FREE'),
      prize: cleanPrize,
      prizePoolCoins: prizeCoins,
      entryFeeCoins: feeCoins,
      escrowCoins: (data['escrowCoins'] as num?)?.toInt() ?? prizeCoins,
      status: data['status'] ?? 'OPEN',
      winnerUid: data['winnerUid'],
      winnerName: data['winnerName'],
      resultSubmissions: Map<String, dynamic>.from(data['resultSubmissions'] ?? {}),
      roomId: data['roomId'] ?? '',
      password: data['password'] ?? '',
      startTime: start,
      maxSlots: (data['maxSlots'] as num?)?.toInt() ?? 2,
      joinedPlayers: List<String>.from(data['joinedPlayers'] ?? []),
      isLive: data['isLive'] ?? true,
      isRoomRevealed: data['isRoomRevealed'] == true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'gameType': gameType,
      'gameMode': gameMode,
      'roomType': roomType,
      'title': title.trim(),
      'map': map,
      'entryFee': entryFee.trim(),
      'prize': prize.trim(),
      'prizePoolCoins': prizePoolCoins,
      'entryFeeCoins': entryFeeCoins,
      'escrowCoins': escrowCoins,
      'status': status,
      'winnerUid': winnerUid,
      'winnerName': winnerName,
      'resultSubmissions': resultSubmissions,
      'roomId': roomId.trim(),
      'password': password.trim(),
      'startTime': Timestamp.fromDate(startTime),
      'maxSlots': maxSlots,
      'joinedPlayers': joinedPlayers,
      'isLive': isLive,
      'isRoomRevealed': isRoomRevealed,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'gameType': gameType,
      'gameMode': gameMode,
      'roomType': roomType,
      'title': title.trim(),
      'map': map,
      'entryFee': entryFee.trim(),
      'prize': prize.trim(),
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
      'maxSlots': maxSlots,
      'joinedPlayers': joinedPlayers,
      'isLive': isLive,
      'isRoomRevealed': isRoomRevealed,
      'createdAt': createdAt?.toIso8601String(),
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
    final rawPrize = json['prize']?.toString() ?? '💰 $prizeCoins Coins Prize';
    final cleanPrize = rawPrize.replaceAll('₹', '💰 ').replaceAll('Cash', 'Coins');
    final gType = json['gameType']?.toString() ?? 'BGMI';
    final gMode = json['gameMode']?.toString() ?? (json['roomType'] ?? 'TDM 1v1');

    return TournamentRoom(
      id: json['id'] ?? '',
      hostId: json['hostId'] ?? '',
      hostName: json['hostName'] ?? 'Host',
      hostAvatar: json['hostAvatar'] ?? '',
      gameType: gType,
      gameMode: gMode,
      roomType: json['roomType'] ?? gMode,
      title: json['title'] ?? 'Custom Tournament',
      map: json['map'] ?? 'Erangel',
      entryFee: json['entryFee']?.toString().replaceAll('₹', '') ?? (feeCoins > 0 ? '$feeCoins Coins' : 'FREE'),
      prize: cleanPrize,
      prizePoolCoins: prizeCoins,
      entryFeeCoins: feeCoins,
      escrowCoins: (json['escrowCoins'] as num?)?.toInt() ?? prizeCoins,
      status: json['status'] ?? 'OPEN',
      winnerUid: json['winnerUid'],
      winnerName: json['winnerName'],
      resultSubmissions: Map<String, dynamic>.from(json['resultSubmissions'] ?? {}),
      roomId: json['roomId'] ?? '',
      password: json['password'] ?? '',
      startTime: start,
      maxSlots: (json['maxSlots'] as num?)?.toInt() ?? 2,
      joinedPlayers: List<String>.from(json['joinedPlayers'] ?? []),
      isLive: json['isLive'] ?? true,
      isRoomRevealed: json['isRoomRevealed'] == true,
      createdAt: created,
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
    String? entryFee,
    String? prize,
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
    List<String>? joinedPlayers,
    bool? isLive,
    bool? isRoomRevealed,
    DateTime? createdAt,
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
      entryFee: entryFee ?? this.entryFee,
      prize: prize ?? this.prize,
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
      maxSlots: maxSlots ?? this.maxSlots,
      joinedPlayers: joinedPlayers ?? this.joinedPlayers,
      isLive: isLive ?? this.isLive,
      isRoomRevealed: isRoomRevealed ?? this.isRoomRevealed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
