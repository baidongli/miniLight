import 'package:flutter/material.dart';

import '../../core/metering/metering.dart';

/// Draws the region the meter is reading. With a [focusMarker] (tap-to-meter
/// active) a small box is drawn where the user touched; otherwise it shows
/// the mode's region: a tight box for spot, a soft circle for
/// center-weighted, nothing for average.
class SpotOverlay extends StatelessWidget {
  const SpotOverlay({super.key, required this.mode, this.focusMarker});

  final MeteringMode mode;
  final Offset? focusMarker;

  static const double _markerSize = 64;

  @override
  Widget build(BuildContext context) {
    if (focusMarker != null) {
      return IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: focusMarker!.dx - _markerSize / 2,
              top: focusMarker!.dy - _markerSize / 2,
              child: Container(
                width: _markerSize,
                height: _markerSize,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amberAccent, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Icon(Icons.add,
                      size: 18, color: Colors.amberAccent),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (mode == MeteringMode.average) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            final short = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
            final size =
                mode == MeteringMode.spot ? short * 0.18 : short * 0.6;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.9),
                  width: 2,
                ),
                shape: mode == MeteringMode.spot
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius:
                    mode == MeteringMode.spot ? BorderRadius.circular(4) : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
