import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log/shot_log.dart';

/// Persists film rolls and their shot-log entries; exports a roll as CSV.
class RollStore extends ChangeNotifier {
  static const _kRolls = 'minilight.rolls.v1';
  static const _kActive = 'minilight.activeRoll.v1';

  final List<FilmRoll> rolls = [];
  String? activeRollId;

  FilmRoll? get activeRoll {
    for (final r in rolls) {
      if (r.id == activeRollId) return r;
    }
    return rolls.isEmpty ? null : rolls.first;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRolls);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => FilmRoll.fromJson(e as Map<String, dynamic>))
            .toList();
        rolls
          ..clear()
          ..addAll(list);
      } catch (_) {}
    }
    activeRollId = prefs.getString(_kActive);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRolls,
      jsonEncode(rolls.map((r) => r.toJson()).toList()),
    );
    if (activeRollId != null) {
      await prefs.setString(_kActive, activeRollId!);
    }
  }

  FilmRoll createRoll({
    required String name,
    required String filmName,
    required double iso,
  }) {
    final roll = FilmRoll(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      filmName: filmName,
      iso: iso,
      createdAt: DateTime.now(),
    );
    rolls.add(roll);
    activeRollId = roll.id;
    notifyListeners();
    _persist();
    return roll;
  }

  void setActive(String id) {
    activeRollId = id;
    notifyListeners();
    _persist();
  }

  void addShot(ShotEntry entry) {
    final roll = activeRoll;
    if (roll == null) return;
    roll.shots.add(entry);
    notifyListeners();
    _persist();
  }

  void deleteRoll(String id) {
    rolls.removeWhere((r) => r.id == id);
    if (activeRollId == id) activeRollId = rolls.isEmpty ? null : rolls.first.id;
    notifyListeners();
    _persist();
  }

  Future<void> exportCsv(FilmRoll roll) async {
    final dir = await getTemporaryDirectory();
    final safe = roll.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}/$safe.csv');
    await file.writeAsString(roll.toCsv());
    await Share.shareXFiles([XFile(file.path)], subject: '${roll.name}.csv');
  }
}
