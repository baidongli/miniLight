import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/exposure/exposure_solver.dart';
import 'package:minilight/core/exposure/film_stock.dart';
import 'package:minilight/ui/widgets/reading_panel.dart';

void main() {
  testWidgets('ReadingPanel shows the solved exposure', (tester) async {
    const solution = ExposureSolution(
      ev100: 15,
      evAtIso: 15,
      aperture: 16,
      shutterSeconds: 1 / 125,
      shutterAfterReciprocity: 1 / 125,
      iso: 100,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadingPanel(
            solution: solution,
            film: FilmStock(name: 'Generic', iso: 100),
            meanLuma: 120,
          ),
        ),
      ),
    );

    expect(find.text('f/16'), findsOneWidget);
    expect(find.text('1/125'), findsOneWidget);
    expect(find.textContaining('EV 15'), findsOneWidget);
  });

  testWidgets('ReadingPanel shows a metering placeholder when unsolved',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadingPanel(
            solution: null,
            film: FilmStock(name: 'Generic', iso: 100),
            meanLuma: 0,
          ),
        ),
      ),
    );

    expect(find.text('Metering…'), findsOneWidget);
  });
}
