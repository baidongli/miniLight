import '../exposure/exposure_math.dart';

/// Incident-style metering from an illuminance reading (lux), as reported
/// by the device ambient-light sensor.
///
///   EV100 = log2(lux / C)
///
/// C is the incident-light calibration constant; ~2.5 (sekonic-style C=250
/// with lux, divided by ~100) is a sound default and can be tuned.
class IncidentEv {
  const IncidentEv({this.constantC = 2.5});

  final double constantC;

  double ev100(double lux) {
    if (lux <= 0) return double.negativeInfinity;
    return ExposureMath.log2(lux / constantC);
  }

  IncidentEv anchorTo(double lux, double knownEv100) {
    if (lux <= 0) return this;
    // knownEv100 = log2(lux/C)  ->  C = lux / 2^knownEv100
    return IncidentEv(constantC: lux / ExposureMath.evToLinear(knownEv100));
  }
}
