import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/steam_app_ids.dart';
import 'supabase_service.dart';

class SteamAllNewsService {
  Future<void> fetchAndTest() async {
    print('Fetching started...');
    // Sirf 1 game se test karte hain pehle - GTA 5
    int testAppId = 271590; // GTA 5
    final url = Uri.parse('https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=$testAppId&count=2');
    
    try {
      final res = await http.get(url);
      print('Status: ${res.statusCode}');
      print('Body: ${res.body.substring(0, 300)}');
      
      if (res.statusCode == 200) {
        print('API KAAM KAR RAHA HAI!');
      }
    } catch (e) {
      print('ERROR: $e');
    }
  }

  Future<int> fetchAllGamesNews() async {
    int total = 0;
    for (var entry in allGamesAppIds.entries) {
      try {
        final url = Uri.parse('https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${entry.value}&count=2');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          var data = jsonDecode(res.body);
          var items = data['appnews']?['newsitems'] as List?;
          if (items != null && items.isNotEmpty) {
            for (var item in items) {
              final nowStr = DateTime.now().toIso8601String();
              try {
                await SupabaseService.client.from('posts').insert({
                  'title': item['title'] ?? 'No Title',
                  'content': item['contents'] ?? '',
                  'source_url': item['url'] ?? '',
                  'sourceUrl': item['url'] ?? '',
                  'game_name': entry.key,
                  'gameName': entry.key,
                  'category': 'Open World',
                  'created_at': nowStr,
                  'timestamp': nowStr,
                  'source': 'Steam',
                });
              } catch (_) {
                await SupabaseService.client.from('news').insert({
                  'title': item['title'] ?? 'No Title',
                  'content': item['contents'] ?? '',
                  'source_url': item['url'] ?? '',
                  'game_name': entry.key,
                  'category': 'Open World',
                  'created_at': nowStr,
                  'source': 'Steam',
                });
              }
              total++;
            }
          }
        }
      } catch (e) {
        print('Skip ${entry.key}: $e');
      }
      await Future.delayed(Duration(seconds: 1));
    }
    return total;
  }
}