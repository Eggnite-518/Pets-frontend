import '../../domain/entities/caretaker_income_record.dart';

class CaretakerIncomeRecordModel extends CaretakerIncomeRecord {
  const CaretakerIncomeRecordModel({
    required super.recordId,
    required super.type,
    required super.typeText,
    required super.direction,
    required super.amount,
    required super.description,
    required super.createdAt,
  });

  factory CaretakerIncomeRecordModel.fromJson(Map<String, dynamic> json) {
    final type = _asInt(json['type']);
    final rawTypeText = json['typeText']?.toString() ?? '';
    final rawDescription = json['description']?.toString() ?? '';
    final relationId = _extractRelationId(rawDescription);

    return CaretakerIncomeRecordModel(
      recordId: json['recordId']?.toString() ?? '',
      type: type,
      typeText: _localizeTypeText(type, rawTypeText),
      direction: _asInt(json['direction']),
      amount: json['amount']?.toString() ?? '0.00',
      description: _localizeDescription(type, rawDescription, relationId),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  static String _localizeTypeText(int type, String raw) {
    final mapped = _typeTextByCode[type];
    if (mapped != null) return mapped;

    return _legacyEnglishTypeText[raw] ?? raw;
  }

  static String _localizeDescription(
    int type,
    String raw,
    String? relationId,
  ) {
    if (_containsChinese(raw)) return raw;

    final mapped = _descriptionByCode(type, relationId);
    if (mapped != null) return mapped;

    return _legacyEnglishDescription[raw] ?? raw;
  }

  static String? _descriptionByCode(int type, String? relationId) {
    switch (type) {
      case 11:
        return relationId == null ? '订单收益' : '订单 #$relationId 完成';
      case 12:
        return relationId == null ? '空跑补偿' : '订单 #$relationId 空跑补偿';
      case 13:
        return relationId == null ? '提现' : '提现 #$relationId';
      case 21:
        return relationId == null ? '订单支付' : '订单 #$relationId 支付';
      case 22:
        return relationId == null ? '订单退款' : '订单 #$relationId 退款';
      case 31:
        return '余额充值';
      case 41:
        return '保证金充值';
      case 42:
        return '保证金退还申请';
      case 43:
        return '保证金退还';
      default:
        return null;
    }
  }

  static String? _extractRelationId(String raw) {
    final match = RegExp(r'#(\d+)').firstMatch(raw);
    return match?.group(1);
  }

  static bool _containsChinese(String value) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
  }

  static const Map<int, String> _typeTextByCode = {
    11: '订单收益',
    12: '空跑补偿',
    13: '提现',
    21: '订单支付',
    22: '订单退款',
    31: '余额充值',
    41: '保证金充值',
    42: '保证金退还申请',
    43: '保证金退还',
  };

  static const Map<String, String> _legacyEnglishTypeText = {
    'Order income': '订单收益',
    'Empty run compensation': '空跑补偿',
    'Withdraw': '提现',
    'Order payment': '订单支付',
    'Order refund': '订单退款',
    'Recharge': '余额充值',
    'Deposit recharge': '保证金充值',
    'Deposit refund applying': '保证金退还申请',
    'Deposit refund': '保证金退还',
    'Wallet transaction': '钱包流水',
    'Unknown': '未知类型',
  };

  static const Map<String, String> _legacyEnglishDescription = {
    'Order income': '订单收益',
    'Empty run compensation': '空跑补偿',
    'Withdraw': '提现',
    'Order payment': '订单支付',
    'Order refund': '订单退款',
    'Recharge': '余额充值',
    'Deposit recharge': '保证金充值',
    'Deposit refund applying': '保证金退还申请',
    'Deposit refund': '保证金退还',
    'Wallet transaction': '钱包流水',
    'Unknown': '未知类型',
  };

  CaretakerIncomeRecord toEntity() => CaretakerIncomeRecord(
        recordId: recordId,
        type: type,
        typeText: typeText,
        direction: direction,
        amount: amount,
        description: description,
        createdAt: createdAt,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CaretakerIncomeRecordPageModel extends CaretakerIncomeRecordPage {
  const CaretakerIncomeRecordPageModel({
    required super.total,
    required super.page,
    required super.pageSize,
    required super.list,
  });

  factory CaretakerIncomeRecordPageModel.fromJson(
      Map<String, dynamic> json) {
    final rawList = json['list'];
    final records = rawList is List
        ? rawList
            .map((e) => CaretakerIncomeRecordModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <CaretakerIncomeRecordModel>[];

    return CaretakerIncomeRecordPageModel(
      total: _asInt(json['total']),
      page: _asInt(json['page']),
      pageSize: _asInt(json['pageSize']),
      list: records,
    );
  }

  CaretakerIncomeRecordPage toEntity() => CaretakerIncomeRecordPage(
        total: total,
        page: page,
        pageSize: pageSize,
        list: list,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
