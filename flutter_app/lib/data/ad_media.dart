// Фотографии и видео, которые продавец прикладывает к объявлению.
//
// Снимок приходит одним куском байтов, а не путём: путь на телефоне, в вебе и
// на десктопе выглядит по-разному, а байты показываются везде одинаково.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'video_poster.dart';

/// Один приложенный файл.
@immutable
class AdMedia {
  const AdMedia({
    required this.name,
    this.asset,
    this.url,
    this.bytes,
    this.path,
    this.posterBytes,
    this.durationSeconds,
    this.width,
    this.height,
    this.video = false,
    this.id,
    this.title,
    this.description,
  });

  /// Демонстрационный снимок из макета — их приложение показывает с самого
  /// начала, чтобы экран не был пустым.
  const AdMedia.demo(String asset, {bool video = false})
      : this(name: asset, asset: asset, video: video);

  /// Сетевой снимок или ролик, загруженный на бэкенд.
  const AdMedia.network(
    String url, {
    int? id,
    bool video = false,
    String? title,
    String? description,
    String? name,
  }) : this(
          name: name ?? url,
          url: url,
          video: video,
          id: id,
          title: title,
          description: description,
        );

  /// Имя файла — им подписаны ролики в «Было добавлено».
  final String name;

  /// Картинка из ассетов приложения.
  final String? asset;

  /// Картинка с бэкенда.
  final String? url;

  /// Содержимое выбранного файла. У ролика его нет: он весит десятки мегабайт
  /// и уходит на сервер потоком с диска, а не через память.
  final Uint8List? bytes;

  /// Путь к выбранному ролику на устройстве. Нужен и для обложки, и для
  /// потоковой загрузки файла.
  final String? path;

  /// Кадр-обложка ролика, снятый на устройстве: его же видит карточка «Было
  /// добавлено» и он же уходит на сервер вместе с видео.
  final Uint8List? posterBytes;

  /// Длительность и разрешение ролика — сервер их больше не вычисляет сам.
  final int? durationSeconds;
  final int? width;
  final int? height;

  final bool video;

  // Added for metadata editing
  final int? id;
  final String? title;
  final String? description;

  /// Тот же файл, но с приехавшей обложкой и метаданными.
  AdMedia withPoster(VideoPoster poster) {
    return AdMedia(
      name: name,
      asset: asset,
      url: url,
      bytes: bytes,
      path: path,
      posterBytes: poster.bytes ?? posterBytes,
      durationSeconds: poster.durationSeconds ?? durationSeconds,
      width: poster.width ?? width,
      height: poster.height ?? height,
      video: video,
      id: id,
      title: title,
      description: description,
    );
  }

  AdMedia copyWith({
    int? id,
    String? title,
    String? description,
    String? url,
  }) {
    return AdMedia(
      name: name,
      asset: asset,
      url: url ?? this.url,
      bytes: bytes,
      path: path,
      posterBytes: posterBytes,
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      video: video,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }
}

/// Откуда приложение берёт файлы. За этим стоит системный выбор из галереи и
/// камера; в тестах на это место встаёт заглушка.
abstract class MediaSource {
  /// Снимки: из галереи можно выбрать несколько, с камеры приходит один.
  Future<List<AdMedia>> photos({required bool camera});

  /// Ролик — всегда один за раз.
  Future<AdMedia?> video({required bool camera});
}

/// Галерея и камера устройства.
class DeviceMedia implements MediaSource {
  const DeviceMedia();

  @override
  Future<List<AdMedia>> photos({required bool camera}) async {
    final picker = ImagePicker();
    final List<XFile> files;
    if (camera) {
      final shot = await picker.pickImage(source: ImageSource.camera);
      files = shot == null ? const [] : [shot];
    } else {
      files = await picker.pickMultiImage();
    }
    return [for (final file in files) await _read(file, video: false)];
  }

  @override
  Future<AdMedia?> video({required bool camera}) async {
    final file = await ImagePicker().pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null) return null;

    // В браузере файла на диске нет: `path` — это blob-ссылка, потоковая
    // отправка по ней невозможна, поэтому читаем байты. На устройстве всё
    // наоборот: держим путь, чтобы стомегабайтный ролик не лежал в памяти.
    if (kIsWeb) {
      return AdMedia(name: file.name, bytes: await file.readAsBytes(), video: true);
    }

    // Кадр-обложку снимает AppState уже после добавления в список — иначе
    // ролик «не появлялся» до конца съёмки кадра.
    return AdMedia(name: file.name, path: file.path, video: true);
  }

  Future<AdMedia> _read(XFile file, {required bool video}) async =>
      AdMedia(name: file.name, bytes: await file.readAsBytes(), video: video);
}
