import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exposure/exposure_scales.dart';
import '../../l10n/app_strings.dart';
import '../../state/meter_controller.dart';
import '../../services/roll_store.dart';

class RollsScreen extends StatelessWidget {
  const RollsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final store = context.watch<RollStore>();
    final meter = context.read<MeterController>();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('rolls'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => store.createRoll(
          name: 'Roll ${store.rolls.length + 1}',
          filmName: meter.film.name,
          iso: meter.film.iso,
        ),
        child: const Icon(Icons.add),
      ),
      body: store.rolls.isEmpty
          ? Center(child: Text(s.t('new_roll')))
          : ListView(
              children: store.rolls.map((roll) {
                final active = roll.id == store.activeRoll?.id;
                return ExpansionTile(
                  title: Text('${roll.name}'
                      '${active ? ' ●' : ''}'),
                  subtitle: Text('${roll.filmName} · ISO '
                      '${roll.iso.toStringAsFixed(0)} · '
                      '${roll.shots.length} frames'),
                  children: [
                    OverflowBar(
                      children: [
                        TextButton(
                          onPressed: () => store.setActive(roll.id),
                          child: const Text('Use'),
                        ),
                        TextButton(
                          onPressed: () => store.exportCsv(roll),
                          child: Text(s.t('export_csv')),
                        ),
                        TextButton(
                          onPressed: () => store.deleteRoll(roll.id),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                    ...roll.shots.map((shot) => ListTile(
                          dense: true,
                          leading: Text('#${shot.frame}'),
                          title: Text(
                            '${ExposureScales.formatAperture(shot.aperture)}'
                            '  ·  '
                            '${ExposureScales.formatShutter(shot.shutterSeconds)}'
                            '  ·  ISO ${shot.iso.toStringAsFixed(0)}',
                          ),
                          subtitle: Text(
                            'EV ${shot.ev100.toStringAsFixed(1)} · '
                            '${shot.timestamp.toIso8601String().substring(0, 19)}'
                            '${shot.latitude != null ? ' · GPS' : ''}',
                          ),
                        )),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
