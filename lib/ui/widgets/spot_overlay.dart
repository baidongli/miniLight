import 'package:flutter/material.dart';

import '../../core/metering/metering.dart';

/// Draws the region the meter is reading: a tight box for spot, a soft
/// circle for center-weighted, nothing for average.
class SpotOverlay extends StatelessWidget {
  const SpotOverlay({super.key, required this.mode});

  final MeteringMode mode;

  @override
  Widget build(BuildContext context) {
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
