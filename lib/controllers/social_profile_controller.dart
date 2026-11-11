import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';

class SocialProfileController extends ChangeNotifier {
  final GamerSocialService _socialService;
  final GamerAuthService _authService;

  SocialProfileController({
    GamerSocialService? socialService,
    GamerAuthService? authService,
  })  : _socialService = socialService ?? GamerSocialService(),
        _authService = authService ?? GamerAuthService();

  GamerUser? _profileUser;
  String _targetUid = '';
  String _boundCurrentUid = '';
  int _squadCount = 0;
  int _alliesCount = 0;
  bool _isAlly = false;
  bool _isLoadingStatus = false;
  bool _isToggling = false;
  bool _isDemoAccount = false;
  bool _hasAuthoritativeTableCounts = false;
  bool _disposed = false;
  String? _errorMessage;

  StreamSubscription<List<Map<String, dynamic>>>? _squadSub;
  StreamSubscription<List<Map<String, dynamic>>>? _alliesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _userSub;
  StreamSubscription<SocialGraphUpdate>? _localGraphSub;

  GamerUser? get profileUser => _profileUser;
  String get targetUid => _targetUid;
  int get squadCount => _squadCount;
  int get alliesCount => _alliesCount;
  bool get isAlly => _isAlly;
  bool get isLoadingStatus => _isLoadingStatus;
  bool get isToggling => _isToggling;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _sameTarget(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return GamerSocialService.stringToUuid(a) ==
        GamerSocialService.stringToUuid(b);
  }

  Future<void> bindProfile({
    required String targetUserId,
    GamerUser? initialUser,
    String? currentUid,
  }) async {
    if (_disposed || targetUserId.isEmpty) return;

    final effectiveCurrentUid = currentUid ?? (_authService.currentUid ?? '');
    final targetChanged =
        _targetUid.isEmpty || !_sameTarget(_targetUid, targetUserId);
    final viewerChanged = _boundCurrentUid != effectiveCurrentUid;

    if (!targetChanged && !viewerChanged) {
      if (initialUser != null) {
        syncUser(initialUser);
      }
      return;
    }

    await _cancelSubscriptions();

    _targetUid = targetUserId;
    _boundCurrentUid = effectiveCurrentUid;
    _profileUser = initialUser ?? _profileUser;
    _isDemoAccount = initialUser?.isDemoAccount ?? false;
    _hasAuthoritativeTableCounts = false;
    _errorMessage = null;

    if (initialUser != null && targetChanged) {
      _squadCount = initialUser.squadCount;
      _alliesCount = initialUser.alliesCount;
    }

    final isViewerSelf = effectiveCurrentUid.isNotEmpty &&
        _sameTarget(effectiveCurrentUid, targetUserId);
    _isLoadingStatus = effectiveCurrentUid.isNotEmpty && !isViewerSelf;
    _safeNotify();

    _attachLocalGraphListener();
    await Future.wait([
      _loadInitialState(effectiveCurrentUid),
      _attachRealtimeStreams(targetUserId, effectiveCurrentUid),
    ]);
  }

  void syncUser(GamerUser user) {
    if (_disposed) return;
    if (_targetUid.isNotEmpty && !_sameTarget(_targetUid, user.uid)) return;

    _profileUser = user;
    _isDemoAccount = user.isDemoAccount;

    if (!_isToggling && !_hasAuthoritativeTableCounts) {
      _squadCount = user.squadCount;
      _alliesCount = user.alliesCount;
    }
    _safeNotify();
  }

  Future<void> refresh({String? currentUid}) async {
    if (_disposed || _targetUid.isEmpty || _isToggling) return;
    final effectiveCurrentUid =
        currentUid ?? (_authService.currentUid ?? _boundCurrentUid);
    await _loadInitialState(effectiveCurrentUid);
  }

  Future<void> _loadInitialState(String currentUid) async {
    if (_disposed || _targetUid.isEmpty) return;

    final isSelf =
        currentUid.isNotEmpty && _sameTarget(currentUid, _targetUid);
    final targetUuid = GamerSocialService.stringToUuid(_targetUid);
    final currentUuid =
        currentUid.isNotEmpty ? GamerSocialService.stringToUuid(currentUid) : '';

    try {
      final bool allyStatus = (!isSelf && currentUuid.isNotEmpty)
          ? await _socialService.isAlly(currentUid, _targetUid)
          : false;
      final SocialCounts? tableCounts = !_isDemoAccount
          ? await _socialService.fetchSocialCounts(_targetUid)
          : null;

      if (_disposed ||
          GamerSocialService.stringToUuid(_targetUid) != targetUuid) {
        return;
      }

      if (!_isToggling) {
        _isAlly = allyStatus;
        if (tableCounts != null) {
          _squadCount = tableCounts.squadCount;
          _alliesCount = tableCounts.alliesCount;
          _hasAuthoritativeTableCounts = true;
          _profileUser = _profileUser?.copyWith(
            followersCount: _squadCount,
            followingCount: _alliesCount,
          );
        }
      }
    } catch (e) {
      debugPrint('[SocialProfileController] _loadInitialState note: $e');
    } finally {
      _isLoadingStatus = false;
      _safeNotify();
    }
  }

  void _attachLocalGraphListener() {
    _localGraphSub?.cancel();
    _localGraphSub = _socialService.socialGraphUpdatesStream.listen(
      (event) {
        if (_disposed || _targetUid.isEmpty) return;

        final targetUuid = GamerSocialService.stringToUuid(_targetUid);
        final eventTargetUuid =
            GamerSocialService.stringToUuid(event.targetUid);
        final eventActorUuid = GamerSocialService.stringToUuid(event.actorUid);
        final currentUid = _authService.currentUid ?? _boundCurrentUid;
        final currentUuid = currentUid.isNotEmpty
            ? GamerSocialService.stringToUuid(currentUid)
            : '';

        bool changed = false;

        if (eventTargetUuid == targetUuid) {
          if (currentUuid.isNotEmpty &&
              eventActorUuid == currentUuid &&
              !_isToggling) {
            if (_isAlly != event.isAllied) {
              _isAlly = event.isAllied;
              changed = true;
            }
          }
          if (!_isDemoAccount &&
              event.targetSquadCount != null &&
              !_isToggling &&
              _squadCount != event.targetSquadCount) {
            _squadCount = event.targetSquadCount!;
            _hasAuthoritativeTableCounts = true;
            _profileUser =
                _profileUser?.copyWith(followersCount: _squadCount);
            changed = true;
          }
        }

        if (eventActorUuid == targetUuid &&
            !_isDemoAccount &&
            event.actorAlliesCount != null &&
            !_isToggling &&
            _alliesCount != event.actorAlliesCount) {
          _alliesCount = event.actorAlliesCount!;
          _hasAuthoritativeTableCounts = true;
          _profileUser = _profileUser?.copyWith(followingCount: _alliesCount);
          changed = true;
        }

        if (changed) _safeNotify();
      },
      onError: (e) {
        debugPrint('[SocialProfileController] local graph note: $e');
      },
    );
  }

  Future<void> _attachRealtimeStreams(
    String targetUserId,
    String currentUid,
  ) async {
    final targetUuid = GamerSocialService.stringToUuid(targetUserId);
    final currentUuid =
        currentUid.isNotEmpty ? GamerSocialService.stringToUuid(currentUid) : '';

    try {
      final table = await _socialService.resolveFollowsTable();
      if (_disposed ||
          GamerSocialService.stringToUuid(_targetUid) != targetUuid) {
        return;
      }

      _squadSub = SupabaseService.client
          .from(table)
          .stream(primaryKey: ['id'])
          .eq('following_id', targetUuid)
          .listen(
            (rows) {
              if (_disposed || _isToggling) return;
              bool changed = false;

              if (currentUuid.isNotEmpty && currentUuid != targetUuid) {
                final foundAlly = rows.any(
                  (r) =>
                      (r['follower_id']?.toString().toLowerCase() ?? '') ==
                      currentUuid,
                );
                if (_isAlly != foundAlly) {
                  _isAlly = foundAlly;
                  changed = true;
                }
              }

              if (!_isDemoAccount && _squadCount != rows.length) {
                _squadCount = rows.length;
                _hasAuthoritativeTableCounts = true;
                _profileUser =
                    _profileUser?.copyWith(followersCount: _squadCount);
                changed = true;
              }

              if (changed) _safeNotify();
            },
            onError: (e) {
              debugPrint(
                  '[SocialProfileController] squad realtime stream note: $e');
            },
          );

      _alliesSub = SupabaseService.client
          .from(table)
          .stream(primaryKey: ['id'])
          .eq('follower_id', targetUuid)
          .listen(
            (rows) {
              if (_disposed || _isToggling || _isDemoAccount) return;
              if (_alliesCount != rows.length) {
                _alliesCount = rows.length;
                _hasAuthoritativeTableCounts = true;
                _profileUser =
                    _profileUser?.copyWith(followingCount: _alliesCount);
                _safeNotify();
              }
            },
            onError: (e) {
              debugPrint(
                  '[SocialProfileController] allies realtime stream note: $e');
            },
          );

      if (!_isDemoAccount) {
        _userSub = SupabaseService.client
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('id', targetUuid)
            .listen(
              (rows) {
                if (_disposed || _isToggling || rows.isEmpty) return;
                final row = rows.first;
                final updated = GamerUser.fromMap(row, targetUserId);
                _profileUser = updated;
                if (!_hasAuthoritativeTableCounts) {
                  _squadCount = updated.squadCount;
                  _alliesCount = updated.alliesCount;
                }
                _safeNotify();
              },
              onError: (e) {
                debugPrint(
                    '[SocialProfileController] users realtime stream note: $e');
              },
            );
      }
    } catch (e) {
      debugPrint(
          '[SocialProfileController] _attachRealtimeStreams setup note: $e');
    }
  }

  Future<bool> toggleAlly({String? currentUid}) async {
    if (_disposed || _isToggling || _targetUid.isEmpty) return false;

    final actorUid = currentUid ?? (_authService.currentUid ?? '');
    if (actorUid.isEmpty) {
      _errorMessage = 'Please sign in to add allies.';
      _safeNotify();
      return false;
    }

    if (_sameTarget(actorUid, _targetUid)) {
      return false;
    }

    final bool wasAllied = _isAlly;
    final int previousSquadCount = _squadCount;
    final GamerUser? previousAuthGamer = _authService.currentGamer;

    // 1. Optimistic instant UI update for button, Squad count, and viewer Allies count
    _isToggling = true;
    _errorMessage = null;
    _isAlly = !wasAllied;
    _squadCount = (wasAllied ? _squadCount - 1 : _squadCount + 1)
        .clamp(0, 999999999);
    _profileUser = _profileUser?.copyWith(followersCount: _squadCount);

    if (previousAuthGamer != null &&
        _sameTarget(previousAuthGamer.uid, actorUid)) {
      final int nextActorAllies =
          (previousAuthGamer.followingCount + (wasAllied ? -1 : 1))
              .clamp(0, 999999999);
      _authService.currentGamerNotifier.value =
          previousAuthGamer.copyWith(followingCount: nextActorAllies);
    }

    _safeNotify();

    // 2. Persist change in Supabase `user_follows`
    bool success = false;
    try {
      if (wasAllied) {
        success = await _socialService.removeAlly(
          currentUid: actorUid,
          targetUid: _targetUid,
        );
      } else {
        success = await _socialService.addAlly(
          currentUid: actorUid,
          targetUid: _targetUid,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      success = false;
    }

    if (_disposed) return success;

    if (!success) {
      // Roll back optimistic state on failure
      _isAlly = wasAllied;
      _squadCount = previousSquadCount;
      _profileUser = _profileUser?.copyWith(followersCount: previousSquadCount);
      if (previousAuthGamer != null) {
        _authService.currentGamerNotifier.value = previousAuthGamer;
      }
      _errorMessage = _socialService.lastSocialError ??
          'Unable to update ally status. Please try again.';
      _isToggling = false;
      _safeNotify();
      return false;
    }

    // 3. Reconcile exact counts from Supabase for non-demo accounts
    if (!_isDemoAccount) {
      final freshCounts = await _socialService.fetchSocialCounts(_targetUid);
      if (!_disposed && freshCounts != null) {
        _squadCount = freshCounts.squadCount;
        _alliesCount = freshCounts.alliesCount;
        _hasAuthoritativeTableCounts = true;
        _profileUser = _profileUser?.copyWith(
          followersCount: _squadCount,
          followingCount: _alliesCount,
        );
      }
    }

    _isToggling = false;
    _safeNotify();
    return true;
  }

  Future<void> _cancelSubscriptions() async {
    await _squadSub?.cancel();
    _squadSub = null;
    await _alliesSub?.cancel();
    _alliesSub = null;
    await _userSub?.cancel();
    _userSub = null;
    await _localGraphSub?.cancel();
    _localGraphSub = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _squadSub?.cancel();
    _alliesSub?.cancel();
    _userSub?.cancel();
    _localGraphSub?.cancel();
    super.dispose();
  }
}
