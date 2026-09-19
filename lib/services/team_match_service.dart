import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/team_match_model.dart';
import '../models/team_ranking_model.dart';
import 'cloudinary_service.dart';

class TeamMatchService {
  static final TeamMatchService _instance = TeamMatchService._internal();
  factory TeamMatchService() => _instance;
  TeamMatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _matchesRef => _firestore.collection('team_matches');
  CollectionReference get _rankingsRef => _firestore.collection('team_rankings');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Check if there is already an active match/challenge between two teams
  /// (Pending, Accepted, Live, Proof Submitted, Disputed)
  Future<TeamMatch?> getActiveMatchBetweenTeams(String teamAId, String teamBId) async {
    try {
      // Query where team1 is A and team2 is B
      final query1 = await _matchesRef
          .where('team1Id', isEqualTo: teamAId)
          .where('team2Id', isEqualTo: teamBId)
          .get();

      for (var doc in query1.docs) {
        final match = TeamMatch.fromFirestore(doc);
        if (match.isActive) return match;
      }

      // Query where team1 is B and team2 is A
      final query2 = await _matchesRef
          .where('team1Id', isEqualTo: teamBId)
          .where('team2Id', isEqualTo: teamAId)
          .get();

      for (var doc in query2.docs) {
        final match = TeamMatch.fromFirestore(doc);
        if (match.isActive) return match;
      }

      return null;
    } catch (e) {
      debugPrint('[TeamMatchService] Error checking active match between teams: $e');
      return null;
    }
  }

  /// 1. Create a challenge from Team 1 to Team 2
  /// Returns a map with 'success', 'matchId', and 'error' message.
  Future<Map<String, dynamic>> sendChallenge({
    required String team1Id,
    required String team1Name,
    required String team1LeaderId,
    required String team1LeaderName,
    String team1Avatar = '',
    List<String> team1Members = const [],
    required String team2Id,
    required String team2Name,
    required String team2LeaderId,
    required String team2LeaderName,
    String team2Avatar = '',
    List<String> team2Members = const [],
    required String game,
    required String mode,
    required DateTime matchTime,
    String entryFee = 'Free',
  }) async {
    try {
      // Check if there is already an active match/challenge between these teams
      final existingActive = await getActiveMatchBetweenTeams(team1Id, team2Id);
      if (existingActive != null) {
        return {
          'success': false,
          'error': 'آپ نے پہلے ہی اس ٹیم کو چیلنج بھیجا ہوا ہے۔ پہلے اسے مکمل یا Cancel کریں۔',
          'matchId': existingActive.matchId,
        };
      }

      final matchDoc = _matchesRef.doc();
      final match = TeamMatch(
        matchId: matchDoc.id,
        team1Id: team1Id,
        team1Name: team1Name,
        team1LeaderId: team1LeaderId,
        team1LeaderName: team1LeaderName,
        team1Avatar: team1Avatar,
        team1Members: team1Members,
        team2Id: team2Id,
        team2Name: team2Name,
        team2LeaderId: team2LeaderId,
        team2LeaderName: team2LeaderName,
        team2Avatar: team2Avatar,
        team2Members: team2Members,
        game: game,
        mode: mode,
        matchTime: matchTime,
        entryFee: entryFee,
        status: 'Pending',
        chatId: matchDoc.id,
        createdAt: DateTime.now(),
      );

      await matchDoc.set(match.toMap());

      // Send in-app notification to Team 2 Leader:
      // "آپ کو [ٹیم کا نام] کی طرف سے چیلنج ملا ہے"
      await _notificationsRef.add({
        'recipientUid': team2LeaderId,
        'senderUid': team1LeaderId,
        'type': 'team_challenge',
        'title': '⚔️ Team Match Challenge!',
        'message': 'آپ کو $team1Name کی طرف سے $game ($mode) کا چیلنج ملا ہے!',
        'matchId': matchDoc.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'matchId': matchDoc.id,
      };
    } catch (e) {
      debugPrint('[TeamMatchService] Error sending challenge: $e');
      return {
        'success': false,
        'error': 'چیلنج بھیجنے میں خرابی پیش آئی: $e',
      };
    }
  }

  /// 2. Accept Challenge
  Future<bool> acceptChallenge(String matchId, {String? customRoomId, String? customRoomPassword}) async {
    try {
      final doc = await _matchesRef.doc(matchId).get();
      if (!doc.exists) return false;
      final match = TeamMatch.fromFirestore(doc);

      final updateData = <String, dynamic>{
        'status': 'Accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      };
      if (customRoomId != null && customRoomId.isNotEmpty) {
        updateData['customRoomId'] = customRoomId;
      }
      if (customRoomPassword != null && customRoomPassword.isNotEmpty) {
        updateData['customRoomPassword'] = customRoomPassword;
      }

      await _matchesRef.doc(matchId).update(updateData);

      // Notify Team 1 Leader
      await _notificationsRef.add({
        'recipientUid': match.team1LeaderId,
        'senderUid': match.team2LeaderId,
        'type': 'team_challenge_accepted',
        'title': '✅ Challenge Accepted!',
        'message': '${match.team2Name} نے آپ کا چیلنج قبول کر لیا ہے! میچ روم تیار ہے۔',
        'matchId': matchId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error accepting challenge: $e');
      return false;
    }
  }

  /// 3. Reject Challenge
  Future<bool> rejectChallenge(String matchId, {String reason = ''}) async {
    try {
      final doc = await _matchesRef.doc(matchId).get();
      if (!doc.exists) return false;
      final match = TeamMatch.fromFirestore(doc);

      await _matchesRef.doc(matchId).update({
        'status': 'Rejected',
        'disputeReason': reason.isNotEmpty ? reason : 'Challenge rejected by opponent team leader',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Notify Team 1 Leader
      await _notificationsRef.add({
        'recipientUid': match.team1LeaderId,
        'senderUid': match.team2LeaderId,
        'type': 'team_challenge_rejected',
        'title': '❌ Challenge Declined',
        'message': '${match.team2Name} نے چیلنج مسترد کر دیا ہے۔',
        'matchId': matchId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error rejecting challenge: $e');
      return false;
    }
  }

  /// 3b. Cancel Challenge (by Team 1 Leader or either team when status is Pending)
  Future<bool> cancelChallenge(String matchId, {String cancelledByUid = ''}) async {
    try {
      final doc = await _matchesRef.doc(matchId).get();
      if (!doc.exists) return false;
      final match = TeamMatch.fromFirestore(doc);

      // Can only cancel if match is in Pending status
      if (!match.isPending) return false;

      await _matchesRef.doc(matchId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': cancelledByUid,
        'disputeReason': 'Challenge cancelled by team leader',
      });

      // Notify the opponent team leader
      final notifyUid = (cancelledByUid == match.team1LeaderId)
          ? match.team2LeaderId
          : match.team1LeaderId;
      if (notifyUid.isNotEmpty) {
        await _notificationsRef.add({
          'recipientUid': notifyUid,
          'senderUid': cancelledByUid,
          'type': 'team_challenge_cancelled',
          'title': '🚫 Challenge Cancelled',
          'message': 'ٹیم چیلنج واپس (Cancel) لے لیا گیا ہے۔',
          'matchId': matchId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error cancelling challenge: $e');
      return false;
    }
  }

  /// 4. Update Custom Room Credentials (Room ID & Password)
  Future<bool> updateRoomCredentials(String matchId, String roomId, String password) async {
    try {
      await _matchesRef.doc(matchId).update({
        'customRoomId': roomId.trim(),
        'customRoomPassword': password.trim(),
        'status': 'Live',
        'roomDetailsUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error updating room credentials: $e');
      return false;
    }
  }

  /// 5. Upload Win Proof Screenshot (Winning or Disputing team)
  Future<bool> submitProof({
    required String matchId,
    required bool isTeam1,
    required File imageFile,
    required String claim, // 'win' or 'loss'
  }) async {
    try {
      final imageUrl = await CloudinaryService.uploadFile(
        file: imageFile,
        folder: 'team_match_proofs',
      );
      if (imageUrl == null || imageUrl.isEmpty) return false;

      final doc = await _matchesRef.doc(matchId).get();
      if (!doc.exists) return false;
      final current = TeamMatch.fromFirestore(doc);

      final Map<String, dynamic> updateData = {};
      if (isTeam1) {
        updateData['team1Proof'] = imageUrl;
        updateData['team1Claim'] = claim;
        updateData['team1ProofUploadedAt'] = FieldValue.serverTimestamp();
      } else {
        updateData['team2Proof'] = imageUrl;
        updateData['team2Claim'] = claim;
        updateData['team2ProofUploadedAt'] = FieldValue.serverTimestamp();
      }

      // Check if both claimed 'win' -> Mark Disputed
      final otherClaim = isTeam1 ? current.team2Claim : current.team1Claim;
      if (claim == 'win' && otherClaim == 'win') {
        updateData['status'] = 'Disputed';
        updateData['disputeReason'] = 'دونوں ٹیموں نے جیت کا دعویٰ کیا ہے۔ ایڈمن تصدیق کرے گا۔';
      } else {
        // Otherwise set to Proof Submitted
        updateData['status'] = 'Proof Submitted';
      }

      await _matchesRef.doc(matchId).update(updateData);
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error submitting proof: $e');
      return false;
    }
  }

  /// 6. Team Confirmation ("Match Confirmed" in chat)
  Future<bool> confirmMatch(String matchId, bool isTeam1) async {
    try {
      final field = isTeam1 ? 'team1Confirmed' : 'team2Confirmed';
      await _matchesRef.doc(matchId).update({
        field: true,
      });

      // Check if both confirmed
      final doc = await _matchesRef.doc(matchId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        if (data['team1Confirmed'] == true && data['team2Confirmed'] == true) {
          if (data['status'] == 'Pending' || data['status'] == 'Accepted') {
            await _matchesRef.doc(matchId).update({'status': 'Live'});
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error confirming match: $e');
      return false;
    }
  }

  /// 7. Send Match Chat Message
  Future<bool> sendChatMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String teamName,
    required bool isTeam1,
    String text = '',
    String imageUrl = '',
    bool isSystem = false,
  }) async {
    try {
      await _matchesRef.doc(matchId).collection('messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'teamName': teamName,
        'isTeam1': isTeam1,
        'text': text.trim(),
        'imageUrl': imageUrl,
        'isSystem': isSystem,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error sending chat: $e');
      return false;
    }
  }

  /// Stream of chat messages for a match
  Stream<QuerySnapshot> getChatMessages(String matchId) {
    return _matchesRef
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// 8. Admin Verification & Outcome Decision
  Future<bool> adminVerifyMatch({
    required String matchId,
    required String winnerTeamId,
    required String adminIdentifier,
    String notes = '',
  }) async {
    try {
      final doc = await _matchesRef.doc(matchId).get();
      if (!doc.exists) return false;
      final match = TeamMatch.fromFirestore(doc);

      final isTeam1Winner = match.team1Id == winnerTeamId;
      final isTeam2Winner = match.team2Id == winnerTeamId;
      final isDraw = winnerTeamId == 'DRAW';

      final winnerName = isDraw
          ? 'Draw'
          : (isTeam1Winner ? match.team1Name : match.team2Name);

      await _matchesRef.doc(matchId).update({
        'status': 'Verified',
        'winnerId': winnerTeamId,
        'winnerName': winnerName,
        'verifiedBy': adminIdentifier,
        'verifiedAt': FieldValue.serverTimestamp(),
        'disputeReason': notes,
      });

      // Update Team Rankings (Leaderboard: Wins, Losses, Points)
      if (isDraw) {
        await _recordTeamResult(match.team1Id, match.team1Name, match.team1LeaderId, match.team1LeaderName, match.team1Avatar, match.game, isWin: false, isLoss: false, isDraw: true);
        await _recordTeamResult(match.team2Id, match.team2Name, match.team2LeaderId, match.team2LeaderName, match.team2Avatar, match.game, isWin: false, isLoss: false, isDraw: true);
      } else if (isTeam1Winner) {
        await _recordTeamResult(match.team1Id, match.team1Name, match.team1LeaderId, match.team1LeaderName, match.team1Avatar, match.game, isWin: true);
        await _recordTeamResult(match.team2Id, match.team2Name, match.team2LeaderId, match.team2LeaderName, match.team2Avatar, match.game, isLoss: true);
      } else if (isTeam2Winner) {
        await _recordTeamResult(match.team2Id, match.team2Name, match.team2LeaderId, match.team2LeaderName, match.team2Avatar, match.game, isWin: true);
        await _recordTeamResult(match.team1Id, match.team1Name, match.team1LeaderId, match.team1LeaderName, match.team1Avatar, match.game, isLoss: true);
      }

      // Notify both leaders of final verified outcome
      await _notificationsRef.add({
        'recipientUid': match.team1LeaderId,
        'senderUid': 'admin',
        'type': 'match_verified',
        'title': '🏆 Match Verified by Admin',
        'message': 'میچ ${match.team1Name} بمقابلہ ${match.team2Name} کی تصدیق ہو گئی ہے۔ فاتح: $winnerName',
        'matchId': matchId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _notificationsRef.add({
        'recipientUid': match.team2LeaderId,
        'senderUid': 'admin',
        'type': 'match_verified',
        'title': '🏆 Match Verified by Admin',
        'message': 'میچ ${match.team1Name} بمقابلہ ${match.team2Name} کی تصدیق ہو گئی ہے۔ فاتح: $winnerName',
        'matchId': matchId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error verifying match: $e');
      return false;
    }
  }

  /// Admin Reject Match
  Future<bool> adminRejectMatch(String matchId, String adminIdentifier, {String reason = ''}) async {
    try {
      await _matchesRef.doc(matchId).update({
        'status': 'Rejected',
        'verifiedBy': adminIdentifier,
        'verifiedAt': FieldValue.serverTimestamp(),
        'disputeReason': reason.isNotEmpty ? reason : 'Proof invalid or rejected by Admin',
      });
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error rejecting match by admin: $e');
      return false;
    }
  }

  /// Record team result in team_rankings collection
  Future<void> _recordTeamResult(
    String teamId,
    String teamName,
    String leaderId,
    String leaderName,
    String avatar,
    String game, {
    bool isWin = false,
    bool isLoss = false,
    bool isDraw = false,
  }) async {
    try {
      final docRef = _rankingsRef.doc(teamId);
      final snap = await docRef.get();
      if (!snap.exists) {
        final ranking = TeamRanking(
          teamId: teamId,
          teamName: teamName,
          leaderId: leaderId,
          leaderName: leaderName,
          avatar: avatar,
          game: game,
          wins: isWin ? 1 : 0,
          losses: isLoss ? 1 : 0,
          draws: isDraw ? 1 : 0,
          totalMatches: 1,
          points: isWin ? 3 : (isDraw ? 1 : 0),
        );
        await docRef.set(ranking.toMap());
      } else {
        await _firestore.runTransaction((tx) async {
          final s = await tx.get(docRef);
          final d = s.data() as Map<String, dynamic>? ?? {};
          int w = (d['wins'] as num?)?.toInt() ?? 0;
          int l = (d['losses'] as num?)?.toInt() ?? 0;
          int dr = (d['draws'] as num?)?.toInt() ?? 0;
          if (isWin) w++;
          if (isLoss) l++;
          if (isDraw) dr++;
          final tm = w + l + dr;
          final pts = (w * 3) + dr;

          tx.update(docRef, {
            'wins': w,
            'losses': l,
            'draws': dr,
            'totalMatches': tm,
            'points': pts,
            'teamName': teamName,
            'avatar': avatar.isNotEmpty ? avatar : (d['avatar'] ?? ''),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
      // Also synchronize wins, losses, draws, points with teams collection
      try {
        final teamDocRef = _firestore.collection('teams').doc(teamId);
        final teamSnap = await teamDocRef.get();
        if (teamSnap.exists) {
          final tData = teamSnap.data() as Map<String, dynamic>? ?? {};
          int curWins = (tData['wins'] as num?)?.toInt() ?? 0;
          int curLosses = (tData['losses'] as num?)?.toInt() ?? 0;
          int curDraws = (tData['draws'] as num?)?.toInt() ?? 0;
          if (isWin) curWins++;
          if (isLoss) curLosses++;
          if (isDraw) curDraws++;
          final curPoints = (curWins * 3) + curDraws;
          await teamDocRef.update({
            'wins': curWins,
            'losses': curLosses,
            'draws': curDraws,
            'points': curPoints,
          });
        }
      } catch (e) {
        debugPrint('[TeamMatchService] Error syncing team doc record: $e');
      }
    } catch (e) {
      debugPrint('[TeamMatchService] Error recording ranking: $e');
    }
  }

  /// 9. Stream all matches (with optional status filter)
  Stream<List<TeamMatch>> getAllMatchesStream({String? statusFilter}) {
    Query q = _matchesRef.orderBy('createdAt', descending: true);
    if (statusFilter != null && statusFilter != 'All') {
      q = q.where('status', isEqualTo: statusFilter);
    }
    return q.snapshots().map((snap) {
      return snap.docs.map((d) => TeamMatch.fromFirestore(d)).toList();
    });
  }

  /// Stream of matches for a particular team or user
  Stream<List<TeamMatch>> getUserTeamMatchesStream(String userId) {
    return _matchesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => TeamMatch.fromFirestore(d))
          .where((m) => m.isMemberOfMatch(userId))
          .toList();
    });
  }

  /// Stream single match by ID
  Stream<TeamMatch?> getMatchStream(String matchId) {
    return _matchesRef.doc(matchId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return TeamMatch.fromFirestore(snap);
    });
  }

  /// Stream Top 10 Leaderboard teams
  Stream<List<TeamRanking>> getTopTeamsLeaderboard({int limit = 10}) {
    return _rankingsRef
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => TeamRanking.fromFirestore(d)).toList();
    });
  }
}
