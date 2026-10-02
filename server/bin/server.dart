import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/api.dart';
import '../lib/database.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final databaseUrl = Platform.environment['DATABASE_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln(
      'Set DATABASE_URL to mysql://user:password@host:4000/database',
    );
    exit(64);
  }
  final database = LeaderboardDatabase(DatabaseConfig.fromUrl(databaseUrl));
  await database.open();

  final server = await shelf_io.serve(
    buildHandler(database),
    InternetAddress.anyIPv4,
    port,
  );
  // ignore: avoid_print
  print(
    'Leaderboard server listening on http://${server.address.host}:${server.port}',
  );
}
