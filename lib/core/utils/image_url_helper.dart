/// 历史占位图，OSS 上已不可公开访问，不再作为 fallback。
const String kDefaultSeedImageUrl = '';

bool isUnavailableRemoteImageUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return true;
  }
  final lower = trimmed.toLowerCase();
  if (lower.contains('/seed/default/') || lower.endsWith('pets-seed.jpg')) {
    return true;
  }
  final uri = Uri.tryParse(trimmed);
  final host = uri?.host.toLowerCase() ?? '';
  return host == 'example.com' || host.endsWith('.example.com');
}

String normalizeRemoteImageUrl(
  String? rawUrl, {
  String fallbackUrl = kDefaultSeedImageUrl,
}) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return trimmed;
  }

  if (isUnavailableRemoteImageUrl(trimmed)) {
    final fallback = fallbackUrl.trim();
    return isUnavailableRemoteImageUrl(fallback) ? '' : fallback;
  }

  return trimmed;
}

/// 履约媒体 URL 统一走 HTTPS，避免 Android 加载 OSS 预签名 HTTP 链接失败。
String ensureHttpsMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty || isUnavailableRemoteImageUrl(trimmed)) {
    return '';
  }
  if (trimmed.startsWith('http://')) {
    return 'https://${trimmed.substring('http://'.length)}';
  }
  return trimmed;
}
