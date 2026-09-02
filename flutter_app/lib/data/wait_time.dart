// Человеческое время ожидания для 429.
//
// Сервер отдаёт `retry_after` в секундах, и это единственное авторитетное
// число: DRF берёт максимум по всем сработавшим ограничениям сразу. Раньше
// оно попадало на экран как есть — «Повторите через 3062 секунды», — и рядом
// работал собственный отсчёт клиента на 60 секунд, из-за чего казалось, что
// действуют несколько разных таймеров.
library;

/// Русское склонение: 1 секунда, 2 секунды, 5 секунд.
String _plural(int value, String one, String few, String many) {
  final mod100 = value % 100;
  if (mod100 >= 11 && mod100 <= 14) return many;
  switch (value % 10) {
    case 1:
      return one;
    case 2:
    case 3:
    case 4:
      return few;
    default:
      return many;
  }
}

/// «42 секунды», «12 минут», «час», «2 часа».
String formatWait(int seconds) {
  if (seconds <= 0) return 'сейчас';

  if (seconds < 60) {
    return '$seconds ${_plural(seconds, 'секунду', 'секунды', 'секунд')}';
  }

  if (seconds < 3600) {
    // Округляем вверх: сказать «через 1 минуту» за 90 секунд до разблокировки
    // хуже, чем «через 2 минуты».
    final minutes = (seconds / 60).ceil();
    return '$minutes ${_plural(minutes, 'минуту', 'минуты', 'минут')}';
  }

  // Винительный падеж после «через»: час, 2 часа, 5 часов.
  final hours = (seconds / 3600).round();
  if (hours <= 1) return 'час';
  return '$hours ${_plural(hours, 'час', 'часа', 'часов')}';
}

/// Готовая фраза для баннера об ошибке.
String waitMessage(int seconds) => 'Повторите через ${formatWait(seconds)}.';
