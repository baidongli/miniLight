import 'package:flutter/material.dart';

import '../../core/exposure/exposure_scales.dart';
import '../../core/exposure/exposure_solver.dart';
import '../../core/exposure/film_stock.dart';

class ReadingPanel extends StatelessWidget {
  const ReadingPanel({
    super.key,
    required this.solution,
    required this.film,
    required this.meanLuma,
  });

  final ExposureSolution? solution;
  final FilmStock film;
  final double meanLuma;

  @override
  Widget build(BuildContext context) {
    final s = solution;
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: s == null
          ? const Text(
              'Metering…',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EV ${s.ev100.toStringAsFixed(1)} @ ISO 100',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      film.name,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _value('Aperture',
                        ExposureScales.formatAperture(s.aperture)),
                    _value(
                      'Shutter',
                      ExposureScales.formatShutter(s.shutterAfterReciprocity),
                    ),
                    _value('ISO', s.iso.toStringAsFixed(0)),
                  ],
                ),
                if (s.reciprocityApplied) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Reciprocity: metered '
                    '${ExposureScales.formatShutter(s.shutterSeconds)} → '
                    'expose ${ExposureScales.formatShutter(s.shutterAfterReciprocity)}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _value(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
