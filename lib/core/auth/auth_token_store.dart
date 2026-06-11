import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthTokenStore {
  static AuthTokenStore instance = InMemoryAuthTokenStore();

  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();

  /// roleType: 1=宠物主, 2=宠托师, 3=两者都有
  Future<int?> readRoleType();
  Future<void> writeRoleType(int roleType);
  Future<void> clearRoleType();

  /// 用户注册/登录时的昵称（用于宠托师档案首次初始化及展示）
  Future<String?> readNickname();
  Future<void> writeNickname(String nickname);
  Future<void> clearNickname();

  /// 用户手机号（用于"我的"页面展示，脱敏处理在 UI 层完成）
  Future<String?> readPhone();
  Future<void> writePhone(String phone);
  Future<void> clearPhone();

  Future<int?> readUserId();
  Future<void> writeUserId(int userId);
  Future<void> clearUserId();

  /// 登出时一并清除所有本地数据
  Future<void> clearAll() async {
    await clearToken();
    await clearRoleType();
    await clearNickname();
    await clearPhone();
    await clearUserId();
  }
}

class InMemoryAuthTokenStore extends AuthTokenStore {
  String? _token;
  int? _roleType;
  String? _nickname;

  @override
  Future<void> clearToken() async => _token = null;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = _normalizeToken(token);

  @override
  Future<int?> readRoleType() async => _roleType;

  @override
  Future<void> writeRoleType(int roleType) async => _roleType = roleType;

  @override
  Future<void> clearRoleType() async => _roleType = null;

  @override
  Future<String?> readNickname() async => _nickname;

  @override
  Future<void> writeNickname(String nickname) async => _nickname = nickname;

  @override
  Future<void> clearNickname() async => _nickname = null;

  String? _phone;
  int? _userId;

  @override
  Future<String?> readPhone() async => _phone;

  @override
  Future<void> writePhone(String phone) async => _phone = phone;

  @override
  Future<void> clearPhone() async => _phone = null;

  @override
  Future<int?> readUserId() async => _userId;

  @override
  Future<void> writeUserId(int userId) async => _userId = userId;

  @override
  Future<void> clearUserId() async => _userId = null;
}

class SharedPreferencesAuthTokenStore extends AuthTokenStore {
  SharedPreferencesAuthTokenStore(this._preferences);

  static const String _tokenKey = 'auth_token';
  static const String _roleTypeKey = 'auth_role_type';
  static const String _nicknameKey = 'auth_nickname';
  static const String _phoneKey = 'auth_phone';
  static const String _userIdKey = 'auth_user_id';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesAuthTokenStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAuthTokenStore(preferences);
  }

  @override
  Future<void> clearToken() async {
    await _preferences.remove(_tokenKey);
  }

  @override
  Future<String?> readToken() async {
    return _preferences.getString(_tokenKey);
  }

  @override
  Future<void> writeToken(String token) async {
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken == null) {
      await clearToken();
      return;
    }
    await _preferences.setString(_tokenKey, normalizedToken);
  }

  @override
  Future<int?> readRoleType() async {
    return _preferences.getInt(_roleTypeKey);
  }

  @override
  Future<void> writeRoleType(int roleType) async {
    await _preferences.setInt(_roleTypeKey, roleType);
  }

  @override
  Future<void> clearRoleType() async {
    await _preferences.remove(_roleTypeKey);
  }

  @override
  Future<String?> readNickname() async {
    return _preferences.getString(_nicknameKey);
  }

  @override
  Future<void> writeNickname(String nickname) async {
    await _preferences.setString(_nicknameKey, nickname);
  }

  @override
  Future<void> clearNickname() async {
    await _preferences.remove(_nicknameKey);
  }

  @override
  Future<String?> readPhone() async {
    return _preferences.getString(_phoneKey);
  }

  @override
  Future<void> writePhone(String phone) async {
    await _preferences.setString(_phoneKey, phone);
  }

  @override
  Future<void> clearPhone() async {
    await _preferences.remove(_phoneKey);
  }

  @override
  Future<int?> readUserId() async {
    return _preferences.getInt(_userIdKey);
  }

  @override
  Future<void> writeUserId(int userId) async {
    await _preferences.setInt(_userIdKey, userId);
  }

  @override
  Future<void> clearUserId() async {
    await _preferences.remove(_userIdKey);
  }
}

String? _normalizeToken(String token) {
  final trimmedToken = token.trim();
  if (trimmedToken.isEmpty) {
    return null;
  }

  const bearerPrefix = 'bearer ';
  if (trimmedToken.toLowerCase().startsWith(bearerPrefix)) {
    final compactToken = trimmedToken.substring(bearerPrefix.length).trim();
    return compactToken.isEmpty ? null : compactToken;
  }

  return trimmedToken;
}
