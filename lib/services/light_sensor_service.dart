import 'dart:async';

import 'package:flutter/foundation.dart';

import 'exposure_metadata_channel.dart';

/// Ambient-light (lux) source for incident-style metering, read through the
/// native plugin's light-sensor stream. Android exposes an illuminance
/// sensor; iOS has no public ambient-lux API, so this stays inactive there
/// and the UI falls back to camera metering.
class LightSensorService extends ChangeNotifier {
  LightSensorService(this._channel);

  final ExposureMetadataChannel _channel;
  StreamSubscription<double>? _sub;

  double _lux = 0;
  double get lux => _lux;

  bool _available = false;
  bool get available => _available;

  Future<void> start() async {
    _available = await _channel.isLuxAvailable();
    notifyListeners();
    if (!_available) return;
    try {
      await _channel.startLux();
      _sub = _channel.luxStream().listen((v) {
        _lux = v;
        notifyListeners();
      });
    } catch (_) {
      _available = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _channel.stopLux();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
