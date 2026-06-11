import 'package:equatable/equatable.dart';

class MedicineListQuery extends Equatable {
  const MedicineListQuery({
    this.search,
    this.productTypeId,
    this.productTypeCode,
  });

  final String? search;
  final String? productTypeId;
  final String? productTypeCode;

  @override
  List<Object?> get props => [search, productTypeId, productTypeCode];
}
