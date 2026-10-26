// ===============================================================================
// ADMIN BANNER CONTROL TAB — Home Feed Announcement Banner Manager
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class _AdminBannerControlTab extends StatefulWidget {
  const _AdminBannerControlTab();

  @override
  State<_AdminBannerControlTab> createState() => _AdminBannerControlTabState();
}

class _AdminBannerControlTabState extends State<_AdminBannerControlTab> {
  final TextEditingController _titleController = TextEditingController(text: 'Upcoming Tournament! 🏆');
  final TextEditingController _messageController = TextEditingController(text: 'Date: 08:00 PM Tonight');
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _publishBanner() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.client.from('app_announcements').upsert({
        'id': 'home_banner',
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner Published Successfully! 📢'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing banner: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeService.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: Color(0xFF00FF88), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Feed Announcement Banner',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Yeh announcement card sabhi users ki feed screen ke top par show hoga.',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Show Banner on Feed',
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    _isActive ? 'Banner is currently VISIBLE to users' : 'Banner is currently HIDDEN',
                    style: TextStyle(
                      color: _isActive ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                      fontSize: 11,
                    ),
                  ),
                  value: _isActive,
                  activeColor: const Color(0xFF00FF88),
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Announcement Title',
                    filled: true,
                    fillColor: ThemeService.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Match Details / Date & Time',
                    filled: true,
                    fillColor: ThemeService.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _publishBanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF0B0F14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Publishing...' : 'Publish Banner 📢',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
