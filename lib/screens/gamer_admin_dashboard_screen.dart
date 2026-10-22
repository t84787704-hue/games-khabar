  // ===================== TAB 3: BLUE TICK (ENHANCED EARLY BIRD & STATS INSPECTION) =====================
  Widget _buildBlueTickRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFFF4655), size: 48),
                  const SizedBox(height: 14),
                  Text('Could not load blue tick requests',
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ThemeService.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data ?? [];

        // All users sorted by created_at to calculate registration index
        final allUsersSorted = List<Map<String, dynamic>>.from(docs);
        allUsersSorted.sort((a, b) {
          final tA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2020);
          final tB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2020);
          return tA.compareTo(tB);
        });

        final List<Map<String, dynamic>> requestsWithIndex = [];
        for (final d in docs) {
          final isVerified = d['is_verified'] == true || d['has_blue_tick'] == true;
          final vStatus = (d['verification_status'] ?? d['blue_tick_status'] ?? '').toString().toLowerCase();

          if (!isVerified && (vStatus == 'pending' || vStatus == 'under_review' || vStatus == 'submitted')) {
            final userObj = GamerUser.fromMap(d);
            final userIndex = allUsersSorted.indexWhere((u) => (u['id'] ?? u['uid']) == userObj.uid) + 1;
            
            requestsWithIndex.add({
              'user': userObj,
              'raw': d,
              'rankNumber': userIndex > 0 ? userIndex : 9999,
            });
          }
        }

        if (requestsWithIndex.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: const Icon(Icons.verified_outlined,
                        color: Color(0xFF38BDF8), size: 40),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Blue Tick Requests',
                    style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All verification requests have been reviewed!',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          itemCount: requestsWithIndex.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = requestsWithIndex[index];
            return _buildVerificationRequestCard(
              item['user'] as GamerUser,
              rankNumber: item['rankNumber'] as int,
              rawData: item['raw'] as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }

  Widget _buildVerificationRequestCard(
    GamerUser user, {
    required int rankNumber,
    required Map<String, dynamic> rawData,
  }) {
    final bool isEarlyBird = rankNumber <= 1200;
    final int likes = (rawData['likes_received'] as num?)?.toInt() ?? 0;
    final ageDays = user.createdAt != null
        ? DateTime.now().difference(user.createdAt!).inDays
        : 1;

    return FutureBuilder<int>(
      future: SupabaseService.client
          .from('users')
          .select('id')
          .eq('referred_by', user.uid)
          .count()
          .then((res) => res.count),
      builder: (context, refSnap) {
        final referralCount = refSnap.data ?? 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEarlyBird ? const Color(0xFF00FF88).withOpacity(0.6) : const Color(0xFF38BDF8).withOpacity(0.4),
              width: isEarlyBird ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GamerAvatar(
                    photoUrl: user.photoUrl,
                    displayName: user.displayName,
                    radius: 24,
                    borderColor: isEarlyBird ? const Color(0xFF00FF88) : const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName.isNotEmpty ? user.displayName : user.username,
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            RankBadgeWidget(
                                badge: user.getRankBadge(),
                                size: 14,
                                showLabel: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username} • UID: ${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                          style: TextStyle(
                              color: ThemeService.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Early Bird Badge or Normal Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isEarlyBird
                          ? const Color(0xFF00FF88).withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isEarlyBird ? const Color(0xFF00FF88) : Colors.blue,
                      ),
                    ),
                    child: Text(
                      isEarlyBird ? 'EARLY BIRD #$rankNumber' : 'STANDARD REGULAR',
                      style: TextStyle(
                        color: isEarlyBird ? const Color(0xFF00FF88) : const Color(0xFF38BDF8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: ThemeService.border, height: 1),
              const SizedBox(height: 10),

              // Metrics & Verification Checklist Grid
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded,
                                size: 14,
                                color: referralCount >= 2 ? const Color(0xFF00FF88) : const Color(0xFFFF8A00)),
                            const SizedBox(width: 4),
                            Text(
                              'Referrals: $referralCount / 2',
                              style: TextStyle(
                                color: referralCount >= 2 ? const Color(0xFF00FF88) : ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Age: $ageDays Days',
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                    if (!isEarlyBird) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Posts: ${user.postsCount} / 30',
                            style: TextStyle(
                              color: user.postsCount >= 30 ? const Color(0xFF00FF88) : ThemeService.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            'Likes: $likes / 100',
                            style: TextStyle(
                              color: likes >= 100 ? const Color(0xFF00FF88) : ThemeService.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            'Rank: ${user.rank.isNotEmpty ? user.rank : "None"}',
                            style: const TextStyle(
                              color: Color(0xFFFF8A00),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _rejectVerification(user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF4655),
                      side: const BorderSide(color: Color(0xFFFF4655)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _approveVerification(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9BF0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Approve Blue Tick',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
