import 'package:apotikflow_app/features/auth/domain/entities/auth_user.dart';
import 'package:apotikflow_app/shared/utils/role_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MANAGER tanpa cabang → Manajer Pusat', () {
    expect(
      RoleLabels.labelForUser(
        const AuthUser(
          id: '1',
          name: 'A',
          email: 'a@test.com',
          role: 'MANAGER',
        ),
      ),
      RoleLabels.managerCentral,
    );
  });

  test('MANAGER dengan cabang → Kepala Cabang', () {
    expect(
      RoleLabels.labelForUser(
        const AuthUser(
          id: '1',
          name: 'A',
          email: 'a@test.com',
          role: 'MANAGER',
          branchId: 'branch-1',
        ),
      ),
      RoleLabels.managerBranch,
    );
  });

  test('labelFromMap memakai branch_id', () {
    final label = RoleLabels.labelFromMap(
      {'branch_id': 'b1'},
      'MANAGER',
    );
    expect(label, RoleLabels.managerBranch);
  });
}
