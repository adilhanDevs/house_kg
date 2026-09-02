// Обложку выбирает сервер. Клиент её только показывает.
//
// Раньше Listing.fromJson собирал список фото из media[], а cover_url
// добавлял в начало ТОЛЬКО если такой строки там ещё нет. Один и тот же
// снимок приходит разными вариантами размера (thumb против original), и от
// случайного совпадения строк зависело, что окажется обложкой: то, что
// выбрал сервер, или первый элемент галереи. Карточка и детальная страница
// из-за этого показывали разные фотографии.
import 'package:flutter_test/flutter_test.dart';

import 'package:house_kgz/data/listings.dart';

/// Ответ каталога: media[] в нём нет, только обложка.
Map<String, dynamic> listCard() => {
      'slug': 'technopark-3k-92',
      'cover_url': 'https://host/media/a_thumb.webp',
      'cover_media_id': 1,
      'photos_count': 2,
    };

/// Ответ детальной страницы: та же обложка плюс галерея.
Map<String, dynamic> detail({int coverMediaId = 1}) => {
      'slug': 'technopark-3k-92',
      'cover_url': 'https://host/media/a_thumb.webp',
      'cover_detail_url': 'https://host/media/a_medium.webp',
      'cover_media_id': coverMediaId,
      'media': [
        {'id': 1, 'kind': 'photo', 'url_original': 'https://host/media/a_original.webp'},
        {'id': 2, 'kind': 'photo', 'url_original': 'https://host/media/b_original.webp'},
      ],
    };

void main() {
  group('обложку задаёт сервер', () {
    test('A: обложка — cover_url, а не первый элемент media', () {
      final listing = Listing.fromJson(detail());

      expect(listing.photo, 'https://host/media/a_thumb.webp');
      expect(listing.photo, isNot('https://host/media/a_original.webp'));
      expect(listing.coverMediaId, 1);
    });

    test('B: обложкой может быть второе медиа — герой показывает именно его', () {
      final listing = Listing.fromJson(detail(coverMediaId: 2));

      expect(listing.coverMediaId, 2);
      // Галерея начинается с обложки, найденной по id, а не по адресу.
      expect(listing.photos.first, 'https://host/media/b_original.webp');
    });

    test('C: без обложки и без медиа галерея пуста, кадра из макета нет', () {
      final listing = Listing.fromJson({
        'slug': 'empty',
        'cover_url': null,
        'cover_media_id': null,
        'media': <dynamic>[],
      });

      expect(listing.photo, '');
      expect(listing.photos, isEmpty);
      expect(
        listing.photos.any((p) => p.startsWith('assets/')),
        isFalse,
        reason: 'ассет из макета не должен выдаваться за фотографию объекта',
      );
    });

    test('D: карточка и детальная сходятся на одной обложке', () {
      final card = Listing.fromJson(listCard());
      final page = Listing.fromJson(detail());

      expect(card.coverMediaId, page.coverMediaId);
      expect(card.photo, page.photo);
    });

    test('E: разные варианты одного снимка не сбивают выбор обложки', () {
      // thumb и original — один и тот же media id 1.
      final listing = Listing.fromJson(detail());

      expect(listing.photo, contains('a_thumb'));
      // В галерее этот снимок ровно один раз и крупным вариантом.
      final aVariants = listing.photos.where((p) => p.contains('a_')).toList();
      expect(aVariants, ['https://host/media/a_original.webp']);
    });
  });

  group('герой и галерея', () {
    test('герой берёт крупный вариант обложки', () {
      final listing = Listing.fromJson(detail());

      expect(listing.heroPhoto, 'https://host/media/a_medium.webp');
      expect(listing.photo, 'https://host/media/a_thumb.webp');
    });

    test('без cover_detail_url герой падает обратно на обложку карточки', () {
      final json = detail()..remove('cover_detail_url');
      final listing = Listing.fromJson(json);

      expect(listing.heroPhoto, listing.photo);
    });

    test('обложка не дублируется в галерее', () {
      final listing = Listing.fromJson(detail());

      expect(listing.photos.length, 2);
      expect(listing.photos.toSet().length, 2);
    });

    test('галерея сохраняет порядок сервера после обложки', () {
      final listing = Listing.fromJson({
        ...detail(coverMediaId: 2),
        'media': [
          {'id': 1, 'kind': 'photo', 'url_original': 'https://host/media/a_original.webp'},
          {'id': 2, 'kind': 'photo', 'url_original': 'https://host/media/b_original.webp'},
          {'id': 3, 'kind': 'photo', 'url_original': 'https://host/media/c_original.webp'},
        ],
      });

      expect(listing.photos, [
        'https://host/media/b_original.webp',
        'https://host/media/a_original.webp',
        'https://host/media/c_original.webp',
      ]);
    });

    test('видео в галерею фотографий не попадает', () {
      final listing = Listing.fromJson({
        ...detail(),
        'media': [
          {'id': 1, 'kind': 'photo', 'url_original': 'https://host/media/a_original.webp'},
          {'id': 9, 'kind': 'video', 'url': 'https://host/media/clip.mp4'},
        ],
      });

      expect(listing.photos.any((p) => p.endsWith('.mp4')), isFalse);
    });
  });

  group('устойчивость разбора', () {
    test('относительный адрес достраивается до абсолютного', () {
      final listing = Listing.fromJson({
        'slug': 'relative',
        'cover_url': '/api/v1/media/listings/a_thumb.webp',
        'cover_media_id': 1,
      });

      expect(listing.photo.startsWith('http'), isTrue);
      expect(listing.photo.endsWith('/api/v1/media/listings/a_thumb.webp'), isTrue);
    });

    test('старый ответ без cover_media_id не ломает разбор', () {
      final listing = Listing.fromJson({
        'slug': 'legacy',
        'cover_url': 'https://host/media/a_thumb.webp',
        'media': [
          {'id': 1, 'kind': 'photo', 'url_original': 'https://host/media/a_original.webp'},
        ],
      });

      expect(listing.photo, 'https://host/media/a_thumb.webp');
      expect(listing.coverMediaId, isNull);
      // Обложку в галерее не опознать без id — она добавляется первой отдельно.
      expect(listing.photos.first, 'https://host/media/a_thumb.webp');
    });
  });
}
