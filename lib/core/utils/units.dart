import 'dart:ui';

import '../models/paper_spec.dart';

const double workingDpi = 150;
const double exportDpi = 300;
const double mmPerInch = 25.4;

Size paperSizePx({
  required double widthMm,
  required double heightMm,
  double dpi = workingDpi,
}) {
  return Size(
    widthMm / mmPerInch * dpi,
    heightMm / mmPerInch * dpi,
  );
}

Size specSizeMm(PaperSpec spec, {required bool landscape}) {
  if (landscape) {
    return Size(spec.heightMm, spec.widthMm);
  }
  return Size(spec.widthMm, spec.heightMm);
}

Size specSizePx(
  PaperSpec spec, {
  required bool landscape,
  double dpi = workingDpi,
}) {
  final mm = specSizeMm(spec, landscape: landscape);
  return paperSizePx(widthMm: mm.width, heightMm: mm.height, dpi: dpi);
}

String formatMm(double value) {
  if ((value - value.roundToDouble()).abs() < 0.05) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
