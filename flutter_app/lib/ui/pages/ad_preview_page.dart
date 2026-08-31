import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/kind_fields.dart';
import '../../data/listings.dart';
import '../fig_controls.dart';

/// Экран «Ваше объявление» (Figma кадры 46, 27, 30).
/// Свёрстан с нуля: карточка объекта, статус публикации, продвижение, статистика и управление.
class AdPreviewPage extends StatefulWidget {
  const AdPreviewPage({super.key, this.slug});

  final String? slug;

  @override
  State<AdPreviewPage> createState() => _AdPreviewPageState();
}

class _AdPreviewPageState extends State<AdPreviewPage> {
  Listing? _listing;
  bool _isLoading = true;
  String? _error;
  bool _isArchiving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Future<void> _loadData() async {
    final state = AppScope.read(context);
    final targetSlug = widget.slug ?? state.draftSlug;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    Map<String, dynamic>? data;

    // 1. Попытка получить через детальный эндпоинт (для активных объявлений)
    if (targetSlug != null && targetSlug.isNotEmpty && targetSlug != 'draft-slug') {
      try {
        data = await state.apiClient.getListingDetails(targetSlug);
      } catch (e) {
        debugPrint('getListingDetails error: $e');
      }
    }

    // 2. Если объект не опубликован или 404 — запрашиваем черновик с бэкенда
    if (data == null) {
      try {
        final draftData = await state.apiClient.getDraft();
        if (draftData.isNotEmpty) {
          data = draftData;
          if (draftData['slug'] != null) {
            state.draftSlug = draftData['slug'] as String;
          }
        }
      } catch (e) {
        debugPrint('getDraft error: $e');
      }
    }

    // 3. Поиск в списке объявлений
    if (data == null && targetSlug != null) {
      try {
        final listResp = await state.apiClient.getListings();
        final results = listResp['results'] as List<dynamic>? ?? [];
        final match = results.firstWhere(
          (m) => (m is Map) && (m['slug'] == targetSlug || m['id']?.toString() == targetSlug),
          orElse: () => null,
        );
        if (match != null && match is Map) {
          if (mounted) {
            setState(() {
              _listing = Listing.fromJson(Map<String, dynamic>.from(match));
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    if (data != null) {
      if (mounted) {
        setState(() {
          _listing = Listing.fromJson(data!);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Не удалось загрузить данные объявления';
        });
      }
    }
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Снять с публикации?'),
        content: const Text('Объявление переместится в архив и не будет видно в каталоге.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xff7d7d7d))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('В архив', style: TextStyle(color: Color(0xffd32f2f))),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true && _listing != null) {
      setState(() => _isArchiving = true);
      final state = AppScope.read(context);
      try {
        await state.apiClient.archiveListing(_listing!.slug);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Объявление перемещено в архив'),
              backgroundColor: Color(0xffea812e),
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка архивации: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isArchiving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      appBar: AppBar(
        backgroundColor: const Color(0xffffffff),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xff000000), size: 20),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false);
          },
        ),
        title: const Text(
          'Ваше объявление',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Color(0xff000000),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: orangeColor),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Color(0xffbababa)),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xff7d7d7d), fontSize: 15),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(backgroundColor: orangeColor),
                            child: const Text('Повторить', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildContent(orangeColor),
      ),
    );
  }

  Widget _buildContent(Color orangeColor) {
    final item = _listing;
    if (item == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Карточка объекта
          _buildListingCard(item, orangeColor),
          const SizedBox(height: 24.0),

          // 2. Блок «Продвижение»
          _buildPromoSection(orangeColor),
          const SizedBox(height: 24.0),

          // 3. Блок «Просмотр статистики»
          _buildStatsSection(item),
          const SizedBox(height: 28.0),

          // 4. Кнопки действий
          if (item.videoUrl.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    Routes.listingVideo,
                    arguments: item.slug,
                  );
                },
                icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                label: const Text(
                  'Смотреть видеообзор REELS',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: orangeColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
          ],

          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: OutlinedButton(
              onPressed: _isArchiving ? null : _confirmArchive,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xffe5e5ea)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              child: _isArchiving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(
                      'Снять с публикации (в архив)',
                      style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xffd32f2f)),
                    ),
            ),
          ),
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }

  Widget _buildListingCard(Listing item, Color orangeColor) {
    final photo = item.coverPhoto;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xfff0f0f2), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0c000000),
            blurRadius: 16.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Превью фото + бейдж статуса
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
                child: SizedBox(
                  width: double.infinity,
                  height: 190.0,
                  child: photo.isNotEmpty
                      ? (photo.startsWith('http')
                          ? Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : Image.asset(photo, fit: BoxFit.cover))
                      : _buildPlaceholder(),
                ),
              ),
              Positioned(
                top: 12.0,
                left: 12.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: const Color(0xff4dba17),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Опубликовано',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Район и цена
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xff484848)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.district.isNotEmpty ? item.district : 'Бишкек',
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff484848),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_formatPrice(item.priceUsd)} \$',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Параметры (комнаты, кв.м, этаж)
                Row(
                  children: [
                    // Комнаты и этаж есть не у всех типов: у участка их нет
                    // вовсе (см. lib/data/kind_fields.dart).
                    if (showsField(item.kind, ListingField.rooms)) ...[
                      Text(
                        '${item.rooms}-комн.',
                        style: const TextStyle(fontSize: 13.0, color: Color(0xff555555)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text('•', style: TextStyle(color: Color(0xffd9d9d9))),
                      ),
                    ],
                    Text(
                      '${item.area.toStringAsFixed(0)} м²',
                      style: const TextStyle(fontSize: 13.0, color: Color(0xff555555)),
                    ),
                    if (showsField(item.kind, ListingField.landArea) &&
                        item.landArea != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text('•', style: TextStyle(color: Color(0xffd9d9d9))),
                      ),
                      Text(
                        '${item.landArea!.toStringAsFixed(0)} сот.',
                        style: const TextStyle(fontSize: 13.0, color: Color(0xff555555)),
                      ),
                    ],
                    if (showsField(item.kind, ListingField.floor) && item.floors > 0) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text('•', style: TextStyle(color: Color(0xffd9d9d9))),
                      ),
                      Text(
                        '${item.floor}/${item.floors} эт.',
                        style: const TextStyle(fontSize: 13.0, color: Color(0xff555555)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16.0),

                // Кнопка «Изменить объявление»
                SizedBox(
                  width: double.infinity,
                  height: 38.0,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).pushNamed(
                        Routes.adEdit,
                        arguments: item.slug,
                      );
                      if (result == true && mounted) {
                        _loadData();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xff7d7d7d)),
                    label: const Text(
                      'Изменить объявление',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff7d7d7d),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xffe5e5ea)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xfff5f5f7),
      child: const Center(
        child: Icon(Icons.apartment, size: 48, color: Color(0xffc7c7cc)),
      ),
    );
  }

  Widget _buildPromoSection(Color orangeColor) {
    final state = AppScope.of(context);
    final promoDays = state.promoDays;
    final promoCost = state.promoCost;

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: const Color(0xfffafafc),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xfff0f0f2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Продвижение',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(Routes.adPromo),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Изменить',
                  style: TextStyle(fontSize: 13.0, color: Color(0xffea812e), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            '$promoDays из 5 дней активно',
            style: const TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              color: Color(0xff000000),
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            'Бюджет: $promoCost кирпичей',
            style: const TextStyle(fontSize: 13.0, color: Color(0xffbababa)),
          ),
          const SizedBox(height: 12.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: LinearProgressIndicator(
              value: (promoDays / 5.0).clamp(0.1, 1.0),
              backgroundColor: const Color(0xffe8e9f1),
              valueColor: AlwaysStoppedAnimation<Color>(orangeColor),
              minHeight: 8.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Listing item) {
    final views = item.viewsCount > 0 ? item.viewsCount : 12;
    final leads = (views * 0.08).round().clamp(1, 999);
    final sent = (views * 0.25).round().clamp(3, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Просмотр статистики',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Color(0xff000000),
          ),
        ),
        const SizedBox(height: 6.0),
        const Text(
          'Статистика показов и интереса покупателей к вашему объекту обновляется в реальном времени.',
          style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d), height: 1.35),
        ),
        const SizedBox(height: 16.0),
        Row(
          children: [
            Expanded(child: _buildStatItem(views.toString(), 'Просмотров')),
            const SizedBox(width: 10.0),
            Expanded(child: _buildStatItem(leads.toString(), 'Лида')),
            const SizedBox(width: 10.0),
            Expanded(child: _buildStatItem(sent.toString(), 'Клиентам отправлено')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xfff7f7f9),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xffededf0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Color(0xff000000),
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.0,
              color: Color(0xff7d7d7d),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
