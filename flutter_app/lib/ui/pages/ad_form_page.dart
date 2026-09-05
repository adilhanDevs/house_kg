import 'package:house_kgz/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../data/kind_fields.dart';
import '../../data/listing_payload.dart';
import '../../data/listings.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../fig_controls.dart';


/// Страница «Добавить недвижимость» (Чистый Flutter layout без наложения дублирующихся графических кадеров).
class AdFormPage extends StatefulWidget {
  const AdFormPage({super.key, this.slug});

  final String? slug;

  @override
  State<AdFormPage> createState() => _AdFormPageState();
}

class _AdFormPageState extends State<AdFormPage> {
  TextEditingController? _areaController;
  TextEditingController? _builderController;
  TextEditingController? _priceController;
  TextEditingController? _roomsController;
  TextEditingController? _floorController;
  TextEditingController? _floorsController;
  TextEditingController? _landAreaController;
  TextEditingController? _ceilingController;
  TextEditingController? _addressController;
  TextEditingController? _descriptionController;
  TextEditingController? _contactNameController;
  TextEditingController? _contactPhoneController;
  TextEditingController? _landmarkController;
  TextEditingController? _roomNameController;
  TextEditingController? _roomAreaController;

  TextEditingController get _effectiveAreaController => _areaController ??= TextEditingController();
  TextEditingController get _effectiveBuilderController => _builderController ??= TextEditingController();
  TextEditingController get _effectivePriceController => _priceController ??= TextEditingController();
  TextEditingController get _effectiveRoomsController => _roomsController ??= TextEditingController();
  TextEditingController get _effectiveFloorController => _floorController ??= TextEditingController();
  TextEditingController get _effectiveFloorsController => _floorsController ??= TextEditingController();
  TextEditingController get _effectiveLandAreaController => _landAreaController ??= TextEditingController();
  TextEditingController get _effectiveCeilingController => _ceilingController ??= TextEditingController();
  TextEditingController get _effectiveAddressController => _addressController ??= TextEditingController();
  TextEditingController get _effectiveDescriptionController => _descriptionController ??= TextEditingController();
  TextEditingController get _effectiveContactNameController => _contactNameController ??= TextEditingController();
  TextEditingController get _effectiveContactPhoneController => _contactPhoneController ??= TextEditingController();
  TextEditingController get _effectiveLandmarkController => _landmarkController ??= TextEditingController();
  TextEditingController get _effectiveRoomNameController => _roomNameController ??= TextEditingController();
  TextEditingController get _effectiveRoomAreaController => _roomAreaController ??= TextEditingController();
  bool _isSaving = false;
  bool _initializedFromState = false;

  // Необязательные поля свёрнуты: иначе форма превращается в ленту из
  // двадцати с лишним секций и обязательные в ней теряются.
  final Set<String> _openBlocks = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      if (widget.slug != null) {
        state.draftSlug = widget.slug;
      }
      if (state.filterOptions['districts'] == null || (state.filterOptions['districts'] as List).isEmpty) {
        state.fetchFilterOptions('bishkek');
      }
      if (state.draftSlug == null) {
        state.loadDraft().then((_) {
          if (mounted) {
            setState(() {
              _initializedFromState = false;
              _syncControllers(state);
            });
          }
        });
      }
    });
  }

  static const List<Map<String, String>> _defaultDistricts = [
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

  List<Map<String, String>> _getDistrictsList(AppState state) {
    final rawList = state.filterOptions['districts'];
    if (rawList is List && rawList.isNotEmpty) {
      return rawList.map<Map<String, String>>((item) {
        if (item is Map) {
          final slug = (item['slug'] ?? item['value'] ?? item['id']?.toString() ?? '').toString();
          final name = (item['name'] ?? item['label'] ?? slug).toString();
          return {'slug': slug, 'name': name};
        }
        return {'slug': item.toString(), 'name': item.toString()};
      }).toList();
    }
    return _defaultDistricts;
  }

  void _syncControllers(AppState state) {
    if (_initializedFromState) return;
    _initializedFromState = true;
    if (state.draftArea.isNotEmpty) _effectiveAreaController.text = state.draftArea;
    if (state.draftBuilder.isNotEmpty) _effectiveBuilderController.text = state.draftBuilder;
    if (state.draftPrice.isNotEmpty) {
      final parsed = double.tryParse(state.draftPrice.replaceAll(' ', '').replaceAll(',', '.'));
      if (parsed != null && parsed > 0) {
        _effectivePriceController.text = parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
      } else {
        _effectivePriceController.text = state.draftPrice;
      }
    }
    if (state.draftRooms > 5) _effectiveRoomsController.text = state.draftRooms.toString();
    if (state.draftFloor > 5) _effectiveFloorController.text = state.draftFloor.toString();
    if (state.draftFloors > 5) _effectiveFloorsController.text = state.draftFloors.toString();
    if (state.draftLandArea.isNotEmpty) _effectiveLandAreaController.text = state.draftLandArea;
    if (state.draftCeilingHeight.isNotEmpty) {
      _effectiveCeilingController.text = state.draftCeilingHeight;
    }
    if (state.draftAddress.isNotEmpty) _effectiveAddressController.text = state.draftAddress;
    if (state.draftDescription.isNotEmpty) {
      _effectiveDescriptionController.text = state.draftDescription;
    }
    if (state.draftContactName.isNotEmpty) {
      _effectiveContactNameController.text = state.draftContactName;
    }
    if (state.draftContactPhone.isNotEmpty) {
      _effectiveContactPhoneController.text = state.draftContactPhone;
    }
  }

  String _getDistrictLabel(AppState state) {
    if (state.draftDistrict.isEmpty || state.draftDistrict == 'Район Бишкека') return context.l10n.addListingSelectDistrict;
    final list = _getDistrictsList(state);
    for (final item in list) {
      if (item['slug'] == state.draftDistrict || item['name'] == state.draftDistrict) {
        return item['name']!;
      }
    }
    return state.draftDistrict;
  }

  Future<void> _submitForm(AppState state) async {
    final cleanPriceText = _effectivePriceController.text.trim().replaceAll(' ', '').replaceAll(',', '.');
    final cleanDraftPrice = state.draftPrice.replaceAll(' ', '').replaceAll(',', '.');
    final price = double.tryParse(cleanPriceText)?.round() ?? (double.tryParse(cleanDraftPrice)?.round() ?? 0);

    final kindEnum = state.draftKinds.isNotEmpty ? state.draftKinds.first : PropertyKind.apartment;
    final isPlot = kindEnum == PropertyKind.plot;

    final area = double.tryParse(_effectiveAreaController.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ??
        (double.tryParse(state.draftArea.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0);
    final landArea = double.tryParse(_effectiveLandAreaController.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ??
        (double.tryParse(state.draftLandArea.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0);

    final builder = _effectiveBuilderController.text.trim().isNotEmpty ? _effectiveBuilderController.text.trim() : state.draftBuilder;

    if (state.draftDistrict.isEmpty || state.draftDistrict == 'Район Бишкека') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addListingErrDistrict)),
      );
      return;
    }
    if (!isPlot && area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addListingErrArea)),
      );
      return;
    }
    if (isPlot && landArea <= 0 && area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addListingErrPlotArea)),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addListingErrPrice)),
      );
      return;
    }

    String districtSlug = state.draftDistrict;
    final districtsList = _getDistrictsList(state);
    for (final d in districtsList) {
      if (d['name'] == state.draftDistrict || d['slug'] == state.draftDistrict) {
        districtSlug = d['slug']!;
        break;
      }
    }

    final kindApi = switch (kindEnum) {
      PropertyKind.house => 'house',
      PropertyKind.apartment => 'apartment',
      PropertyKind.plot => 'plot',
      PropertyKind.newBuilding => 'new_building',
      PropertyKind.room => 'room',
      PropertyKind.commercial => 'commercial',
    };

    final roomsVal = int.tryParse(_effectiveRoomsController.text.trim()) ?? (state.draftRooms > 0 ? state.draftRooms : 1);
    final floorVal = int.tryParse(_effectiveFloorController.text.trim()) ?? (state.draftFloor > 0 ? state.draftFloor : 1);
    final floorsVal = int.tryParse(_effectiveFloorsController.text.trim()) ?? (state.draftFloors > 0 ? state.draftFloors : (floorVal > 1 ? floorVal : 1));
    final sellerKindApi = state.draftOwner ? 'owner' : 'realtor';

    // Тело запроса собирает общий модуль — он же следит, чтобы имена ключей
    // совпадали с ListingUpdateSerializer (см. lib/data/listing_payload.dart).
    final data = buildListingPayload(
      kind: kindEnum,
      districtSlug: districtSlug,
      address: state.draftAddress,
      description: state.draftDescription,
      usd: state.draftUsd,
      sellerKind: sellerKindApi,
      price: price,
      area: area,
      landArea: state.draftLandArea,
      rooms: roomsVal,
      floor: floorVal,
      floors: floorsVal,
      seriesCode: state.draftSeries,
      builderSlug: builder.toLowerCase().contains('elite') ? 'elite-house' : null,
      isSecondary: state.draftSecondary,
      furniture: state.draftFurniture,
      condition: state.draftCondition,
      heating: state.draftHeating,
      hasGas: state.draftHasGas,
      exchangePossible: state.draftExchange,
      hasDirectSale: state.draftDirectSale,
      hasMortgage: state.draftMortgage,
      plotPurpose: state.draftPlotPurpose,
      commercialPurpose: state.draftCommercialPurpose,
      separateEntrance: state.draftSeparateEntrance,
      buildingLine: state.draftBuildingLine,
      ceilingHeight: state.draftCeilingHeight,
      contactName: state.draftContactName,
      contactPhone: state.draftContactPhone,
      landmarks: state.draftLandmarks,
      roomsBreakdown: state.draftRoomList,
    );

    setState(() => _isSaving = true);
    try {
      final response = await state.apiClient.createDraft(data);
      if (response['slug'] != null) {
        state.draftSlug = response['slug'] as String;
      }
      if (mounted) {
        Navigator.pushNamed(context, Routes.adPhotos);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.addListingErrorSave(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _areaController?.dispose();
    _landAreaController?.dispose();
    _ceilingController?.dispose();
    _addressController?.dispose();
    _descriptionController?.dispose();
    _contactNameController?.dispose();
    _contactPhoneController?.dispose();
    _landmarkController?.dispose();
    _roomNameController?.dispose();
    _roomAreaController?.dispose();
    _builderController?.dispose();
    _priceController?.dispose();
    _roomsController?.dispose();
    _floorController?.dispose();
    _floorsController?.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getBuildersList(AppState state) {
    if (state.filterOptions['builders'] != null) {
      final list = state.filterOptions['builders'] as List;
      return list.map((item) {
        if (item is Map) {
          final slug = item['slug']?.toString() ?? '';
          final name = item['name']?.toString() ?? '';
          return {'slug': slug, 'name': name};
        }
        return {'slug': item.toString(), 'name': item.toString()};
      }).toList();
    }
    return [];
  }

  String _getBuilderLabel(AppState state) {
    if (state.draftBuilder.isEmpty) return context.l10n.addListingSelectBuilder;
    final list = _getBuildersList(state);
    for (final item in list) {
      if (item['slug'] == state.draftBuilder || item['name'] == state.draftBuilder) {
        return item['name']!;
      }
    }
    return state.draftBuilder;
  }

  void _showBuilderPicker(BuildContext context, AppState state) {
    if (state.filterOptions['builders'] == null || (state.filterOptions['builders'] as List).isEmpty) {
      state.fetchFilterOptions('bishkek');
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        final builders = _getBuildersList(state);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  context.l10n.addListingSelectBuilder,
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: builders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = builders[index];
                    final slug = item['slug']!;
                    final label = item['name']!;
                    final isSelected = state.draftBuilder == slug || state.draftBuilder == label;
                    return ListTile(
                      title: Text(label),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xffea812e))
                          : null,
                      onTap: () {
                        state.setDraft(() {
                          state.draftBuilder = slug;
                          _effectiveBuilderController.text = label;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDistrictPicker(BuildContext context, AppState state) {
    if (state.filterOptions['districts'] == null || (state.filterOptions['districts'] as List).isEmpty) {
      state.fetchFilterOptions('bishkek');
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        final districts = _getDistrictsList(state);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  context.l10n.addListingSelectDistrictHints,
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: districts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = districts[index];
                    final slug = item['slug']!;
                    final label = item['name']!;
                    final isSelected = state.draftDistrict == slug || state.draftDistrict == label;
                    return ListTile(
                      title: Text(label),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xffea812e))
                          : null,
                      onTap: () {
                        state.setDraft(() {
                          state.draftDistrict = slug;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const orangeColor = Color(0xffea812e);

    final areaCtrl = _effectiveAreaController;
    final builderCtrl = _effectiveBuilderController;
    final priceCtrl = _effectivePriceController;
    final roomsCtrl = _effectiveRoomsController;
    final floorCtrl = _effectiveFloorController;
    final floorsCtrl = _effectiveFloorsController;
    final landAreaCtrl = _effectiveLandAreaController;
    final ceilingCtrl = _effectiveCeilingController;
    final addressCtrl = _effectiveAddressController;
    final descriptionCtrl = _effectiveDescriptionController;
    final contactNameCtrl = _effectiveContactNameController;
    final contactPhoneCtrl = _effectiveContactPhoneController;
    final landmarkCtrl = _effectiveLandmarkController;
    final roomNameCtrl = _effectiveRoomNameController;
    final roomAreaCtrl = _effectiveRoomAreaController;

    // Набор секций зависит от типа: у участка нет комнат и этажей, у
    // коммерции — свои параметры (см. lib/data/kind_fields.dart).
    final formKind =
        state.draftKinds.isNotEmpty ? state.draftKinds.first : PropertyKind.apartment;

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Прогресс-бар сверху
              Container(
                height: 4.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xffe8e9f1),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.25,
                  child: Container(
                    decoration: BoxDecoration(
                      color: orangeColor,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.0),

              // Заголовок и подзаголовок
              Text(
                context.l10n.addListingTitle,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              SizedBox(height: 4.0),
              Text(
                context.l10n.addListingSubtitle,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Color(0xff7d7d7d),
                ),
              ),
              const SizedBox(height: 24.0),

              // 1. Тип недвижимости
              _buildSectionTitle(context.l10n.addListingPropertyKind),
              const SizedBox(height: 10.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  for (final kind in PropertyKind.values)
                    _buildChip(
                      label: kind.labelL10n(context),
                      selected: state.draftKinds.contains(kind),
                      onTap: () => state.setDraftKind(kind),
                    ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 2. Район
              _buildSectionTitle(context.l10n.addListingDistrict),
              const SizedBox(height: 10.0),
              GestureDetector(
                onTap: () => _showDistrictPicker(context, state),
                child: Container(
                  height: 48.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xfff5f5f7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.draftDistrict.isEmpty ? context.l10n.addListingSelectDistrict : _getDistrictLabel(state),
                        style: TextStyle(
                          fontSize: 15.0,
                          color: state.draftDistrict.isEmpty
                              ? const Color(0x993c3c43)
                              : const Color(0xff000000),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: orangeColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // 3. Количество комнат
              if (showsField(formKind, ListingField.rooms)) ...[
                _buildSectionTitle(context.l10n.addListingRoomsCount),
                const SizedBox(height: 10.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int index = 0; index < 5; index++) ...[
                        if (index > 0) const SizedBox(width: 8.0),
                        _buildChip(
                          label: '${index + 1} ком.',
                          selected: state.draftRooms == index + 1 && roomsCtrl.text.isEmpty,
                          onTap: () {
                            roomsCtrl.clear();
                            state.setDraft(() => state.draftRooms = index + 1);
                          },
                        ),
                      ],
                      const SizedBox(width: 8.0),
                      SizedBox(
                        width: 190.0,
                        child: _buildInputField(
                          controller: roomsCtrl,
                          hintText: context.l10n.addListingEnterCustomValue,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final parsed = int.tryParse(val.replaceAll(' ', ''));
                            if (parsed != null && parsed > 0) {
                              state.setDraft(() => state.draftRooms = parsed);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
              ],

              // 4. Квадратура
              _buildSectionTitle(context.l10n.addListingArea),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: areaCtrl,
                      hintText: 'Введите свою квадратуру...',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => state.setDraft(() => state.draftArea = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 5. Этаж
              if (showsField(formKind, ListingField.floor)) ...[
                _buildSectionTitle(context.l10n.addListingFloor),
                const SizedBox(height: 10.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int index = 0; index < 5; index++) ...[
                        if (index > 0) const SizedBox(width: 8.0),
                        SizedBox(
                          width: 44.0,
                          child: _buildChip(
                            label: '${index + 1}',
                            selected: state.draftFloor == index + 1 && floorCtrl.text.isEmpty,
                            onTap: () {
                              floorCtrl.clear();
                              state.setDraft(() {
                                state.draftFloor = index + 1;
                                if (state.draftFloor > state.draftFloors) {
                                  state.draftFloors = state.draftFloor;
                                  if (floorsCtrl.text.isNotEmpty) {
                                    floorsCtrl.text = state.draftFloors.toString();
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ],
                      const SizedBox(width: 8.0),
                      SizedBox(
                        width: 190.0,
                        child: _buildInputField(
                          controller: floorCtrl,
                          hintText: context.l10n.addListingEnterCustomValue,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final parsed = int.tryParse(val.replaceAll(' ', ''));
                            if (parsed != null && parsed > 0) {
                              state.setDraft(() {
                                state.draftFloor = parsed;
                                if (state.draftFloor > state.draftFloors) {
                                  state.draftFloors = state.draftFloor;
                                  if (floorsCtrl.text.isNotEmpty) {
                                    floorsCtrl.text = state.draftFloors.toString();
                                  }
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
              ],

              // 6. Кол-во этажей в здании
              if (showsField(formKind, ListingField.floors)) ...[
                _buildSectionTitle(context.l10n.addListingTotalFloors),
                const SizedBox(height: 10.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int index = 0; index < 5; index++) ...[
                        if (index > 0) const SizedBox(width: 8.0),
                        SizedBox(
                          width: 44.0,
                          child: _buildChip(
                            label: '${index + 1}',
                            selected: state.draftFloors == index + 1 && floorsCtrl.text.isEmpty,
                            onTap: () {
                              floorsCtrl.clear();
                              state.setDraft(() {
                                state.draftFloors = index + 1;
                                if (state.draftFloor > state.draftFloors) {
                                  state.draftFloor = state.draftFloors;
                                  if (floorCtrl.text.isNotEmpty) {
                                    floorCtrl.text = state.draftFloor.toString();
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ],
                      const SizedBox(width: 8.0),
                      SizedBox(
                        width: 190.0,
                        child: _buildInputField(
                          controller: floorsCtrl,
                          hintText: context.l10n.addListingEnterCustomValue,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final parsed = int.tryParse(val.replaceAll(' ', ''));
                            if (parsed != null && parsed > 0) {
                              state.setDraft(() {
                                state.draftFloors = parsed;
                                if (state.draftFloor > state.draftFloors) {
                                  state.draftFloor = state.draftFloors;
                                  if (floorCtrl.text.isNotEmpty) {
                                    floorCtrl.text = state.draftFloor.toString();
                                  }
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
              ],

              // 7. Строительная компания
              if (showsField(formKind, ListingField.builder)) ...[
                _buildSectionTitle(context.l10n.addListingBuilder),
                const SizedBox(height: 10.0),
                GestureDetector(
                  onTap: () => _showBuilderPicker(context, state),
                  child: Container(
                    height: 48.0,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f5f7),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          state.draftBuilder.isEmpty ? context.l10n.addListingSelectBuilder : _getBuilderLabel(state),
                          style: TextStyle(
                            fontSize: 15.0,
                            color: state.draftBuilder.isEmpty
                                ? const Color(0x993c3c43)
                                : const Color(0xff000000),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: orangeColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
              ],

              // Параметры, применимые только к отдельным типам.
              if (showsField(formKind, ListingField.landArea)) ...[
                _buildSectionTitle(context.l10n.addListingPlotArea),
                const SizedBox(height: 10.0),
                _buildInputField(
                  controller: landAreaCtrl,
                  hintText: context.l10n.addListingExample8,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => state.setDraft(() => state.draftLandArea = val),
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(formKind, ListingField.plotPurpose)) ...[
                _buildSectionTitle(context.l10n.addListingPlotPurpose),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final entry in plotPurposeLabels.entries)
                      _buildChip(
                        label: entry.value,
                        selected: state.draftPlotPurpose == entry.key,
                        onTap: () => state.setDraft(() => state.draftPlotPurpose = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(formKind, ListingField.commercialPurpose)) ...[
                _buildSectionTitle(context.l10n.addListingCommercialPurpose),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final entry in commercialPurposeLabels.entries)
                      _buildChip(
                        label: entry.value,
                        selected: state.draftCommercialPurpose == entry.key,
                        onTap: () =>
                            state.setDraft(() => state.draftCommercialPurpose = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(formKind, ListingField.buildingLine)) ...[
                _buildSectionTitle(context.l10n.addListingBuildingLine),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final entry in buildingLineLabels.entries)
                      _buildChip(
                        label: entry.value,
                        selected: state.draftBuildingLine == entry.key,
                        onTap: () => state.setDraft(() => state.draftBuildingLine = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(formKind, ListingField.separateEntrance)) ...[
                _buildSectionTitle(context.l10n.addListingSeparateEntrance),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  children: [
                    _buildChip(
                      label: context.l10n.addListingHas,
                      selected: state.draftSeparateEntrance,
                      onTap: () => state.setDraft(() => state.draftSeparateEntrance = true),
                    ),
                    _buildChip(
                      label: context.l10n.addListingHasNot,
                      selected: !state.draftSeparateEntrance,
                      onTap: () => state.setDraft(() => state.draftSeparateEntrance = false),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(formKind, ListingField.ceilingHeight)) ...[
                _buildSectionTitle(context.l10n.addListingCeilingHeight),
                const SizedBox(height: 10.0),
                _buildInputField(
                  controller: ceilingCtrl,
                  hintText: context.l10n.addListingOptionalArea,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => state.setDraft(() => state.draftCeilingHeight = val),
                ),
                const SizedBox(height: 24.0),
              ],

              // ——— Необязательное: свёрнуто, чтобы форма не разрасталась ———
              _buildBlock(
                title: context.l10n.addListingMoreInfo,
                subtitle: 'Адрес, описание, ремонт, отопление',
                children: [
                  _buildSectionTitle('Адрес'),
                  const SizedBox(height: 10.0),
                  _buildInputField(
                    controller: addressCtrl,
                    hintText: context.l10n.addListingStreet,
                    onChanged: (val) => state.setDraft(() => state.draftAddress = val),
                  ),
                  const SizedBox(height: 20.0),
                  _buildSectionTitle(context.l10n.addListingDescTitle),
                  const SizedBox(height: 10.0),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 5,
                    onChanged: (val) => state.setDraft(() => state.draftDescription = val),
                    decoration: InputDecoration(
                      hintText: context.l10n.addListingMoreInfoSubtitle,
                      hintStyle: const TextStyle(fontSize: 15.0, color: Color(0x993c3c43)),
                      filled: true,
                      fillColor: const Color(0xfff5f5f7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  if (showsField(formKind, ListingField.interior)) ...[
                    _buildChoiceRow(
                      title: context.l10n.addListingFurniture,
                      options: getFurnitureLabels(context),
                      selected: state.draftFurniture,
                      onSelect: (val) => state.setDraft(() => state.draftFurniture = val),
                    ),
                    _buildChoiceRow(
                      title: context.l10n.addListingConditionTitle,
                      options: getConditionLabels(context),
                      selected: state.draftCondition,
                      onSelect: (val) => state.setDraft(() => state.draftCondition = val),
                    ),
                    _buildChoiceRow(
                      title: context.l10n.addListingHeating,
                      options: getHeatingLabels(context),
                      selected: state.draftHeating,
                      onSelect: (val) => state.setDraft(() => state.draftHeating = val),
                    ),
                    _buildToggleRow(
                      label: 'Наличие газа',
                      value: state.draftHasGas,
                      onChanged: (val) => state.setDraft(() => state.draftHasGas = val),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                  if (showsField(formKind, ListingField.isSecondary)) ...[
                    _buildToggleRow(
                      label: context.l10n.addListingSecondary,
                      value: state.draftSecondary,
                      onChanged: (val) => state.setDraft(() => state.draftSecondary = val),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                  _buildToggleRow(
                    label: context.l10n.addListingExchangePossible,
                    value: state.draftExchange,
                    onChanged: (val) => state.setDraft(() => state.draftExchange = val),
                  ),
                  const SizedBox(height: 12.0),
                  _buildToggleRow(
                    label: context.l10n.addListingDirectBuy,
                    value: state.draftDirectSale,
                    onChanged: (val) => state.setDraft(() => state.draftDirectSale = val),
                  ),
                  const SizedBox(height: 12.0),
                  _buildToggleRow(
                    label: context.l10n.addListingMortgagePossible,
                    value: state.draftMortgage,
                    onChanged: (val) => state.setDraft(() => state.draftMortgage = val),
                  ),
                ],
              ),

              if (showsField(formKind, ListingField.interior))
                _buildBlock(
                  title: context.l10n.addListingRoomAreas,
                  subtitle: context.l10n.addListingRoomsHint,
                  children: [
                    for (var i = 0; i < state.draftRoomList.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: 44.0,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff5f5f7),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  state.draftRoomList[i].name,
                                  style: const TextStyle(fontSize: 15.0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 44.0,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff5f5f7),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  '${state.draftRoomList[i].area} м²',
                                  style: const TextStyle(fontSize: 15.0),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Color(0xff7d7d7d)),
                              onPressed: () =>
                                  state.setDraft(() => state.draftRoomList.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 8.0),
                    Text(
                      context.l10n.addListingSelectRoom,
                      style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                    ),
                    const SizedBox(height: 10.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        for (final name in getRoomNameSuggestions(context))
                          _buildChip(
                            label: name,
                            selected: roomNameCtrl.text.trim() == name,
                            onTap: () => setState(() => roomNameCtrl.text = name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInputField(
                            controller: roomNameCtrl,
                            hintText: context.l10n.addListingRoomName,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          flex: 2,
                          child: _buildInputField(
                            controller: roomAreaCtrl,
                            hintText: context.l10n.addListingSqM,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    _buildChip(
                      label: context.l10n.addListingAddRoom,
                      selected: roomNameCtrl.text.trim().isNotEmpty &&
                          roomAreaCtrl.text.trim().isNotEmpty,
                      onTap: () {
                        final name = roomNameCtrl.text.trim();
                        final area = roomAreaCtrl.text.trim();
                        if (name.isEmpty || double.tryParse(area) == null) return;
                        state.setDraft(
                          () => state.draftRoomList.add(DraftRoom(name: name, area: area)),
                        );
                        roomNameCtrl.clear();
                        roomAreaCtrl.clear();
                        setState(() {});
                      },
                    ),
                  ],
                ),

              _buildBlock(
                title: context.l10n.addListingContactsTitle,
                subtitle: context.l10n.addListingContactsSubtitle,
                children: [
                  _buildSectionTitle(context.l10n.addListingContactName),
                  const SizedBox(height: 10.0),
                  _buildInputField(
                    controller: contactNameCtrl,
                    hintText: context.l10n.addListingContactNameHint,
                    onChanged: (val) => state.setDraft(() => state.draftContactName = val),
                  ),
                  const SizedBox(height: 20.0),
                  _buildSectionTitle(context.l10n.addListingContactPhone),
                  const SizedBox(height: 10.0),
                  _buildInputField(
                    controller: contactPhoneCtrl,
                    hintText: '+996 700 123 456',
                    keyboardType: TextInputType.phone,
                    onChanged: (val) => state.setDraft(() => state.draftContactPhone = val),
                  ),
                  SizedBox(height: 20.0),
                  _buildSectionTitle(context.l10n.addListingKeyPlaces),
                  SizedBox(height: 6.0),
                  Text(
                    context.l10n.addListingDescPlaceholder,
                    style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: landmarkCtrl,
                          hintText: 'Например, школа №61',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      _buildChip(
                        label: 'Добавить',
                        selected: landmarkCtrl.text.trim().isNotEmpty,
                        onTap: () {
                          final value = landmarkCtrl.text.trim();
                          if (value.isEmpty) return;
                          state.setDraft(() => state.draftLandmarks.add(value));
                          landmarkCtrl.clear();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  if (state.draftLandmarks.isNotEmpty) ...[
                    const SizedBox(height: 10.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        for (final landmark in state.draftLandmarks)
                          Container(
                            padding: const EdgeInsets.fromLTRB(12.0, 7.0, 8.0, 7.0),
                            decoration: BoxDecoration(
                              color: const Color(0xfff5f5f7),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    landmark,
                                    style: const TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xff000000),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      state.setDraft(() => state.draftLandmarks.remove(landmark)),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16.0,
                                    color: Color(0xff7d7d7d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),

              // 8. Цена
              _buildSectionTitle(context.l10n.addListingPrice),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: priceCtrl,
                      hintText: context.l10n.addListingPrice,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => state.setDraft(() => state.draftPrice = val),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  _buildChip(
                    label: 'USD',
                    selected: state.draftUsd,
                    onTap: () => state.setDraft(() => state.draftUsd = true),
                  ),
                  const SizedBox(width: 8.0),
                  _buildChip(
                    label: 'KGS',
                    selected: !state.draftUsd,
                    onTap: () => state.setDraft(() => state.draftUsd = false),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 9. Вы являетесь?
              _buildSectionTitle(context.l10n.addListingWhoAreYou),
              const SizedBox(height: 12.0),
              _buildToggleRow(
                label: context.l10n.addListingSellerOwner,
                value: state.draftOwner,
                onChanged: (val) => state.setDraft(() => state.draftOwner = val),
              ),
              const SizedBox(height: 12.0),
              _buildToggleRow(
                label: context.l10n.addListingSellerRealtor,
                value: !state.draftOwner,
                onChanged: (val) => state.setDraft(() => state.draftOwner = !val),
              ),
              const SizedBox(height: 12.0),
              _buildToggleRow(
                label: context.l10n.sellerAgency,
                value: false,
                onChanged: (_) {},
              ),
              const SizedBox(height: 32.0),

              // 10. Кнопка Далее
              SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _submitForm(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          context.l10n.addListingNext,
                          style: TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }

  /// Свёрнутый блок необязательных полей. Заголовок оформлен как обычная
  /// секция формы, поэтому раскрытый блок от неё неотличим.
  Widget _buildBlock({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final isOpen = _openBlocks.contains(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            isOpen ? _openBlocks.remove(title) : _openBlocks.add(title);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(title),
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xffea812e),
                ),
              ],
            ),
          ),
        ),
        if (isOpen) ...[
          const SizedBox(height: 14.0),
          ...children,
        ],
        const SizedBox(height: 24.0),
      ],
    );
  }

  /// Выбор одного значения из словаря «код → подпись» чипами.
  Widget _buildChoiceRow({
    required String title,
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 10.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final entry in options.entries)
              _buildChip(
                label: entry.value,
                selected: selected == entry.key,
                onTap: () => onSelect(selected == entry.key ? '' : entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20.0),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: Color(0xff000000),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const orangeColor = Color(0xffea812e);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xfffdf1e8) : const Color(0xffffffff),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: selected ? const Color(0xfffdf1e8) : const Color(0xffe5e5ea),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? orangeColor : const Color(0xff7d7d7d),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Builder(
      builder: (context) {
        return Container(
          height: 44.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: const Color(0xfff5f5f7),
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) {
                  Scrollable.ensureVisible(
                    context,
                    alignment: 0.2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
            style: const TextStyle(fontSize: 14.0, color: Color(0xff000000)),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 13.0, color: Color(0x993c3c43)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15.0,
            color: Color(0xff3c3c43),
          ),
        ),
        FigToggle(
          value: value,
          label: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
