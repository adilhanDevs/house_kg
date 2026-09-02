// Плитка приложенного файла: снимок или ролик, поверх — крестик «убрать».
import 'package:flutter/material.dart';

import '../app/stage.dart';
import '../data/ad_media.dart';

/// Ключ крестика — им до него добираются тесты.
Key removeKey(AdMedia media) => ValueKey('remove:${media.name}');

class AdMediaTile extends StatelessWidget {
  const AdMediaTile({
    super.key,
    required this.media,
    required this.onRemove,
    this.size,
  });

  final AdMedia media;
  final VoidCallback onRemove;

  /// Сторона плитки. null — плитка тянется по месту в сетке.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Preview(media: media),
            if (media.video)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 32,
                  color: Color(0xe6ffffff),
                ),
              ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        tile,
        Positioned(
          right: 4,
          top: 4,
          child: Semantics(
            container: true,
            button: true,
            label: 'Убрать ${media.name}',
            child: GestureDetector(
              key: removeKey(media),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: ExcludeSemantics(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Что видно на плитке: выбранный файл, кадр ролика, снимок из макета
/// или — если ничего не вышло — имя файла.
class _Preview extends StatelessWidget {
  const _Preview({required this.media});

  final AdMedia media;

  @override
  Widget build(BuildContext context) {
    // У ролика показываем кадр, снятый при выборе файла: раньше на его месте
    // была заглушка с именем файла.
    final bytes = media.bytes ?? media.posterBytes;
    if (bytes != null) {
      // Файл может оказаться нечитаемым — тогда вместо плитки покажем имя,
      // а не красный экран.
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _Name(media: media),
      );
    }
    final url = media.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _Name(media: media),
      );
    }
    final asset = media.asset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _Name(media: media),
      );
    }
    // Кадр снять не удалось (нет плагина или файл не читается) — показываем
    // имя файла.
    return _Name(media: media);
  }
}

/// Плитка без картинки: тёмная подложка с именем файла.
class _Name extends StatelessWidget {
  const _Name({required this.media});

  final AdMedia media;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FigColors.shell,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            media.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xccffffff)),
          ),
        ),
      ),
    );
  }
}
