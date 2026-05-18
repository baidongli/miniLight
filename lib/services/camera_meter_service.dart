import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../core/metering/calibration.dart';
import '../core/metering/metering.dart';

/// Owns the camera, streams frames, and turns them into a smoothed scene
/// EV (ISO 100) using the calibration model.
///
/// The camera is exposure-locked on start so that the luma -> EV mapping is
/// stable (auto-exposure would chase the scene and invalidate the model).
class CameraMeterService extends ChangeNotifier {
  CameraController? _controller;
  CameraController? get controller => _controller;

  bool _streaming = false;
  bool _busy = false;

  MeteringMode meteringMode = MeteringMode.centerWeighted;
  CalibrationModel calibration = const CalibrationModel();

  double _meanLuma = 0;
  double get meanLuma => _meanLuma;

  double? _ev100;
  double? get ev100 => _ev100;

  /// When set, metering reads a small spot at this normalised image-plane
  /// point (tap-to-meter) instead of using [meteringMode].
  ({double nx, double ny})? _focusPoint;
  ({double nx, double ny})? get focusPoint => _focusPoint;
  bool get isFocusActive => _focusPoint != null;

  String? _error;
  String? get error => _error;

  static const _emaAlpha = 0.25;

  Future<void> start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _error = 'No camera available on this device.';
        notifyListeners();
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      // Lock exposure & focus so readings are not chased by auto-exposure.
      try {
        await controller.setExposureMode(ExposureMode.locked);
        await controller.setFocusMode(FocusMode.locked);
      } catch (_) {
        // Not all devices support locking; calibration still produces a
        // usable relative reading.
      }
      _controller = controller;
      _error = null;
      notifyListeners();
      await _startStream();
    } catch (e) {
      _error = 'Camera init failed: $e';
      notifyListeners();
    }
  }

  Future<void> _startStream() async {
    final c = _controller;
    if (c == null || _streaming) return;
    _streaming = true;
    await c.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    if (_busy) return;
    _busy = true;
    try {
      final Uint8List yPlane;
      final int width = image.width;
      final int height = image.height;
      final int rowStride;

      if (image.format.group == ImageFormatGroup.bgra8888) {
        yPlane = LuminanceSampler.bgraToY(
          image.planes[0].bytes,
          width,
          height,
        );
        rowStride = width;
      } else {
        yPlane = image.planes[0].bytes;
        rowStride = image.planes[0].bytesPerRow;
      }

      final fp = _focusPoint;
      final luma = fp != null
          ? LuminanceSampler.meanLumaAtPoint(
              yPlane: yPlane,
              width: width,
              height: height,
              rowStride: rowStride,
              nx: fp.nx,
              ny: fp.ny,
            )
          : LuminanceSampler.meanLuma(
              yPlane: yPlane,
              width: width,
              height: height,
              rowStride: rowStride,
              mode: meteringMode,
            );

      _meanLuma = _meanLuma == 0
          ? luma
          : _meanLuma + _emaAlpha * (luma - _meanLuma);
      _ev100 = calibration.ev100(_meanLuma);
      notifyListeners();
    } catch (_) {
      // Drop the frame; next one will recover.
    } finally {
      _busy = false;
    }
  }

  void updateCalibration(CalibrationModel model) {
    calibration = model;
    if (_meanLuma > 0) {
      _ev100 = calibration.ev100(_meanLuma);
      notifyListeners();
    }
  }

  void setMeteringMode(MeteringMode mode) {
    meteringMode = mode;
    // Switching to an explicit mode cancels tap-to-meter.
    _focusPoint = null;
    notifyListeners();
  }

  void setFocusPoint(double nx, double ny) {
    _focusPoint = (nx: nx, ny: ny);
    _meanLuma = 0; // restart the smoother so the new spot settles quickly
    notifyListeners();
  }

  void clearFocusPoint() {
    if (_focusPoint == null) return;
    _focusPoint = null;
    _meanLuma = 0;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (_streaming) {
        try {
          await c.stopImageStream();
        } catch (_) {}
      }
      await c.dispose();
    }
    super.dispose();
  }
}
