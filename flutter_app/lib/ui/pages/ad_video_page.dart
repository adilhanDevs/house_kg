import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/ad_media.dart';
import '../../data/api_client.dart';
import '../add_media.dart';
import '../fig_controls.dart';

class AdVideoPage extends StatefulWidget {
  const AdVideoPage({super.key});

  @override
  State<AdVideoPage> createState() => _AdVideoPageState();
}

class _AdVideoPageState extends State<AdVideoPage> {
  bool _useInfo = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _useInfo = state.draftUseAdInfo;
  }

  Future<void> _pickAndAddVideo(AppState state) async {
    final prevCount = state.draftVideoList.length;
    await addAdMedia(context, video: true);
    if (mounted && state.draftVideoList.length > prevCount) {
      final newIndex = state.draftVideoList.length - 1;
      await _showVideoMetadataSheet(context, newIndex, state);
    }
  }

  Future<void> _showVideoMetadataSheet(
    BuildContext context,
    int index,
    AppState state,
  ) async {
    if (index < 0 || index >= state.draftVideoList.length) return;
    final video = state.draftVideoList[index];

    final titleCtrl = TextEditingController(text: video.title ?? '');
    final descCtrl = TextEditingController(text: video.description ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24.0,
            16.0,
            24.0,
            MediaQuery.of(ctx).viewInsets.bottom + 24.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: const Color(0xffe5e5ea),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'Информация о видео',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff000000),
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Укажите заголовок и краткое описание для REELS',
                  style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                ),
                const SizedBox(height: 20.0),
                TextFormField(
                  controller: titleCtrl,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Заголовок видео',
                    hintText: 'Например, обзор дома',
                    filled: true,
                    fillColor: const Color(0xfff8f8fa),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffe5e5ea)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffe5e5ea)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffea812e), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Описание видео',
                    hintText: 'Расскажите подробнее о видео...',
                    filled: true,
                    fillColor: const Color(0xfff8f8fa),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffe5e5ea)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffe5e5ea)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffea812e), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: () {
                      if (index < state.draftVideoList.length) {
                        setState(() {
                          state.draftVideoList[index] = state.draftVideoList[index].copyWith(
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                          );
                        });
                      }
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffea812e),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndNext(AppState state) async {
    setState(() => _isSaving = true);
    final apiClient = state.apiClient;
    final failures = <String>[];

    try {
      final realSlug = state.draftSlug ?? 'draft-slug';

      for (int i = 0; i < state.draftVideoList.length; i++) {
        final video = state.draftVideoList[i];
        final hasFile = (video.path != null && video.path!.isNotEmpty) ||
            (video.bytes != null && video.bytes!.isNotEmpty);
        if (video.asset != null || !hasFile) {
          continue;
        }
        int? realMediaId = video.id;

        if (realMediaId == null) {
          try {
            final fileName = video.name.toLowerCase().endsWith('.mp4') ||
                    video.name.toLowerCase().endsWith('.mov')
                ? video.name
                : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
            final uploadResponse = await apiClient.uploadMedia(
              realSlug,
              filePath: video.path,
              bytes: video.path == null ? video.bytes : null,
              filename: fileName,
              kind: 'video',
              thumbnailBytes: video.posterBytes,
              durationSeconds: video.durationSeconds,
              width: video.width,
              height: video.height,
            );
            final mediaList = uploadResponse['media'] as List?;
            if (mediaList != null && mediaList.isNotEmpty) {
              realMediaId = mediaList[0]['id'] as int?;
              if (realMediaId != null) {
                state.draftVideoList[i] = video.copyWith(id: realMediaId);
              }
            }
          } catch (e) {
            debugPrint('Video upload warning: $e');
            failures.add(_uploadErrorText(e));
          }
        }

        if (realMediaId != null) {
          try {
            await apiClient.updateMediaMetadata(
              realSlug,
              realMediaId,
              video.title,
              video.description,
            );
          } catch (e) {
            debugPrint('Metadata update warning: $e');
          }
        }
      }

      if (!mounted) return;

      if (failures.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ролик не загрузился: ${failures.first}'),
            backgroundColor: const Color(0xffd93025),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      Navigator.pushNamed(context, Routes.adPromo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const orangeColor = Color(0xffea812e);

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Прогресс-бар сверху (75%)
                    Container(
                      height: 4.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xffe8e9f1),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.75,
                        child: Container(
                          decoration: BoxDecoration(
                            color: orangeColor,
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Заголовок и подзаголовок
                    const Text(
                      'Добавьте видео обзор REELS',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Text(
                      'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.',
                      style: TextStyle(
                        fontSize: 14.0,
                        height: 1.35,
                        color: Color(0xff7d7d7d),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Блок загрузки видео
                    GestureDetector(
                      onTap: () => _pickAndAddVideo(state),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                        decoration: BoxDecoration(
                          color: const Color(0xffffffff),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 28.0, color: orangeColor),
                            const SizedBox(width: 14.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Добавить видео',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff000000),
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  state.freeVideoSlots > 0
                                      ? 'Можно до ${AppState.draftMediaLimit} роликов'
                                      : 'Больше ${AppState.draftMediaLimit} роликов не добавить',
                                  style: const TextStyle(
                                    fontSize: 12.0,
                                    color: Color(0xff7d7d7d),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Тумблер Использовать информацию из объявления
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Использовать информацию из объявления',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff85858a),
                            ),
                          ),
                        ),
                        FigToggle(
                          value: _useInfo,
                          label: 'Использовать информацию из объявления',
                          onChanged: (val) {
                            setState(() => _useInfo = val);
                            state.draftUseAdInfo = val;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    const Divider(height: 1.0, color: Color(0xffe5e5ea)),
                    const SizedBox(height: 24.0),

                    // Блок "Было добавлено"
                    const Text(
                      'Было добавлено',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    if (state.draftVideoList.isEmpty)
                      const Text(
                        'Пока ни одного ролика',
                        style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                      )
                    else
                      Wrap(
                        spacing: 16.0,
                        runSpacing: 16.0,
                        children: [
                          for (int i = 0; i < state.draftVideoList.length; i++)
                            _VideoCardItem(
                              media: state.draftVideoList[i],
                              onTap: () => _showVideoMetadataSheet(context, i, state),
                              onRemove: () {
                                state.removeMedia(
                                    state.draftVideoList, state.draftVideoList[i]);
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Кнопка Далее внизу
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveAndNext(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Далее',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCardItem extends StatelessWidget {
  final AdMedia media;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _VideoCardItem({
    required this.media,
    required this.onTap,
    required this.onRemove,
  });

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '01:04';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final durationStr = _formatDuration(media.durationSeconds);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: SizedBox(
                  width: 100.0,
                  height: 100.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _VideoPreview(media: media),
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
              ),
              Positioned(
                top: 4.0,
                right: 4.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Container(
                    width: 22.0,
                    height: 22.0,
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'REELS | $durationStr',
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: Color(0xff85858a),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.media});

  final AdMedia media;

  @override
  Widget build(BuildContext context) {
    final bytes = media.posterBytes ?? media.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _FallbackPoster(media: media),
      );
    }
    final url = media.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _FallbackPoster(media: media),
      );
    }
    final asset = media.asset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _FallbackPoster(media: media),
      );
    }
    return _FallbackPoster(media: media);
  }
}

class _FallbackPoster extends StatelessWidget {
  const _FallbackPoster({required this.media});

  final AdMedia media;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff2c2c2e),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.all(4.0),
      child: Text(
        media.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9.0, color: Color(0xccffffff)),
      ),
    );
  }
}

String _uploadErrorText(Object error) {
  if (error is ApiException) return error.message;
  if (error is NetworkException) return error.message;
  return error.toString();
}
