import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/team_model.dart';
import 'supabase_service.dart';

class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _teamsRef => _firestore.collection('teams');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Create a new team
  Future<String?> createTeam({
    required String name,
    required String tag,
    File? logoFile,
    required String game,
    String description = '',
    String requirements = '',
    required String leaderId,
    required String leaderName,
    String leaderAvatar = '',
  }) async {
    try {
      String logoUrl = '';
      if (logoFile != null) {
        logoUrl = await SupabaseService.uploadFile(
              file: logoFile,
              folder: 'team_logos',
              bucket: SupabaseService.bucketTeamLogos,
            ) ??
            '';
      }

      final docRef = _teamsRef.doc();
      final team = TeamModel(
        id: docRef.id,
        name: name.trim(),
        tag: tag.trim().toUpperCase(),
        logo: logoUrl,
        game: game,
        description: description.trim(),
        requirements: requirements.trim(),
        leaderId: leaderId,
        leaderName: leaderName,
        leaderAvatar: leaderAvatar,
        members: [leaderId],
        memberDetails: [
          {
            'id': leaderId,
            'name': leaderName,
            'avatar': leaderAvatar,
            'role': 'Leader',
            'joinedAt': DateTime.now().toIso8601String(),
          }
        ],
        pendingJoinRequests: const [],
        wins: 0,
        losses: 0,
        draws: 0,
        points: 0,
        createdAt: DateTime.now(),
      );

      await docRef.set(team.toMap());

      // Sync to Supabase teams and team_members tables
      try {
        await SupabaseService.saveTeam({
          'team_id': docRef.id,
          'name': name.trim(),
          'tag': tag.trim().toUpperCase(),
          'logo_url': logoUrl,
          'leader_id': leaderId,
          'leader_name': leaderName,
          'game': game,
          'bio': description.trim(),
          'member_count': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        await SupabaseService.addTeamMember(
          teamId: docRef.id,
          userId: leaderId,
          username: leaderName,
          role: 'Leader',
        );
      } catch (e) {
        debugPrint('[TeamService] Supabase sync notice: $e');
      }

      return docRef.id;
    } catch (e) {
      debugPrint('[TeamService] Error creating team: $e');
      return null;
    }
  }

  /// Stream of all teams with optional game filter and search query
  Stream<List<TeamModel>> getTeamsStream({String gameFilter = 'All', String searchQuery = ''}) {
    Query query = _teamsRef.orderBy('createdAt', descending: true);
    if (gameFilter != 'All') {
      query = query.where('game', isEqualTo: gameFilter);
    }

    return query.snapshots().map((snapshot) {
      final teams = snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
      if (searchQuery.trim().isEmpty) return teams;
      final q = searchQuery.toLowerCase().trim();
      return teams.where((t) {
        return t.name.toLowerCase().contains(q) ||
            t.tag.toLowerCase().contains(q) ||
            t.leaderName.toLowerCase().contains(q);
      }).toList();
    });
  }

  /// Get single team stream
  Stream<TeamModel?> getTeamStream(String teamId) {
    return _teamsRef.doc(teamId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TeamModel.fromFirestore(doc);
    });
  }

  /// Send Join Request to a team
  Future<bool> requestToJoinTeam({
    required String teamId,
    required String userId,
    required String userName,
  }) async {
    try {
      final doc = await _teamsRef.doc(teamId).get();
      if (!doc.exists) return false;
      final team = TeamModel.fromFirestore(doc);

      if (team.isMember(userId) || team.hasRequestedJoin(userId)) {
        return true;
      }

      await _teamsRef.doc(teamId).update({
        'pendingJoinRequests': FieldValue.arrayUnion([userId]),
      });

      // Notify team leader
      await _notificationsRef.add({
        'recipientUid': team.leaderId,
        'senderUid': userId,
        'type': 'team_join_request',
        'title': '🛡️ New Team Join Request',
        'message': '$userName نے آپ کی ٹیم "${team.name}" میں شامل ہونے کی درخواست کی ہے۔',
        'teamId': teamId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync join request & notification to Supabase
      try {
        await SupabaseService.createTeamJoinRequest(
          teamId: teamId,
          teamName: team.name,
          userId: userId,
          username: userName,
        );
        await SupabaseService.sendNotification({
          'userId': team.leaderId,
          'title': '🛡️ New Team Join Request',
          'message': '$userName نے آپ کی ٹیم "${team.name}" میں شامل ہونے کی درخواست کی ہے۔',
          'type': 'team_join_request',
        });
      } catch (e) {
        debugPrint('[TeamService] Supabase join request sync notice: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[TeamService] Error sending join request: $e');
      return false;
    }
  }

  /// Accept join request (Leader only)
  Future<bool> acceptJoinRequest({
    required String teamId,
    required String userId,
    required String userName,
    String userAvatar = '',
  }) async {
    try {
      await _teamsRef.doc(teamId).update({
        'pendingJoinRequests': FieldValue.arrayRemove([userId]),
        'members': FieldValue.arrayUnion([userId]),
        'memberDetails': FieldValue.arrayUnion([
          {
            'id': userId,
            'name': userName,
            'avatar': userAvatar,
            'role': 'Member',
            'joinedAt': DateTime.now().toIso8601String(),
          }
        ]),
      });

      // Notify candidate
      await _notificationsRef.add({
        'recipientUid': userId,
        'type': 'team_join_accepted',
        'title': '🎉 Welcome to the Team!',
        'message': 'آپ کی ٹیم جوائن کرنے کی درخواست قبول کر لی گئی ہے!',
        'teamId': teamId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync accept status to Supabase team_join_requests and team_members
      try {
        await SupabaseService.updateTeamJoinRequestStatus(teamId, userId, 'accepted');
        await SupabaseService.addTeamMember(
          teamId: teamId,
          userId: userId,
          username: userName,
          role: 'Member',
        );
        await SupabaseService.sendNotification({
          'userId': userId,
          'title': '🎉 Welcome to the Team!',
          'message': 'آپ کی ٹیم جوائن کرنے کی درخواست قبول کر لی گئی ہے!',
          'type': 'team_join_accepted',
        });
      } catch (e) {
        debugPrint('[TeamService] Supabase accept sync notice: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[TeamService] Error accepting join request: $e');
      return false;
    }
  }

  /// Reject join request (Leader only)
  Future<bool> rejectJoinRequest({
    required String teamId,
    required String userId,
  }) async {
    try {
      await _teamsRef.doc(teamId).update({
        'pendingJoinRequests': FieldValue.arrayRemove([userId]),
      });

      // Sync reject status to Supabase team_join_requests
      try {
        await SupabaseService.updateTeamJoinRequestStatus(teamId, userId, 'rejected');
      } catch (e) {
        debugPrint('[TeamService] Supabase reject sync notice: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[TeamService] Error rejecting join request: $e');
      return false;
    }
  }

  /// Get user's teams (teams where user is leader or member)
  Future<List<TeamModel>> getUserTeams(String userId) async {
    try {
      final snap = await _teamsRef.where('members', arrayContains: userId).get();
      return snap.docs.map((d) => TeamModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[TeamService] Error getting user teams: $e');
      return [];
    }
  }
}
