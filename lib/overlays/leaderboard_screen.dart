import 'package:flutter/material.dart';

import '../services/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _leaderboard = LeaderboardService();
  late Future<List<LeaderboardEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _leaderboard.fetchLeaderboard();
  }

  @override
  void dispose() {
    _leaderboard.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _entriesFuture = _leaderboard.fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not reach leaderboard server.\n'
                  'Start it with: dart run bin/server.dart (in server/)\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('No scores yet — be the first!'));
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LeaderboardTable(entries: entries),
            ),
          );
        },
      ),
    );
  }
}

class LeaderboardTable extends StatelessWidget {
  const LeaderboardTable({super.key, required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
      columns: const [
        DataColumn(label: Text('Rank')),
        DataColumn(label: Text('Player')),
        DataColumn(label: Text('Distance'), numeric: true),
        DataColumn(label: Text('Money'), numeric: true),
      ],
      rows: [
        for (final entry in entries)
          DataRow(
            cells: [
              DataCell(Text('${entry.rank}')),
              DataCell(Text(entry.playerName)),
              DataCell(Text('${entry.distanceMeters.toStringAsFixed(1)} m')),
              DataCell(Text('\$${entry.money.toStringAsFixed(2)}')),
            ],
          ),
      ],
    );
  }
}
