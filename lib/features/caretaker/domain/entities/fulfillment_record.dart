/// 履约节点类型
class FulfillmentRecord {
  /// 1=抵达签到 2=入户确认 3=喂食换水 4=铲屎清洁 5=遛宠中 6=锁门离场
  final int nodeType;

  /// 兼容字段：图片节点是图片 URL；视频节点处理成功后是视频临时 URL
  final String? imageUrl;

  /// 媒体类型：IMAGE / VIDEO / null
  final String? mediaType;

  /// OSS 对象 Key，后端用于生成临时 URL，前端只展示不持久化
  final String? objectKey;

  /// 处理后媒体大小，单位字节
  final int? fileSize;

  /// 处理后媒体 MIME 类型，例如 video/mp4 / image/jpeg
  final String? contentType;

  /// 视频帧率，仅视频处理成功后可能有值
  final int? frameRate;

  /// 处理状态：PROCESSING / SUCCESS / FAILED / null（无媒体节点）
  final String? processingStatus;

  /// 处理失败错误码，便于前端做稳定分支
  final String? processingErrorCode;

  /// 处理失败原因说明
  final String? processingError;

  /// 后端实际写入视频的水印文案
  final String? watermarkText;

  final String createdAt;

  const FulfillmentRecord({
    required this.nodeType,
    this.imageUrl,
    this.mediaType,
    this.objectKey,
    this.fileSize,
    this.contentType,
    this.frameRate,
    this.processingStatus,
    this.processingErrorCode,
    this.processingError,
    this.watermarkText,
    required this.createdAt,
  });

  bool get isVideo => mediaType == 'VIDEO';
  bool get isProcessing => processingStatus == 'PROCESSING';
  bool get isFailed => processingStatus == 'FAILED';
  bool get isMediaReady =>
      processingStatus == null || processingStatus == 'SUCCESS';
}
