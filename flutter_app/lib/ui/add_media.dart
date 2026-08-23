// Как продавец прикладывает файлы к объявлению: лист «Галерея / Камера»,
// сам выбор и разговор с пользователем о том, что получилось.
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/stage.dart';

/// Откуда берём файл.
enum MediaFrom { gallery, camera }

/// Спросить источник. null — пользователь закрыл лист.
Future<MediaFrom?> askMediaSource(
  BuildContext context, {
  required bool video,
}) {
  return showModalBottomSheet<MediaFrom>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _Row(
            icon: Icons.photo_library_outlined,
            label: video ? 'Выбрать ролик из галереи' : 'Выбрать из галереи',
            onTap: () => Navigator.pop(context, MediaFrom.gallery),
          ),
          _Row(
            icon: video ? Icons.videocam_outlined : Icons.photo_camera_outlined,
            label: video ? 'Снять видео' : 'Сделать снимок',
            onTap: () => Navigator.pop(context, MediaFrom.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Весь путь целиком: спросить источник, взять файлы и сказать, что вышло.
Future<void> addAdMedia(BuildContext context, {required bool video}) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final free = video ? state.freeVideoSlots : state.freePhotoSlots;
  if (free <= 0) {
    _say(messenger, 'Больше ${AppState.draftMediaLimit} файлов не добавить');
    return;
  }

  final from = await askMediaSource(context, video: video);
  if (from == null) return;

  final camera = from == MediaFrom.camera;
  final int added;
  try {
    added = video
        ? await state.addVideo(camera: camera)
        : await state.addPhotos(camera: camera);
  } catch (error) {
    // Отказ в доступе, отсутствие камеры, платформа без выбора файлов — всё
    // это приходит сюда исключением, и молчать о нём нельзя.
    _say(messenger, 'Не получилось открыть ${camera ? 'камеру' : 'галерею'}');
    debugPrint('Выбор файла не удался: $error');
    return;
  }

  if (added == 0) return;
  _say(
    messenger,
    video
        ? 'Ролик добавлен'
        : 'Добавлено ${_photos(added)} — всего ${state.draftPhotos}',
  );
}

String _photos(int count) {
  final tail = count % 100 >= 11 && count % 100 <= 14
      ? 'фотографий'
      : switch (count % 10) {
          1 => 'фотография',
          2 || 3 || 4 => 'фотографии',
          _ => 'фотографий',
        };
  return '$count $tail';
}

void _say(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        backgroundColor: FigColors.accent,
      ),
    );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: FigColors.accent),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, color: FigColors.ink),
      ),
      onTap: onTap,
    );
  }
}
