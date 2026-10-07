// ==========================================
// UPDATE TEAM (Owner only)
// ==========================================
Future<bool> updateTeam({
  required String teamId,
  required String name,
  required String tag,
  File? newLogoFile,
  required String game,
  required String description,
  required String requirements,
}) async {
  if (teamId.isEmpty) return false;
  try {
    final Map<String, dynamic> updates = {
      'name': name.trim(),
      'tag': tag.trim().toUpperCase(),
      'game': game,
      'description': description.trim(),
      'requirements': requirements.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (newLogoFile != null) {
      final newLogoUrl = await SupabaseService.uploadFile(
        file: newLogoFile,
        folder: 'team_logos',
        bucket: SupabaseService.bucketTeamLogos,
      );
      if (newLogoUrl != null && newLogoUrl.isNotEmpty) {
        updates['logo_url'] = newLogoUrl;
      }
    }

    await SupabaseService.client
        .from('teams')
        .update(updates)
        .eq('id', teamId);

    debugPrint('[TeamService] ✅ Team updated: $teamId');
    return true;
  } catch (e) {
    debugPrint('[TeamService] updateTeam error: $e');
    return false;
  }
}

// ==========================================
// DELETE TEAM (Owner only — deletes everything)
// Returns:
//   'ok'            → deleted successfully
//   'not_owner'     → current user is not owner
//   'active_match'  → cannot delete, active match exists
//   'error'         → generic error
// ==========================================
Future<String> deleteTeam({
  required String teamId,
  required String currentUserId,
}) async {
  if (teamId.isEmpty || currentUserId.isEmpty) return 'error';
  try {
    final userUuid = SupabaseService.toUuid(currentUserId);

    // 1. Verify current user is owner
    final memberRow = await SupabaseService.client
        .from('team_members')
        .select('role')
        .eq('team_id', teamId)
        .eq('user_id', userUuid)
        .maybeSingle();

    if (memberRow == null) {
      debugPrint('[TeamService] deleteTeam: not a member');
      return 'not_owner';
    }
    final role = (memberRow['role'] ?? '').toString().toLowerCase();
    if (role != 'owner') {
      debugPrint('[TeamService] deleteTeam: not owner (role=$role)');
      return 'not_owner';
    }

    // 2. Check for active matches
    final teamUuid = SupabaseService.toUuid(teamId);
    final activeMatches = await SupabaseService.client
        .from('active_matches')
        .select('id')
        .or('team1_id.eq.$teamUuid,team2_id.eq.$teamUuid')
        .inFilter('status', ['active', 'under_review']);

    if (activeMatches.isNotEmpty) {
      debugPrint('[TeamService] deleteTeam: active match exists');
      return 'active_match';
    }

    // 3. Delete challenges (both directions)
    try {
      await SupabaseService.client
          .from('challenges')
          .delete()
          .eq('from_team_id', teamUuid);
    } catch (_) {}
    try {
      await SupabaseService.client
          .from('challenges')
          .delete()
          .eq('to_team_id', teamUuid);
    } catch (_) {}

    // 4. Delete join requests
    try {
      await SupabaseService.client
          .from('team_join_requests')
          .delete()
          .eq('team_id', teamUuid);
    } catch (_) {}

    // 5. Delete team members
    try {
      await SupabaseService.client
          .from('team_members')
          .delete()
          .eq('team_id', teamUuid);
    } catch (_) {}

    // 6. Delete the team itself
    await SupabaseService.client
        .from('teams')
        .delete()
        .eq('id', teamUuid);

    debugPrint('[TeamService] ✅ Team deleted: $teamId');
    return 'ok';
  } catch (e) {
    debugPrint('[TeamService] deleteTeam error: $e');
    return 'error';
  }
}