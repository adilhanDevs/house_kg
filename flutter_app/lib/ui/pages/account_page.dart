import 'package:flutter/material.dart';

import '../../fig/fig.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _twoFactorEnabled = true;

  String _userName = 'Ташиев Камчыбек';
  String _userPhone = '+996 555 123 456';
  String _userEmail = 'tashiev.k@house.kg';
  String _userCity = 'Бишкек';

  Future<void> _editField({
    required String label,
    required String currentValue,
    required ValueChanged<String> onSave,
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

    if (newValue != null && newValue.isNotEmpty && mounted) {
      setState(() => onSave(newValue));
      ScaffoldMessenger.of(context).showSnackBar(
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
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xfffdf1e8),
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName.split(' ').map((e) => e[0]).take(2).join()
                                : 'ТК',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xffea812e),
                            ),
                          ),
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
                            _userName,
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
                                'PRO Риелтор • $_userCity',
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
                value: _userName,
                onTap: () => _editField(
                  label: 'Имя и Фамилия',
                  currentValue: _userName,
                  onSave: (val) => _userName = val,
                ),
              ),
              _buildInfoTile(
                icon: Icons.phone_outlined,
                label: 'Номер телефона',
                value: _userPhone,
                verified: true,
                onTap: () => _editField(
                  label: 'Номер телефона',
                  currentValue: _userPhone,
                  onSave: (val) => _userPhone = val,
                ),
              ),
              _buildInfoTile(
                icon: Icons.email_outlined,
                label: 'Электронная почта',
                value: _userEmail,
                onTap: () => _editField(
                  label: 'Электронная почта',
                  currentValue: _userEmail,
                  onSave: (val) => _userEmail = val,
                ),
              ),
              _buildInfoTile(
                icon: Icons.location_on_outlined,
                label: 'Город',
                value: _userCity,
                onTap: () => _editField(
                  label: 'Город',
                  currentValue: _userCity,
                  onSave: (val) => _userCity = val,
                ),
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
    required VoidCallback onTap,
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
