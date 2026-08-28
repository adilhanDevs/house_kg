// «Видеообзор» — просмотр видеоматериалов объекта в интерфейсе полноэкранного плеера (Instagram Reels style).
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';

/// Затемнение поверх видео — аналогично просмотрщику фото.
const LinearGradient _shade = LinearGradient(
  begin: Alignment(0.018, 1.004),
  end: Alignment(-0.018, -1.004),
  colors: [Color(0x26000000), Color(0x00666666)],
  stops: [0.241, 0.945],
);

const double _chevronTop = 397;
const double _sideGap = 25;
const double _chevronSize = 48;

const Color _white = Color(0xf2ffffff);
const Color _heartInk = Color(0xccea812e);

/// Ролик для конкретного объявления
class _SubVideo {
  final String asset;
  final String title;
  final String description;

  const _SubVideo({
    required this.asset,
    required this.title,
    required this.description,
  });
}

/// Объявление с набором из 2 уникальных видеороликов
class _ListingFeedItem {
  final Listing listing;
  final List<_SubVideo> videos;

  const _ListingFeedItem({
    required this.listing,
    required this.videos,
  });
}

/// У каждого из 5 объявлений СВОЁ УНИКАЛЬНОЕ первое видео
final List<_ListingFeedItem> kVideoListings = [
  _ListingFeedItem(
    listing: listingById('technopark'),
    videos: const [
      _SubVideo(
        asset: 'assets/videos_obzor/video_1.mp4',
        title: 'Обзор квартиры — Технопарк',
        description: 'Просторная 3-комнатная квартира с дизайнерским ремонтом.',
      ),
      _SubVideo(
        asset: 'assets/videos_obzor/video_2.mp4',
        title: 'Обзор территории — Технопарк',
        description: 'Тихий и удобный район, парковочные места и зелёный двор.',
      ),
    ],
  ),
  _ListingFeedItem(
    listing: listingById('asanbay'),
    videos: const [
      _SubVideo(
        asset: 'assets/videos_obzor/video_2.mp4',
        title: 'Обзор квартиры — Асанбай',
        description: '🏡 Сатылат 4 бөлмөлүү батир — 102 м². Району: Аю-Грант.',
      ),
      _SubVideo(
        asset: 'assets/videos_obzor/video_3.mp4',
        title: 'Планировка и интерьер — Асанбай',
        description: 'Кең жана ыңгайлуу 4 бөлмөлүү батир с качественной отделкой.',
      ),
    ],
  ),
  _ListingFeedItem(
    listing: listingById('kok-jar'),
    videos: const [
      _SubVideo(
        asset: 'assets/videos_obzor/video_3.mp4',
        title: 'Обзор дома — Кок-Жар',
        description: '🏡 Собственный дом без первоначального взноса!',
      ),
      _SubVideo(
        asset: 'assets/videos_obzor/video_4.mp4',
        title: 'Участок и сад — Кок-Жар',
        description: 'Ежемесячный платеж всего от 48 000 сом. Это реально!',
      ),
    ],
  ),
  _ListingFeedItem(
    listing: listingById('djal'),
    videos: const [
      _SubVideo(
        asset: 'assets/videos_obzor/video_4.mp4',
        title: 'Обзор объекта — 7-микрорайон',
        description: '🏡 7-кичи райондо 3 бөлмөлүү батир сатылат. 105-серия.',
      ),
      _SubVideo(
        asset: 'assets/videos_obzor/video_5.mp4',
        title: 'Инфраструктура — 7-микрорайон',
        description: 'Рядом сквер, магазины и удобная транспортная развязка.',
      ),
    ],
  ),
  _ListingFeedItem(
    listing: listingById('center'),
    videos: const [
      _SubVideo(
        asset: 'assets/videos_obzor/video_5.mp4',
        title: 'Срочно продаётся дом — Центр',
        description: '🚨 Срочно продаётся дом! 🏡📍 Рядом с жилмассивом Алтын Ордо.',
      ),
      _SubVideo(
        asset: 'assets/videos_obzor/video_1.mp4',
        title: 'Прилегающая территория — Центр',
        description: 'Отличный вариант для комфортного проживания семьи.',
      ),
    ],
  ),
];

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.id});

  final String id;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late final PageController _verticalPages;
  final Map<int, PageController> _horizontalControllers = {};
  int _listingIndex = 0;
  final Map<int, int> _subVideoIndices = {};
  bool _isMuted = false;

  final GlobalKey<_VideoPlayerItemState> _playerKey = GlobalKey<_VideoPlayerItemState>();

  @override
  void initState() {
    super.initState();
    final initialIdx = kVideoListings.indexWhere((v) => v.listing.id == widget.id);
    if (initialIdx != -1) {
      _listingIndex = initialIdx;
      _verticalPages = PageController(initialPage: initialIdx);
    } else {
      _verticalPages = PageController();
    }
  }

  PageController _getHorizontalController(int listingIdx) {
    return _horizontalControllers.putIfAbsent(
      listingIdx,
      () => PageController(initialPage: _getSubIndex(listingIdx)),
    );
  }

  @override
  void dispose() {
    _verticalPages.dispose();
    for (final c in _horizontalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _getSubIndex(int listingIdx) => _subVideoIndices[listingIdx] ?? 0;

  void _goSubVideo(int step) {
    final currentListing = kVideoListings[_listingIndex];
    if (currentListing.videos.isEmpty) return;
    final currentSubIdx = _getSubIndex(_listingIndex);
    final count = currentListing.videos.length;
    final nextSubIdx = (currentSubIdx + step + count) % count;

    _subVideoIndices[_listingIndex] = nextSubIdx;
    final ctrl = _getHorizontalController(_listingIndex);
    if (ctrl.hasClients) {
      ctrl.animateToPage(
        nextSubIdx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() {});
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
  }

  void _togglePlayPause() {
    final playerState = _playerKey.currentState;
    if (playerState != null) {
      playerState.togglePlayPause();
    }
  }

  void _stopAndNavigate(VoidCallback action) {
    _playerKey.currentState?.pauseVideo();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currentListingItem = kVideoListings[_listingIndex];
    final listing = currentListingItem.listing;
    final subIndex = _getSubIndex(_listingIndex);
    final currentSubVideo = currentListingItem.videos[subIndex % currentListingItem.videos.length];
    final favourite = state.isFavourite(listing.id);

    return Scaffold(
      backgroundColor: const Color(0xff1c1b19),
      body: Stack(
        children: [
          // Вертикальный скролл между РАЗНЫМИ объявлениями + Горизонтальный скролл между видео объявления
          Positioned.fill(
            child: PageView.builder(
              controller: _verticalPages,
              scrollDirection: Axis.vertical,
              itemCount: kVideoListings.length,
              onPageChanged: (i) {
                setState(() {
                  _listingIndex = i;
                });
              },
              itemBuilder: (context, i) {
                final listingItem = kVideoListings[i];
                final horizontalCtrl = _getHorizontalController(i);

                return PageView.builder(
                  controller: horizontalCtrl,
                  scrollDirection: Axis.horizontal,
                  itemCount: listingItem.videos.length,
                  onPageChanged: (subIdx) {
                    setState(() {
                      _subVideoIndices[i] = subIdx;
                    });
                  },
                  itemBuilder: (context, subIdx) {
                    final video = listingItem.videos[subIdx];
                    final isActive = (i == _listingIndex) && (subIdx == _getSubIndex(i));

                    return _VideoPlayerItem(
                      key: ValueKey('v_item_${listingItem.listing.id}_$subIdx'),
                      asset: video.asset,
                      posterPhoto: listingItem.listing.photo,
                      isActive: isActive,
                      isMuted: _isMuted,
                      onTap: _togglePlayPause,
                    );
                  },
                );
              },
            ),
          ),

          // Градиенты затемнения кадра
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: _shade)),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xcc000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),

          // Интерфейс поверх видео
          _Chrome(
            children: [
              // Описание и информация об объекте снизу
              _About(
                listing: listing,
                videoTitle: currentSubVideo.title,
                videoDescription: currentSubVideo.description,
                onAgentTap: () {
                  _stopAndNavigate(() {
                    Navigator.of(context).pushNamed(Routes.agentListings);
                  });
                },
                onDetailsTap: () {
                  _stopAndNavigate(() {
                    Navigator.of(context).pushNamed(
                      Routes.listing,
                      arguments: ListingArgs(listing.id),
                    );
                  });
                },
              ),

              // Верхняя панель: Заголовок, звук, скачивание и избранное
              Positioned(
                left: 25,
                right: 15,
                top: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FigText(
                        noWrap: true,
                        ellipsis: true,
                        span: TextSpan(
                          text: 'Видеообзор',
                          style: figStyle(
                            fontSize: 21.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.0,
                            letterSpacing: -0.21,
                            color: const Color(0xffffffff),
                          ),
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 6,
                        children: [
                          _MuteButton(isMuted: _isMuted, onTap: _toggleMute),
                          const _DownloadVideoPill(),
                          _HeartButton(
                            filled: favourite,
                            onTap: () => state.toggleFavourite(listing.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Кнопка переключения на ПРЕДЫДУЩЕЕ видео (Стрелка влево)
              Positioned(
                left: _sideGap,
                top: _chevronTop - (_chevronSize - 18) / 2,
                width: _chevronSize,
                height: _chevronSize,
                child: Semantics(
                  button: true,
                  label: 'Предыдущее видео',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _goSubVideo(-1),
                    child: Center(
                      child: Container(
                        width: _chevronSize,
                        height: _chevronSize,
                        decoration: const BoxDecoration(
                          color: Color(0x33000000),
                          shape: BoxShape.circle,
                        ),
                        child: Transform.rotate(
                          angle: pi,
                          child: const Center(
                            child: FigSvg(
                              width: 10.0,
                              height: 18.0,
                              vbWidth: 10.0,
                              vbHeight: 18.0,
                              shapes: [FigShape(d: _chevron, fill: Color(0xffffffff), evenOdd: true)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Кнопка переключения на СЛЕДУЮЩЕЕ видео (Стрелка вправо)
              Positioned(
                right: _sideGap,
                top: _chevronTop - (_chevronSize - 18) / 2,
                width: _chevronSize,
                height: _chevronSize,
                child: Semantics(
                  button: true,
                  label: 'Следующее видео',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _goSubVideo(1),
                    child: Center(
                      child: Container(
                        width: _chevronSize,
                        height: _chevronSize,
                        decoration: const BoxDecoration(
                          color: Color(0x33000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: FigSvg(
                            width: 10.0,
                            height: 18.0,
                            vbWidth: 10.0,
                            vbHeight: 18.0,
                            shapes: [FigShape(d: _chevron, fill: Color(0xffffffff), evenOdd: true)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Точки-индикаторы 2 роликов текущего объявления (снизу по центру)
              Positioned(
                left: 0,
                right: 0,
                bottom: 25.0,
                child: IgnorePointer(
                  child: Center(
                    child: FigBox(
                      color: const Color(0x4dffffff),
                      radius: 20.0,
                      blur: 27.0,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(currentListingItem.videos.length, (i) {
                          final isActive = i == subIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: isActive ? 14.0 : 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.0),
                              color: isActive ? const Color(0xffea812e) : const Color(0x99ffffff),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),

              // Кнопка [ 📰 Вернуться ] слева снизу
              Positioned(
                left: 25.0,
                bottom: 25.0,
                child: Semantics(
                  button: true,
                  label: 'Вернуться',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _stopAndNavigate(() {
                        Navigator.of(context).maybePop();
                      });
                    },
                    child: ExcludeSemantics(
                      child: FigBox(
                        color: const Color(0x4dffffff),
                        radius: 20.0,
                        blur: 27.0,
                        padding: const EdgeInsets.fromLTRB(12.0, 6.0, 14.0, 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 6.0,
                          children: [
                            const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.667,
                                    top: 1.333,
                                    child: FigSvg(
                                      width: 14.135,
                                      height: 13.327,
                                      vbWidth: 14.135,
                                      vbHeight: 13.327,
                                      shapes: [FigShape(d: _backIcon, fill: _white)],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FigText(
                              noWrap: true,
                              span: TextSpan(
                                text: 'Вернуться',
                                style: figStyle(
                                  fontSize: 13.0,
                                  family: FigFont.display,
                                  weight: 500,
                                  height: 1.0,
                                  color: _white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerItem extends StatefulWidget {
  const _VideoPlayerItem({
    super.key,
    required this.asset,
    required this.posterPhoto,
    required this.isActive,
    required this.isMuted,
    required this.onTap,
    this.videoItem,
  });

  final String asset;
  final String posterPhoto;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onTap;
  final dynamic videoItem;

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;

  bool get isPlaying => _isPlaying;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    VideoPlayerController controller;
    try {
      if (kIsWeb) {
        final uri = Uri.base.resolve('assets/${widget.asset}');
        controller = VideoPlayerController.networkUrl(uri);
      } else {
        controller = VideoPlayerController.asset(widget.asset);
      }
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      await controller.seekTo(Duration.zero);
      
      controller.addListener(_onControllerUpdate);

      setState(() {
        _isInitialized = true;
      });

      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

      if (widget.isActive && isCurrentRoute) {
        try {
          await controller.play();
          if (mounted) setState(() => _isPlaying = true);
        } catch (e) {
          debugPrint('Autoplay error (unmuted fallback): $e');
          await controller.setVolume(0.0);
          await controller.play();
          if (mounted) setState(() => _isPlaying = true);
        }
      }
    } catch (e) {
      debugPrint('Primary controller failed ($e), trying fallback...');
      try {
        final fallbackController = VideoPlayerController.asset(widget.asset);
        _controller = fallbackController;
        await fallbackController.initialize();
        if (!mounted) return;
        await fallbackController.setLooping(true);
        await fallbackController.setVolume(widget.isMuted ? 0.0 : 1.0);
        fallbackController.addListener(_onControllerUpdate);
        setState(() {
          _isInitialized = true;
        });
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (widget.isActive && isCurrentRoute) {
          await fallbackController.play();
          if (mounted) setState(() => _isPlaying = true);
        }
      } catch (err) {
        debugPrint('Video initialization failed completely: $err');
      }
    }
  }

  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    final isPlaying = _controller!.value.isPlaying;
    if (_isPlaying != isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller != null) {
          final currentPlaying = _controller!.value.isPlaying;
          if (_isPlaying != currentPlaying) {
            setState(() => _isPlaying = currentPlaying);
          }
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) {
      pauseVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_isInitialized) return;

    if (oldWidget.asset != widget.asset) {
      _controller?.removeListener(_onControllerUpdate);
      _controller?.dispose();
      _isInitialized = false;
      _initController();
      return;
    }

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive && isCurrentRoute) {
        _controller!.play();
      } else {
        pauseVideo();
      }
    }

    if (oldWidget.isMuted != widget.isMuted) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  @override
  void deactivate() {
    _controller?.pause();
    _controller?.setVolume(0.0);
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      pauseVideo();
    } else {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  void pauseVideo() {
    if (_controller != null) {
      try {
        _controller!.pause();
        _controller!.setVolume(0.0);
      } catch (_) {}
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isPlaying) {
            setState(() => _isPlaying = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            Image.asset(
              widget.posterPhoto,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) =>
                  const ColoredBox(color: Color(0xff1c1b19)),
            ),
          if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xffea812e),
              ),
            ),
          // Показываем иконку Плей по центру только если видео стоит на паузе
          if (_isInitialized && !_isPlaying)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x99ffffff), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 38,
                    color: Color(0xffffffff),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onTap});

  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isMuted ? 'Включить звук' : 'Выключить звук',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FigBox(
          color: const Color(0x4dffffff),
          radius: 20.0,
          blur: 27.0,
          padding: const EdgeInsets.fromLTRB(10.0, 3.0, 10.0, 5.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 4.0,
            children: [
              Icon(
                isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                size: 14,
                color: _white,
              ),
              FigText(
                noWrap: true,
                span: TextSpan(
                  text: isMuted ? 'Звук выкл' : 'Звук вкл',
                  style: figStyle(
                    fontSize: 10.0,
                    family: FigFont.display,
                    weight: 500,
                    height: 1.0,
                    color: _white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomSafe = bottomSafeInset(context);

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafe),
        child: MediaQuery(
          data: media.copyWith(textScaler: TextScaler.noScaling),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxHeight / kDesignHeight;
              return FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: constraints.maxWidth / scale,
                  height: kDesignHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: children,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About({
    required this.listing,
    required this.videoTitle,
    required this.videoDescription,
    required this.onAgentTap,
    required this.onDetailsTap,
  });

  final Listing listing;
  final String videoTitle;
  final String videoDescription;
  final VoidCallback onAgentTap;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 25,
      right: 25,
      bottom: 85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: listing.agent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAgentTap,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: _white),
                      const SizedBox(width: 8),
                      FigText(
                        noWrap: true,
                        span: TextSpan(
                          text: listing.agent,
                          style: figStyle(
                            fontSize: 15.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.0,
                            color: const Color(0xffffffff),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: _white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDetailsTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  videoTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xffffffff),
                  ),
                ),
                const SizedBox(height: 4),
                FigText(
                  ellipsis: true,
                  span: TextSpan(
                    text: videoDescription,
                    style: figStyle(
                      fontSize: 13.0,
                      family: FigFont.display,
                      weight: 400,
                      height: 1.3,
                      color: const Color(0xccffffff),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FigText(
                        noWrap: true,
                        span: TextSpan(
                          text: listing.price,
                          style: figStyle(
                            fontSize: 21.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.0,
                            letterSpacing: -0.21,
                            color: const Color(0xffffffff),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Specs(listing: listing),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 14, color: _white),
                          const SizedBox(width: 4),
                          FigText(
                            noWrap: true,
                            span: TextSpan(
                              text: listing.district,
                              style: figStyle(
                                fontSize: 13.0,
                                family: FigFont.display,
                                weight: 600,
                                height: 1.0,
                                letterSpacing: -0.13,
                                color: _white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Specs extends StatelessWidget {
  const _Specs({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final style = figStyle(
      fontSize: 13.0,
      family: FigFont.display,
      weight: 600,
      height: 1.0,
      letterSpacing: -0.13,
      color: _white,
    );

    final String rooms = (listing.roomsLabel.isNotEmpty && !listing.isPlot)
        ? listing.roomsLabel
        : '3-комн.';
    final String area = listing.areaLabel;
    final String floor = (listing.floorLong.isNotEmpty && !listing.isPlot)
        ? listing.floorLong
        : '8 этаж';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FigText(noWrap: true, span: TextSpan(text: rooms, style: style)),
        const _Dot(),
        FigText(
          span: TextSpan(
            style: style,
            children: [
              TextSpan(text: area, style: style),
              figSuper('2', figStyle(fontSize: 9.36, color: _white), 13.0),
            ],
          ),
        ),
        const _Dot(),
        FigText(noWrap: true, span: TextSpan(text: floor, style: style)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: FigBox(width: 4, height: 4, radius: 2, color: Color(0x99ffffff)),
      );
}

class _DownloadVideoPill extends StatelessWidget {
  const _DownloadVideoPill();

  @override
  Widget build(BuildContext context) {
    return FigBox(
      color: const Color(0x4dffffff),
      radius: 20.0,
      blur: 27.0,
      padding: const EdgeInsets.fromLTRB(10.0, 3.0, 10.0, 5.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 4.0,
        children: [
          const Icon(Icons.videocam_outlined, size: 14, color: _white),
          FigText(
            noWrap: true,
            span: TextSpan(
              text: 'Скачать видео',
              style: figStyle(
                fontSize: 10.0,
                family: FigFont.display,
                weight: 500,
                height: 1.0,
                color: _white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.filled, required this.onTap});

  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: filled ? 'Убрать из избранного' : 'В избранное',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FigBox(
          width: 24.0,
          height: 24.0,
          radius: 12.0,
          color: const Color(0xffffffff),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 5.823,
                top: 6.864,
                child: FigSvg(
                  width: 12.127,
                  height: 10.627,
                  vbWidth: 12.127,
                  vbHeight: 10.627,
                  shapes: [FigShape(d: filled ? _heartFilled : _heart, fill: _heartInk)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final String _heartFilled = _heart.substring(0, _heart.indexOf(' M 0.983'));

const String _backIcon =
    'M 0 11.45 C 0 12.687 0.615 13.327 1.877 13.327 L 12.183 13.327 C 13.489 13.327 14.135 12.687 14.135 11.406 L 14.135 1.927 C 14.135 0.646 13.489 0 12.183 0 L 4.693 0 C 3.394 0 2.741 0.646 2.741 1.927 L 1.256 4.892 C 0.466 4.892 0 5.321 0 6.061 L 0 11.45 Z M 1.001 11.45 L 1.001 6.253 C 1.001 6.023 1.138 5.893 1.368 5.893 L 2.741 5.893 L 2.741 11.45 C 2.741 11.966 2.362 12.326 1.877 12.326 C 1.386 12.326 1.001 11.947 1.001 11.45 Z M 3.531 12.326 C 3.667 12.059 3.742 11.748 3.742 11.388 L 3.742 1.983 C 3.742 1.336 4.09 1.001 4.712 1.001 L 12.165 1.001 C 12.786 1.001 13.134 1.336 13.134 1.983 L 13.134 11.35 C 13.134 11.997 12.786 12.326 12.165 12.326 L 3.531 12.326 Z M 5.358 3.705 L 11.531 3.705 C 11.748 3.705 11.916 3.531 11.916 3.313 C 11.916 3.102 11.748 2.94 11.531 2.94 L 5.358 2.94 C 5.134 2.94 4.967 3.102 4.967 3.313 C 4.967 3.531 5.134 3.705 5.358 3.705 Z M 5.358 5.893 L 11.531 5.893 C 11.748 5.893 11.916 5.725 11.916 5.514 C 11.916 5.296 11.748 5.128 11.531 5.128 L 5.358 5.128 C 5.134 5.128 4.967 5.296 4.967 5.514 C 4.967 5.725 5.134 5.893 5.358 5.893 Z M 5.725 10.325 L 7.335 10.325 C 7.807 10.325 8.093 10.039 8.093 9.566 L 8.093 8.087 C 8.093 7.608 7.807 7.322 7.335 7.322 L 5.725 7.322 C 5.246 7.322 4.96 7.608 4.96 8.087 L 4.96 9.566 C 4.96 10.039 5.246 10.325 5.725 10.325 Z M 9.212 8.087 L 11.524 8.087 C 11.748 8.087 11.91 7.925 11.91 7.714 C 11.91 7.49 11.748 7.322 11.524 7.322 L 9.212 7.322 C 8.988 7.322 8.827 7.49 8.827 7.714 C 8.827 7.925 8.988 8.087 9.212 8.087 Z M 9.212 10.325 L 11.524 10.325 C 11.748 10.325 11.91 10.163 11.91 9.952 C 11.91 9.734 11.748 9.56 11.524 9.56 C 8.988 9.56 8.827 9.734 8.827 9.952 C 8.827 10.163 8.988 10.325 9.212 10.325 Z';

const String _chevron =
    'M 0.418 0.439 C -0.139 1.025 -0.139 1.975 0.418 2.561 L 6.551 9 L 0.418 15.439 C -0.139 16.025 -0.139 16.975 0.418 17.561 C 0.976 18.146 1.881 18.146 2.439 17.561 L 9.582 10.061 C 10.139 9.475 10.139 8.525 9.582 7.939 L 2.439 0.439 C 1.881 -0.146 0.976 -0.146 0.418 0.439 Z';

const String _heart =
    'M 0 3.496 C 0 5.962 2.18 8.387 5.624 10.471 C 5.752 10.546 5.935 10.627 6.064 10.627 C 6.192 10.627 6.375 10.546 6.509 10.471 C 9.947 8.387 12.127 5.962 12.127 3.496 C 12.127 1.447 10.643 0 8.665 0 C 7.535 0 6.619 0.509 6.064 1.291 C 5.52 0.515 4.592 0 3.462 0 C 1.484 0 0 1.447 0 3.496 Z M 0.983 3.496 C 0.983 1.956 2.033 0.932 3.45 0.932 C 4.598 0.932 5.258 1.793 6.294 2.438 C 6.477 2.696 6.593 2.767 6.756 2.767 C 6.92 2.767 7.022 2.69 7.219 2.438 C 6.9 1.621 7.535 0.932 8.677 0.932 C 10.094 0.932 11.144 1.956 11.144 3.496 C 11.144 5.649 8.744 7.971 6.192 9.58 C 6.131 9.62 6.088 9.649 6.064 9.649 C 6.039 9.649 5.996 9.62 5.941 9.58 C 3.383 7.971 0.983 5.649 0.983 3.496 Z';
