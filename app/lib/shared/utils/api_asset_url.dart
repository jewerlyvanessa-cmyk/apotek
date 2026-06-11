/// URL absolut untuk file statis di server (mis. `/uploads/...`).
String resolveApiAssetUrl(String apiBaseUrl, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final origin = apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
  final normalized = path.startsWith('/') ? path : '/$path';
  return '$origin$normalized';
}
