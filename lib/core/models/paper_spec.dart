enum PaperCategory {
  iso('ISO'),
  print('冲印'),
  idPhoto('证件照');

  const PaperCategory(this.label);
  final String label;
}

class PaperSpec {
  const PaperSpec({
    required this.id,
    required this.label,
    required this.widthMm,
    required this.heightMm,
    required this.category,
  });

  final String id;
  final String label;
  final double widthMm;
  final double heightMm;
  final PaperCategory category;
}
