import 'dart:io';
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/ad_media.dart';
import '../../data/api_client.dart';
import '../add_media.dart';
import '../fig_controls.dart';
import '../media_tile.dart';

class AdVideoPage extends StatefulWidget {
  const AdVideoPage({super.key});

  @override
  State<AdVideoPage> createState() => _AdVideoPageState();
}

class _AdVideoPageState extends State<AdVideoPage> {
  bool _useInfo = true;
  bool _isSaving = false;

  Future<void> _saveAndNext(AppState state) async {
    setState(() => _isSaving = true);
    final apiClient = state.apiClient;
    
    try {
      final realSlug = state.draftSlug ?? 'draft-slug';

      for (int i = 0; i < state.draftVideoList.length; i++) {
        final video = state.draftVideoList[i];
        int realMediaId;
        
        if (video.id != null) {
          realMediaId = video.id!;
        } else {
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/${video.name}');
          if (video.bytes != null) {
            await file.writeAsBytes(video.bytes!);
          } else {
            await file.writeAsString('dummy video content');
          }
          
          final uploadResponse = await apiClient.uploadMedia(realSlug, file);
          final mediaList = uploadResponse['media'] as List;
          if (mediaList.isEmpty) {
            throw Exception('Сервер не вернул загруженное медиа');
          }
          realMediaId = mediaList[0]['id'] as int;
          
          // Save the ID in the state to avoid re-uploading on next save
          state.draftVideoList[i] = video.copyWith(id: realMediaId);
        }
        
        await apiClient.updateMediaMetadata(
          realSlug, 
          realMediaId, 
          video.title, 
          video.description,
        );
      }
      
      if (mounted) {
        Navigator.pushNamed(context, Routes.adPromo);
      }
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

                    // Заголовок и подзаголовок аккуратного размера
                    const Text(
                      'Добавьте видео обзор REELS',
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

                    // Блок загрузки видео
                    GestureDetector(
                      onTap: () => addAdMedia(context, video: true),
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
                            const Icon(Icons.video_call_outlined, size: 28.0, color: orangeColor),
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
                              fontSize: 14.0,
                              color: Color(0xff3c3c43),
                            ),
                          ),
                        ),
                        FigToggle(
                          value: _useInfo,
                          label: 'Использовать информацию из объявления',
                          onChanged: (val) => setState(() => _useInfo = val),
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
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    if (state.draftVideoList.isEmpty)
                      const Text(
                        'Пока ни одного ролика',
                        style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < state.draftVideoList.length; i++) ...[
                            if (i > 0) const SizedBox(height: 24),
                            _VideoFormItem(
                              media: state.draftVideoList[i],
                              onChanged: (newMedia) {
                                setState(() {
                                  state.draftVideoList[i] = newMedia;
                                });
                              },
                              onRemove: () {
                                state.removeMedia(state.draftVideoList, state.draftVideoList[i]);
                              },
                            ),
                          ]
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
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

class _VideoFormItem extends StatefulWidget {
  final AdMedia media;
  final ValueChanged<AdMedia> onChanged;
  final VoidCallback onRemove;

  const _VideoFormItem({
    required this.media,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_VideoFormItem> createState() => _VideoFormItemState();
}

class _VideoFormItemState extends State<_VideoFormItem> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.media.title);
    _descController = TextEditingController(text: widget.media.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AdMediaTile(
              media: widget.media,
              size: 80.0,
              onRemove: widget.onRemove,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Заголовок видео',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => widget.onChanged(widget.media.copyWith(title: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Описание видео',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (val) => widget.onChanged(widget.media.copyWith(description: val)),
        ),
      ],
    );
  }
}
