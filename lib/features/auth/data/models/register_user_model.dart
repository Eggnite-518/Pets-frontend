class RegisterUserModel {
  final String nickname;
  final String phone;
  final String requestId;

  const RegisterUserModel({
    required this.nickname,
    required this.phone,
    required this.requestId,
  });

  factory RegisterUserModel.fromJson(Map<String, dynamic> json) {
    return RegisterUserModel(
      nickname: json['nickname']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? '',
    );
  }
}
