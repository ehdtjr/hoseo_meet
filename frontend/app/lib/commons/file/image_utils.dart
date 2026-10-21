import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

bool isWebP(String path) {
  return path.toLowerCase().endsWith('.webp');
}

Future<File> ensureWebP(File file, {int quality = 80}) async {
  if (isWebP(file.path)) return file;

  if (!await file.exists()) {
    throw Exception('파일이 존재하지 않음: ${file.path}');
  }

  // ✅ 안전한 출력 경로: 앱 임시 디렉토리 사용
  final tempDir = await getTemporaryDirectory();
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.webp';
  final targetPath = p.join(tempDir.path, fileName);

  print('▶️ 원본 경로: ${file.absolute.path}');
  print('▶️ 타겟 경로: $targetPath');

  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    format: CompressFormat.webp,
    quality: quality,
  );

  if (result == null) {
    throw Exception('WebP 변환 실패 (파일: ${file.path})');
  }

  return File(result.path);
}