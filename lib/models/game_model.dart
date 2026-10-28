class GameModel {
  final String title;
  final String imageUrl;
  final String playedCount;

  // 👇 یہاں ہم نے const شامل کیا ہے تاکہ لسٹ میں ایرر ختم ہو جائے
  const GameModel({
    required this.title,
    required this.imageUrl,
    required this.playedCount,
  });
}