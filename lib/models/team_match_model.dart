import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values:
/// 'Pending' - Challenge sent, awaiting opponent team's response
/// 'Accepted' - Opponent team accepted, Match Room scheduled
/// 'Live' - Match time reached or started, Custom Room ID/Password live
/// 'Proof Submitted' - One or both teams submitted victory screenshot
/// 'Verified' - Admin reviewed proof and declared official winner
/// 'Disputed' - Both teams claimed win or disputed outcome; waiting for Admin
/// 'Rejected' - Challenge declined or match rejected by Admin
class TeamMatch {
  final String matchId;
  final String team1Id;
  final String team1Name;
  final String team1LeaderId;
  final String team1LeaderName;
  final String team1Avatar;
  final List<String> team1Members;

  final String team2Id;
  final String team2Name;
  final String team2LeaderId;
  final String team2LeaderName;
  final String team2Avatar;
  final List<String> team2Members;

  final String game; // BGMI, Free Fire, PUBG Mobile, COD Mobile, Valorant
  final String mode; // 1v1, 2v2, 4v4, Squad, TDM Warehouse
  final DateTime matchTime;
  final String entryFee; // 'Free'
  final String status; // Pending, Accepted, Live, Proof Submitted, Verified, Disputed, Rejected

  // Custom Room details (when match is Accepted or Live)
  final String customRoomId;
  final String customRoomPassword;

  // Win proof screenshots & claims
  final String? team1Proof;
  final String? team1Claim; // 'win', 'loss'
  final DateTime? team1ProofUploadedAt;
  final String? team2Proof;
  final String? team2Claim; // 'win', 'loss'
  final DateTime? team2ProofUploadedAt;

  final String? winnerId;
  final String? winnerName;
  final String? verifiedBy; // Admin ID or email
  final DateTime? verifiedAt;

  final String chatId;
  final bool team1Confirmed;
  final bool team2Confirmed;

  final DateTime createdAt;
  final String disputeReason;

  const TeamMatch({
    required this.matchId,
    required this.team1Id,
    required this.team1Name,
    required this.team1LeaderId,
    required this.team1LeaderName,
    this.team1Avatar = '',
    this.team1Members = const [],
    required this.team2Id,
    required this.team2Name,
    required this.team2LeaderId,
    required this.team2LeaderName,
    this.team2Avatar = '',
    this.team2Members = const [],
    required this.game,
    required this.mode,
    required this.matchTime,
    this.entryFee = 'Free',
    this.status = 'Pending',
    this.customRoomId = '',
    this.customRoomPassword = '',
    this.team1Proof,
    this.team1Claim,
    this.team1ProofUploadedAt,
    this.team2Proof,
    this.team2Claim,
    this.team2ProofUploadedAt,
    this.winnerId,
    this.winnerName,
    this.verifiedBy,
    this.verifiedAt,
    required this.chatId,
    this.team1Confirmed = false,
    this.team2Confirmed = false,
    required this.createdAt,
    this.disputeReason = '',
  });

  bool get isPending => status == 'Pending';
  bool get isAccepted => status == 'Accepted';
  bool get isLive => status == 'Live';
  bool get isProofSubmitted => status == 'Proof Submitted';
  bool get isVerified => status == 'Verified';
  bool get isDisputed => status == 'Disputed';
  bool get isRejected => status == 'Rejected';

  bool isMemberOfMatch(String userId) {
    return team1LeaderId == userId ||
        team2LeaderId == userId ||
        team1Members.contains(userId) ||
        team2Members.contains(userId);
  }

  bool isTeam1Leader(String userId) => team1LeaderId == userId;
  bool isTeam2Leader(String userId) => team2LeaderId == userId;
  bool isLeaderOfEither(String userId) => isTeam1Leader(userId) || isTeam2Leader(userId);

  factory TeamMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final mTime = parseTime(data['matchTime']);
    final cTime = parseTime(data['createdAt']);
    DateTime? vTime;
    if (data['verifiedAt'] != null) {
      vTime = parseTime(data['verifiedAt']);
    }
    DateTime? t1ProofTime;
    if (data['team1ProofUploadedAt'] != null) {
      t1ProofTime = parseTime(data['team1ProofUploadedAt']);
    }
    DateTime? t2ProofTime;
    if (data['team2ProofUploadedAt'] != null) {
      t2ProofTime = parseTime(data['team2ProofUploadedAt']);
    }

    return TeamMatch(
      matchId: data['matchId'] ?? doc.id,
      team1Id: (data['team1Id'] ?? '').toString(),
      team1Name: (data['team1Name'] ?? 'Team Alpha').toString(),
      team1LeaderId: (data['team1LeaderId'] ?? '').toString(),
      team1LeaderName: (data['team1LeaderName'] ?? 'Leader 1').toString(),
      team1Avatar: (data['team1Avatar'] ?? '').toString(),
      team1Members: List<String>.from(data['team1Members'] ?? []),
      team2Id: (data['team2Id'] ?? '').toString(),
      team2Name: (data['team2Name'] ?? 'Team Bravo').toString(),
      team2LeaderId: (data['team2LeaderId'] ?? '').toString(),
      team2LeaderName: (data['team2LeaderName'] ?? 'Leader 2').toString(),
      team2Avatar: (data['team2Avatar'] ?? '').toString(),
      team2Members: List<String>.from(data['team2Members'] ?? []),
      game: (data['game'] ?? 'BGMI').toString(),
      mode: (data['mode'] ?? '4v4').toString(),
      matchTime: mTime,
      entryFee: (data['entryFee'] ?? 'Free').toString(),
      status: (data['status'] ?? 'Pending').toString(),
      customRoomId: (data['customRoomId'] ?? '').toString(),
      customRoomPassword: (data['customRoomPassword'] ?? '').toString(),
      team1Proof: data['team1Proof'],
      team1Claim: data['team1Claim'],
      team1ProofUploadedAt: t1ProofTime,
      team2Proof: data['team2Proof'],
      team2Claim: data['team2Claim'],
      team2ProofUploadedAt: t2ProofTime,
      winnerId: data['winnerId'],
      winnerName: data['winnerName'],
      verifiedBy: data['verifiedBy'],
      verifiedAt: vTime,
      chatId: (data['chatId'] ?? doc.id).toString(),
      team1Confirmed: data['team1Confirmed'] == true,
      team2Confirmed: data['team2Confirmed'] == true,
      createdAt: cTime,
      disputeReason: (data['disputeReason'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'team1Id': team1Id,
      'team1Name': team1Name,
      'team1LeaderId': team1LeaderId,
      'team1LeaderName': team1LeaderName,
      'team1Avatar': team1Avatar,
      'team1Members': team1Members,
      'team2Id': team2Id,
      'team2Name': team2Name,
      'team2LeaderId': team2LeaderId,
      'team2LeaderName': team2LeaderName,
      'team2Avatar': team2Avatar,
      'team2Members': team2Members,
      'game': game,
      'mode': mode,
      'matchTime': Timestamp.fromDate(matchTime),
      'entryFee': entryFee,
      'status': status,
      'customRoomId': customRoomId,
      'customRoomPassword': customRoomPassword,
      'team1Proof': team1Proof,
      'team1Claim': team1Claim,
      'team1ProofUploadedAt': team1ProofUploadedAt != null ? Timestamp.fromDate(team1ProofUploadedAt!) : null,
      'team2Proof': team2Proof,
      'team2Claim': team2Claim,
      'team2ProofUploadedAt': team2ProofUploadedAt != null ? Timestamp.fromDate(team2ProofUploadedAt!) : null,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'chatId': chatId,
      'team1Confirmed': team1Confirmed,
      'team2Confirmed': team2Confirmed,
      'createdAt': Timestamp.fromDate(createdAt),
      'disputeReason': disputeReason,
    };
  }
}
