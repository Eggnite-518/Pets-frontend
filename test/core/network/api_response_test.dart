import 'package:flutter_test/flutter_test.dart';
import 'package:pets/core/network/api_response.dart';

void main() {
  test('parses string code', () {
    final response = ApiResponse.fromJson(
      {
        'code': 'success',
        'message': 'ok',
        'data': {'value': 1},
        'requestId': 'r1',
      },
    );

    expect(response.code, 'success');
    expect(response.message, 'ok');
    expect(response.requestId, 'r1');
    expect(response.isSuccess, isTrue);
  });

  test('parses numeric code and null data', () {
    final response = ApiResponse.fromJson(
      {
        'code': 0,
        'message': 'success',
        'data': null,
      },
    );

    expect(response.code, 0);
    expect(response.data, isNull);
    expect(response.isSuccess, isTrue);
  });
}
