import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
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
                      Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        children: [
                          for (final video in state.draftVideoList)
                            AdMediaTile(
                              media: video,
                              size: 100.0,
                              onRemove: () =>
                                  state.removeMedia(state.draftVideoList, video),
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
                  onPressed: () => Navigator.pushNamed(context, Routes.adPromo),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
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
