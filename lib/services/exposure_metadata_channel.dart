import 'package:flutter/services.dart';

import '../core/metering/absolute_ev.dart';

/// Dart side of the native real-metering bridge. The native plugin
/// (Camera2 on Android, AVFoundation on iOS) runs a metering session and
/// streams per-frame auto-exposure metadata + the metered region's linear
/// luminance, from which [AbsoluteEvCalculator] derives an absolute EV.
class ExposureMetadataChannel {
  static const MethodChannel _method =
      MethodChannel('minilight/exposure');
  static const EventChannel _events =
      EventChannel('minilight/exposure_events');

  /// 0=center spot, 1=center-weighted, 2=average — kept in sync with the
  /// Dart MeteringMode index so native samples the same region.
  Future<void> start({int regionMode = 1}) =>
      _method.invokeMethod('start', {'regionMode': regionMode});

  Future<void> setRegion(int regionMode) =>
      _method.invokeMethod('setRegion', {'regionMode': regionMode});

  /// Set a normalised tap point (tap-to-meter); pass null to clear.
  Future<void> setPoint(double? nx, double? ny) =>
      _method.invokeMethod('setPoint', {'nx': nx, 'ny': ny});

  Future<void> stop() => _method.invokeMethod('stop');

  /// True if the device exposes the native plugin.
  Future<bool> isAvailable() async {
    try {
      final v = await _method.invokeMethod<bool>('isAvailable');
      return v ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<ExposureSample> samples() =>
      _events.receiveBroadcastStream().map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return ExposureSample(
          exposureSeconds: (m['exposureNs'] as num).toDouble() / 1e9,
          iso: (m['iso'] as num).toDouble(),
          apertureF: (m['apertureF'] as num?)?.toDouble() ?? 1.8,
          midLuma: (m['midLuma'] as num).toDouble(),
        );
      });
}
