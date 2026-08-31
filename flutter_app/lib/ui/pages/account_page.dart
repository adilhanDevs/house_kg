import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../fig/fig.dart';
import '../widgets/profile_identity.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _twoFactorEnabled = true;

  @override
  void initState() {
    super.initState();
    // Карточка показывает данные из `GET /users/me/`, а не заглушки макета.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).fetchProfile();
    });
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
                    Text(
                      'Редактировать: $label',
                      style: const TextStyle(
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
                      if (val.isNotEmpty) {
                        Navigator.of(context).pop(val);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffea812e),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0,
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

    if (newValue == null || newValue.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await onSave(newValue);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Данные успешно обновлены!'),
            ],
          ),
          backgroundColor: Color(0xff34c759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить: $e'),
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
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Все ваши объявления, баланс кирпичей и история будут безвозвратно удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Color(0xffd93025))),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запрос на удаление аккаунта отправлен'),
          backgroundColor: Color(0xffd93025),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = (state.userName ?? '').isNotEmpty ? state.userName! : 'Без имени';
    final phone = (state.userPhone ?? '').isNotEmpty ? state.userPhone! : 'Не указан';

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
          'Аккаунт',
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
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка профиля
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0a000000), blurRadius: 10.0, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ProfileAvatar(
                          url: state.userAvatarUrl,
                          initials: state.userInitials,
                          size: 64.0,
                          radius: 32.0,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xff34c759),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
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
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, size: 16, color: Color(0xffea812e)),
                              const SizedBox(width: 4.0),
                              Text(
                                state.roleLabel,
                                style: const TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xff7d7d7d),
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
              const Text(
                'Личные данные',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              _buildInfoTile(
                icon: Icons.person_outline,
                label: 'Имя и Фамилия',
                value: name,
                onTap: () => _editField(
                  label: 'Имя и Фамилия',
                  currentValue: state.userName ?? '',
                  onSave: (val) => state.updateProfileName(val),
                ),
              ),
              // Телефон меняется только через повторную верификацию по SMS,
              // поэтому здесь он показан, но не редактируется.
              _buildInfoTile(
                icon: Icons.phone_outlined,
                label: 'Номер телефона',
                value: phone,
                verified: true,
              ),
              _buildInfoTile(
                icon: Icons.badge_outlined,
                label: 'Тип аккаунта',
                value: state.roleLabel,
              ),

              const SizedBox(height: 28.0),

              // Раздел: Безопасность
              const Text(
                'Безопасность и вход',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              _buildActionTile(
                icon: Icons.lock_outline,
                title: 'Изменить пароль',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Форма смены пароля отправлена на email'),
                      backgroundColor: Color(0xffea812e),
                    ),
                  );
                },
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Двухфакторная защита (2FA)',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff000000),
                            ),
                          ),
                          Text(
                            'Защита входа через СМС',
                            style: TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _twoFactorEnabled,
                      activeColor: const Color(0xffea812e),
                      onChanged: (val) => setState(() => _twoFactorEnabled = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36.0),

              // Кнопка удаления аккаунта
              Center(
                child: TextButton.icon(
                  onPressed: _deleteAccountDialog,
                  icon: const Icon(Icons.delete_outline, color: Color(0xffd93025), size: 18),
                  label: const Text(
                    'Удалить аккаунт',
                    style: TextStyle(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.0, color: Color(0xff7d7d7d))),
                const SizedBox(height: 2.0),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff000000),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6.0),
                      const Icon(Icons.check_circle, size: 14, color: Color(0xff34c759)),
                    ],
                  ],
                ),
              ],
            ),
            const Spacer(),
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
