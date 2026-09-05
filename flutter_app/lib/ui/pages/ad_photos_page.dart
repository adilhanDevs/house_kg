import 'package:house_kgz/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
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

  /// Сколько снимков уже ушло и сколько их всего в этой отправке. Пока здесь
  /// крутился безымянный спиннер, десять фотографий выглядели как зависший
  /// экран: пользователю не с чем было сверить, идёт что-то или нет.
  int _uploadDone = 0;
  int _uploadTotal = 0;

  Future<void> _uploadPhotosAndNext(AppState state) async {
    final slug = state.draftSlug;
    if (slug == null) {
      Navigator.pushNamed(context, Routes.adVideo);
      return;
    }

    setState(() => _isSaving = true);

    // Молчащая загрузка — та же беда, что была у роликов: снимок не уходил,
    // а экран как ни в чём не бывало вёл дальше.
    final failures = <String>[];

    try {
      await state.apiClient.updateDraft(slug, {
        'allow_media_download': _allowDownload,
      });

      // Отправляем только то, чего ещё нет на сервере: уже загруженные при
      // повторной попытке второй раз не поедут.
      final pending = <int>[
        for (int i = 0; i < state.draftGallery.length; i++)
          if (state.draftGallery[i].id == null && state.draftGallery[i].bytes != null) i,
      ];
      if (mounted) {
        setState(() {
          _uploadDone = 0;
          _uploadTotal = pending.length;
        });
      }

      for (final i in pending) {
        final photo = state.draftGallery[i];
        try {
          final res = await state.apiClient.uploadMedia(
            slug,
            bytes: photo.bytes,
            filename: photo.name,
            kind: 'photo',
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
          failures.add(_uploadErrorText(e));
        }
        if (mounted) setState(() => _uploadDone++);
      }
      if (!mounted) return;

      if (failures.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.addListingPhotoUploadError(failures.first.toString())),
            backgroundColor: const Color(0xffd93025),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      Navigator.pushNamed(context, Routes.adVideo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.addListingPhotoSaveError(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadTotal = 0;
          _uploadDone = 0;
        });
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
                    SizedBox(height: 20.0),

                    // Заголовок и подзаголовок с аккуратными размерами
                    Text(
                      context.l10n.addListingPhotosEdit,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 6.0),
                    Text(
                      context.l10n.addListingVideoDummyDesc,
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
                            SizedBox(width: 14.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.addListingAddPhoto,
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff000000),
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  state.freePhotoSlots > 0
                                      ? context.l10n.addListingMaxPhotos(AppState.draftMediaLimit.toString())
                                      : context.l10n.addListingNoMorePhotos(AppState.draftMediaLimit.toString()),
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
                    SizedBox(height: 20.0),

                    // Сетка из 6 загруженных фото
                    if (state.draftGallery.isEmpty)
                      Text(
                        context.l10n.addListingNoPhotos,
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
                        Expanded(
                          child: Text(
                            context.l10n.addListingAllowDownload,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Color(0xff3c3c43),
                            ),
                          ),
                        ),
                        FigToggle(
                          value: _allowDownload,
                          label: context.l10n.addListingAllowDownload,
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
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Text(
                              _uploadTotal > 0
                                  ? context.l10n.addListingUploading +
                                      '${_uploadDone < _uploadTotal ? _uploadDone + 1 : _uploadTotal}'
                                      ' из $_uploadTotal'
                                  : context.l10n.addListingSaving,
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          context.l10n.addListingNext,
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

/// Текст ошибки загрузки — настоящий, а не общая фраза: по «нет связи с
/// сервером» невозможно отличить обрыв сети от неподдерживаемого вызова.
String _uploadErrorText(Object error) {
  if (error is ApiException) return error.message;
  if (error is NetworkException) return error.message;
  return error.toString();
}
