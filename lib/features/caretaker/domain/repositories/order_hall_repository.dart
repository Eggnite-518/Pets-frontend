import 'package:pets/core/network/api_result.dart';

import '../entities/order_hall_item.dart';

abstract class OrderHallRepository {
  Future<ApiResult<OrderHallPage>> getOrderHall({
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
  });

  Future<ApiResult<String>> applyOrder(String orderId);

  Future<ApiResult<void>> cancelApplication(String orderId);
}
