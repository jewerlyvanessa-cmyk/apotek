import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReportDateMode { today, singleDay, range }

class ReportDateFilter {
  const ReportDateFilter({
    required this.mode,
    required this.from,
    required this.to,
  });

  final ReportDateMode mode;
  final DateTime from;
  final DateTime to;

  factory ReportDateFilter.today() {
    final d = _dateOnly(DateTime.now());
    return ReportDateFilter(mode: ReportDateMode.today, from: d, to: d);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get dateFromIso => from.toIso8601String();
  String get dateToIso => to.toIso8601String();

  bool get isSingleDay =>
      from.year == to.year && from.month == to.month && from.day == to.day;

  String label() {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    switch (mode) {
      case ReportDateMode.today:
        return 'Hari ini (${fmt(from)})';
      case ReportDateMode.singleDay:
        return fmt(from);
      case ReportDateMode.range:
        return '${fmt(from)} – ${fmt(to)}';
    }
  }
}

final reportDateFilterProvider =
    StateProvider<ReportDateFilter>((ref) => ReportDateFilter.today());
