class ReviewAttachmentModel {
  final String url;
  final String objectKey;
  final String mediaType;
  final String contentType;
  final int fileSize;
  final int? sortOrder;

  const ReviewAttachmentModel({
    required this.url,
    required this.objectKey,
    required this.mediaType,
    required this.contentType,
    required this.fileSize,
    this.sortOrder,
  });

  factory ReviewAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ReviewAttachmentModel(
      url: json['url']?.toString() ?? '',
      objectKey: json['objectKey']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      fileSize: _toInt(json['fileSize']),
      sortOrder: json['sortOrder'] == null ? null : _toInt(json['sortOrder']),
    );
  }

  ReviewAttachmentModel withSortOrder(int value) {
    return ReviewAttachmentModel(
      url: url,
      objectKey: objectKey,
      mediaType: mediaType,
      contentType: contentType,
      fileSize: fileSize,
      sortOrder: value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'objectKey': objectKey,
      'mediaType': mediaType,
      'contentType': contentType,
      'fileSize': fileSize,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
