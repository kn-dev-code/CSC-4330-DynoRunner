class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerName,
    required this.distanceMeters,
    required this.money,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      playerName: json['playerName'] as String,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      money: (json['money'] as num).toDouble(),
    );
  }

  final int rank;
  final String playerName;
  final double distanceMeters;
  final double money;
}
