import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../data/customer_repository.dart';

final _customerPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final _customersProvider =
    FutureProvider.autoDispose<PaginatedResult<Map<String, dynamic>>>((ref) async {
  final page = ref.watch(_customerPageProvider);
  return ref.watch(customerRepositoryProvider).searchCustomers(page: page);
});

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _openCreate() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Pelanggan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama *'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telepon'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.length < 2) return;
              try {
                await ref.read(customerRepositoryProvider).createCustomer(
                      name: name,
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                    );
                ref.invalidate(_customersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_customersProvider);
    return AppScaffold(
      title: 'Data Pelanggan',
      actions: [
        IconButton(onPressed: _openCreate, icon: const Icon(Icons.add)),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_err(e))),
        data: (result) {
          final items = result.items;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada pelanggan.\nTambah manual atau otomatis saat buat order.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return PaginationBar(
                  meta: result.meta,
                  onPageChanged: (p) =>
                      ref.read(_customerPageProvider.notifier).state = p,
                );
              }
              final c = items[index];
              final name = c['name']?.toString() ?? '-';
              final phone = c['phone']?.toString();
              final email = c['email']?.toString();
              final subtitle = [
                if (phone != null && phone.isNotEmpty) phone,
                if (email != null && email.isNotEmpty) email,
              ].join(' · ');
              final id = c['id']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.person,
                    accentKey: name,
                  ),
                  title: Text(name),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: id.isEmpty
                      ? null
                      : () => context.push('/customers/$id'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Pelanggan'),
      ),
    );
  }
}
