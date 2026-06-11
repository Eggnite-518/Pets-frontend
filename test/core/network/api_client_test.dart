import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';

void main() {
  test('parses success payload', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        return http.Response(
          '{"code":"0","message":"success","data":{"petId":1,"ownerId":2,"petName":"Mimi","petType":1,"defaultReq":"feed"}}',
          200,
        );
      }),
    );

    final response = await client.post<Map<String, dynamic>>(
      path: '/api/v1/pet-archives',
      body: {
        'petName': 'Mimi',
        'petType': 1,
        'defaultReq': 'feed',
      },
    );

    expect(response.isSuccess, isTrue);
    expect(response.data?['petName'], 'Mimi');
  });

  test('maps non-2xx to server exception', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        return http.Response('{"message":"bad request"}', 400);
      }),
    );

    expect(
      () => client.post(
        path: '/api/v1/pet-archives',
        body: const {},
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('maps invalid json to parse exception', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        return http.Response('not json', 200);
      }),
    );

    expect(
      () => client.post(
        path: '/api/v1/pet-archives',
        body: const {},
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('adds Authorization header from stored token', () async {
    AuthTokenStore.instance = InMemoryAuthTokenStore();
    await AuthTokenStore.instance.writeToken('test-token');

    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          '{"code":"0","message":"success","data":{}}',
          200,
        );
      }),
    );

    final response = await client.post<Map<String, dynamic>>(
      path: '/api/v1/pet-archives',
      body: const {},
    );

    expect(response.isSuccess, isTrue);
  });
}
