import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

bool isWebP(String path) {
  return path.toLowerCase().endsWith('.webp');
}

Future<File> ensureWebP(File file, {int quality = 80}) async {
  if (isWebP(file.path)) return file;

  final targetPath = p.setExtension(file.path, '.webp');
  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    format: CompressFormat.webp,
    quality: quality,
  );

  if (result == null) throw Exception('WebP 변환 실패');
  return File(result.path);
}

