import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/exposure/camera_body.dart';
import '../core/exposure/exposure_adjustments.dart';
import '../core/exposure/exposure_scales.dart';
import '../core/exposure/exposure_solver.dart';
import '../core/exposure/film_stock.dart';
import '../core/metering/absolute_ev.dart';
import '../core/metering/calibration.dart';
import '../core/metering/incident_ev.dart';

enum MeterSource { camera, incident, real }

/// Holds all meter settings, persists them, and turns a metered scene EV
/// into an [ExposureSolution] including film, body, Zone System and every
/// exposure compensation.
class MeterController extends ChangeNotifier {
  FilmStock film = FilmStock.presets.first;
  PriorityMode priority = PriorityMode.aperture;
  StopIncrement increment = StopIncrement.third;
  double fixedAperture = 8.0;
  double fixedShutterSeconds = 1 / 125;
  CalibrationModel calibration = const CalibrationModel();

  MeterSource source = MeterSource.camera;
  CameraBody body = CameraBody.generic;
  ExposureAdjustments adjustments = const ExposureAdjustments();
  ZonePlacement zone = ZonePlacement.zoneV;
  AbsoluteEvCalculator absoluteCalc = const AbsoluteEvCalculator();
  IncidentEv incidentCalc = const IncidentEv();
  final List<FilmStock> customFilms = [];
  Locale? locale; // null = follow system
  bool held = false;

  List<FilmStock> get allFilms => [...FilmStock.presets, ...customFilms];

  static const _kPrefs = 'minilight.settings.v2';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefs);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      customFilms
        ..clear()
        ..addAll(((j['customFilms'] as List?) ?? const [])
            .map((e) => FilmStock.fromJson(e as Map<String, dynamic>)));
      final filmName = j['film'] as String?;
      film = allFilms.firstWhere(
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
      source = MeterSource.values[(j['source'] as int?) ?? 0];
      final bodyJson = j['body'];
      if (bodyJson is Map<String, dynamic>) {
        body = CameraBody.fromJson(bodyJson);
      }
      final adj = j['adjustments'];
      if (adj is Map<String, dynamic>) {
        adjustments = ExposureAdjustments.fromJson(adj);
      }
      zone = ZonePlacement((j['zone'] as int?) ?? 5).clamp();
      absoluteCalc = AbsoluteEvCalculator(
        deviceConstant: (j['absConst'] as num?)?.toDouble() ?? 0,
      );
      incidentCalc = IncidentEv(
        constantC: (j['incidentC'] as num?)?.toDouble() ?? 2.5,
      );
      final lang = j['locale'] as String?;
      locale = lang == null ? null : Locale(lang);
      notifyListeners();
    } catch (_) {
      // Corrupt prefs: keep defaults.
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
        'source': source.index,
        'body': body.toJson(),
        'adjustments': adjustments.toJson(),
        'zone': zone.zone,
        'absConst': absoluteCalc.deviceConstant,
        'incidentC': incidentCalc.constantC,
        'customFilms': customFilms.map((f) => f.toJson()).toList(),
        'locale': locale?.languageCode,
      }),
    );
  }

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
    _persist();
  }

  void setFilm(FilmStock f) => _update(() => film = f);
  void setPriority(PriorityMode p) => _update(() => priority = p);
  void setIncrement(StopIncrement i) => _update(() => increment = i);
  void setFixedAperture(double a) => _update(() => fixedAperture = a);
  void setFixedShutter(double s) => _update(() => fixedShutterSeconds = s);
  void setCalibration(CalibrationModel c) => _update(() => calibration = c);
  void setSource(MeterSource s) => _update(() => source = s);
  void setBody(CameraBody b) => _update(() => body = b);
  void setAdjustments(ExposureAdjustments a) =>
      _update(() => adjustments = a);
  void setZone(int z) => _update(() => zone = ZonePlacement(z).clamp());
  void setAbsolute(AbsoluteEvCalculator c) => _update(() => absoluteCalc = c);
  void setIncident(IncidentEv c) => _update(() => incidentCalc = c);
  void setLocale(Locale? l) => _update(() => locale = l);

  void addCustomFilm(FilmStock f) => _update(() => customFilms.add(f));
  void removeCustomFilm(FilmStock f) =>
      _update(() => customFilms.removeWhere((x) => x.name == f.name));

  void toggleHold() {
    held = !held;
    notifyListeners();
  }

  ExposureSolution? solve(double? ev100) {
    if (ev100 == null || ev100.isNaN || ev100.isInfinite) return null;
    final solver = ExposureSolver(
      film: film,
      priority: priority,
      increment: increment,
      fixedAperture: fixedAperture,
      fixedShutterSeconds: fixedShutterSeconds,
      body: body,
      adjustments: adjustments,
      zone: zone,
    );
    return solver.solve(ev100);
  }
}
