/// Status values:
/// 'Pending' - Challenge sent, awaiting opponent team's response
/// 'Accepted' - Opponent team accepted, Match Room scheduled
/// 'Live' - Match time reached or started, Custom Room ID/Password live
/// 'Proof Submitted' - One or both teams submitted victory screenshot
/// 'Verified' - Admin reviewed proof and declared official winner
/// 'Disputed' - Both teams claimed win or disputed outcome; waiting for Admin
/// 'Rejected' - Challenge declined or match rejected by Admin
/// 'Cancelled' - Challenge cancelled by the challenging team leader
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

  // Admin Note, Proof Tracking & Resubmission
  final String? adminNote;
  final String? rejectReason;
  final int proofAttempts; // 1 or 2
  final DateTime? lastProofAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;

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
    this.adminNote,
    this.rejectReason,
    this.proofAttempts = 0,
    this.lastProofAt,
    this.rejectedBy,
    this.rejectedAt,
  });

  bool get isPending => status == 'Pending';
  bool get isAccepted => status == 'Accepted';
  bool get isLive => status == 'Live';
  bool get isProofSubmitted => status == 'Proof Submitted';
  bool get isVerified => status == 'Verified';
  bool get isDisputed => status == 'Disputed';
  bool get isRejected => status == 'Rejected';
  bool get isCancelled => status == 'Cancelled';

  bool get canUploadNewProof => proofAttempts < 2 && !isVerified && !isCancelled && !isPermanentlyRejected;
  bool get isPermanentlyRejected => isRejected && proofAttempts >= 2;

  bool get isActive =>
      isPending || isAccepted || isLive || isProofSubmitted || (isDisputed && !isPermanentlyRejected) || (isRejected && canUploadNewProof);
  bool get isHistory => isVerified || isCancelled || isPermanentlyRejected || (isRejected && !canUploadNewProof);

  bool isMemberOfMatch(String userId) {
    return team1LeaderId == userId ||
        team2LeaderId == userId ||
        team1Members.contains(userId) ||
        team2Members.contains(userId);
  }

  bool isTeam1Leader(String userId) => team1LeaderId == userId;
  bool isTeam2Leader(String userId) => team2LeaderId == userId;
  bool isLeaderOfEither(String userId) => isTeam1Leader(userId) || isTeam2Leader(userId);

  static DateTime _parseDateTime(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    try {
      final dt = (raw as dynamic)?.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    try {
      final dt = (raw as dynamic)?.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }

  factory TeamMatch.fromFirestore(dynamic doc) => TeamMatch.fromSupabase(doc);
  factory TeamMatch.fromSupabase(dynamic doc) {
    if (doc == null) return TeamMatch.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return TeamMatch.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return TeamMatch.fromMap(doc, doc['id']?.toString());
    }
    return TeamMatch.fromMap({}, '');
  }

  factory TeamMatch.fromMap(Map<String, dynamic> data, [String? docId]) {
    final mTime = _parseDateTime(data['matchTime'] ?? data['match_time']);
    final cTime = _parseDateTime(data['createdAt'] ?? data['created_at']);
    final vTime = _parseNullableDateTime(data['verifiedAt'] ?? data['verified_at']);
    final t1ProofTime = _parseNullableDateTime(data['team1ProofUploadedAt'] ?? data['team1_proof_uploaded_at']);
    final t2ProofTime = _parseNullableDateTime(data['team2ProofUploadedAt'] ?? data['team2_proof_uploaded_at']);
    final rejTime = _parseNullableDateTime(data['rejectedAt'] ?? data['rejected_at']);
    final lastProofTime = _parseNullableDateTime(data['lastProofAt'] ?? data['last_proof_at']);

    final adminNoteVal = (data['adminNote'] ?? data['admin_note']) as String?;
    final rejectReasonVal = (data['rejectReason'] ?? data['reject_reason']) as String?;
    final effectiveNote = adminNoteVal ?? rejectReasonVal;

    int pAttempts = (data['proofAttempts'] ?? data['proof_attempts'] as num?)?.toInt() ?? 0;
    if (pAttempts == 0 && (data['team1Proof'] != null || data['team2Proof'] != null || effectiveNote != null)) {
      pAttempts = 1;
    }

    final id = data['matchId'] ?? data['match_id'] ?? data['id'] ?? docId ?? '';

    return TeamMatch(
      matchId: id.toString(),
      team1Id: (data['team1Id'] ?? data['team1_id'] ?? '').toString(),
      team1Name: (data['team1Name'] ?? data['team1_name'] ?? 'Team Alpha').toString(),
      team1LeaderId: (data['team1LeaderId'] ?? data['team1_leader_id'] ?? '').toString(),
      team1LeaderName: (data['team1LeaderName'] ?? data['team1_leader_name'] ?? 'Leader 1').toString(),
      team1Avatar: (data['team1Avatar'] ?? data['team1_avatar'] ?? '').toString(),
      team1Members: List<String>.from(data['team1Members'] ?? data['team1_members'] ?? []),
      team2Id: (data['team2Id'] ?? data['team2_id'] ?? '').toString(),
      team2Name: (data['team2Name'] ?? data['team2_name'] ?? 'Team Bravo').toString(),
      team2LeaderId: (data['team2LeaderId'] ?? data['team2_leader_id'] ?? '').toString(),
      team2LeaderName: (data['team2LeaderName'] ?? data['team2_leader_name'] ?? 'Leader 2').toString(),
      team2Avatar: (data['team2Avatar'] ?? data['team2_avatar'] ?? '').toString(),
      team2Members: List<String>.from(data['team2Members'] ?? data['team2_members'] ?? []),
      game: (data['game'] ?? 'BGMI').toString(),
      mode: (data['mode'] ?? '4v4').toString(),
      matchTime: mTime,
      entryFee: (data['entryFee'] ?? data['entry_fee'] ?? 'Free').toString(),
      status: (data['status'] ?? 'Pending').toString(),
      customRoomId: (data['customRoomId'] ?? data['custom_room_id'] ?? '').toString(),
      customRoomPassword: (data['customRoomPassword'] ?? data['custom_room_password'] ?? '').toString(),
      team1Proof: data['team1Proof'] ?? data['team1_proof'],
      team1Claim: data['team1Claim'] ?? data['team1_claim'],
      team1ProofUploadedAt: t1ProofTime,
      team2Proof: data['team2Proof'] ?? data['team2_proof'],
      team2Claim: data['team2Claim'] ?? data['team2_claim'],
      team2ProofUploadedAt: t2ProofTime,
      winnerId: data['winnerId'] ?? data['winner_id'],
      winnerName: data['winnerName'] ?? data['winner_name'],
      verifiedBy: data['verifiedBy'] ?? data['verified_by'],
      verifiedAt: vTime,
      chatId: (data['chatId'] ?? data['chat_id'] ?? id).toString(),
      team1Confirmed: data['team1Confirmed'] == true || data['team1_confirmed'] == true,
      team2Confirmed: data['team2Confirmed'] == true || data['team2_confirmed'] == true,
      createdAt: cTime,
      disputeReason: (data['disputeReason'] ?? data['dispute_reason'] ?? '').toString(),
      adminNote: adminNoteVal,
      rejectReason: effectiveNote,
      proofAttempts: pAttempts,
      lastProofAt: lastProofTime,
      rejectedBy: (data['rejectedBy'] ?? data['rejected_by']) as String?,
      rejectedAt: rejTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'match_id': matchId,
      'team1Id': team1Id,
      'team1_id': team1Id,
      'team1Name': team1Name,
      'team1_name': team1Name,
      'team1LeaderId': team1LeaderId,
      'team1_leader_id': team1LeaderId,
      'team1LeaderName': team1LeaderName,
      'team1_leader_name': team1LeaderName,
      'team1Avatar': team1Avatar,
      'team1_avatar': team1Avatar,
      'team1Members': team1Members,
      'team1_members': team1Members,
      'team2Id': team2Id,
      'team2_id': team2Id,
      'team2Name': team2Name,
      'team2_name': team2Name,
      'team2LeaderId': team2LeaderId,
      'team2_leader_id': team2LeaderId,
      'team2LeaderName': team2LeaderName,
      'team2_leader_name': team2LeaderName,
      'team2Avatar': team2Avatar,
      'team2_avatar': team2Avatar,
      'team2Members': team2Members,
      'team2_members': team2Members,
      'game': game,
      'mode': mode,
      'matchTime': matchTime.toIso8601String(),
      'match_time': matchTime.toIso8601String(),
      'entryFee': entryFee,
      'entry_fee': entryFee,
      'status': status,
      'customRoomId': customRoomId,
      'custom_room_id': customRoomId,
      'customRoomPassword': customRoomPassword,
      'custom_room_password': customRoomPassword,
      'team1Proof': team1Proof,
      'team1_proof': team1Proof,
      'team1Claim': team1Claim,
      'team1_claim': team1Claim,
      'team1ProofUploadedAt': team1ProofUploadedAt?.toIso8601String(),
      'team1_proof_uploaded_at': team1ProofUploadedAt?.toIso8601String(),
      'team2Proof': team2Proof,
      'team2_proof': team2Proof,
      'team2Claim': team2Claim,
      'team2_claim': team2Claim,
      'team2ProofUploadedAt': team2ProofUploadedAt?.toIso8601String(),
      'team2_proof_uploaded_at': team2ProofUploadedAt?.toIso8601String(),
      'winnerId': winnerId,
      'winner_id': winnerId,
      'winnerName': winnerName,
      'winner_name': winnerName,
      'verifiedBy': verifiedBy,
      'verified_by': verifiedBy,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'chatId': chatId,
      'chat_id': chatId,
      'team1Confirmed': team1Confirmed,
      'team1_confirmed': team1Confirmed,
      'team2Confirmed': team2Confirmed,
      'team2_confirmed': team2Confirmed,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'disputeReason': disputeReason,
      'dispute_reason': disputeReason,
      'adminNote': adminNote,
      'admin_note': adminNote,
      'rejectReason': rejectReason ?? adminNote,
      'reject_reason': rejectReason ?? adminNote,
      'proofAttempts': proofAttempts,
      'proof_attempts': proofAttempts,
      'lastProofAt': lastProofAt?.toIso8601String(),
      'last_proof_at': lastProofAt?.toIso8601String(),
      'rejectedBy': rejectedBy,
      'rejected_by': rejectedBy,
      'rejectedAt': rejectedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
    };
  }
}
