import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/order.dart';

bool _editableStatus(String status) =>
    status == 'WAITING_PAYMENT' || status == 'PENDING_PHARMACY';

bool canEditOrder(AuthUser? user, OrderSummary order) {
  if (user == null || !_editableStatus(order.status)) return false;
  if (user.isTenantWideManager || user.isBranchManager) return true;
  if (user.isStaff && order.servedById == user.id) return true;
  return false;
}

bool canCancelOrder(AuthUser? user, OrderSummary order) {
  if (user == null || !_editableStatus(order.status)) return false;
  if (user.isTenantWideManager) return true;
  if (user.isBranchManager || user.isPharmacist) {
    return user.branchId != null;
  }
  return false;
}

bool canApprovePharmacy(AuthUser? user, OrderSummary order) {
  if (user == null || order.status != 'PENDING_PHARMACY') return false;
  return user.isPharmacist || user.isTenantWideManager;
}

bool canPayOrder(OrderSummary order) {
  return order.status == 'WAITING_PAYMENT';
}
