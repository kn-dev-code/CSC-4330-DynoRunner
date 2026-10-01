import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/player_profile.dart';
import '../services/player_upgrades_service.dart';
import '../services/upgrade_catalog.dart';

/// Global service so gameplay can read purchased upgrade levels.
final playerUpgradesService = PlayerUpgradesService();

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _nameController = TextEditingController();
  final _service = playerUpgradesService;
  var _loading = false;
  String? _error;
  PlayerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('playerName');
    if (saved != null && saved.isNotEmpty) {
      _nameController.text = saved;
      await _refreshProfile();
    }
  }

  Future<void> _refreshProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your player name.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.fetchProfile(name);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playerName', name);
      if (!mounted) {
        return;
      }
      setState(() => _profile = profile);
    } on PlayerUpgradesException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _buy(UpgradeId upgrade) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.purchaseUpgrade(
        playerName: name,
        upgrade: upgrade,
      );
      if (!mounted) {
        return;
      }
      setState(() => _profile = profile);
    } on PlayerUpgradesException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Shop'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refreshProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Player name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _refreshProfile,
            child: const Text('Load server profile'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          if (profile != null) ...[
            const SizedBox(height: 20),
            Text(
              'Server balance: \$${profile.money.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final upgrade in UpgradeId.values)
              _UpgradeTile(
                upgrade: upgrade,
                level: profile.upgradeLevels[upgrade.id] ?? 0,
                balance: profile.money,
                onBuy: _loading ? null : () => _buy(upgrade),
              ),
          ],
        ],
      ),
    );
  }
}

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({
    required this.upgrade,
    required this.level,
    required this.balance,
    required this.onBuy,
  });

  final UpgradeId upgrade;
  final int level;
  final double balance;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final atMax = level >= upgrade.maxLevel;
    final cost = upgrade.costForLevel(level);
    final canAfford = !atMax && balance >= cost;

    return Card(
      child: ListTile(
        title: Text(upgrade.title),
        subtitle: Text(
          '${upgrade.description}\nLevel $level / ${upgrade.maxLevel}',
        ),
        isThreeLine: true,
        trailing: atMax
            ? const Text('MAX')
            : FilledButton(
                onPressed: canAfford ? onBuy : null,
                child: Text('\$${cost.toStringAsFixed(0)}'),
              ),
      ),
    );
  }
}
