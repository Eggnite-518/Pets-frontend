import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/order_hall_item_model.dart';

class OrderHallRemoteDataSource {
  final ApiClient _apiClient;

  const OrderHallRemoteDataSource(this._apiClient);

  Future<ApiResponse<OrderHallPageModel>> getOrderHall({
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
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (caretakerLat != null && caretakerLng != null) ...{
        'caretakerLat': caretakerLat.toString(),
        'caretakerLng': caretakerLng.toString(),
      },
      if (petType != null) 'petType': petType.toString(),
      if (serviceType != null) 'serviceType': serviceType.toString(),
      if (maxDistanceKm != null && maxDistanceKm > 0)
        'maxDistanceKm': maxDistanceKm.toString(),
      if (minAmount != null) 'minAmount': minAmount.toString(),
      if (maxAmount != null) 'maxAmount': maxAmount.toString(),
      if (serviceDate != null && serviceDate.isNotEmpty)
        'serviceDate': serviceDate,
    };
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    return _apiClient.get<OrderHallPageModel>(
      path: '/api/v1/orders/open?$queryString',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return OrderHallPageModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> applyOrder(String orderId) {
    return _apiClient.post<Map<String, dynamic>>(
      path: '/api/v1/orders/$orderId/reservations',
      body: <String, dynamic>{},
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<void>> cancelApplication(String orderId) {
    return _apiClient.delete<void>(
      path: '/api/v1/orders/$orderId/reservations',
    );
  }
}
