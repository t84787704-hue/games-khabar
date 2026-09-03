import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageNewsScreen extends StatefulWidget {
  const ManageNewsScreen({super.key});
  @override
  State<ManageNewsScreen> createState() => _ManageNewsScreenState();
}

class _ManageNewsScreenState extends State<ManageNewsScreen> {
  bool _isSyncing = false;

  Future<void> _syncGNews() async {
    setState(() => _isSyncing = true);
    const apiKey = "7393192ee1c618b90783514125719bc1";
    
    try {
      final url = "https://gnews.io/api/v4/search?q=PUBG&lang=en&max=3&apikey=$apiKey";
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

      // Step 1 - API check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Status: ${res.statusCode}'), backgroundColor: Colors.blue),
        );
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List articles = data['articles'] ?? [];
        
        for (var art in articles) {
          await FirebaseFirestore.instance.collection('news').add({
            'title': art['title'] ?? 'No Title',
            'content': art['description'] ?? '',
            'imageUrl': art['image'] ?? '',
            'link': art['url'] ?? '',
            'sourceName': art['source']['name'] ?? 'GNews',
            'category': 'PUBG',
            'createdAt': FieldValue.serverTimestamp(),
            'views': 0,
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${articles.length} News Added!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(title: const Text('Manage News'), backgroundColor: const Color(0xFF1E1E24)),
      body: Center(
        child: ElevatedButton(
          onPressed: _isSyncing ? null : _syncGNews,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.all(20)),
          child: _isSyncing 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Text('Sync GNews Now - Final Test'),
        ),
      ),
    );
  }
}