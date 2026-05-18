import 'dart:typed_data';

enum MeteringMode { spot, centerWeighted, average }

extension MeteringModeLabel on MeteringMode {
  String get label => switch (this) {
        MeteringMode.spot => 'Spot',
        MeteringMode.centerWeighted => 'Center',
        MeteringMode.average => 'Average',
      };
}

/// Pure luminance sampling over an 8-bit grayscale (Y) plane.
///
/// Kept free of any camera/Flutter types so the sampling logic can be unit
/// tested with synthetic buffers. Platform image decoding (YUV vs BGRA) is
/// the adapter layer's job; it feeds a Y plane in here.
class LuminanceSampler {
  const LuminanceSampler._();

  /// Mean luminance (0..255) of [yPlane] for the given [mode].
  ///
  /// [width]/[height] describe the plane; [rowStride] is the byte distance
  /// between rows (>= width, padding allowed). Sampling is strided for
  /// performance on large frames.
  static double meanLuma({
    required Uint8List yPlane,
    required int width,
    required int height,
    required int rowStride,
    required MeteringMode mode,
  }) {
    final region = _regionFor(mode, width, height);
    final stepX = (region.width ~/ 64).clamp(1, 64);
    final stepY = (region.height ~/ 64).clamp(1, 64);

    var sum = 0.0;
    var weight = 0.0;
    final cx = width / 2.0;
    final cy = height / 2.0;
    // Falloff so center-weighted gently biases the middle of the frame.
    final maxDist = (cx * cx + cy * cy);

    for (var y = region.top; y < region.top + region.height; y += stepY) {
      final base = y * rowStride;
      for (var x = region.left; x < region.left + region.width; x += stepX) {
        final v = yPlane[base + x].toDouble();
        if (mode == MeteringMode.centerWeighted) {
          final dx = x - cx;
          final dy = y - cy;
          final w = 1.0 - 0.75 * ((dx * dx + dy * dy) / maxDist);
          sum += v * w;
          weight += w;
        } else {
          sum += v;
          weight += 1;
        }
      }
    }
    if (weight == 0) return 0;
    return sum / weight;
  }

  static _Rect _regionFor(MeteringMode mode, int w, int h) {
    switch (mode) {
      case MeteringMode.spot:
        // ~8% of the shorter edge, centered.
        final s = (w < h ? w : h) * 0.08;
        return _Rect(
          ((w - s) / 2).round(),
          ((h - s) / 2).round(),
          s.round().clamp(1, w),
          s.round().clamp(1, h),
        );
      case MeteringMode.centerWeighted:
      case MeteringMode.average:
        return _Rect(0, 0, w, h);
    }
  }

  /// Convert a BGRA8888 buffer (iOS default) to a packed grayscale Y plane
  /// using Rec. 601 luma weights.
  static Uint8List bgraToY(Uint8List bgra, int width, int height) {
    final out = Uint8List(width * height);
    for (var i = 0, p = 0; p < out.length; i += 4, p++) {
      final b = bgra[i];
      final g = bgra[i + 1];
      final r = bgra[i + 2];
      out[p] = ((0.114 * b) + (0.587 * g) + (0.299 * r)).round();
    }
    return out;
  }
}

class _Rect {
  const _Rect(this.left, this.top, this.width, this.height);
  final int left;
  final int top;
  final int width;
  final int height;
}
