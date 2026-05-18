import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:light/light.dart';

/// Ambient-light (lux) source for incident-style metering. Android exposes
/// an illuminance sensor; iOS has no public ambient-lux API, so this stays
/// inactive there and the UI falls back to camera metering.
class LightSensorService extends ChangeNotifier {
  Light? _light;
  StreamSubscription<int>? _sub;

  double _lux = 0;
  double get lux => _lux;

  bool _available = false;
  bool get available => _available;

  Future<void> start() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _available = false;
      notifyListeners();
      return;
    }
    try {
      _light = Light();
      _sub = _light!.lightSensorStream.listen((v) {
        _lux = v.toDouble();
        _available = true;
        notifyListeners();
      });
      _available = true;
    } catch (_) {
      _available = false;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
