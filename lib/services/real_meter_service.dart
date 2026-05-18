import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/metering/absolute_ev.dart';
import 'exposure_metadata_channel.dart';

/// Subscribes to the native exposure-metadata stream and derives a
/// calibration-free absolute EV via [AbsoluteEvCalculator].
class RealMeterService extends ChangeNotifier {
  RealMeterService(this._channel);

  final ExposureMetadataChannel _channel;
  StreamSubscription<ExposureSample>? _sub;

  AbsoluteEvCalculator calc = const AbsoluteEvCalculator();

  bool _available = false;
  bool get available => _available;

  ExposureSample? _last;
  ExposureSample? get lastSample => _last;

  double? _ev100;
  double? get ev100 => _ev100;

  Future<void> start({int regionMode = 1}) async {
    _available = await _channel.isAvailable();
    notifyListeners();
    if (!_available) return;
    await _channel.start(regionMode: regionMode);
    _sub = _channel.samples().listen((s) {
      _last = s;
      _ev100 = calc.ev100(s);
      notifyListeners();
    });
  }

  Future<void> setRegion(int regionMode) => _channel.setRegion(regionMode);

  Future<void> setPoint(double? nx, double? ny) =>
      _channel.setPoint(nx, ny);

  void updateCalc(AbsoluteEvCalculator c) {
    calc = c;
    final s = _last;
    if (s != null) {
      _ev100 = calc.ev100(s);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _channel.stop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
