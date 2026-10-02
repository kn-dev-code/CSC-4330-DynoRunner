import 'package:test/test.dart';

import '../lib/database.dart';

void main() {
  group('DatabaseConfig.fromUrl', () {
    test('reads a TiDB Cloud style URL', () {
      final config = DatabaseConfig.fromUrl(
        'mysql://abc123.root:p%40ss@gateway01.us-east-1.prod.aws.tidbcloud.com:4000/dyno',
      );

      expect(config.user, 'abc123.root');
      expect(config.password, 'p@ss');
      expect(config.host, 'gateway01.us-east-1.prod.aws.tidbcloud.com');
      expect(config.port, 4000);
      expect(config.database, 'dyno');
    });

    test('defaults to the TiDB port', () {
      expect(DatabaseConfig.fromUrl('mysql://u:p@host/db').port, 4000);
    });

    test('rejects URLs missing a database', () {
      expect(
        () => DatabaseConfig.fromUrl('mysql://u:p@host:4000'),
        throwsFormatException,
      );
    });
  });

  group('run limits', () {
    test('distance limit grows with time played', () {
      expect(LeaderboardDatabase.maxDistanceForSeconds(0), 0);
      // 280px/s at 1.55x superspeed is 4.34 m/s before the speed ramp.
      expect(LeaderboardDatabase.maxDistanceForSeconds(1), closeTo(4.37, 0.01));
    });

    test('money limit includes coin magnet and boss bonuses', () {
      expect(LeaderboardDatabase.maxMoneyForDistance(100, 0), 25);
      expect(
        LeaderboardDatabase.maxMoneyForDistance(100, 1),
        closeTo(27.5, 1e-9),
      );
      expect(LeaderboardDatabase.maxMoneyForDistance(250, 0), 112.5);
    });
  });
}
