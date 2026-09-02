// Кадр-обложка ролика и его метаданные — снимаются на устройстве.
//
// Раньше это делал бэкенд: на каждую загрузку он писал временную копию видео и
// запускал ffprobe и ffmpeg, а на выдаче каталога — ещё раз ffmpeg, если
// обложки не оказалось. Телефон уже держит ролик в руках, поэтому кадр и
// длительность снимает он и отправляет вместе с файлом.
//
// Плагин работает на Android и iOS. Везде, где его нет (веб, десктоп, тесты),
// возвращается пустой результат: сервер в таком случае покажет обложку
// объявления, и загрузка всё равно проходит.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Чем снимается обложка ролика. Отдельный тип нужен, чтобы в тестах
/// подставить заглушку вместо платформенного плагина.
typedef VideoPosterCapture = Future<VideoPoster> Function(String path);

/// Что удалось снять с ролика.
@immutable
class VideoPoster {
  const VideoPoster({this.bytes, this.durationSeconds, this.width, this.height});

  /// Пустой результат — плагина нет или файл не читается.
  static const VideoPoster none = VideoPoster();

  /// JPEG-кадр для обложки.
  final Uint8List? bytes;

  /// Длительность ролика в секундах — по ней сервер проверяет лимит.
  final int? durationSeconds;

  final int? width;
  final int? height;

  bool get hasImage => bytes != null && bytes!.isNotEmpty;

  bool get isEmpty => !hasImage && durationSeconds == null;
}

/// Снимает кадр и метаданные ролика по пути к файлу.
///
/// Никогда не бросает: обложка — украшение, из-за которого не должна падать
/// публикация объявления.
Future<VideoPoster> captureVideoPoster(
  String path, {
  int maxWidth = 1080,
  int atMs = 1000,
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (path.isEmpty) return VideoPoster.none;

  // Таймаут обязателен: и извлечение кадра, и инициализация плеера умеют
  // зависать на битом файле или незнакомом кодеке, а из-за обложки ролик не
  // должен застревать на полпути.
  final bytes = await _guard(_frame(path, maxWidth: maxWidth, atMs: atMs), timeout, 'кадр');
  final meta = await _guard(_metadata(path), timeout, 'метаданные') ?? const _VideoMeta();

  return VideoPoster(
    bytes: bytes,
    durationSeconds: meta.durationSeconds,
    width: meta.width,
    height: meta.height,
  );
}

/// Ждёт результат не дольше таймаута и никогда не бросает.
Future<T?> _guard<T>(Future<T> work, Duration timeout, String what) async {
  try {
    return await work.timeout(timeout);
  } catch (e) {
    debugPrint('Не удалось получить $what видео: $e');
    return null;
  }
}

/// Кадр на первой секунде; если ролик короче — самый первый.
Future<Uint8List?> _frame(String path, {required int maxWidth, required int atMs}) async {
  for (final time in <int>{atMs, 0}) {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        timeMs: time,
        quality: 80,
      );
      if (data != null && data.isNotEmpty) return data;
    } catch (e) {
      debugPrint('Кадр из видео снять не удалось ($time мс): $e');
    }
  }
  return null;
}

class _VideoMeta {
  const _VideoMeta({this.durationSeconds, this.width, this.height});
  final int? durationSeconds;
  final int? width;
  final int? height;
}

/// Длительность и разрешение — из того же плеера, которым ролик и показывается.
Future<_VideoMeta> _metadata(String path) async {
  VideoPlayerController? controller;
  try {
    if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
      controller = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      controller = VideoPlayerController.file(File(path));
    }
    await controller.initialize();
    final value = controller.value;
    final size = value.size;
    final durSec = value.duration.inSeconds;
    return _VideoMeta(
      durationSeconds: durSec > 0 ? durSec : (value.duration.inMilliseconds > 0 ? 1 : null),
      width: size.width > 0 ? size.width.round() : null,
      height: size.height > 0 ? size.height.round() : null,
    );
  } catch (e) {
    debugPrint('Метаданные видео прочитать не удалось: $e');
    return const _VideoMeta();
  } finally {
    await controller?.dispose();
  }
}
