import '../core/models/paper_spec.dart';

class PaperPresets {
  static const List<PaperSpec> all = [
    PaperSpec(
      id: 'a3',
      label: 'A3',
      widthMm: 297,
      heightMm: 420,
      category: PaperCategory.iso,
    ),
    PaperSpec(
      id: 'a4',
      label: 'A4',
      widthMm: 210,
      heightMm: 297,
      category: PaperCategory.iso,
    ),
    PaperSpec(
      id: 'a5',
      label: 'A5',
      widthMm: 148,
      heightMm: 210,
      category: PaperCategory.iso,
    ),
    PaperSpec(
      id: 'letter',
      label: 'Letter',
      widthMm: 215.9,
      heightMm: 279.4,
      category: PaperCategory.iso,
    ),
    PaperSpec(
      id: 'inch5',
      label: '5寸',
      widthMm: 89,
      heightMm: 127,
      category: PaperCategory.print,
    ),
    PaperSpec(
      id: 'inch6',
      label: '6寸',
      widthMm: 102,
      heightMm: 152,
      category: PaperCategory.print,
    ),
    PaperSpec(
      id: 'inch7',
      label: '7寸',
      widthMm: 127,
      heightMm: 178,
      category: PaperCategory.print,
    ),
    PaperSpec(
      id: 'inch8',
      label: '8寸',
      widthMm: 152,
      heightMm: 203,
      category: PaperCategory.print,
    ),
    PaperSpec(
      id: 'one_inch',
      label: '一寸',
      widthMm: 25,
      heightMm: 35,
      category: PaperCategory.idPhoto,
    ),
    PaperSpec(
      id: 'small_one_inch',
      label: '小一寸',
      widthMm: 22,
      heightMm: 32,
      category: PaperCategory.idPhoto,
    ),
    PaperSpec(
      id: 'two_inch',
      label: '两寸',
      widthMm: 35,
      heightMm: 49,
      category: PaperCategory.idPhoto,
    ),
    PaperSpec(
      id: 'id_card',
      label: '身份证',
      widthMm: 26,
      heightMm: 32,
      category: PaperCategory.idPhoto,
    ),
  ];

  static PaperSpec get defaultSpec => byId('a4');

  static PaperSpec byId(String id) {
    return all.firstWhere(
      (spec) => spec.id == id,
      orElse: () => defaultSpec,
    );
  }

  static List<PaperSpec> of(PaperCategory category) {
    return all.where((spec) => spec.category == category).toList();
  }
}
