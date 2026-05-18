import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exposure/exposure_scales.dart';
import '../../core/exposure/exposure_solver.dart';
import '../../core/exposure/film_stock.dart';
import '../../services/camera_meter_service.dart';
import '../../state/meter_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meter = context.watch<MeterController>();
    final cam = context.watch<CameraMeterService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Film stock'),
            subtitle: Text('${meter.film.name}  ·  ISO '
                '${meter.film.iso.toStringAsFixed(0)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickFilm(context, meter),
          ),
          const Divider(),
          ListTile(
            title: const Text('Priority'),
            subtitle: Text(meter.priority == PriorityMode.aperture
                ? 'Aperture priority (you pick f-stop)'
                : 'Shutter priority (you pick speed)'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<PriorityMode>(
              segments: const [
                ButtonSegment(
                    value: PriorityMode.aperture, label: Text('Aperture')),
                ButtonSegment(
                    value: PriorityMode.shutter, label: Text('Shutter')),
              ],
              selected: {meter.priority},
              showSelectedIcon: false,
              onSelectionChanged: (s) => meter.setPriority(s.first),
            ),
          ),
          const SizedBox(height: 8),
          if (meter.priority == PriorityMode.aperture)
            _scalePicker(
              context,
              title: 'Fixed aperture',
              current: ExposureScales.formatAperture(meter.fixedAperture),
              values: ExposureScales.apertures(meter.increment),
              format: ExposureScales.formatAperture,
              onPick: meter.setFixedAperture,
            )
          else
            _scalePicker(
              context,
              title: 'Fixed shutter',
              current:
                  ExposureScales.formatShutter(meter.fixedShutterSeconds),
              values: ExposureScales.fullShutters,
              format: ExposureScales.formatShutter,
              onPick: meter.setFixedShutter,
            ),
          const Divider(),
          const ListTile(
            title: Text('Stop increment'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<StopIncrement>(
              segments: const [
                ButtonSegment(value: StopIncrement.full, label: Text('1')),
                ButtonSegment(value: StopIncrement.half, label: Text('1/2')),
                ButtonSegment(value: StopIncrement.third, label: Text('1/3')),
              ],
              selected: {meter.increment},
              showSelectedIcon: false,
              onSelectionChanged: (s) => meter.setIncrement(s.first),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Calibrate'),
            subtitle: Text(
              'slope ${meter.calibration.slope.toStringAsFixed(2)}, '
              'offset ${meter.calibration.intercept.toStringAsFixed(2)}\n'
              'Point at a scene with a known EV (or use Sunny-16) and enter it.',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.center_focus_strong),
            onTap: () => _calibrate(context, meter, cam),
          ),
        ],
      ),
    );
  }

  void _pickFilm(BuildContext context, MeterController meter) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: FilmStock.presets
              .map((f) => ListTile(
                    title: Text(f.name),
                    subtitle: Text('ISO ${f.iso.toStringAsFixed(0)}'),
                    selected: f.name == meter.film.name,
                    onTap: () {
                      meter.setFilm(f);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _scalePicker(
    BuildContext context, {
    required String title,
    required String current,
    required List<double> values,
    required String Function(double) format,
    required void Function(double) onPick,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(current),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            children: values
                .map((v) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: OutlinedButton(
                        onPressed: () {
                          onPick(v);
                          Navigator.pop(context);
                        },
                        child: Text(format(v)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _calibrate(
    BuildContext context,
    MeterController meter,
    CameraMeterService cam,
  ) {
    final ctrl = TextEditingController(
      text: cam.ev100?.toStringAsFixed(1) ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Calibrate to known EV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current luma: ${cam.meanLuma.toStringAsFixed(1)} / 255'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Known EV at ISO 100',
                hintText: 'e.g. 15 for Sunny-16',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final ev = double.tryParse(ctrl.text.trim());
              if (ev != null && cam.meanLuma > 0) {
                final model =
                    meter.calibration.anchorTo(cam.meanLuma, ev);
                meter.setCalibration(model);
                cam.updateCalibration(model);
              }
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
