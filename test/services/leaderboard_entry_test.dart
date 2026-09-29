import 'package:dyno_app/services/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LeaderboardEntry parses server JSON', () {
    final entry = LeaderboardEntry.fromJson({
      'rank': 2,
      'playerName': 'Alex',
      'distanceMeters': 42.5,
      'money': 10.625,
    });

    expect(entry.rank, 2);
    expect(entry.playerName, 'Alex');
    expect(entry.distanceMeters, 42.5);
    expect(entry.money, 10.625);
  });
}
