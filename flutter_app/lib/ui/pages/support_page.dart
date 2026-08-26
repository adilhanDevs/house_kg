import 'package:flutter/material.dart';

import '../../fig/fig.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final TextEditingController _msgController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _msgController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Сообщение отправлено! Ответим в течение 5 минут.'),
            ],
          ),
          backgroundColor: const Color(0xff34c759),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
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
          'Служба поддержки',
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
              // Шапка поддержки
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfffdf1e8), Color(0xfffff8f3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(color: const Color(0x33ea812e), width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Color(0xffea812e),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Мы на связи 24/7',
                                style: TextStyle(
                                  fontSize: 17.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff000000),
                                ),
                              ),
                              SizedBox(width: 6.0),
                              Icon(Icons.circle, size: 10, color: Color(0xff34c759)),
                            ],
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            'Оперативно ответим на любые вопросы по объектам, балансу кирпичей и PRO подписке',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Color(0xff555555),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24.0),

              // Раздел: Способы быстрой связи
              const Text(
                'Быстрая связь',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              Row(
                children: [
                  Expanded(
                    child: _buildContactCard(
                      icon: Icons.send_rounded,
                      iconColor: const Color(0xff29a9ea),
                      title: 'Telegram',
                      subtitle: '@house_kg_bot',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Открываем бот поддержки Telegram...'),
                            backgroundColor: Color(0xff29a9ea),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildContactCard(
                      icon: Icons.phone_in_talk_rounded,
                      iconColor: const Color(0xff34c759),
                      title: 'Позвонить',
                      subtitle: '+996 (312) 998-877',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Набор номера поддержки +996 (312) 998-877'),
                            backgroundColor: Color(0xff34c759),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24.0),

              // Написать нам напрямую
              const Text(
                'Задать вопрос напрямую',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _msgController,
                      maxLines: 4,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Опишите вашу проблему или вопрос...',
                        hintStyle: TextStyle(fontSize: 14.0, color: Color(0xffa2a2a7)),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSending ? null : _sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffea812e),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          ),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined, size: 18),
                          label: Text(_isSending ? 'Отправка...' : 'Отправить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28.0),

              // Раздел FAQ
              const Text(
                'Часто задаваемые вопросы',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 12.0),

              _buildFaqItem(
                question: 'Как пополнить баланс кирпичей?',
                answer:
                    'Перейдите на вкладку «Профиль», нажмите на кнопку «Пополнить» на панели баланса и выберите удобный способ оплаты (MBANK, Элсом, Visa, О!Деньги).',
              ),
              _buildFaqItem(
                question: 'Как получить статус PRO агентства?',
                answer:
                    'Пройдите быструю верификацию в профиле, загрузив фото вашего риелторского удостоверения или паспорта.',
              ),
              _buildFaqItem(
                question: 'Сколько списывается кирпичей за публикацию?',
                answer:
                    'Списание зависит от категории объекта и дополнительных опций (выделение цветом, топ списка, автоподъем).',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: const Color(0xffffffff),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8.0, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 12.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
                color: Color(0xff000000),
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        childrenPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 14.0),
        iconColor: const Color(0xffea812e),
        collapsedIconColor: const Color(0xff7d7d7d),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: Color(0xff000000),
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13.0,
              color: Color(0xff555555),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
