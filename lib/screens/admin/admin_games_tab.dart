import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminGamesTab extends StatefulWidget {
  const AdminGamesTab({super.key});

  @override
  State<AdminGamesTab> createState() => _AdminGamesTabState();
}

class _AdminGamesTabState extends State<AdminGamesTab> {
  final _titleController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _playedCountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addGame() async {
    if (_titleController.text.isEmpty || _imageUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and image URL'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('games').insert({
        'title': _titleController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'played_count': _playedCountController.text.trim().isEmpty ? '0' : _playedCountController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game Added Successfully!'), backgroundColor: Colors.green),
        );
        _titleController.clear();
        _imageUrlController.clear();
        _playedCountController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Game',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Game Title (e.g., Free Fire)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Image URL (Link from Google)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _playedCountController,
            decoration: const InputDecoration(
              labelText: 'Played Count (e.g., 5.9M)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addGame,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Game', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}