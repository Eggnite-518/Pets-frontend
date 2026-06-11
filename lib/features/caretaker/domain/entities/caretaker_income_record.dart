/// 钱包流水记录
class CaretakerIncomeRecord {
  final String recordId;

  /// 记录类型：1=订单收益，2=提现
  final int type;

  /// 类型展示文案，后端生成，如「订单收益」「提现」
  final String typeText;

  /// 资金方向：1=收入(+)，2=支出(-)
  final int direction;

  /// 金额，保留两位小数，如 "65.00"（始终为正数，方向由 direction 决定）
  final String amount;

  /// 摘要说明，如「订单 #10086 完成」「提现至微信支付」
  final String description;

  /// 创建时间，YYYY-MM-DD HH:mm:ss
  final String createdAt;

  const CaretakerIncomeRecord({
    required this.recordId,
    required this.type,
    required this.typeText,
    required this.direction,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  bool get isIncome => direction == 1;
}

class CaretakerIncomeRecordPage {
  final int total;
  final int page;
  final int pageSize;
  final List<CaretakerIncomeRecord> list;

  const CaretakerIncomeRecordPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });
}
