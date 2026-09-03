import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:saver_gallery/saver_gallery.dart';

import 'api_client.dart';

/// Скачивает Reel во временный файл и публикует его в галерее.
class VideoDownloadService {
  const VideoDownloadService(this._apiClient);

  final ListingApiClient _apiClient;

  Future<void> saveToGallery(String source) async {
    if (kIsWeb) {
      throw UnsupportedError('Сохранение видео на web не поддерживается');
    }

    final tempDirectory = await Directory.systemTemp.createTemp(
      'house_kg_reel_',
    );
    final fileName = _fileName(source);
    final tempFile = File('${tempDirectory.path}/$fileName');

    try {
      final uri = Uri.tryParse(source);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        await _apiClient.downloadFile(source, tempFile.path);
      } else {
        final localFile = File(source);
        if (await localFile.exists()) {
          await localFile.copy(tempFile.path);
        } else {
          final asset = await rootBundle.load(source);
          await tempFile.writeAsBytes(
            asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
            flush: true,
          );
        }
      }

      final result = await SaverGallery.saveFile(
        filePath: tempFile.path,
        fileName: fileName,
        albumPath: 'House KG',
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Галерея не сохранила видео');
      }
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  String _fileName(String source) {
    final uri = Uri.tryParse(source);
    final lastSegment = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : '';
    final sanitized = lastSegment.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isNotEmpty && sanitized.contains('.')) return sanitized;
    return 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }
}
