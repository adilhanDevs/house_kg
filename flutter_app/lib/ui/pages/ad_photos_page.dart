import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../add_media.dart';
import '../fig_controls.dart';
import '../media_tile.dart';

class AdPhotosPage extends StatefulWidget {
  const AdPhotosPage({super.key});

  @override
  State<AdPhotosPage> createState() => _AdPhotosPageState();
}

class _AdPhotosPageState extends State<AdPhotosPage> {
  bool _allowDownload = true;
  bool _isSaving = false;
  bool _initialized = false;

  Future<void> _uploadPhotosAndNext(AppState state) async {
    final slug = state.draftSlug;
    if (slug == null) {
      Navigator.pushNamed(context, Routes.adVideo);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await state.apiClient.updateDraft(slug, {
        'allow_media_download': _allowDownload,
      });

      for (int i = 0; i < state.draftGallery.length; i++) {
        final photo = state.draftGallery[i];
        if (photo.id == null && photo.bytes != null) {
          try {
            final res = await state.apiClient.uploadMedia(
              slug,
              null,
              photo.bytes,
              photo.name,
              'photo',
            );
            final mediaList = res['media'] as List<dynamic>?;
            if (mediaList != null && mediaList.isNotEmpty) {
              final newId = mediaList[0]['id'] as int?;
              if (newId != null) {
                state.draftGallery[i] = photo.copyWith(id: newId);
              }
            }
          } catch (e) {
            debugPrint('Failed to upload photo $i: $e');
          }
        }
      }
      if (mounted) {
        Navigator.pushNamed(context, Routes.adVideo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения фото: $e')),
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

    if (!_initialized) {
      _initialized = true;
      _allowDownload = state.draftAllowDownload;
    }

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
                    // Прогресс-бар сверху (50%)
                    Container(
                      height: 4.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xffe8e9f1),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: orangeColor,
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Заголовок и подзаголовок с аккуратными размерами
                    const Text(
                      'Добавить/изменить фотографии',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Text(
                      'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.',
                      style: TextStyle(
                        fontSize: 13.0,
                        height: 1.35,
                        color: Color(0xff7d7d7d),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Блок загрузки
                    GestureDetector(
                      onTap: () => addAdMedia(context, video: false),
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
                            const Icon(Icons.add_a_photo_outlined, size: 28.0, color: orangeColor),
                            const SizedBox(width: 14.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Добавить фото',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff000000),
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  state.freePhotoSlots > 0
                                      ? 'Можно до ${AppState.draftMediaLimit} фото'
                                      : 'Больше ${AppState.draftMediaLimit} фото не добавить',
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
                    const SizedBox(height: 20.0),

                    // Сетка из 6 загруженных фото
                    if (state.draftGallery.isEmpty)
                      const Text(
                        'Пока ни одной фотографии',
                        style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.draftGallery.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          final photo = state.draftGallery[index];
                          return AdMediaTile(
                            media: photo,
                            onRemove: () =>
                                state.removeMedia(state.draftGallery, photo),
                          );
                        },
                      ),
                    const SizedBox(height: 24.0),

                    // Тумблер разрешить скачивать
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Разрешить скачивать фотографии',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Color(0xff3c3c43),
                            ),
                          ),
                        ),
                        FigToggle(
                          value: _allowDownload,
                          label: 'Разрешить скачивать фотографии',
                          onChanged: (val) => setState(() => _allowDownload = val),
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
                  onPressed: _isSaving ? null : () => _uploadPhotosAndNext(state),
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
