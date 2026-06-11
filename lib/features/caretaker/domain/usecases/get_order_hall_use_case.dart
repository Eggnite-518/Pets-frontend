import 'package:pets/core/network/api_result.dart';

import '../entities/order_hall_item.dart';
import '../repositories/order_hall_repository.dart';

class GetOrderHallUseCase {
  final OrderHallRepository _repository;

  const GetOrderHallUseCase(this._repository);

  Future<ApiResult<OrderHallPage>> call({
    double? caretakerLat,
    double? caretakerLng,
    int? petType,
    int? serviceType,
    double? maxDistanceKm,
    int? minAmount,
    int? maxAmount,
    String? serviceDate,
    int page = 1,
    int pageSize = 10,
  }) {
    return _repository.getOrderHall(
      caretakerLat: caretakerLat,
      caretakerLng: caretakerLng,
      petType: petType,
      serviceType: serviceType,
      maxDistanceKm: maxDistanceKm,
      minAmount: minAmount,
      maxAmount: maxAmount,
      serviceDate: serviceDate,
      page: page,
      pageSize: pageSize,
    );
  }
}
