import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../providers/report_date_filter.dart';

class ReportDateFilterBar extends ConsumerWidget {
  const ReportDateFilterBar({
    super.key,
    this.filterProvider,
    this.filter,
    this.onFilterChanged,
  });

  /// Mode provider (laporan). Default: [reportDateFilterProvider].
  final StateProvider<ReportDateFilter>? filterProvider;

  /// Mode terkontrol (mis. halaman pelanggan).
  final ReportDateFilter? filter;
  final ValueChanged<ReportDateFilter>? onFilterChanged;

  Future<DateTime?> _pickDate(
    BuildContext context, {
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih tanggal',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isControlled = filter != null && onFilterChanged != null;
    final activeFilter = isControlled
        ? filter!
        : ref.watch(filterProvider ?? reportDateFilterProvider);
    void updateFilter(ReportDateFilter next) {
      if (isControlled) {
        onFilterChanged!(next);
      } else {
        ref.read((filterProvider ?? reportDateFilterProvider).notifier).state =
            next;
      }
    }

    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ReportDateMode>(
              segments: const [
                ButtonSegment(
                  value: ReportDateMode.today,
                  label: Text('Hari ini'),
                  icon: Icon(Icons.today, size: 18),
                ),
                ButtonSegment(
                  value: ReportDateMode.singleDay,
                  label: Text('Tanggal'),
                  icon: Icon(Icons.event, size: 18),
                ),
                ButtonSegment(
                  value: ReportDateMode.range,
                  label: Text('Rentang'),
                  icon: Icon(Icons.date_range, size: 18),
                ),
              ],
              selected: {activeFilter.mode},
              onSelectionChanged: (modes) {
                final mode = modes.first;
                switch (mode) {
                  case ReportDateMode.today:
                    updateFilter(ReportDateFilter.today());
                    break;
                  case ReportDateMode.singleDay:
                    updateFilter(ReportDateFilter(
                      mode: mode,
                      from: activeFilter.from,
                      to: activeFilter.from,
                    ));
                    break;
                  case ReportDateMode.range:
                    updateFilter(ReportDateFilter(
                      mode: mode,
                      from: activeFilter.from,
                      to: activeFilter.to.isBefore(activeFilter.from)
                          ? activeFilter.from
                          : activeFilter.to,
                    ));
                    break;
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (activeFilter.mode == ReportDateMode.singleDay)
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDate(context, initial: activeFilter.from);
                  if (picked == null) return;
                  final d = DateTime(picked.year, picked.month, picked.day);
                  updateFilter(
                    ReportDateFilter(mode: ReportDateMode.singleDay, from: d, to: d),
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: Text('Tanggal: ${activeFilter.label()}'),
              )
            else if (activeFilter.mode == ReportDateMode.range) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickDate(
                          context,
                          initial: activeFilter.from,
                          lastDate: activeFilter.to,
                        );
                        if (picked == null) return;
                        final from = DateTime(picked.year, picked.month, picked.day);
                        final to =
                            activeFilter.to.isBefore(from) ? from : activeFilter.to;
                        updateFilter(ReportDateFilter(
                          mode: ReportDateMode.range,
                          from: from,
                          to: to,
                        ));
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(
                        'Dari\n${_short(activeFilter.from)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickDate(
                          context,
                          initial: activeFilter.to,
                          firstDate: activeFilter.from,
                        );
                        if (picked == null) return;
                        final to = DateTime(picked.year, picked.month, picked.day);
                        updateFilter(ReportDateFilter(
                          mode: ReportDateMode.range,
                          from: activeFilter.from,
                          to: to.isBefore(activeFilter.from)
                              ? activeFilter.from
                              : to,
                        ));
                      },
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(
                        'Sampai\n${_short(activeFilter.to)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  activeFilter.label(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
