// ===============================================================================
// GAMER ADMIN DASHBOARD SCREEN — Modular Dashboard Controller
// ===============================================================================

import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

// Saare Tabs Imports
import 'admin_tournaments_tab.dart';
import 'admin_banner_tab.dart';
import 'admin_users_tab.dart';
import 'admin_rank_verify_tab.dart';
import 'admin_blue_tick_tab.dart';
import 'admin_uc_requests_tab.dart';
import 'admin_uc_history_tab.dart';
import 'admin_moderation_tab.dart';
import 'admin_team_matches_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_coins_vault_tab.dart';
import 'admin_referrals_tab.dart';
import 'admin_under_review_tab.dart';
import 'admin_proof_history_tab.dart';
import 'admin_games_tab.dart'; // 👇 نیا گیمز مینجمنٹ ٹیب شامل کیا

class GamerAdminDashboardScreen extends StatefulWidget {
  const GamerAdminDashboardScreen({super.key});

  @override
  State<GamerAdminDashboardScreen> createState() => _GamerAdminDashboardScreenState();
}

class _GamerAdminDashboardScreenState extends State<GamerAdminDashboardScreen> {
  int _currentIndex = 0;

  // Saare tabs ki list (Public Class Names ke sath)
  late final List<Widget> _adminTabs = [
    const AdminTournamentsTab(),        // 0: Tournaments
    const AdminBannerControlTab(),      // 1: Banner Control
    const AdminUsersTab(),              // 2: Users Management
    const AdminGamesTab(),              // 3: Games Management (👇 یہاں شامل کیا)
    const AdminRankVerifyTab(),         // 4: Rank Verification
    const AdminBlueTickTab(),           // 5: Blue Tick Requests
    const AdminUcRequestsTab(),         // 6: UC Requests
    const AdminUcHistoryTab(),          // 7: UC History
    const AdminPostsModerationTab(),    // 8: Posts Moderation
    const AdminTeamMatchesTab(),        // 9: Team Matches
    const AdminReportsTab(),            // 10: Reports Management
    const AdminCoinsVaultTab(),         // 11: Coins Vault
    const AdminReferralsTrackerTab(),   // 12: Referrals Tracker
    const AdminUnderReviewTab(),        // 13: Under Review
    const AdminProofHistoryTab(),       // 14: Proof History
  ];

  // Tabs ke naam Drawer ke liye
  final List<String> _tabTitles = [
    'Tournaments Management',
    'Banner Control',
    'Users Management',
    'Games Management', // 👇 یہاں شامل کیا
    'Rank Verification',
    'Blue Tick Requests',
    'UC Requests',
    'UC History',
    'Posts Moderation',
    'Team Matches',
    'Reports Management',
    'Coins Vault',
    'Referrals Tracker',
    'Under Review Items',
    'Proof History Logs',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeService.bg,
      appBar: AppBar(
        backgroundColor: ThemeService.card,
        title: Text(
          _tabTitles[_currentIndex],
          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        iconTheme: IconThemeData(color: ThemeService.textPrimary),
      ),
      drawer: Drawer(
        backgroundColor: ThemeService.card,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF00FF88)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '15 Modular Tabs Panel', // 👇 14 سے 15 کر دیا
                    style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < _tabTitles.length; i++)
              ListTile(
                selected: _currentIndex == i,
                selectedTileColor: const Color(0xFF00FF88).withOpacity(0.15),
                leading: Icon(
                  _getIconForIndex(i),
                  color: _currentIndex == i ? const Color(0xFF00FF88) : ThemeService.textSecondary,
                  size: 20,
                ),
                title: Text(
                  _tabTitles[i],
                  style: TextStyle(
                    color: _currentIndex == i ? const Color(0xFF00FF88) : ThemeService.textPrimary,
                    fontWeight: _currentIndex == i ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  setState(() => _currentIndex = i);
                  Navigator.pop(context); // Drawer close karein
                },
              ),
          ],
        ),
      ),
      // Yahan body mein saare tabs IndexedStack ke zariye connect hain
      body: IndexedStack(
        index: _currentIndex,
        children: _adminTabs,
      ),
    );
  }

  // 👇 آئیکنز کی لسٹ میں گیمز کا آئیکن شامل کیا اور باقیوں کے نمبر بڑھا دیے
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.emoji_events_rounded;
      case 1: return Icons.view_carousel_rounded;
      case 2: return Icons.people_rounded;
      case 3: return Icons.sports_esports_rounded; // گیمز مینجمنٹ کا آئیکن
      case 4: return Icons.verified_rounded;
      case 5: return Icons.verified_user_rounded;
      case 6: return Icons.flash_on_rounded;
      case 7: return Icons.history_rounded;
      case 8: return Icons.dynamic_feed_rounded;
      case 9: return Icons.sports_esports_rounded;
      case 10: return Icons.report_rounded;
      case 11: return Icons.monetization_on_rounded;
      case 12: return Icons.group_rounded;
      case 13: return Icons.rate_review_rounded;
      case 14: return Icons.history_edu_rounded;
      default: return Icons.folder_rounded;
    }
  }
}