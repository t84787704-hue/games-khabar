import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String tag; // 4 characters e.g. GIDN
  final String logo;
  final String game; // BGMI, Free Fire, PUBG, COD
  final String description;
  final String requirements;
  final String leaderId;
  final String leaderName;
  final String leaderAvatar;
  final List<String> members; // user IDs
  final List<Map<String, dynamic>> memberDetails; // [{id, name, avatar, role}]
  final List<String> pendingJoinRequests; // user IDs who requested to join
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final DateTime createdAt;

  const TeamModel({
    required this.id,
    required this.name,
    required this.tag,
    this.logo = '',
    required this.game,
    this.description = '',
    this.requirements = '',
    required this.leaderId,
    required this.leaderName,
    this.leaderAvatar = '',
    this.members = const [],
    this.memberDetails = const [],
    this.pendingJoinRequests = const [],
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    required this.createdAt,
  });

  int get memberCount => members.length;
  int get totalMatches => wins + losses + draws;
  double get winRate => totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;

  bool isLeader(String userId) => leaderId == userId;
  bool isMember(String userId) => members.contains(userId) || leaderId == userId;
  bool hasRequestedJoin(String userId) => pendingJoinRequests.contains(userId);

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rawMembers = data['members'];
    final List<String> membersList = [];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m != null) membersList.add(m.toString());
      }
    }

    final rawRequests = data['pendingJoinRequests'];
    final List<String> reqList = [];
    if (rawRequests is List) {
      for (final r in rawRequests) {
        if (r != null) reqList.add(r.toString());
      }
    }

    final rawMemberDetails = data['memberDetails'];
    final List<Map<String, dynamic>> detailsList = [];
    if (rawMemberDetails is List) {
      for (final item in rawMemberDetails) {
        if (item is Map) {
          detailsList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final createdAtRaw = data['createdAt'];
    DateTime created;
    if (createdAtRaw is Timestamp) {
      created = createdAtRaw.toDate();
    } else {
      created = DateTime.now();
    }

    final w = (data['wins'] as num?)?.toInt() ?? 0;
    final l = (data['losses'] as num?)?.toInt() ?? 0;
    final d = (data['draws'] as num?)?.toInt() ?? 0;
    final pts = (data['points'] as num?)?.toInt() ?? (w * 3 + d);

    return TeamModel(
      id: doc.id,
      name: data['name'] ?? 'Gamer Team',
      tag: (data['tag'] ?? 'TEAM').toString().toUpperCase(),
      logo: data['logo'] ?? '',
      game: data['game'] ?? 'BGMI',
      description: data['description'] ?? '',
      requirements: data['requirements'] ?? '',
      leaderId: data['leaderId'] ?? '',
      leaderName: data['leaderName'] ?? 'Team Leader',
      leaderAvatar: data['leaderAvatar'] ?? '',
      members: membersList,
      memberDetails: detailsList,
      pendingJoinRequests: reqList,
      wins: w,
      losses: l,
      draws: d,
      points: pts,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'tag': tag.trim().toUpperCase(),
      'logo': logo,
      'game': game,
      'description': description.trim(),
      'requirements': requirements.trim(),
      'leaderId': leaderId,
      'leaderName': leaderName,
      'leaderAvatar': leaderAvatar,
      'members': members,
      'memberDetails': memberDetails,
      'pendingJoinRequests': pendingJoinRequests,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'points': points,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TeamModel copyWith({
    String? name,
    String? tag,
    String? logo,
    String? game,
    String? description,
    String? requirements,
    String? leaderId,
    String? leaderName,
    String? leaderAvatar,
    List<String>? members,
    List<Map<String, dynamic>>? memberDetails,
    List<String>? pendingJoinRequests,
    int? wins,
    int? losses,
    int? draws,
    int? points,
    DateTime? createdAt,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      logo: logo ?? this.logo,
      game: game ?? this.game,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      leaderId: leaderId ?? this.leaderId,
      leaderName: leaderName ?? this.leaderName,
      leaderAvatar: leaderAvatar ?? this.leaderAvatar,
      members: members ?? this.members,
      memberDetails: memberDetails ?? this.memberDetails,
      pendingJoinRequests: pendingJoinRequests ?? this.pendingJoinRequests,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
