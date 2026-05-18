import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/exposure/exposure_scales.dart';
import '../core/exposure/exposure_solver.dart';
import '../core/exposure/film_stock.dart';
import '../core/metering/calibration.dart';

/// Holds user-facing meter settings, persists them, and turns a metered
/// scene EV into an [ExposureSolution].
class MeterController extends ChangeNotifier {
  FilmStock film = FilmStock.presets.first;
  PriorityMode priority = PriorityMode.aperture;
  StopIncrement increment = StopIncrement.third;
  double fixedAperture = 8.0;
  double fixedShutterSeconds = 1 / 125;
  CalibrationModel calibration = const CalibrationModel();

  static const _kPrefs = 'minilight.settings.v1';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefs);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final filmName = j['film'] as String?;
      film = FilmStock.presets.firstWhere(
        (f) => f.name == filmName,
        orElse: () => FilmStock.presets.first,
      );
      priority = PriorityMode.values[(j['priority'] as int?) ?? 0];
      increment = StopIncrement.values[(j['increment'] as int?) ?? 2];
      fixedAperture = (j['fixedAperture'] as num?)?.toDouble() ?? 8.0;
      fixedShutterSeconds =
          (j['fixedShutterSeconds'] as num?)?.toDouble() ?? 1 / 125;
      final cal = j['calibration'];
      if (cal is Map<String, dynamic>) {
        calibration = CalibrationModel.fromJson(cal);
      }
      notifyListeners();
    } catch (_) {
      // Corrupt prefs: fall back to defaults silently.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefs,
      jsonEncode({
        'film': film.name,
        'priority': priority.index,
        'increment': increment.index,
        'fixedAperture': fixedAperture,
        'fixedShutterSeconds': fixedShutterSeconds,
        'calibration': calibration.toJson(),
      }),
    );
  }

  void setFilm(FilmStock f) {
    film = f;
    notifyListeners();
    _persist();
  }

  void setPriority(PriorityMode p) {
    priority = p;
    notifyListeners();
    _persist();
  }

  void setIncrement(StopIncrement i) {
    increment = i;
    notifyListeners();
    _persist();
  }

  void setFixedAperture(double a) {
    fixedAperture = a;
    notifyListeners();
    _persist();
  }

  void setFixedShutter(double s) {
    fixedShutterSeconds = s;
    notifyListeners();
    _persist();
  }

  void setCalibration(CalibrationModel c) {
    calibration = c;
    notifyListeners();
    _persist();
  }

  ExposureSolution? solve(double? ev100) {
    if (ev100 == null) return null;
    final solver = ExposureSolver(
      film: film,
      priority: priority,
      increment: increment,
      fixedAperture: fixedAperture,
      fixedShutterSeconds: fixedShutterSeconds,
    );
    return solver.solve(ev100);
  }
}
