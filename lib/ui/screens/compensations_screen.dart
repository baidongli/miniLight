import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exposure/exposure_adjustments.dart';
import '../../l10n/app_strings.dart';
import '../../state/meter_controller.dart';

class CompensationsScreen extends StatelessWidget {
  const CompensationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final meter = context.watch<MeterController>();
    final a = meter.adjustments;

    Widget slider(String label, double value, double min, double max,
        int divisions, ValueChanged<double> onChanged) {
      return ListTile(
        title: Text('$label: ${value.toStringAsFixed(2)}'),
        subtitle: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('compensations'))),
      body: ListView(
        children: [
          slider(s.t('push_pull'), a.pushPullStops, -3, 3, 24,
              (v) => meter.setAdjustments(a.copyWith(pushPullStops: v))),
          slider(s.t('filter'), a.filterStops, 0, 6, 24,
              (v) => meter.setAdjustments(a.copyWith(filterStops: v))),
          slider(s.t('bellows'), a.bellowsStops, 0, 4, 16,
              (v) => meter.setAdjustments(a.copyWith(bellowsStops: v))),
          ListTile(
            title: const Text('Bellows from focal / extension (mm)'),
            subtitle: _BellowsCalc(
              onResult: (stops) =>
                  meter.setAdjustments(a.copyWith(bellowsStops: stops)),
            ),
          ),
          slider(s.t('exp_comp'), a.exposureCompensation, -3, 3, 24,
              (v) =>
                  meter.setAdjustments(a.copyWith(exposureCompensation: v))),
          const Divider(),
          ListTile(
            title: Text('${s.t('zone')}: ${meter.zone.zone} '
                '(${meter.zone.evShift >= 0 ? '+' : ''}'
                '${meter.zone.evShift.toStringAsFixed(0)} EV)'),
            subtitle: Slider(
              value: meter.zone.zone.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: 'Zone ${meter.zone.zone}',
              onChanged: (v) => meter.setZone(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellowsCalc extends StatefulWidget {
  const _BellowsCalc({required this.onResult});
  final ValueChanged<double> onResult;

  @override
  State<_BellowsCalc> createState() => _BellowsCalcState();
}

class _BellowsCalcState extends State<_BellowsCalc> {
  final _focal = TextEditingController();
  final _ext = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _focal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'focal'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ext,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'extension'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calculate),
          onPressed: () {
            final f = double.tryParse(_focal.text) ?? 0;
            final e = double.tryParse(_ext.text) ?? 0;
            widget.onResult(
                ExposureAdjustments.bellowsStopsFor(focalLength: f, extension: e));
          },
        ),
      ],
    );
  }
}
