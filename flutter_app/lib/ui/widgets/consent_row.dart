// Галка «принимаю соглашение об обработке персональных данных».
//
// Версию документа задаёт сервер, поэтому пока она не загрузилась —
// показываем ожидание, а не готовую к нажатию галку: принять документ,
// которого ещё нет, нельзя.
import 'package:flutter/material.dart';

/// Галка «принимаю соглашение» с ссылкой на текст.
class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.value,
    required this.loading,
    required this.error,
    required this.onChanged,
  });

  final bool value;
  final bool loading;
  final String? error;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 22.0,
        child: Row(
          children: [
            SizedBox(
              width: 16.0,
              height: 16.0,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xffea812e)),
            ),
            SizedBox(width: 10.0),
            Text(
              'Загружаем соглашение…',
              style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Text(
        error!,
        style: const TextStyle(fontSize: 13.0, color: Color(0xffd93025)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24.0,
          height: 24.0,
          child: Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
            activeColor: const Color(0xffea812e),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: const Text(
              'Принимаю соглашение об обработке персональных данных',
              style: TextStyle(fontSize: 13.0, height: 1.3, color: Color(0xff1c1939)),
            ),
          ),
        ),
      ],
    );
  }
}
