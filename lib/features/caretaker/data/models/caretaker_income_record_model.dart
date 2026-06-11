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
    return CaretakerIncomeRecordModel(
      recordId: json['recordId']?.toString() ?? '',
      type: _asInt(json['type']),
      typeText: json['typeText']?.toString() ?? '',
      direction: _asInt(json['direction']),
      amount: json['amount']?.toString() ?? '0.00',
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

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
