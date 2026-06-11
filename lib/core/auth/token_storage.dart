import 'auth_token_store.dart';

class TokenStorage {
  static Future<String?> getToken() => AuthTokenStore.instance.readToken();

  static Future<void> saveToken(String token) =>
      AuthTokenStore.instance.writeToken(token);

  static Future<void> clearToken() => AuthTokenStore.instance.clearToken();
}
