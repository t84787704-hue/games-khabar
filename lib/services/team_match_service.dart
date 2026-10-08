import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/team_match_model.dart';
import '../models/team_ranking_model.dart';
import 'supabase_service.dart';

class TeamMatchService {
  static final TeamMatchService _instance = TeamMatchService._internal();
  factory TeamMatchService() => _instance;
  TeamMatchService._internal();

  /// Check if there is already an active match/challenge between two teams
  Future<TeamMatch?> getActiveMatchBetweenTeams(String teamAId, String teamBId) async {
    try {
      final list = await SupabaseService.client
          .from('team_matches')
          .select()
          .or('and(team1_id.eq.$teamAId,team2_id.eq.$teamBId),and(team1_id.eq.$teamBId,team2_id.eq.$teamAId),and(team1Id.eq.$teamAId,team2Id.eq.$teamBId),and(team1Id.eq.$teamBId,team2Id.eq.$teamAId)');

      for (var row in list) {
        final match = TeamMatch.fromMap(row);
        if (match.isActive) return match;
      }
    } catch (e) {
      debugPrint('[TeamMatchService] Error checking active match between teams: $e');
    }
    return null;
  }

  /// 1. Create a challenge from Team 1 to Team 2
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
      final existingActive = await getActiveMatchBetweenTeams(team1Id, team2Id);
      if (existingActive != null) {
        return {
          'success': false,
          'error': 'آپ نے پہلے ہی اس ٹیم کو چیلنج بھیجا ہوا ہے۔ پہلے اسے مکمل یا Cancel کریں۔',
          'matchId': existingActive.matchId,
        };
      }

      final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_${team1Id.hashCode.abs()}';
      final match = TeamMatch(
        matchId: matchId,
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
        chatId: matchId,
        createdAt: DateTime.now(),
      );

      final mapData = match.toMap();
      await SupabaseService.client.from('team_matches').insert(mapData);

      // Send in-app notification to Team 2 Leader
      try {
        await SupabaseService.client.from('notifications').insert({
          'recipientUid': team2LeaderId,
          'user_id': team2LeaderId,
          'senderUid': team1LeaderId,
          'type': 'team_challenge',
          'title': '⚔️ Team Match Challenge!',
          'message': 'آپ کو $team1Name کی طرف سے $game ($mode) کا چیلنج ملا ہے!',
          'matchId': matchId,
          'match_id': matchId,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      return {
        'success': true,
        'matchId': matchId,
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
      final nowStr = DateTime.now().toIso8601String();
      final updateData = <String, dynamic>{
        'status': 'Accepted',
        'acceptedAt': nowStr,
        'accepted_at': nowStr,
      };
      if (customRoomId != null && customRoomId.isNotEmpty) {
        updateData['customRoomId'] = customRoomId;
        updateData['custom_room_id'] = customRoomId;
      }
      if (customRoomPassword != null && customRoomPassword.isNotEmpty) {
        updateData['customRoomPassword'] = customRoomPassword;
        updateData['custom_room_password'] = customRoomPassword;
      }

      await SupabaseService.client
          .from('team_matches')
          .update(updateData)
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');

      final matchData = await SupabaseService.getTeamMatch(matchId);
      if (matchData != null) {
        final match = TeamMatch.fromMap(matchData);
        try {
          await SupabaseService.client.from('notifications').insert({
            'recipientUid': match.team1LeaderId,
            'user_id': match.team1LeaderId,
            'senderUid': match.team2LeaderId,
            'type': 'team_challenge_accepted',
            'title': '✅ Challenge Accepted!',
            'message': '${match.team2Name} نے آپ کا چیلنج قبول کر لیا ہے! میچ روم تیار ہے۔',
            'matchId': matchId,
            'match_id': matchId,
            'read': false,
            'createdAt': nowStr,
            'created_at': nowStr,
          });
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error accepting challenge: $e');
      return false;
    }
  }

  /// 3. Reject Challenge
  Future<bool> rejectChallenge(String matchId, {String reason = ''}) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('team_matches')
          .update({
            'status': 'Rejected',
            'disputeReason': reason.isNotEmpty ? reason : 'Challenge rejected by opponent team leader',
            'dispute_reason': reason.isNotEmpty ? reason : 'Challenge rejected by opponent team leader',
            'rejectedAt': nowStr,
            'rejected_at': nowStr,
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');

      final matchData = await SupabaseService.getTeamMatch(matchId);
      if (matchData != null) {
        final match = TeamMatch.fromMap(matchData);
        try {
          await SupabaseService.client.from('notifications').insert({
            'recipientUid': match.team1LeaderId,
            'user_id': match.team1LeaderId,
            'senderUid': match.team2LeaderId,
            'type': 'team_challenge_rejected',
            'title': '❌ Challenge Declined',
            'message': '${match.team2Name} نے چیلنج مسترد کر دیا ہے۔',
            'matchId': matchId,
            'match_id': matchId,
            'read': false,
            'createdAt': nowStr,
            'created_at': nowStr,
          });
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error rejecting challenge: $e');
      return false;
    }
  }

  /// 3b. Cancel Challenge
  Future<bool> cancelChallenge(String matchId, {String cancelledByUid = ''}) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('team_matches')
          .update({
            'status': 'Cancelled',
            'cancelledAt': nowStr,
            'cancelled_at': nowStr,
            'cancelledBy': cancelledByUid,
            'cancelled_by': cancelledByUid,
            'disputeReason': 'Challenge cancelled by team leader',
            'dispute_reason': 'Challenge cancelled by team leader',
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');

      final matchData = await SupabaseService.getTeamMatch(matchId);
      if (matchData != null) {
        final match = TeamMatch.fromMap(matchData);
        final notifyUid = (cancelledByUid == match.team1LeaderId)
            ? match.team2LeaderId
            : match.team1LeaderId;
        if (notifyUid.isNotEmpty) {
          try {
            await SupabaseService.client.from('notifications').insert({
              'recipientUid': notifyUid,
              'user_id': notifyUid,
              'senderUid': cancelledByUid,
              'type': 'team_challenge_cancelled',
              'title': '🚫 Challenge Cancelled',
              'message': 'ٹیم چیلنج واپس (Cancel) لے لیا گیا ہے۔',
              'matchId': matchId,
              'match_id': matchId,
              'read': false,
              'createdAt': nowStr,
              'created_at': nowStr,
            });
          } catch (_) {}
        }
      }

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error cancelling challenge: $e');
      return false;
    }
  }

  /// 3c. End / Complete Match
  Future<bool> completeMatch(String matchId, {String completedByUid = ''}) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('team_matches')
          .update({
            'status': 'Completed',
            'completedAt': nowStr,
            'completed_at': nowStr,
            'completedBy': completedByUid,
            'completed_by': completedByUid,
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error completing match: $e');
      return false;
    }
  }

  /// 3d. Cancel challenge between two teams directly
  Future<bool> cancelChallengeBetweenTeams(String teamAId, String teamBId, {String cancelledByUid = ''}) async {
    try {
      final match = await getActiveMatchBetweenTeams(teamAId, teamBId);
      if (match != null) {
        return await cancelChallenge(match.matchId, cancelledByUid: cancelledByUid);
      }
      return false;
    } catch (e) {
      debugPrint('[TeamMatchService] Error in cancelChallengeBetweenTeams: $e');
      return false;
    }
  }

  /// 4. Update Custom Room Credentials
  Future<bool> updateRoomCredentials(String matchId, String roomId, String password) async {
    try {
      await SupabaseService.client
          .from('team_matches')
          .update({
            'customRoomId': roomId.trim(),
            'custom_room_id': roomId.trim(),
            'customRoomPassword': password.trim(),
            'custom_room_password': password.trim(),
            'status': 'Live',
            'roomDetailsUpdatedAt': DateTime.now().toIso8601String(),
            'room_details_updated_at': DateTime.now().toIso8601String(),
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error updating room credentials: $e');
      return false;
    }
  }

  /// 5. Submit Win Proof Screenshot
  Future<Map<String, dynamic>> submitProof({
    required String matchId,
    required String teamId,
    required String userId,
    required File proofImage,
    required String claim,
  }) async {
    try {
      final imageUrl = await SupabaseService.uploadFile(
        file: proofImage,
        folder: 'team_matches/$matchId',
        bucket: SupabaseService.bucketMatchProofs,
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        return {'success': false, 'error': 'تصویر اپلوڈ نہیں ہو سکی'};
      }

      final matchData = await SupabaseService.getTeamMatch(matchId);
      if (matchData == null) {
        return {'success': false, 'error': 'میچ نہیں ملا'};
      }
      final match = TeamMatch.fromMap(matchData);
      final isTeam1 = match.team1Id == teamId || match.team1LeaderId == userId;

      final nowStr = DateTime.now().toIso8601String();
      final updateData = <String, dynamic>{
        'status': 'Proof Submitted',
        'lastProofAt': nowStr,
        'last_proof_at': nowStr,
        'proofAttempts': (match.proofAttempts) + 1,
        'proof_attempts': (match.proofAttempts) + 1,
      };

      if (isTeam1) {
        updateData['team1Proof'] = imageUrl;
        updateData['team1_proof'] = imageUrl;
        updateData['team1Claim'] = claim;
        updateData['team1_claim'] = claim;
        updateData['team1ProofUploadedAt'] = nowStr;
        updateData['team1_proof_uploaded_at'] = nowStr;
      } else {
        updateData['team2Proof'] = imageUrl;
        updateData['team2_proof'] = imageUrl;
        updateData['team2Claim'] = claim;
        updateData['team2_claim'] = claim;
        updateData['team2ProofUploadedAt'] = nowStr;
        updateData['team2_proof_uploaded_at'] = nowStr;
      }

      if ((isTeam1 && match.team2Proof != null) || (!isTeam1 && match.team1Proof != null)) {
        final otherClaim = isTeam1 ? match.team2Claim : match.team1Claim;
        if (claim == 'win' && otherClaim == 'win') {
          updateData['status'] = 'Disputed';
          updateData['disputeReason'] = 'Both teams claimed victory';
          updateData['dispute_reason'] = 'Both teams claimed victory';
        }
      }

      await SupabaseService.client
          .from('team_matches')
          .update(updateData)
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');

      return {'success': true, 'imageUrl': imageUrl};
    } catch (e) {
      debugPrint('[TeamMatchService] Error submitting proof: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 6. Confirm Match Result
  Future<bool> confirmMatch(String matchId, bool isTeam1) async {
    try {
      final updateField = isTeam1 ? 'team1Confirmed' : 'team2Confirmed';
      final snakeField = isTeam1 ? 'team1_confirmed' : 'team2_confirmed';
      await SupabaseService.client
          .from('team_matches')
          .update({
            updateField: true,
            snakeField: true,
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error confirming match: $e');
      return false;
    }
  }

  /// 7. Send In-Match Chat Message
  Future<bool> sendChatMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String teamName,
    required String text,
    String imageUrl = '',
    bool isSystem = false,
    String? senderAvatar,
  }) async {
    try {
      await SupabaseService.sendMatchChatMessage(
        matchId: matchId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        message: text.trim().isNotEmpty ? text.trim() : (imageUrl.isNotEmpty ? '📷 Image' : ''),
        imageUrl: imageUrl,
        messageType: isSystem ? 'system' : (imageUrl.isNotEmpty ? 'image' : 'text'),
      );
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error sending chat: $e');
      return false;
    }
  }

  /// Stream of chat messages for a match
  Stream<List<Map<String, dynamic>>> getChatMessages(String matchId) {
    return SupabaseService.getMatchChatStream(matchId);
  }

  /// 8. Admin Verification & Outcome Decision
  Future<bool> adminVerifyMatch({
    required String matchId,
    required String winnerTeamId,
    required String adminId,
    String note = '',
  }) async {
    try {
      final matchData = await SupabaseService.getTeamMatch(matchId);
      if (matchData == null) return false;
      final match = TeamMatch.fromMap(matchData);

      final isTeam1Winner = match.team1Id == winnerTeamId;
      final isDraw = winnerTeamId == 'draw';
      final winnerName = isDraw
          ? 'Draw'
          : (isTeam1Winner ? match.team1Name : match.team2Name);

      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('team_matches')
          .update({
            'status': 'Verified',
            'winnerId': winnerTeamId,
            'winner_id': winnerTeamId,
            'winnerName': winnerName,
            'winner_name': winnerName,
            'verifiedBy': adminId,
            'verified_by': adminId,
            'verifiedAt': nowStr,
            'verified_at': nowStr,
            'adminNote': note,
            'admin_note': note,
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');

      if (!isDraw) {
        final winnerId = isTeam1Winner ? match.team1Id : match.team2Id;
        final winnerTeamName = isTeam1Winner ? match.team1Name : match.team2Name;
        final winnerLeaderId = isTeam1Winner ? match.team1LeaderId : match.team2LeaderId;
        final winnerLeaderName = isTeam1Winner ? match.team1LeaderName : match.team2LeaderName;
        final winnerAvatar = isTeam1Winner ? match.team1Avatar : match.team2Avatar;

        final loserId = isTeam1Winner ? match.team2Id : match.team1Id;
        final loserTeamName = isTeam1Winner ? match.team2Name : match.team1Name;
        final loserLeaderId = isTeam1Winner ? match.team2LeaderId : match.team1LeaderId;
        final loserLeaderName = isTeam1Winner ? match.team2LeaderName : match.team1LeaderName;
        final loserAvatar = isTeam1Winner ? match.team2Avatar : match.team1Avatar;

        await _recordTeamResult(winnerId, winnerTeamName, winnerLeaderId, winnerLeaderName, winnerAvatar, match.game, isWin: true);
        await _recordTeamResult(loserId, loserTeamName, loserLeaderId, loserLeaderName, loserAvatar, match.game, isLoss: true);
      } else {
        await _recordTeamResult(match.team1Id, match.team1Name, match.team1LeaderId, match.team1LeaderName, match.team1Avatar, match.game, isDraw: true);
        await _recordTeamResult(match.team2Id, match.team2Name, match.team2LeaderId, match.team2LeaderName, match.team2Avatar, match.game, isDraw: true);
      }

      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error verifying match: $e');
      return false;
    }
  }

  /// Admin Rejects Match
  Future<bool> adminRejectMatch(
    String matchId, {
    required String adminId,
    required String reason,
  }) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('team_matches')
          .update({
            'status': 'Rejected',
            'adminNote': reason,
            'admin_note': reason,
            'rejectReason': reason,
            'reject_reason': reason,
            'rejectedBy': adminId,
            'rejected_by': adminId,
            'rejectedAt': nowStr,
            'rejected_at': nowStr,
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error rejecting match by admin: $e');
      return false;
    }
  }

  /// Admin Requests New Proof
  Future<bool> adminRequestNewProof(
    String matchId, {
    required String adminId,
    required String note,
  }) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('team_matches')
          .update({
            'status': 'Rejected',
            'adminNote': note,
            'admin_note': note,
            'rejectReason': note,
            'reject_reason': note,
            'rejectedBy': adminId,
            'rejected_by': adminId,
            'rejectedAt': nowStr,
            'rejected_at': nowStr,
          })
          .or('matchId.eq.$matchId,match_id.eq.$matchId,id.eq.$matchId');
      return true;
    } catch (e) {
      debugPrint('[TeamMatchService] Error requesting new proof: $e');
      return false;
    }
  }

  /// Record team result in team_rankings
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
      final rows = await SupabaseService.client
          .from('team_rankings')
          .select()
          .or('teamId.eq.$teamId,team_id.eq.$teamId')
          .limit(1);

      int w = isWin ? 1 : 0;
      int l = isLoss ? 1 : 0;
      int dr = isDraw ? 1 : 0;

      if (rows.isNotEmpty) {
        final d = rows.first;
        w += (d['wins'] as num?)?.toInt() ?? 0;
        l += (d['losses'] as num?)?.toInt() ?? 0;
        dr += (d['draws'] as num?)?.toInt() ?? 0;
      }

      final tm = w + l + dr;
      final pts = (w * 3) + dr;

      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client.from('team_rankings').upsert({
        'teamId': teamId,
        'team_id': teamId,
        'teamName': teamName,
        'team_name': teamName,
        'leaderId': leaderId,
        'leader_id': leaderId,
        'leaderName': leaderName,
        'leader_name': leaderName,
        'avatar': avatar,
        'game': game,
        'wins': w,
        'losses': l,
        'draws': dr,
        'totalMatches': tm,
        'total_matches': tm,
        'points': pts,
        'updatedAt': nowStr,
        'updated_at': nowStr,
      });

      // Synchronize with teams table
      try {
        await SupabaseService.client.from('teams').update({
          'wins': w,
          'losses': l,
          'draws': dr,
          'points': pts,
        }).or('id.eq.$teamId,team_id.eq.$teamId');
      } catch (_) {}
    } catch (e) {
      debugPrint('[TeamMatchService] Error recording ranking: $e');
    }
  }

  /// 9. Stream all matches
  Stream<List<TeamMatch>> getAllMatchesStream({String? statusFilter}) async* {
    while (true) {
      try {
        final list = await SupabaseService.getTeamMatches(status: statusFilter);
        yield list.map((m) => TeamMatch.fromMap(m)).toList();
      } catch (_) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Stream of matches for a particular user
  Stream<List<TeamMatch>> getUserTeamMatchesStream(String userId) async* {
    while (true) {
      try {
        final list = await SupabaseService.getTeamMatches();
        yield list
            .map((m) => TeamMatch.fromMap(m))
            .where((m) => m.isMemberOfMatch(userId))
            .toList();
      } catch (_) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Stream single match by ID
  Stream<TeamMatch?> getMatchStream(String matchId) async* {
    while (true) {
      try {
        final data = await SupabaseService.getTeamMatch(matchId);
        yield data != null ? TeamMatch.fromMap(data) : null;
      } catch (_) {
        yield null;
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Stream Top 10 Leaderboard teams
  Stream<List<TeamRanking>> getTopTeamsLeaderboard({int limit = 10}) async* {
    while (true) {
      try {
        final rows = await SupabaseService.query('team_rankings', order: 'points.desc', limit: limit);
        yield rows.map((r) => TeamRanking.fromMap(r)).toList();
      } catch (_) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
