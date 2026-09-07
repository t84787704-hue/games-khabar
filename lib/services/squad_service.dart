import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/squad_post_model.dart';
import '../models/squad_request_model.dart';
import 'gamer_auth_service.dart';

class SquadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Primary LFG collections
  CollectionReference get _squadRef => _firestore.collection('squads');
  CollectionReference get _lfgPostsRef => _firestore.collection('lfg_posts');
  CollectionReference get _legacySquadRef => _firestore.collection('squad_posts');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  Future<void> createSquadPost(SquadPost post) async {
    try {
      final doc = post.id.isNotEmpty ? _squadRef.doc(post.id) : _squadRef.doc();
      final finalPost = post.id.isEmpty ? post.copyWith(id: doc.id) : post;
      final data = finalPost.toMap();
      await doc.set(data);

      // Also mirror to lfg_posts and legacy collection
      try {
        await _lfgPostsRef.doc(doc.id).set(data);
      } catch (_) {}
      try {
        await _legacySquadRef.doc(doc.id).set(data);
      } catch (_) {}
      debugPrint('[SquadService] Successfully created squad post doc ${doc.id}');
    } catch (e, st) {
      debugPrint('[SquadService] Error creating squad post: $e\n$st');
      rethrow;
    }
  }

  Stream<List<SquadPost>> getActiveSquadsStream() {
    return _squadRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      debugPrint('[SquadService] Fetched squads docs length from Firestore: ${snap.docs.length}');
      return snap.docs.map((d) => SquadPost.fromFirestore(d)).toList();
    });
  }

  Future<List<SquadPost>> fetchSquadsOnce() async {
    try {
      final snap = await _squadRef.orderBy('createdAt', descending: true).get();
      debugPrint('[SquadService] One-time fetched squads docs length: ${snap.docs.length}');
      return snap.docs.map((d) => SquadPost.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[SquadService] Error fetching squads once: $e');
      return [];
    }
  }

  Future<void> requestJoinSquad({
    required String postId,
    required String leaderUid,
    required String applicantUid,
    required String applicantName,
    String applicantUsername = '',
    String applicantAvatar = '',
    String applicantTier = 'Ace',
    double applicantKd = 3.0,
    String applicantGameId = '',
  }) async {
    try {
      final gamer = GamerAuthService().currentGamer;
      final effectiveName = applicantName.isNotEmpty
          ? applicantName
          : (gamer?.displayName.isNotEmpty == true ? gamer!.displayName : 'Gamer');
      final effectiveUsername = applicantUsername.isNotEmpty
          ? applicantUsername
          : (gamer?.username ?? '');
      final effectiveAvatar = applicantAvatar.isNotEmpty
          ? applicantAvatar
          : (gamer?.photoUrl ?? '');
      final effectiveTier = applicantTier.isNotEmpty
          ? applicantTier
          : (gamer?.rank ?? 'Ace');
      final effectiveKd = applicantKd > 0
          ? applicantKd
          : (gamer?.kdRatio ?? 3.0);
      final effectiveGameId = applicantGameId.isNotEmpty
          ? applicantGameId
          : (gamer?.gameId ?? '');

      final reqData = {
        'id': applicantUid,
        'postId': postId,
        'userId': applicantUid,
        'applicantUid': applicantUid,
        'name': effectiveName,
        'displayName': effectiveName,
        'username': effectiveUsername,
        'userAvatar': effectiveAvatar,
        'photoUrl': effectiveAvatar,
        'tier': effectiveTier,
        'userRank': effectiveTier,
        'kd': effectiveKd,
        'kdRatio': effectiveKd,
        'inGameUid': effectiveGameId,
        'gameId': effectiveGameId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Write to 'lfg_posts' -> docId -> 'requests' subcollection
      try {
        await _lfgPostsRef.doc(postId).collection('requests').doc(applicantUid).set(reqData);
        await _lfgPostsRef.doc(postId).set({
          'joinRequests': FieldValue.arrayUnion([applicantUid]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[SquadService] Error writing to lfg_posts requests: $e');
      }

      // 2. Also write to 'squads' -> docId -> 'requests' subcollection & arrayUnion
      try {
        await _squadRef.doc(postId).collection('requests').doc(applicantUid).set(reqData);
        await _squadRef.doc(postId).update({
          'joinRequests': FieldValue.arrayUnion([applicantUid]),
        });
      } catch (e) {
        debugPrint('[SquadService] Error writing to squads requests: $e');
      }

      // 3. Mirror to legacy
      try {
        await _legacySquadRef.doc(postId).update({
          'joinRequests': FieldValue.arrayUnion([applicantUid]),
        });
      } catch (_) {}

      // 4. Send notification to squad leader
      if (leaderUid != applicantUid && leaderUid.isNotEmpty) {
        await _notificationsRef.add({
          'recipientUid': leaderUid,
          'senderUid': applicantUid,
          'type': 'squad_request',
          'message': 'requested to join your Squad!',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[SquadService] Error requesting join: $e');
    }
  }

  /// Real-time stream of all requests in 'lfg_posts' -> docId -> 'requests' (and 'squads' subcollection)
  Stream<List<SquadJoinRequest>> getSquadRequestsStream(String postId, [List<String>? initialJoinRequests]) {
    final controller = StreamController<List<SquadJoinRequest>>();
    final Map<String, SquadJoinRequest> requestsMap = {};

    void emitRequests() {
      final list = requestsMap.values.toList();
      list.sort((a, b) {
        final tA = a.createdAt ?? DateTime(1970);
        final tB = b.createdAt ?? DateTime(1970);
        return tB.compareTo(tA);
      });
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    // Populate from fallback initialJoinRequests if any
    if (initialJoinRequests != null && initialJoinRequests.isNotEmpty) {
      for (final uid in initialJoinRequests) {
        if (!requestsMap.containsKey(uid)) {
          requestsMap[uid] = SquadJoinRequest(
            id: uid,
            postId: postId,
            userId: uid,
            name: 'Gamer',
            tier: 'Ace',
            kd: 3.0,
          );
          // Asynchronously resolve real user details from users collection
          _firestore.collection('users').doc(uid).get().then((userDoc) {
            if (userDoc.exists) {
              final d = userDoc.data() ?? {};
              requestsMap[uid] = SquadJoinRequest(
                id: uid,
                postId: postId,
                userId: uid,
                name: d['displayName']?.toString() ?? d['username']?.toString() ?? 'Gamer',
                username: d['username']?.toString() ?? '',
                userAvatar: d['photoUrl']?.toString() ?? '',
                tier: d['rank']?.toString() ?? 'Ace',
                kd: (d['kdRatio'] as num?)?.toDouble() ?? 3.0,
                inGameUid: d['gameId']?.toString() ?? '',
              );
              emitRequests();
            }
          }).catchError((_) {});
        }
      }
      emitRequests();
    }

    // Stream 1: lfg_posts -> postId -> requests
    final subLfg = _lfgPostsRef.doc(postId).collection('requests').snapshots().listen((snap) {
      for (final doc in snap.docs) {
        requestsMap[doc.id] = SquadJoinRequest.fromFirestore(doc, postId);
      }
      // Remove docs that were deleted in snapshot if snap is primary
      final docIds = snap.docs.map((d) => d.id).toSet();
      // Only remove if this subcollection had docs
      if (snap.docs.isNotEmpty) {
        requestsMap.removeWhere((key, _) => !docIds.contains(key) && (initialJoinRequests?.contains(key) != true));
      }
      emitRequests();
    }, onError: (e) {
      debugPrint('[SquadService] lfg requests stream error: $e');
    });

    // Stream 2: squads -> postId -> requests
    final subSquad = _squadRef.doc(postId).collection('requests').snapshots().listen((snap) {
      for (final doc in snap.docs) {
        requestsMap[doc.id] = SquadJoinRequest.fromFirestore(doc, postId);
      }
      emitRequests();
    }, onError: (e) {
      debugPrint('[SquadService] squads requests stream error: $e');
    });

    // Stream 3: Also listen to the squad post doc itself to see joinRequests array changes
    final subDoc = _squadRef.doc(postId).snapshots().listen((docSnap) {
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> currentArray = data['joinRequests'] ?? [];
        final currentUids = currentArray.map((e) => e.toString()).toSet();
        // Remove items that were removed from joinRequests array
        requestsMap.removeWhere((key, _) => !currentUids.contains(key) && requestsMap[key]?.status != 'pending');
        emitRequests();
      }
    }, onError: (_) {});

    controller.onCancel = () {
      subLfg.cancel();
      subSquad.cancel();
      subDoc.cancel();
    };

    return controller.stream;
  }

  /// Accept join request: add to squad members, delete request doc, send notification
  Future<void> acceptSquadRequest({
    required String postId,
    required SquadJoinRequest request,
    required SquadPost squad,
  }) async {
    try {
      debugPrint('[SquadService] acceptSquadRequest: postId=$postId, requesterId=${request.userId}');

      final currentUid = GamerAuthService().currentUid;
      if (currentUid != null && currentUid != squad.userId && currentUid != squad.ownerId) {
        throw "Only owner can accept";
      }

      // Reference both collections for sync
      final lfgPostRef = _lfgPostsRef.doc(postId);
      final squadRef = _squadRef.doc(postId);

      await _firestore.runTransaction((tx) async {
        DocumentSnapshot lfgSnap = await tx.get(lfgPostRef);
        DocumentSnapshot squadSnap = await tx.get(squadRef);

        DocumentSnapshot? targetSnap = lfgSnap.exists ? lfgSnap : (squadSnap.exists ? squadSnap : null);
        List<dynamic> members = [];
        if (targetSnap != null) {
          final data = targetSnap.data() as Map<String, dynamic>? ?? {};
          members = List.from(data['members'] ?? []);
          if (members.isEmpty) {
            final owner = data['userId']?.toString() ?? squad.userId;
            if (owner.isNotEmpty) members.add(owner);
          }
        } else {
          members = [squad.userId];
        }

        if (members.length >= 4) {
          throw "Squad Full";
        }
        if (members.contains(request.userId)) {
          throw "Already in squad";
        }

        final updateData = {
          'members': FieldValue.arrayUnion([request.userId]),
          'joinRequests': FieldValue.arrayRemove([request.userId]),
          'membersCount': FieldValue.increment(1),
          'requestedCount': FieldValue.increment(-1),
        };

        if (lfgSnap.exists) {
          tx.update(lfgPostRef, updateData);
        } else {
          tx.set(lfgPostRef, {
            ...squad.toMap(),
            'members': FieldValue.arrayUnion([squad.userId, request.userId]),
            'membersCount': 2,
            'requestedCount': 0,
          }, SetOptions(merge: true));
        }

        if (squadSnap.exists) {
          tx.update(squadRef, updateData);
        } else {
          tx.set(squadRef, {
            ...squad.toMap(),
            'members': FieldValue.arrayUnion([squad.userId, request.userId]),
            'membersCount': 2,
            'requestedCount': 0,
          }, SetOptions(merge: true));
        }

        // Delete from requests subcollection
        final reqLfg = lfgPostRef.collection('requests').doc(request.id);
        final reqSquad = squadRef.collection('requests').doc(request.id);
        final reqUserIdLfg = lfgPostRef.collection('requests').doc(request.userId);
        final reqUserIdSquad = squadRef.collection('requests').doc(request.userId);

        tx.delete(reqLfg);
        tx.delete(reqSquad);
        tx.delete(reqUserIdLfg);
        tx.delete(reqUserIdSquad);
      });

      // Mirror to legacy if needed
      try {
        await _legacySquadRef.doc(postId).set({
          'members': FieldValue.arrayUnion([request.userId]),
          'joinRequests': FieldValue.arrayRemove([request.userId]),
          'membersCount': FieldValue.increment(1),
          'requestedCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      } catch (_) {}

      // Send notification to applicant
      try {
        await _notificationsRef.add({
          'recipientUid': request.userId,
          'senderUid': squad.userId,
          'type': 'squad_accepted',
          'message': 'accepted your request to join squad (${squad.mode})! Leader BGMI UID: ${squad.inGameUid}',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      debugPrint('[SquadService] Successfully accepted squad request ${request.id} for post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error accepting squad request: $e');
      rethrow;
    }
  }

  /// Reject join request: delete request doc, remove from joinRequests array
  Future<void> rejectSquadRequest({
    required String postId,
    required String requestId,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Delete request doc
      batch.delete(_lfgPostsRef.doc(postId).collection('requests').doc(requestId));
      batch.delete(_squadRef.doc(postId).collection('requests').doc(requestId));

      // 2. Remove from joinRequests array
      batch.set(_squadRef.doc(postId), {
        'joinRequests': FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true));

      batch.set(_lfgPostsRef.doc(postId), {
        'joinRequests': FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true));

      try {
        batch.set(_legacySquadRef.doc(postId), {
          'joinRequests': FieldValue.arrayRemove([userId]),
        }, SetOptions(merge: true));
      } catch (_) {}

      await batch.commit();
      debugPrint('[SquadService] Successfully rejected squad request $requestId');
    } catch (e) {
      debugPrint('[SquadService] Error rejecting squad request: $e');
      rethrow;
    }
  }

  Future<void> closeSquadPost(String postId) async {
    try {
      await _squadRef.doc(postId).update({'isActive': false});
      try {
        await _lfgPostsRef.doc(postId).update({'isActive': false});
      } catch (_) {}
      try {
        await _legacySquadRef.doc(postId).update({'isActive': false});
      } catch (_) {}
      debugPrint('[SquadService] Closed squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error closing squad post: $e');
    }
  }

  Future<void> deleteSquadPost(String postId) async {
    try {
      await _squadRef.doc(postId).delete();
      try {
        await _lfgPostsRef.doc(postId).delete();
      } catch (_) {}
      try {
        await _legacySquadRef.doc(postId).delete();
      } catch (_) {}
      debugPrint('[SquadService] Deleted squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error deleting squad post: $e');
    }
  }
}

