/// OSS 图片处理：http(s) 图片地址追加格式转换参数，其余地址（本地、空值）原样返回。
String imageProcessFormat(String? img, {String format = 'webp'}) {
  if (img == null || img.isEmpty) return '';
  if (!_isHttpImageUrl(img)) return img;
  return '$img?x-oss-process=image/format,$format';
}

bool _isHttpImageUrl(String url) =>
    url.startsWith('http://') || url.startsWith('https://');
