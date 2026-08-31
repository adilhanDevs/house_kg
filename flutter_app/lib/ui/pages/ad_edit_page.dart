import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/ad_media.dart';
import '../../data/api_client.dart';
import '../../data/kind_fields.dart';
import '../../data/listing_payload.dart';
import '../../data/listings.dart';

class AdEditPage extends StatefulWidget {
  const AdEditPage({
    super.key,
    this.slug,
    this.media = const DeviceMedia(),
  });

  final String? slug;
  final MediaSource media;

  @override
  State<AdEditPage> createState() => _AdEditPageState();
}

class _AdEditPageState extends State<AdEditPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String _slug = '';

  // Text Controllers
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();
  final _priceController = TextEditingController();
  final _floorController = TextEditingController();
  final _floorsController = TextEditingController();
  final _builderController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Room area breakdown
  final _kitchenAreaController = TextEditingController();
  final _livingAreaController = TextEditingController();
  final _hallAreaController = TextEditingController();
  final _bedroomAreaController = TextEditingController();
  final _bedroom2AreaController = TextEditingController();
  final _bathroomAreaController = TextEditingController();
  final _balconyAreaController = TextEditingController();

  // Selection states
  String _selectedDistrict = 'asanbay';
  String _selectedDistrictName = 'Асанбай';
  int _selectedRooms = 3;
  String _selectedSeries = '106';
  /// Тип объекта приходит с сервера: от него зависит, какие поля вообще
  /// имеет смысл отправлять (см. lib/data/kind_fields.dart).
  PropertyKind _kind = PropertyKind.apartment;

  String _selectedCondition = 'good';
  String _selectedFurniture = 'full';
  String _selectedHeating = 'central';
  bool _hasGas = true;
  bool _mortgageReady = true;
  bool _exchangePossible = false;

  // Media
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _videos = [];
  final List<dynamic> _newPhotoFiles = [];
  final List<dynamic> _newVideoFiles = [];

  static const List<Map<String, String>> _districts = [
    {'slug': 'asanbay', 'name': 'Асанбай'},
    {'slug': 'center', 'name': 'Центр'},
    {'slug': 'yuzhnye-vorota', 'name': 'Южные ворота'},
    {'slug': 'technopark', 'name': 'Технопарк'},
    {'slug': 'lenin', 'name': 'Ленин'},
    {'slug': 'djal', 'name': 'Джал'},
    {'slug': 'tunguch', 'name': 'Тунгуч'},
    {'slug': 'vostok-5', 'name': 'Восток-5'},
    {'slug': 'alamedin-1', 'name': 'Аламедин-1'},
    {'slug': 'kyzyl-asker', 'name': 'Кызыл-Аскер'},
    {'slug': 'pishpek', 'name': 'Пишпек'},
  ];

  static const List<Map<String, String>> _seriesList = [
    {'code': '104', 'name': '104 серия'},
    {'code': '105', 'name': '105 серия'},
    {'code': '106', 'name': '106 серия'},
    {'code': '108', 'name': '108 серия'},
    {'code': 'elita', 'name': 'Элитка'},
    {'code': 'individual', 'name': 'Индивидуалка'},
    {'code': 'khrushchev', 'name': 'Хрущевка'},
    {'code': 'stalin', 'name': 'Сталинка'},
    {'code': 'penthouse', 'name': 'Пентхаус'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadListing();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    _floorController.dispose();
    _floorsController.dispose();
    _builderController.dispose();
    _descriptionController.dispose();
    _kitchenAreaController.dispose();
    _livingAreaController.dispose();
    _hallAreaController.dispose();
    _bedroomAreaController.dispose();
    _bedroom2AreaController.dispose();
    _bathroomAreaController.dispose();
    _balconyAreaController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final state = AppScope.read(context);
    _slug = widget.slug ?? state.draftSlug ?? 'draft-slug';

    try {
      Map<String, dynamic>? data;
      try {
        data = await state.apiClient.getListingDetails(_slug);
      } catch (_) {
        try {
          data = await state.apiClient.getDraft();
        } catch (_) {}
      }

      if (data != null) {
        _populateFields(data);
      } else {
        // Fallback from default listings mock
        final item = kListings.firstWhere((l) => l.slug == _slug, orElse: () => kListings.first);
        _populateFromItem(item);
      }
    } catch (e) {
      _error = 'Не удалось загрузить данные объявления: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _kind = PropertyKind.values.firstWhere(
      (k) => propertyKindCode(k) == data['kind'],
      orElse: () => PropertyKind.apartment,
    );
    _addressController.text = (data['address'] ?? '').toString();
    final rawArea = data['area'];
    _areaController.text = rawArea is num ? (rawArea % 1 == 0 ? rawArea.toInt().toString() : rawArea.toString()) : (rawArea ?? '').toString();
    _priceController.text = (data['price'] ?? data['price_usd'] ?? '').toString();
    _floorController.text = (data['floor'] ?? '').toString();
    _floorsController.text = (data['floors'] ?? '').toString();
    _builderController.text = (data['builder'] is Map ? data['builder']['name'] : data['builder'] ?? '').toString();
    _descriptionController.text = (data['description'] ?? '').toString();

    // Area breakdown
    _kitchenAreaController.text = (data['kitchen_area'] ?? '').toString();
    _livingAreaController.text = (data['living_room_area'] ?? '').toString();
    _hallAreaController.text = (data['hall_area'] ?? '').toString();
    _bedroomAreaController.text = (data['bedroom_area'] ?? '').toString();
    _bedroom2AreaController.text = (data['bedroom_2_area'] ?? '').toString();
    _bathroomAreaController.text = (data['bathroom_area'] ?? '').toString();
    _balconyAreaController.text = (data['balcony_area'] ?? '').toString();

    // Selections
    if (data['district'] != null) {
      if (data['district'] is Map) {
        _selectedDistrict = data['district']['slug']?.toString() ?? 'asanbay';
        _selectedDistrictName = data['district']['name']?.toString() ?? 'Асанбай';
      } else {
        _selectedDistrict = data['district'].toString();
        final match = _districts.firstWhere((d) => d['slug'] == _selectedDistrict, orElse: () => {'name': _selectedDistrict});
        _selectedDistrictName = match['name'] ?? _selectedDistrict;
      }
    }

    _selectedRooms = int.tryParse(data['rooms']?.toString() ?? '3') ?? 3;

    if (data['series'] != null) {
      _selectedSeries = (data['series'] is Map ? data['series']['code'] : data['series']).toString();
    }

    // Пустое значение с сервера означает «не указано» — подставлять сюда
    // 'good'/'full'/'central' нельзя, иначе первое же сохранение припишет
    // объявлению характеристики, которых владелец не выбирал.
    _selectedCondition = (data['condition'] ?? '').toString();
    _selectedFurniture = (data['furniture'] ?? '').toString();
    _selectedHeating = (data['heating'] ?? '').toString();
    _hasGas = data['has_gas'] == true;
    _mortgageReady = data['has_mortgage'] == true;
    _exchangePossible = data['exchange_possible'] == true;

    // Photos & Video
    final mediaList = data['media'];
    if (mediaList is List) {
      _photos = mediaList
          .where((m) => m is Map && (m['kind'] == 'photo' || m['is_video'] != true))
          .cast<Map<String, dynamic>>()
          .toList();
      _videos = mediaList
          .where((m) => m is Map && (m['kind'] == 'video' || m['is_video'] == true))
          .cast<Map<String, dynamic>>()
          .toList();
    }
  }

  void _populateFromItem(Listing item) {
    _addressController.text = item.address;
    _areaController.text = item.area > 0 ? item.area.toStringAsFixed(0) : '118';
    _priceController.text = item.priceUsd > 0 ? item.priceUsd.toString() : '145000';
    _floorController.text = item.floor > 0 ? item.floor.toString() : '8';
    _floorsController.text = item.floors > 0 ? item.floors.toString() : '14';
    _builderController.text = '';
    _descriptionController.text = item.description;
    _selectedRooms = item.rooms > 0 ? item.rooms : 3;
    _selectedDistrict = item.district.isNotEmpty ? item.district : 'asanbay';
    _selectedDistrictName = item.district.isNotEmpty ? item.district : 'Асанбай';
    _selectedSeries = item.series ?? '106';

    _photos = [
      if (item.photo.isNotEmpty) {'url': item.photo, 'kind': 'photo', 'id': 1},
      ...item.more.map((url) => {'url': url, 'kind': 'photo', 'id': url.hashCode}),
    ];
    _videos = item.videos
        .map((v) => {'url': v.url, 'kind': 'video', 'id': v.url.hashCode, 'title': v.title})
        .toList();
  }

  Future<void> _pickPhotos() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newPhotoFiles.addAll(pickedFiles);
        });
      }
    } catch (e) {
      debugPrint('Photo picker error: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedVideo = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedVideo != null) {
        setState(() {
          _newVideoFiles.add(pickedVideo);
        });
      }
    } catch (e) {
      debugPrint('Video picker error: $e');
    }
  }

  Future<void> _deleteExistingPhoto(Map<String, dynamic> photo) async {
    final photoId = photo['id'];
    setState(() {
      _photos.remove(photo);
    });

    if (photoId != null && photoId is int) {
      try {
        final state = AppScope.read(context);
        await state.apiClient.deleteMedia(_slug, photoId);
      } catch (e) {
        debugPrint('Delete media error: $e');
      }
    }
  }

  Future<void> _deleteExistingVideo(Map<String, dynamic> video) async {
    final videoId = video['id'];
    setState(() {
      _videos.remove(video);
    });

    if (videoId != null && videoId is int) {
      try {
        final state = AppScope.read(context);
        await state.apiClient.deleteMedia(_slug, videoId);
      } catch (e) {
        debugPrint('Delete video error: $e');
      }
    }
  }

  List<Map<String, String>> _getSeriesList(AppState state) {
    final raw = state.filterOptions['series'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map<Map<String, String>>((item) {
        if (item is Map) {
          final code = (item['code'] ?? item['slug'] ?? item['value'] ?? item['id']?.toString() ?? '').toString();
          final name = (item['name'] ?? item['label'] ?? '$code серия').toString();
          return {'code': code, 'name': name};
        }
        return {'code': item.toString(), 'name': item.toString()};
      }).toList();
    }
    return _seriesList;
  }

  List<Map<String, String>> _getDistrictsList(AppState state) {
    final raw = state.filterOptions['districts'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map<Map<String, String>>((item) {
        if (item is Map) {
          final slug = (item['slug'] ?? item['value'] ?? item['id']?.toString() ?? '').toString();
          final name = (item['name'] ?? item['label'] ?? slug).toString();
          return {'slug': slug, 'name': name};
        }
        return {'slug': item.toString(), 'name': item.toString()};
      }).toList();
    }
    return _districts;
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final state = AppScope.read(context);

    final roomAreas = <String, String>{
      'kitchen_area': _kitchenAreaController.text.trim(),
      'living_room_area': _livingAreaController.text.trim(),
      'hall_area': _hallAreaController.text.trim(),
      'bedroom_area': _bedroomAreaController.text.trim(),
      'bedroom_2_area': _bedroom2AreaController.text.trim(),
      'bathroom_area': _bathroomAreaController.text.trim(),
      'balcony_area': _balconyAreaController.text.trim(),
    }..removeWhere((_, value) => value.isEmpty);

    // Серию отправляем только если она есть в справочнике. Раньше здесь
    // подставлялась «первая попавшаяся», что тихо подменяло данные владельца.
    final availableSeries = _getSeriesList(state);
    final seriesCode =
        availableSeries.any((item) => item['code'] == _selectedSeries) ? _selectedSeries : null;

    final bText = _builderController.text.trim().toLowerCase();
    final builderSlug = switch (bText) {
      _ when bText.contains('elite') => 'elite-house',
      _ when bText.contains('ihlas') || bText.contains('ихлас') => 'ihlas',
      _ when bText.contains('avangard') || bText.contains('авангард') => 'avangard-stil',
      _ when bText.contains('emakom') || bText.contains('эмаком') => 'ema-com',
      _ => null,
    };

    // Тело запроса собирает общий модуль: раньше этот экран слал floors_total
    // вместо floors и ещё пять несуществующих полей — сервер отвечал 200,
    // а данные исчезали.
    final payload = buildListingPayload(
      kind: _kind,
      districtSlug: _selectedDistrict,
      address: _addressController.text,
      description: _descriptionController.text,
      price: int.tryParse(_priceController.text.trim()),
      area: double.tryParse(_areaController.text.trim()),
      rooms: _selectedRooms,
      floor: int.tryParse(_floorController.text.trim()),
      floors: int.tryParse(_floorsController.text.trim()),
      seriesCode: seriesCode,
      builderSlug: builderSlug,
      furniture: _selectedFurniture,
      condition: _selectedCondition,
      heating: _selectedHeating,
      hasGas: _hasGas,
      hasMortgage: _mortgageReady,
      exchangePossible: _exchangePossible,
      roomAreas: roomAreas,
    );

    try {
      // 1. Update listing fields with automatic validation retry
      try {
        await state.apiClient.updateListing(_slug, payload);
      } on ApiException catch (apiErr) {
        final msg = apiErr.message.toLowerCase();
        bool shouldRetry = false;
        if (msg.contains('series') || msg.contains('code=')) {
          payload.remove('series');
          shouldRetry = true;
        }
        if (msg.contains('builder') || msg.contains('slug=')) {
          payload.remove('builder');
          shouldRetry = true;
        }
        if (msg.contains('district')) {
          payload.remove('district');
          shouldRetry = true;
        }
        if (shouldRetry) {
          await state.apiClient.updateListing(_slug, payload);
        } else {
          rethrow;
        }
      }

      // 2. Upload new photos if any
      for (final photoFile in _newPhotoFiles) {
        try {
          await state.apiClient.uploadMedia(_slug, photoFile, null, null, 'photo');
        } catch (pe) {
          debugPrint('Upload photo error: $pe');
        }
      }

      // 3. Upload new videos if any
      for (final videoFile in _newVideoFiles) {
        try {
          await state.apiClient.uploadMedia(_slug, videoFile, null, null, 'video');
        } catch (ve) {
          debugPrint('Upload video error: $ve');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Объявление успешно обновлено!'),
            backgroundColor: Color(0xff2e7d32),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: const Color(0xfff5222d),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDistrictPicker() {
    final state = AppScope.read(context);
    final districts = _getDistrictsList(state);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Выберите район',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: districts.length,
                itemBuilder: (ctx, i) {
                  final d = districts[i];
                  final isSelected = d['slug'] == _selectedDistrict;
                  return ListTile(
                    title: Text(d['name']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xffea812e)) : null,
                    onTap: () {
                      setState(() {
                        _selectedDistrict = d['slug']!;
                        _selectedDistrictName = d['name']!;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeriesPicker() {
    final state = AppScope.read(context);
    final series = _getSeriesList(state);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Серия дома',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: series.length,
                itemBuilder: (ctx, i) {
                  final s = series[i];
                  final isSelected = s['code'] == _selectedSeries;
                  return ListTile(
                    title: Text(s['name']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xffea812e)) : null,
                    onTap: () {
                      setState(() {
                        _selectedSeries = s['code']!;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Редактирование объявления',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: orangeColor))
                  : const Text('Сохранить', style: TextStyle(color: orangeColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: orangeColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadListing, child: const Text('Повторить')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Медиа-секция
                      _buildSectionTitle('Фотографии объекта'),
                      const SizedBox(height: 10),
                      _buildMediaSection(orangeColor),
                      const SizedBox(height: 24),

                      // 2. Видеоролик
                      _buildSectionTitle('Видеоролик объекта'),
                      const SizedBox(height: 10),
                      _buildVideoSection(orangeColor),
                      const SizedBox(height: 24),

                      // 3. Основные данные
                      _buildSectionTitle('Основная информация'),
                      const SizedBox(height: 12),
                      _buildCardWrapper([
                        // Район
                        _buildPickerTile(
                          label: 'Район',
                          value: _selectedDistrictName,
                          onTap: _showDistrictPicker,
                          icon: Icons.location_on_outlined,
                        ),
                        const Divider(height: 1),

                        // Адрес
                        _buildTextField(
                          controller: _addressController,
                          label: 'Улица / Адрес',
                          hint: 'например, ул. Аалы Токомбаева, 21/3',
                          icon: Icons.map_outlined,
                        ),
                        const Divider(height: 1),

                        // Серия дома
                        _buildPickerTile(
                          label: 'Серия дома',
                          value: _seriesList.firstWhere((s) => s['code'] == _selectedSeries, orElse: () => {'name': _selectedSeries})['name']!,
                          onTap: _showSeriesPicker,
                          icon: Icons.apartment_outlined,
                        ),
                        const Divider(height: 1),

                        // Застройщик
                        _buildTextField(
                          controller: _builderController,
                          label: 'Застройщик / ЖК',
                          hint: 'Ихлас, Авангард, Elite House и др.',
                          icon: Icons.domain_outlined,
                        ),
                        const Divider(height: 1),

                        // Количество комнат
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Количество комнат', style: TextStyle(fontSize: 13, color: Color(0xff8e8e93))),
                              const SizedBox(height: 8),
                              Row(
                                children: [1, 2, 3, 4, 5].map((r) {
                                  final isSelected = _selectedRooms == r;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => setState(() => _selectedRooms = r),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? orangeColor : const Color(0xfff2f2f7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            r >= 5 ? '5+' : '$r',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Площадь и Этаж
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _areaController,
                                label: 'Площадь (м²)',
                                hint: '118',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            Container(width: 1, height: 48, color: const Color(0xffe5e5ea)),
                            Expanded(
                              child: _buildTextField(
                                controller: _floorController,
                                label: 'Этаж',
                                hint: '8',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            Container(width: 1, height: 48, color: const Color(0xffe5e5ea)),
                            Expanded(
                              child: _buildTextField(
                                controller: _floorsController,
                                label: 'Всего этажей',
                                hint: '14',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1),

                        // Цена
                        _buildTextField(
                          controller: _priceController,
                          label: 'Стоимость (\$ USD)',
                          hint: '145 000',
                          keyboardType: TextInputType.number,
                          icon: Icons.attach_money_rounded,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 4. Параметры и удобства
                      _buildSectionTitle('Удобства и состояние'),
                      const SizedBox(height: 12),
                      _buildCardWrapper([
                        _buildDropdownTile(
                          label: 'Состояние / Ремонт',
                          value: _selectedCondition,
                          items: const {
                            'euro': 'Евроремонт',
                            'good': 'Хорошее состояние',
                            'shell': 'Под самоотделку',
                            'medium': 'Среднее состояние',
                            'none': 'Без ремонта',
                          },
                          onChanged: (val) => setState(() => _selectedCondition = val!),
                        ),
                        const Divider(height: 1),
                        _buildDropdownTile(
                          label: 'Мебель',
                          value: _selectedFurniture,
                          items: const {
                            'full': 'Полностью меблирована',
                            'partial': 'Частично с мебелью',
                            'none': 'Без мебели',
                          },
                          onChanged: (val) => setState(() => _selectedFurniture = val!),
                        ),
                        const Divider(height: 1),
                        _buildDropdownTile(
                          label: 'Отопление',
                          value: _selectedHeating,
                          items: const {
                            'central': 'Центральное',
                            'gas': 'Газовое',
                            'electric': 'Электрическое',
                            'autonomous': 'Автономное',
                          },
                          onChanged: (val) => setState(() => _selectedHeating = val!),
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile('Наличие газа', _hasGas, (v) => setState(() => _hasGas = v)),
                        const Divider(height: 1),
                        _buildSwitchTile('Возможность ипотеки', _mortgageReady, (v) => setState(() => _mortgageReady = v)),
                        const Divider(height: 1),
                        _buildSwitchTile('Возможность обмена', _exchangePossible, (v) => setState(() => _exchangePossible = v)),
                      ]),
                      const SizedBox(height: 24),

                      // 5. Экспликация комнат
                      _buildSectionTitle('Площади отдельных зон (м²)'),
                      const SizedBox(height: 12),
                      _buildCardWrapper([
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _kitchenAreaController, label: 'Кухня', hint: '16', keyboardType: TextInputType.number)),
                            Container(width: 1, height: 48, color: const Color(0xffe5e5ea)),
                            Expanded(child: _buildTextField(controller: _livingAreaController, label: 'Гостиная', hint: '32', keyboardType: TextInputType.number)),
                          ],
                        ),
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _bedroomAreaController, label: 'Спальня 1', hint: '20', keyboardType: TextInputType.number)),
                            Container(width: 1, height: 48, color: const Color(0xffe5e5ea)),
                            Expanded(child: _buildTextField(controller: _bedroom2AreaController, label: 'Спальня 2', hint: '18', keyboardType: TextInputType.number)),
                          ],
                        ),
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _hallAreaController, label: 'Прихожая', hint: '12', keyboardType: TextInputType.number)),
                            Container(width: 1, height: 48, color: const Color(0xffe5e5ea)),
                            Expanded(child: _buildTextField(controller: _bathroomAreaController, label: 'Санузел', hint: '8', keyboardType: TextInputType.number)),
                            Container(width: 1, height: 48, color: const Color(0xffe5e5ea)),
                            Expanded(child: _buildTextField(controller: _balconyAreaController, label: 'Балкон', hint: '6', keyboardType: TextInputType.number)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 6. Описание объекта
                      _buildSectionTitle('Описание объекта'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xffe5e5ea)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: TextField(
                          controller: _descriptionController,
                          minLines: 4,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            hintText: 'Расскажите об объекте подробнее: ремонт, вид из окна, соседи, инфраструктура рядом...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orangeColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _isSaving ? null : _saveChanges,
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Сохранить изменения',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff1c1c1e)),
    );
  }

  Widget _buildCardWrapper(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe5e5ea)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildMediaSection(Color orangeColor) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add Photo button
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickPhotos,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xfff2f2f7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffd1d1d6), style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: Color(0xffea812e), size: 30),
                  SizedBox(height: 4),
                  Text('Добавить', style: TextStyle(fontSize: 12, color: Color(0xff8e8e93))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Existing server photos
          ..._photos.asMap().entries.map((entry) {
            final index = entry.key;
            final photo = entry.value;
            final url = photo['url']?.toString() ?? '';
            return Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xffe5e5ea),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xcc000000),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Главное', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _deleteExistingPhoto(photo),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xcc000000), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Newly added local photo files
          ..._newPhotoFiles.map((file) {
            return Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xffe5e5ea),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (file is File)
                        ? Image.file(file, width: 100, height: 100, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.photo, color: Color(0xffea812e), size: 36)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => setState(() => _newPhotoFiles.remove(file)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xcc000000), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVideoSection(Color orangeColor) {
    final totalVideos = _videos.length + _newVideoFiles.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe5e5ea)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List of existing server videos
          for (int i = 0; i < _videos.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xfffee2e2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.videocam, color: Color(0xfff5222d), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _videos[i]['title'] != null && _videos[i]['title'].toString().isNotEmpty
                            ? _videos[i]['title'].toString()
                            : 'Видеоролик ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Загружен на сервер',
                        style: TextStyle(color: Color(0xff8e8e93), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xfff5222d)),
                  onPressed: () => _deleteExistingVideo(_videos[i]),
                ),
              ],
            ),
          ],

          // List of newly added local videos
          for (int j = 0; j < _newVideoFiles.length; j++) ...[
            if (_videos.isNotEmpty || j > 0) const Divider(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xfffef3c7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.video_file, color: Color(0xffea812e), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Новое видео ${_videos.length + j + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Будет загружено при сохранении',
                        style: TextStyle(color: Color(0xff8e8e93), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xff8e8e93)),
                  onPressed: () => setState(() => _newVideoFiles.removeAt(j)),
                ),
              ],
            ),
          ],

          if (totalVideos > 0) const SizedBox(height: 12),

          // Add video button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_call_outlined, color: Color(0xffea812e), size: 20),
              label: Text(
                totalVideos == 0 ? 'Добавить видеоролик' : 'Добавить еще видео (+)',
                style: const TextStyle(color: Color(0xffea812e), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xffea812e)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon, color: const Color(0xff8e8e93), size: 22) : null,
      title: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xff8e8e93))),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xffc7c7cc)),
      onTap: onTap,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: const Color(0xff8e8e93)),
                const SizedBox(width: 6),
              ],
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xff8e8e93))),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xffc7c7cc), fontWeight: FontWeight.normal),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Пустое значение — это «не указано», а не первый пункт списка: показывать
    // «Евроремонт» там, где владелец ничего не выбирал, значит врать.
    final options = {'': 'Не указано', ...items};
    final displayValue = options.containsKey(value) ? value : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          DropdownButton<String>(
            value: displayValue,
            underline: const SizedBox.shrink(),
            items: options.entries.map((e) {
              return DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xffea812e))),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      value: value,
      activeColor: const Color(0xffea812e),
      onChanged: onChanged,
    );
  }
}
