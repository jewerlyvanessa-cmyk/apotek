import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../data/search_repository.dart';

final _globalSearchProvider = FutureProvider.autoDispose
    .family<GlobalSearchResult, String>((ref, query) async {
  return ref.watch(searchRepositoryProvider).search(query);
});

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    setState(() => _query = value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final async = _query.isEmpty
        ? null
        : ref.watch(_globalSearchProvider(_query));

    return AppScaffold(
      title: 'Pencarian',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Semantics(
              label: 'Kotak pencarian global',
              textField: true,
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Obat, pelanggan, nomor order…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          tooltip: 'Hapus',
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const EmptyStateView(
                    title: 'Cari di seluruh modul',
                    subtitle:
                        'Ketik nama obat, pelanggan, atau nomor order lalu tekan Enter.',
                    icon: Icons.manage_search,
                  )
                : async!.when(
                    loading: () =>
                        const AsyncLoadingView(message: 'Mencari…'),
                    error: (e, _) => AsyncErrorView.fromError(
                      e,
                      onRetry: () =>
                          ref.invalidate(_globalSearchProvider(_query)),
                    ),
                    data: (result) {
                      if (result.isEmpty) {
                        return EmptyStateView(
                          title: 'Tidak ada hasil',
                          subtitle: 'Coba kata kunci lain untuk "$_query".',
                          icon: Icons.search_off,
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        children: [
                          if (result.medicines.isNotEmpty)
                            _section(
                              context,
                              title: 'Obat',
                              icon: Icons.medication_outlined,
                              children: result.medicines.map((m) {
                                final id = m['id']?.toString() ?? '';
                                final name =
                                    m['name']?.toString() ?? 'Obat';
                                return ListTile(
                                  title: Text(name),
                                  subtitle: Text(
                                    [
                                      if (m['barcode'] != null)
                                        'Barcode: ${m['barcode']}',
                                      if (m['sku'] != null) 'SKU: ${m['sku']}',
                                    ].join(' · '),
                                  ),
                                  onTap: id.isEmpty
                                      ? null
                                      : () => context.push(
                                            '/medicines/$id/edit',
                                          ),
                                );
                              }).toList(),
                            ),
                          if (result.customers.isNotEmpty)
                            _section(
                              context,
                              title: 'Pelanggan',
                              icon: Icons.person_outline,
                              children: result.customers.map((c) {
                                final name =
                                    c['name']?.toString() ?? 'Pelanggan';
                                final phone = c['phone']?.toString();
                                return ListTile(
                                  title: Text(name),
                                  subtitle: phone != null ? Text(phone) : null,
                                  onTap: () => context.push('/customers'),
                                );
                              }).toList(),
                            ),
                          if (result.orders.isNotEmpty)
                            _section(
                              context,
                              title: 'Order',
                              icon: Icons.receipt_long_outlined,
                              children: result.orders.map((o) {
                                final id = o['id']?.toString() ?? '';
                                final no =
                                    o['orderNumber']?.toString() ?? id;
                                return ListTile(
                                  title: Text(no),
                                  subtitle: Text(
                                    '${o['customerName'] ?? 'Walk-in'} · ${o['status'] ?? '-'}',
                                  ),
                                  onTap: id.isEmpty
                                      ? null
                                      : () => context.push('/orders/$id'),
                                );
                              }).toList(),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        Card(child: Column(children: children)),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
