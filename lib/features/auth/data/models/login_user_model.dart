class LoginUserModel {
  final int userId;
  final String nickname;
  final String phone;
  final int roleType;
  final String roleTypeDesc;
  final String token;

  const LoginUserModel({
    required this.userId,
    required this.nickname,
    required this.phone,
    required this.roleType,
    required this.roleTypeDesc,
    required this.token,
  });

  factory LoginUserModel.fromJson(Map<String, dynamic> json) {
    return LoginUserModel(
      userId: json['userId'] as int,
      nickname: json['nickname']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      roleType: json['roleType'] as int,
      roleTypeDesc: json['roleTypeDesc']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }
}
