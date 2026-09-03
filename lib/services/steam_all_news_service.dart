import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/steam_app_ids.dart';
import 'translation_service.dart';

class SteamAllNewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TranslationService _translator = TranslationService();

  String detectCategory(String text) {
    text = text.toLowerCase();
    if (text.contains('truck') || text.contains('simulator') || text.contains('farming') || text.contains('powerwash') || text.contains('bus') || text.contains('house flipper')) {
      return 'Simulator Games';
    }
    if (text.contains('forza') || text.contains('assetto') || text.contains('drift') || text.contains('racing') || text.contains('dirt rally') || text.contains('f1') || text.contains('carx') || text.contains('beamng')) {
      return 'Driving Games';
    }
    if (text.contains('gta') || text.contains('red dead') || text.contains('witcher') || text.contains('cyberpunk') || text.contains('elden') || text.contains('skyrim') || text.contains('fallout') || text.contains('rust') || text.contains('ark') || text.contains('open world')) {
      return 'Open World';
    }
    return 'Action Games';
  }

  Future<int> fetchAllGamesNews() async {
    int totalFetched = 0;

    for (var entry in allGamesAppIds.entries) {
      int appId = entry.value;
      String gameName = entry.key;

      try {
        final url = Uri.parse('https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=$appId&count=3&maxlength=300');
        final res = await http.get(url);

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List? newsItems = data['appnews']?['newsitems'];

          if (newsItems != null) {
            for (var item in newsItems) {
              String title = item['title'] ?? '';
              String contents = item['contents'] ?? '';
              String newsUrl = item['url'] ?? '';
              if (title.isEmpty) continue;

              // Duplicate check
              var existing = await _firestore.collection('news').where('sourceUrl', isEqualTo: newsUrl).limit(1).get();
              if (existing.docs.isNotEmpty) continue;

              String category = detectCategory(title + ' ' + contents);
              
              // Roman Urdu me convert
              String romanTitle = await _translator.translateToRomanUrdu(title);
              String romanContent = await _translator.translateToRomanUrdu(contents);

              await _firestore.collection('news').add({
                'title': romanTitle,
                'titleEn': title,
                'content': romanContent,
                'contentEn': contents,
                'category': category,
                'gameName': gameName,
                'sourceUrl': newsUrl,
                'imageUrl': '',
                'timestamp': FieldValue.serverTimestamp(),
                'source': 'Steam',
                'appId': appId,
                'isVideo': false,
              });
              totalFetched++;
            }
          }
        }
      } catch (e) {
        print('Error $gameName: $e');
        continue;
      }

      // 2 sec wait taake Steam block na kare
      await Future.delayed(Duration(seconds: 2));
    }
    return totalFetched;
  }
}