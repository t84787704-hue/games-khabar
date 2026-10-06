import 'dart:io';
import 'package:games_khabar/compat/cloud_firestore.dart';
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
    if (teamId.isEmpty) return Stream.value(null);
    return _teamsRef.doc(teamId).snapshots().asyncMap((doc) async {
      if (doc.exists) return TeamModel.fromFirestore(doc);
      // Fallback: search by 'id' or 'name'
      var q = await _teamsRef.where('id', isEqualTo: teamId).limit(1).get();
      if (q.docs.isEmpty) {
        q = await _teamsRef.where('name', isEqualTo: teamId).limit(1).get();
      }
      if (q.docs.isNotEmpty) {
        return TeamModel.fromFirestore(q.docs.first);
      }
      return null;
    });
  }

  /// Get single team future (checks Firestore doc, or Supabase UUID/ID)
  Future<TeamModel?> getTeam(String teamId) async {
    try {
      if (teamId.isEmpty) return null;
      final doc = await _teamsRef.doc(teamId).get();
      if (doc.exists) return TeamModel.fromFirestore(doc);

      // Check Firestore where 'id' or other fields might match
      var querySnap = await _teamsRef.where('id', isEqualTo: teamId).limit(1).get();
      if (querySnap.docs.isEmpty) {
        querySnap = await _teamsRef.where('name', isEqualTo: teamId).limit(1).get();
      }
      if (querySnap.docs.isNotEmpty) {
        return TeamModel.fromFirestore(querySnap.docs.first);
      }

      // Fallback: check Supabase teams table
      try {
        final tUuid = SupabaseService.toUuid(teamId);
        final supaTeam = await SupabaseService.client
            .from('teams')
            .select()
            .or('id.eq.$tUuid,team_id.eq.$teamId')
            .maybeSingle();

        if (supaTeam != null) {
          return TeamModel(
            id: supaTeam['team_id']?.toString() ?? supaTeam['id']?.toString() ?? teamId,
            name: supaTeam['name']?.toString() ?? 'Team',
            tag: supaTeam['tag']?.toString() ?? '',
            logo: supaTeam['logo_url']?.toString() ?? '',
            game: supaTeam['game']?.toString() ?? '',
            description: supaTeam['bio']?.toString() ?? '',
            requirements: '',
            leaderId: supaTeam['leader_id']?.toString() ?? '',
            leaderName: supaTeam['leader_name']?.toString() ?? '',
            members: [supaTeam['leader_id']?.toString() ?? ''],
            pendingJoinRequests: const [],
            wins: (supaTeam['wins'] as num?)?.toInt() ?? 0,
            losses: (supaTeam['losses'] as num?)?.toInt() ?? 0,
            draws: (supaTeam['draws'] as num?)?.toInt() ?? 0,
            points: (supaTeam['points'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.tryParse(supaTeam['created_at']?.toString() ?? '') ?? DateTime.now(),
          );
        }
      } catch (e) {
        debugPrint('[TeamService] Supabase fallback getTeam error: $e');
      }

      return null;
    } catch (e) {
      debugPrint('[TeamService] Error getting team $teamId: $e');
      return null;
    }
  }

  /// Send Join Request to a team
  Future<bool> requestToJoinTeam({
    required String teamId,
    required String userId,
    required String userName,
    String teamName = '',
  }) async {
    final effectiveUserId = userId.trim().isNotEmpty
        ? userId.trim()
        : (SupabaseService.client.auth.currentUser?.id ?? '');

    if (effectiveUserId.isEmpty) {
      debugPrint('[TeamService] Error: userId is empty for join request');
      return false;
    }

    bool firestoreSuccess = false;
    String resolvedTeamName = teamName;
    String leaderId = '';

    try {
      DocumentReference teamDocRef = _teamsRef.doc(teamId);
      DocumentSnapshot doc = await teamDocRef.get();
      if (!doc.exists) {
        var q = await _teamsRef.where('id', isEqualTo: teamId).limit(1).get();
        if (q.docs.isEmpty) {
          q = await _teamsRef.where('name', isEqualTo: teamId).limit(1).get();
        }
        if (q.docs.isEmpty && teamName.isNotEmpty) {
          q = await _teamsRef.where('name', isEqualTo: teamName).limit(1).get();
        }
        if (q.docs.isNotEmpty) {
          doc = q.docs.first;
          teamDocRef = doc.reference;
        } else {
          // Comprehensive fallback: scan all teams
          final allTeams = await _teamsRef.get();
          for (final d in allTeams.docs) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final dName = (data['name'] ?? '').toString().toLowerCase();
            final dTag = (data['tag'] ?? '').toString().toLowerCase();
            final dUuid = SupabaseService.toUuid(d.id).toLowerCase();
            final search = teamId.toLowerCase();
            if (d.id == teamId ||
                dName == search ||
                dTag == search ||
                dUuid == search ||
                (teamName.isNotEmpty && dName == teamName.toLowerCase())) {
              doc = d;
              teamDocRef = d.reference;
              break;
            }
          }
        }
      }

      if (doc.exists) {
        final team = TeamModel.fromFirestore(doc);
        resolvedTeamName = team.name;
        leaderId = team.leaderId;

        if (team.isMember(effectiveUserId)) {
          debugPrint('[TeamService] User $effectiveUserId is already a member of team ${team.name}');
          return true;
        }

        if (team.hasRequestedJoin(effectiveUserId)) {
          debugPrint('[TeamService] User $effectiveUserId has already requested to join team ${team.name}');
          return true;
        }

        try {
          await teamDocRef.update({
            'pendingJoinRequests': FieldValue.arrayUnion([effectiveUserId]),
          });
          firestoreSuccess = true;
        } catch (fErr) {
          debugPrint('[TeamService] Firestore update pendingJoinRequests notice: $fErr');
          try {
            await teamDocRef.set({
              'pendingJoinRequests': FieldValue.arrayUnion([effectiveUserId]),
            }, SetOptions(merge: true));
            firestoreSuccess = true;
          } catch (setErr) {
            debugPrint('[TeamService] Firestore set pendingJoinRequests error: $setErr');
          }
        }

        // Notify team leader
        if (team.leaderId.isNotEmpty && team.leaderId != effectiveUserId) {
          try {
            await _notificationsRef.add({
              'recipientUid': team.leaderId,
              'senderUid': effectiveUserId,
              'type': 'team_join_request',
              'title': '🛡️ New Team Join Request',
              'message': '$userName نے آپ کی ٹیم "${team.name}" میں شامل ہونے کی درخواست کی ہے۔',
              'teamId': team.id,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (nErr) {
            debugPrint('[TeamService] Firestore notification notice: $nErr');
          }
        }
      }
    } catch (e) {
      debugPrint('[TeamService] Firestore team join error: $e');
    }

    // Always sync join request & notification to Supabase
    bool supabaseSuccess = false;
    try {
      supabaseSuccess = await SupabaseService.createTeamJoinRequest(
        teamId: teamId,
        teamName: resolvedTeamName,
        userId: effectiveUserId,
        username: userName,
      );
      if (leaderId.isNotEmpty && leaderId != effectiveUserId) {
        await SupabaseService.sendNotification({
          'userId': leaderId,
          'title': '🛡️ New Team Join Request',
          'message': '$userName نے آپ کی ٹیم "${resolvedTeamName.isNotEmpty ? resolvedTeamName : 'Team'}" میں شامل ہونے کی درخواست کی ہے۔',
          'type': 'team_join_request',
        });
      }
    } catch (e) {
      debugPrint('[TeamService] Supabase join request sync notice: $e');
    }

    return firestoreSuccess || supabaseSuccess;
  }

  /// Accept join request (Leader only)
  Future<bool> acceptJoinRequest({
    required String teamId,
    required String userId,
    required String userName,
    String userAvatar = '',
  }) async {
    try {
      DocumentReference teamDocRef = _teamsRef.doc(teamId);
      DocumentSnapshot doc = await teamDocRef.get();
      if (!doc.exists) {
        var q = await _teamsRef.where('id', isEqualTo: teamId).limit(1).get();
        if (q.docs.isEmpty) {
          q = await _teamsRef.where('name', isEqualTo: teamId).limit(1).get();
        }
        if (q.docs.isNotEmpty) {
          teamDocRef = q.docs.first.reference;
        }
      }

      await teamDocRef.update({
        'pendingJoinRequests': FieldValue.arrayRemove([userId, SupabaseService.toUuid(userId)]),
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
      DocumentReference teamDocRef = _teamsRef.doc(teamId);
      DocumentSnapshot doc = await teamDocRef.get();
      if (!doc.exists) {
        var q = await _teamsRef.where('id', isEqualTo: teamId).limit(1).get();
        if (q.docs.isEmpty) {
          q = await _teamsRef.where('name', isEqualTo: teamId).limit(1).get();
        }
        if (q.docs.isNotEmpty) {
          teamDocRef = q.docs.first.reference;
        }
      }

      await teamDocRef.update({
        'pendingJoinRequests': FieldValue.arrayRemove([userId, SupabaseService.toUuid(userId)]),
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

  /// Stream of user's teams (real-time updates)
  Stream<List<TeamModel>> getUserTeamsStream(String userId) {
    return _teamsRef.where('members', arrayContains: userId).snapshots().map((snap) {
      return snap.docs.map((d) => TeamModel.fromFirestore(d)).toList();
    });
  }
}
