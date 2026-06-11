import '../../domain/entities/fulfillment_record.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class FulfillmentRecordModel extends FulfillmentRecord {
  const FulfillmentRecordModel({
    required super.nodeType,
    super.imageUrl,
    super.mediaType,
    super.objectKey,
    super.fileSize,
    super.contentType,
    super.frameRate,
    super.processingStatus,
    super.processingErrorCode,
    super.processingError,
    super.watermarkText,
    required super.createdAt,
  });

  factory FulfillmentRecordModel.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['imageUrl']?.toString() ?? json['mediaUrl']?.toString();
    return FulfillmentRecordModel(
      nodeType: _asInt(json['nodeType']),
      imageUrl: rawUrl == null ? null : ensureHttpsMediaUrl(rawUrl),
      mediaType: json['mediaType']?.toString(),
      objectKey: json['objectKey']?.toString(),
      fileSize: _asIntOrNull(json['fileSize']),
      contentType: json['contentType']?.toString(),
      frameRate: _asIntOrNull(json['frameRate']),
      processingStatus: json['processingStatus']?.toString(),
      processingErrorCode: json['processingErrorCode']?.toString(),
      processingError: json['processingError']?.toString(),
      watermarkText: json['watermarkText']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
