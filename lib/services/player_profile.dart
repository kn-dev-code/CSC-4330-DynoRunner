class PlayerProfile {
  const PlayerProfile({
    required this.playerName,
    required this.money,
    required this.upgradeLevels,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final upgrades = json['upgrades'] as Map<String, dynamic>? ?? {};
    return PlayerProfile(
      playerName: json['playerName'] as String,
      money: (json['money'] as num).toDouble(),
      upgradeLevels: upgrades.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
  }

  final String playerName;
  final double money;
  final Map<String, int> upgradeLevels;
}
