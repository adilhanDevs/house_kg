import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../../data/chat_controller.dart' show describeApiError;
import '../../data/chat_models.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import '../widgets/profile_identity.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _twoFactorEnabled = true;

  /// Настройки уведомлений с сервера. Пока не загрузились — переключатель
  /// показываем неактивным, чтобы не врать про текущее значение.
  NotificationSettings? _notificationSettings;
  bool _savingNotificationSettings = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  bool _isDeletingAccount = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotificationSettings());
    // Карточка показывает данные из `GET /users/me/`, а не заглушки макета.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).fetchProfile();
    });
  }

  // ——— Управление аватаром ———

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final state = AppScope.read(context);
      await state.updateAvatar(bytes: bytes, filename: image.name);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(context.l10n.accountProfileAvatarUpdated),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : context.l10n.accountAvatarUploadFailed(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xffd93025),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _deleteAvatar() async {
    if (_isUploadingAvatar) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.accountDeleteAvatarPrompt),
        content: Text(context.l10n.accountAvatarDeleteWarn),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.accountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.accountDelete, style: TextStyle(color: Color(0xffd93025))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      setState(() => _isUploadingAvatar = true);
      final state = AppScope.read(context);
      await state.updateAvatar(delete: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(context.l10n.accountProfileAvatarDeleted),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountAvatarDeleteFailed(e.toString())),
          backgroundColor: const Color(0xffd93025),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showAvatarOptions() {
    final state = AppScope.read(context);
    final hasAvatar = state.userAvatarUrl != null && state.userAvatarUrl!.isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xffe5e5ea),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.accountProfileAvatar,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff000000),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xffea812e)),
                title: Text(context.l10n.accountChooseFromGallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xffea812e)),
                title: Text(context.l10n.accountTakePhoto),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xffd93025)),
                  title: Text(
                    context.l10n.accountDeleteAvatar,
                    style: TextStyle(color: Color(0xffd93025)),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ——— Управление фоном/обложкой профиля ———

  Future<void> _pickAndUploadCover(ImageSource source) async {
    if (_isUploadingCover) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _isUploadingCover = true);
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final state = AppScope.read(context);
      await state.updateProfileCover(bytes: bytes, filename: image.name);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(context.l10n.accountProfileCoverUpdated),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : context.l10n.accountCoverUploadFailed(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xffd93025),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _deleteCover() async {
    if (_isUploadingCover) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.accountDeleteCoverPrompt),
        content: Text(context.l10n.accountCoverDeleteWarn),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.accountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.accountDelete, style: TextStyle(color: Color(0xffd93025))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      setState(() => _isUploadingCover = true);
      final state = AppScope.read(context);
      await state.updateProfileCover(delete: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(context.l10n.accountProfileCoverDeleted),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountCoverDeleteFailed(e.toString())),
          backgroundColor: const Color(0xffd93025),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  void _showCoverOptions() {
    final state = AppScope.read(context);
    final hasCover = state.userProfileCoverUrl != null && state.userProfileCoverUrl!.isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xffe5e5ea),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.accountCoverTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff000000),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xffea812e)),
                title: Text(context.l10n.accountChooseFromGallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadCover(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xffea812e)),
                title: Text(context.l10n.accountTakePhoto),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadCover(ImageSource.camera);
                },
              ),
              if (hasCover)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xffd93025)),
                  title: Text(
                    context.l10n.accountDeleteCover,
                    style: TextStyle(color: Color(0xffd93025)),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteCover();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ——— Смена пароля ———

  void _showChangePasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PasswordChangeSheet(),
    );
  }

  Future<void> _editField({
    required String label,
    required String currentValue,
    required Future<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final newValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.accountEditField(label),
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff000000),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xff7d7d7d)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: const TextStyle(color: Color(0xffea812e)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffea812e), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xffe5e5ea), width: 1.0),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: () {
                      final val = controller.text.trim();
                      Navigator.of(context).pop(val);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffea812e),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.l10n.accountSave,
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

    if (newValue == null || newValue.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await onSave(newValue);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(context.l10n.accountDataUpdated),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountSaveFailed(e.toString())),
          backgroundColor: const Color(0xffd93025),
        ),
      );
    }
  }

  Future<void> _deleteAccountDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xffffffff),
        surfaceTintColor: Colors.transparent,
        title: Text(context.l10n.accountDeleteAccountPrompt),
        content: Text(
          context.l10n.accountDeleteWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.accountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.accountDelete, style: TextStyle(color: Color(0xffd93025))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      setState(() => _isDeletingAccount = true);
      final state = AppScope.read(context);
      await state.deleteAccount();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountDeletedSuccess),
          backgroundColor: Color(0xff34c759),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.welcome, (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountDeleteFailed(e.toString())),
          backgroundColor: const Color(0xffd93025),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  /// Читает настройки уведомлений. Ошибку не показываем баннером: экран
  /// аккаунта живёт и без них, переключатель просто останется неактивным.
  Future<void> _loadNotificationSettings() async {
    try {
      final data = await AppScope.read(context).apiClient.getNotificationSettings();
      if (mounted) {
        setState(() => _notificationSettings = NotificationSettings.fromJson(data));
      }
    } catch (e) {
      debugPrint(context.l10n.accountSettingsLoadFailed(describeApiError(e)));
    }
  }

  /// Включает и выключает push о новых сообщениях.
  ///
  /// Сам список уведомлений в приложении от этого не зависит: сервер всё равно
  /// создаёт запись, флаг управляет только отправкой push.
  Future<void> _toggleNewMessage(bool value) async {
    final current = _notificationSettings;
    if (current == null || _savingNotificationSettings) return;

    setState(() {
      _savingNotificationSettings = true;
      _notificationSettings = current.copyWith(newMessageEnabled: value);
    });
    try {
      final data = await AppScope.read(context)
          .apiClient
          .updateNotificationSettings({'new_message_enabled': value});
      if (mounted) {
        setState(() => _notificationSettings = NotificationSettings.fromJson(data));
      }
    } catch (e) {
      if (!mounted) return;
      // Сервер не принял — возвращаем прежнее значение, а не врём галочкой.
      setState(() => _notificationSettings = current);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(describeApiError(e))));
    } finally {
      if (mounted) setState(() => _savingNotificationSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;
    final name = (state.userName ?? '').isNotEmpty ? state.userName! : l10n.profileNoName;
    final phone = (state.userPhone ?? '').isNotEmpty ? state.userPhone! : '—';

    return Scaffold(
      backgroundColor: const Color(0xfffefefe),
      appBar: AppBar(
        backgroundColor: const Color(0xffffffff),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xff000000)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          l10n.profileAccountRow,
          style: figStyle(
            fontSize: 20.0,
            family: FigFont.display,
            weight: 600,
            color: const Color(0xff000000),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка профиля с обложкой и аватаром
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0a000000), blurRadius: 10.0, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Обложка / фон
                    Stack(
                      children: [
                        ProfileCover(
                          url: state.userProfileCoverUrl,
                          width: double.infinity,
                          height: 130.0,
                          radius: 0.0,
                          darken: false,
                        ),
                        if (_isUploadingCover)
                          Container(
                            height: 130.0,
                            color: Colors.black38,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        // Кнопка редактирования фона на обложке
                        Positioned(
                          top: 10.0,
                          right: 10.0,
                          child: Material(
                            color: Colors.black45,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                              tooltip: context.l10n.accountChangeCover,
                              onPressed: _isUploadingCover ? null : _showCoverOptions,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Аватар и данные пользователя
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      child: Column(
                        children: [
                          // Аватар сдвинут вверх, перекрывая обложку
                          Transform.translate(
                            offset: const Offset(0, -36.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x1a000000),
                                            blurRadius: 8.0,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ProfileAvatar(
                                        url: state.userAvatarUrl,
                                        initials: state.userInitials,
                                        size: 72.0,
                                        radius: 36.0,
                                      ),
                                    ),
                                    if (_isUploadingAvatar)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black45,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onTap: _isUploadingAvatar ? null : _showAvatarOptions,
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: const Color(0xffea812e),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 36.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18.0,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff000000),
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        RoleBadge(label: state.localizedRoleLabel(context.l10n)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Кнопки действий с фото и фоном
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isUploadingAvatar ? null : _showAvatarOptions,
                                  icon: const Icon(Icons.account_box_outlined, size: 16),
                                  label: Text(context.l10n.accountProfileAvatar, style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xff000000),
                                    side: const BorderSide(color: Color(0xffe5e5ea)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isUploadingCover ? null : _showCoverOptions,
                                  icon: const Icon(Icons.panorama_outlined, size: 16),
                                  label: Text(context.l10n.accountProfileCover, style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xff000000),
                                    side: const BorderSide(color: Color(0xffe5e5ea)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
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

              const SizedBox(height: 28.0),

              // Раздел: Личные данные
              Text(
                context.l10n.accountPersonalData,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              _buildInfoTile(
                icon: Icons.person_outline,
                label: context.l10n.accountFullName,
                value: name,
                onTap: () => _editField(
                  label: context.l10n.accountFullName,
                  currentValue: state.userName ?? '',
                  onSave: (val) => state.updateProfileName(val),
                ),
              ),
              // Телефон меняется только через повторную верификацию по SMS (§1.6 ТЗ)
              _buildInfoTile(
                icon: Icons.phone_outlined,
                label: context.l10n.accountPhoneNumber,
                value: phone,
                verified: true,
                subtitle: context.l10n.accountLinkedToAccount,
              ),
              _buildInfoTile(
                icon: Icons.chat_bubble_outline,
                label: context.l10n.accountWhatsapp,
                value: (state.userWhatsappPhone ?? '').isNotEmpty
                    ? state.userWhatsappPhone!
                    : context.l10n.accountNotSpecified,
                onTap: () => _editField(
                  label: context.l10n.accountWhatsapp,
                  currentValue: state.userWhatsappPhone ?? '',
                  onSave: (val) => state.updateWhatsappPhone(val.trim()),
                ),
                subtitle: context.l10n.accountWhatsappHint,
              ),
              _buildInfoTile(
                icon: Icons.badge_outlined,
                label: context.l10n.accountType,
                value: state.localizedRoleLabel(context.l10n),
              ),

              const SizedBox(height: 28.0),

              // Раздел: Безопасность
              Text(
                context.l10n.accountSecurityLogin,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              _buildActionTile(
                icon: Icons.lock_outline,
                title: context.l10n.accountChangePassword,
                onTap: _showChangePasswordSheet,
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 20, color: Color(0xffea812e)),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.accountTwoFactor,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff000000),
                            ),
                          ),
                          Text(
                            context.l10n.accountSmsProtection,
                            style: TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _twoFactorEnabled,
                      activeTrackColor: const Color(0xffea812e),
                      onChanged: (val) => setState(() => _twoFactorEnabled = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12.0),

              // Push о новых сообщениях. Сама лента уведомлений в приложении
              // от переключателя не зависит — сервер запись создаёт всегда.
              Container(
                key: const Key('settings_new_message'),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined, size: 20, color: Color(0xffea812e)),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.accountMessages,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff000000),
                            ),
                          ),
                          Text(
                            context.l10n.accountPushMessages,
                            style: TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _notificationSettings?.newMessageEnabled ?? false,
                      activeTrackColor: const Color(0xffea812e),
                      onChanged: _notificationSettings == null || _savingNotificationSettings
                          ? null
                          : _toggleNewMessage,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36.0),

              // Кнопка удаления аккаунта
              Center(
                child: TextButton.icon(
                  onPressed: _isDeletingAccount ? null : _deleteAccountDialog,
                  icon: _isDeletingAccount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xffd93025)),
                        )
                      : const Icon(Icons.delete_outline, color: Color(0xffd93025), size: 18),
                  label: Text(
                    _isDeletingAccount ? context.l10n.accountDeleting : context.l10n.accountDeleteAccount,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xffd93025),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool verified = false,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xffffffff),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xff7d7d7d)),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11.0, color: Color(0xff7d7d7d))),
                  const SizedBox(height: 2.0),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff000000),
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6.0),
                        const Icon(Icons.check_circle, size: 14, color: Color(0xff34c759)),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.0, color: Color(0xff9e9e9e)),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.edit_outlined, size: 18, color: Color(0xffea812e)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: const Color(0xffffffff),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xffea812e)),
            const SizedBox(width: 12.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                color: Color(0xff000000),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xffc7c7cc)),
          ],
        ),
      ),
    );
  }
}

/// Модальный экран смены пароля
class _PasswordChangeSheet extends StatefulWidget {
  const _PasswordChangeSheet();

  @override
  State<_PasswordChangeSheet> createState() => _PasswordChangeSheetState();
}

class _PasswordChangeSheetState extends State<_PasswordChangeSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = context.l10n.accountEnterNewPassword);
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _errorMessage = context.l10n.accountPasswordMinLen);
      return;
    }
    if (confirm.isEmpty) {
      setState(() => _errorMessage = context.l10n.accountRepeatNewPassword);
      return;
    }
    if (newPassword != confirm) {
      setState(() => _errorMessage = context.l10n.accountPasswordsNotMatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final state = AppScope.read(context);
      await state.changePassword(
        currentPassword: current.isNotEmpty ? current : null,
        newPassword: newPassword,
        confirmation: confirm,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(context.l10n.accountPasswordChanged),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String error = context.l10n.accountChangePasswordFailed;
      if (e is ApiException) {
        if (e.details.isNotEmpty) {
          final firstKey = e.details.keys.first;
          final val = e.details[firstKey];
          if (val is List && val.isNotEmpty) {
            error = '$val[0]';
          } else if (val is String) {
            error = val;
          } else {
            error = e.message;
          }
        } else {
          error = e.message;
        }
      } else {
        error = e.toString();
      }

      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.accountPasswordChangeTitle,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff000000),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xff7d7d7d)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                context.l10n.accountPasswordHint,
                style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
              ),
              const SizedBox(height: 20.0),

              // Текущий пароль
              TextField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: context.l10n.accountCurrentPassword,
                  hintText: context.l10n.accountIfSetBefore,
                  labelStyle: const TextStyle(color: Color(0xff7d7d7d)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xff7d7d7d),
                    ),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xffea812e), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xffe5e5ea), width: 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 14.0),

              // Новый пароль
              TextField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: context.l10n.accountNewPassword,
                  labelStyle: const TextStyle(color: Color(0xffea812e)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xff7d7d7d),
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xffea812e), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xffe5e5ea), width: 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 14.0),

              // Подтверждение
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: context.l10n.accountRepeatNewPassword,
                  labelStyle: const TextStyle(color: Color(0xffea812e)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xff7d7d7d),
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xffea812e), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xffe5e5ea), width: 1.0),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14.0),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xfffde8e8),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xfff8b4b4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xffd93025), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13.0,
                            color: Color(0xffd93025),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24.0),

              // Кнопка сохранения
              SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffea812e),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.l10n.accountSavePassword,
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
      ),
    );
  }
}
