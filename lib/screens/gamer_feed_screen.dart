import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GamerFeedScreen extends StatefulWidget {
  const GamerFeedScreen({super.key});
  @override
  State<GamerFeedScreen> createState() => _GamerFeedScreenState();
}

class _GamerFeedScreenState extends State<GamerFeedScreen> {
  List posts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFeed(); // ek hi dafa call hoga, loop khatam
  }

  Future<void> loadFeed() async {
    // FIX 2: limit 10, sara data ek sath nahi
    final data = await Supabase.instance.client
       .from('posts')
       .select()
       .order('created_at', ascending: false)
       .limit(10);
    setState(() {
      posts = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (c, i) {
        final p = posts[i];
        final img = p['image_url']?? '';
        return Card(
          child: Column(
            children: [
              ListTile(title: Text(p['username']?? 'Gamer')),
              if (p['content']!= null) Padding(padding: EdgeInsets.all(8), child: Text(p['content'])),

              // FIX 1 + 3: Cache + compress + video thumbnail
              if (img.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: "$img?width=400&quality=50",
                  memCacheWidth: 400,
                  placeholder: (c,s) => Container(height: 200, color: Colors.black12),
                  errorWidget: (c,s,e) => Icon(Icons.image),
                ),
            ],
          ),
        );
      },
    );
  }
}