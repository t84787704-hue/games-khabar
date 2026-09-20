final data = await supabase.from('posts').select();
// data = [
//   {
//     'id': 'abc-123',
//     'user_id': 'xyz-456',
//     'content': 'meny ye change kea hy',
//     'game': 'BGMI',
//     'likes_count': 0,
//     'created_at': '2026-09-19T12:00:00Z'
//   }
// ]

final posts = data.map((map) => GamerPost.fromMap(map)).toList();