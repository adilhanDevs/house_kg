// Фотографии и видео, которые продавец прикладывает к объявлению.
//
// Снимок приходит одним куском байтов, а не путём: путь на телефоне, в вебе и
// на десктопе выглядит по-разному, а байты показываются везде одинаково.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Один приложенный файл.
@immutable
class AdMedia {
  const AdMedia({
    required this.name,
    this.asset,
    this.bytes,
    this.video = false,
  });

  /// Демонстрационный снимок из макета — их приложение показывает с самого
  /// начала, чтобы экран не был пустым.
  const AdMedia.demo(String asset, {bool video = false})
      : this(name: asset, asset: asset, video: video);

  /// Имя файла — им подписаны ролики в «Было добавлено».
  final String name;

  /// Картинка из ассетов приложения.
  final String? asset;

  /// Содержимое выбранного файла. У ролика его нет: кадр-обложку из видео без
  /// отдельного плеера не достать, поэтому карточка рисует заглушку.
  final Uint8List? bytes;

  final bool video;
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
    // Байты ролика не читаем: он весит десятки мегабайт, а показать его без
    // плеера всё равно нечем.
    return AdMedia(name: file.name, video: true);
  }

  Future<AdMedia> _read(XFile file, {required bool video}) async =>
      AdMedia(name: file.name, bytes: await file.readAsBytes(), video: video);
}
