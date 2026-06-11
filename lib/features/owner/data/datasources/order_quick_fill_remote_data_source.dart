import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';
import 'package:pets/features/owner/domain/entities/address_family_sop.dart';
import 'package:pets/features/owner/domain/entities/reorder_prefill.dart';

class OrderQuickFillRemoteDataSource {
  final ApiClient _apiClient;

  const OrderQuickFillRemoteDataSource(this._apiClient);

  Future<ApiResponse<ReorderPrefill>> getReorderPrefill(String orderId) {
    return _apiClient.get<ReorderPrefill>(
      path: '/api/v1/orders/$orderId/reorder-prefill',
      dataParser: (data) =>
          ReorderPrefill.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ApiResponse<AddressFamilySop>> getFamilySop(int addressId) {
    return _apiClient.get<AddressFamilySop>(
      path: '/api/v1/user-addresses/$addressId/family-sop',
      dataParser: (data) =>
          AddressFamilySop.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ApiResponse<AddressFamilySop>> saveFamilySop({
    required int addressId,
    required Map<String, dynamic> body,
  }) {
    return _apiClient.put<AddressFamilySop>(
      path: '/api/v1/user-addresses/$addressId/family-sop',
      body: body,
      dataParser: (data) =>
          AddressFamilySop.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}
