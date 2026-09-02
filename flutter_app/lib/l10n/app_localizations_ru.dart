// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'House KGZ';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get close => 'Закрыть';

  @override
  String get back => 'Назад';

  @override
  String get done => 'Готово';

  @override
  String get next => 'Далее';

  @override
  String get error => 'Ошибка';

  @override
  String get success => 'Успешно';

  @override
  String get retry => 'Повторить';

  @override
  String get apply => 'Применить';

  @override
  String get reset => 'Сбросить';

  @override
  String get clear => 'Очистить';

  @override
  String get search => 'Поиск';

  @override
  String get all => 'Все';

  @override
  String get loading => 'Загрузка...';

  @override
  String get empty => 'Ничего не найдено';

  @override
  String get tryAgain => 'Попробовать снова';

  @override
  String get dataLoadError => 'Не удалось загрузить данные';

  @override
  String get noInternet => 'Нет подключения к интернету';

  @override
  String get fillAllFields => 'Заполните все поля';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabCatalog => 'Поиск';

  @override
  String get tabHistory => 'История';

  @override
  String get tabFavourites => 'Избранное';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get langTitle => 'Язык';

  @override
  String get langRu => 'Русский';

  @override
  String get langKy => 'Кыргызский';

  @override
  String get langKyShort => 'Кыргызча';

  @override
  String get langRuShort => 'Русский';

  @override
  String get roleClient => 'Клиент';

  @override
  String get roleOwner => 'Собственник';

  @override
  String get roleRealtor => 'Риелтор';

  @override
  String get roleAgency => 'Агентство';

  @override
  String get rolePro => 'Исполнитель';

  @override
  String get kindHouse => 'Дома';

  @override
  String get kindApartment => 'Квартиры';

  @override
  String get kindPlot => 'Участки';

  @override
  String get kindNewBuilding => 'Новостройки';

  @override
  String get kindRoom => 'Комната';

  @override
  String get kindCommercial => 'Коммерция';

  @override
  String get sellerOwner => 'Только собственник';

  @override
  String get sellerRealtor => 'Риелторы';

  @override
  String get sellerAgency => 'Агентство недвижимости';

  @override
  String get statusDraft => 'Черновик';

  @override
  String get statusPending => 'На модерации';

  @override
  String get statusActive => 'Активно';

  @override
  String get statusRejected => 'Отклонено';

  @override
  String get statusArchived => 'В архиве';

  @override
  String get statusSold => 'Продано';

  @override
  String get welcomeTitle => 'Поиск недвижимости в Кыргызстане';

  @override
  String get welcomeSubtitle =>
      'Квартиры, дома, участки и коммерческая недвижимость';

  @override
  String get login => 'Войти';

  @override
  String get register => 'Зарегистрироваться';

  @override
  String get phone => 'Номер телефона';

  @override
  String get phoneHint => '+996 000 000 000';

  @override
  String get password => 'Пароль';

  @override
  String get passwordHint => 'Введите пароль';

  @override
  String get passwordConfirm => 'Подтверждение пароля';

  @override
  String get passwordConfirmHint => 'Повторите пароль';

  @override
  String get name => 'Имя';

  @override
  String get nameHint => 'Как к вам обращаться';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get dontHaveAccount => 'Нет аккаунта?';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get consentPrefix => 'Я согласен с ';

  @override
  String get consentTermsLink => 'условиями обработки персональных данных';

  @override
  String get consentRequired => 'Примите условия соглашения';

  @override
  String get invalidPhone => 'Введите корректный номер телефона';

  @override
  String get invalidPasswordLength => 'Пароль должен быть не менее 6 символов';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get enterName => 'Введите ваше имя';

  @override
  String get loginError => 'Ошибка авторизации';

  @override
  String get passwordResetTitle => 'Восстановление пароля';

  @override
  String get passwordResetSubtitle =>
      'Укажите номер телефона, и мы отправим код для сброса пароля';

  @override
  String get sendCode => 'Отправить код';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get newPasswordHint => 'Введите новый пароль';

  @override
  String get repeatNewPassword => 'Повторите новый пароль';

  @override
  String get savePassword => 'Сохранить пароль';

  @override
  String get codeTitle => 'Код подтверждения';

  @override
  String codeSubtitle(String phone) {
    return 'Введите 4-значный код, отправленный на номер $phone';
  }

  @override
  String resendCodeIn(int seconds) {
    return 'Повторить через $seconds сек.';
  }

  @override
  String get resendCode => 'Отправить код повторно';

  @override
  String get codeSending => 'Отправка кода...';

  @override
  String get homeCategories => 'Категории';

  @override
  String get homePopular => 'Популярные';

  @override
  String get homeFeatured => 'Рекомендованные';

  @override
  String get homeSeeAll => 'Посмотреть все';

  @override
  String get homeNewBuildings => 'Новостройки';

  @override
  String get homeSecondary => 'Вторичка';

  @override
  String get homeHouses => 'Дома';

  @override
  String get homePlots => 'Участки';

  @override
  String get homeCommercial => 'Коммерция';

  @override
  String get homeSearchHint => 'Поиск по адресу, району...';

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get catalogFilters => 'Фильтры';

  @override
  String get catalogPrice => 'Цена';

  @override
  String get catalogPriceFrom => 'от';

  @override
  String get catalogPriceTo => 'до';

  @override
  String get catalogRooms => 'Комнатность';

  @override
  String get catalogArea => 'Площадь, м²';

  @override
  String get catalogFloor => 'Этаж';

  @override
  String get catalogSeries => 'Серия дома';

  @override
  String get catalogSeries103 => 'Только 103 серия';

  @override
  String get catalogSecondaryOnly => 'Только вторичка';

  @override
  String get catalogSeller => 'Продавец';

  @override
  String get catalogPlotPurpose => 'Назначение участка';

  @override
  String get catalogCommercialPurpose => 'Назначение помещения';

  @override
  String get catalogBuildingLine => 'Линия';

  @override
  String catalogFoundCount(int count) {
    return 'Найдено объявлений: $count';
  }

  @override
  String get catalogShowListings => 'Показать объявления';

  @override
  String get catalogClearFilters => 'Сбросить фильтры';

  @override
  String get catalogSaveFilter => 'Сохранить фильтр';

  @override
  String get catalogSaveFilterTitle => 'Сохранение фильтра';

  @override
  String get catalogFilterName => 'Название фильтра';

  @override
  String get catalogFilterNameHint => 'Например, 2-комн. в центре';

  @override
  String get catalogSavedFilters => 'Мои фильтры';

  @override
  String get catalogNoSavedFilters => 'Нет сохраненных фильтров';

  @override
  String get listingCharacteristics => 'Характеристики';

  @override
  String get listingDescription => 'Описание';

  @override
  String get listingLocation => 'Расположение';

  @override
  String get listingSeller => 'Продавец';

  @override
  String get listingWrite => 'Написать';

  @override
  String get listingCall => 'Позвонить';

  @override
  String get listingShare => 'Поделиться';

  @override
  String get listingToFavourites => 'В избранное';

  @override
  String get listingInFavourites => 'В избранном';

  @override
  String get listingSimilar => 'Похожие объявления';

  @override
  String get listingPriceDrop => 'Снижение цены';

  @override
  String get listingRedBook => 'Красная книга';

  @override
  String get listingBelowMarket => 'Ниже рынка';

  @override
  String get listingPhotos => 'Фотообзор';

  @override
  String get listingVideo => 'Видеообзор';

  @override
  String get listingDownloadPhoto => 'Скачать фото';

  @override
  String get listingDownloadAllowed => 'Скачивание разрешено';

  @override
  String listingViewsCount(int count) {
    return 'Количество просмотров: $count';
  }

  @override
  String listingPublishedAt(String date) {
    return 'Опубликовано: $date';
  }

  @override
  String listingRoomsCount(int count) {
    return '$count-комн.';
  }

  @override
  String listingAreaSqM(String area) {
    return '$area м²';
  }

  @override
  String listingFloorOf(int floor, int total) {
    return '$floor/$total этаж';
  }

  @override
  String get adCreate => 'Подать объявление';

  @override
  String get adEdit => 'Изменить объявление';

  @override
  String get adPublish => 'Опубликовать';

  @override
  String get adSaveDraft => 'Сохранить черновик';

  @override
  String get adCategory => 'Категория';

  @override
  String get adCity => 'Город';

  @override
  String get adDistrict => 'Район';

  @override
  String get adAddress => 'Адрес';

  @override
  String get adPriceUSD => 'Цена в \$';

  @override
  String get adPriceKGS => 'Цена в сомах';

  @override
  String get adRooms => 'Количество комнат';

  @override
  String get adTotalArea => 'Общая площадь (м²)';

  @override
  String get adLivingArea => 'Жилая площадь (м²)';

  @override
  String get adKitchenArea => 'Площадь кухни (м²)';

  @override
  String get adFloor => 'Этаж';

  @override
  String get adFloorsTotal => 'Этажность дома';

  @override
  String get adSeries => 'Серия';

  @override
  String get adDescription => 'Описание объекта';

  @override
  String get adDescriptionHint => 'Расскажите подробнее об объекте...';

  @override
  String get adPhotosTitle => 'Фотографии';

  @override
  String get adPhotosSubtitle =>
      'Добавьте до 20 фотографий. Первое фото станет обложкой.';

  @override
  String get adAddPhotos => 'Добавить фото';

  @override
  String get adAddVideo => 'Добавить видео';

  @override
  String get adMakeCover => 'Сделать обложкой';

  @override
  String get adDeleteMedia => 'Удалить';

  @override
  String get adCoverBadge => 'Обложка';

  @override
  String get adPromoTitle => 'Продвижение объявления';

  @override
  String adPromoDays(int days) {
    return '$days дней';
  }

  @override
  String adPromoCost(int cost) {
    return '$cost кирпичей';
  }

  @override
  String get adPreview => 'Предпросмотр';

  @override
  String get adPublishedSuccess => 'Объявление успешно опубликовано!';

  @override
  String get adSavedSuccess => 'Объявление сохранено';

  @override
  String get adMustHavePhotos => 'Добавьте хотя бы одну фотографию';

  @override
  String get adMustSelectCategory => 'Выберите категорию';

  @override
  String get favouritesTitle => 'Вам понравилось';

  @override
  String get favouritesEmpty => 'Нет избранных объявлений';

  @override
  String get favouritesEmptySubtitle =>
      'Нажимайте на сердечко в карточках объектов, чтобы сохранить их здесь';

  @override
  String get historyTitle => 'История просмотров';

  @override
  String get historyEmpty => 'Вы еще не просматривали объявления';

  @override
  String get historyClear => 'Очистить историю';

  @override
  String get historyClearConfirmTitle => 'Очистить историю просмотров?';

  @override
  String get historyClearConfirmBody =>
      'Все просмотренные объявления будут удалены из истории.';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsLatest => 'Последние уведомления';

  @override
  String get notificationsEmpty => 'Уведомлений пока нет';

  @override
  String get notificationsMarkAllRead => 'Отметить все как прочитанные';

  @override
  String get priceDecreased => 'Цена снизилась';

  @override
  String get messagesTitle => 'Сообщения';

  @override
  String get messagesEmpty => 'Нет сообщений';

  @override
  String get chatInputHint => 'Введите сообщение...';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatNoDialogs => 'Диалогов пока нет';

  @override
  String get profileTitle => 'Ваш профиль';

  @override
  String get profileNoName => 'Без имени';

  @override
  String get profileFavoritesRow => 'Вам понравилось';

  @override
  String get profileTariffsRow => 'Тарифы';

  @override
  String get profileNotificationsRow => 'Уведомления';

  @override
  String get profileAccountRow => 'Аккаунт';

  @override
  String get profileSupportRow => 'Служба поддержки';

  @override
  String get profileHistoryRow => 'История пополнения и трат';

  @override
  String get profileLanguageRow => 'Язык';

  @override
  String get profileSellButton => 'Продать недвижимость';

  @override
  String get profileLogout => 'Выйти из аккаунта';

  @override
  String get profileLogoutConfirmTitle => 'Выйти из аккаунта?';

  @override
  String get profileLogoutConfirmBody =>
      'Избранное и фильтры этого сеанса будут забыты.';

  @override
  String get profileLoggingOut => 'Выход...';

  @override
  String get proProfileTitle => 'Профиль продавца';

  @override
  String proSold(int count) {
    return 'Продано: $count';
  }

  @override
  String proObjectsCount(int count) {
    return '$count объектов недвижимости';
  }

  @override
  String get proAddListing => 'Добавить объявление';

  @override
  String get proMyListings => 'Мои объявления';

  @override
  String get proEmptyNewBuildings => 'Нет новостроек';

  @override
  String get proEmptyApartments => 'Нет квартир';

  @override
  String get proEmptyCommercial => 'Нет коммерческих объектов';

  @override
  String get proEmptyHouses => 'Нет домов';

  @override
  String get proEmptyPlots => 'Нет участков';

  @override
  String get proEmptyRooms => 'Нет комнат';

  @override
  String proWalletBalance(int count) {
    return '$count кирпичей';
  }

  @override
  String get proWalletTitle => 'Баланс';

  @override
  String get proTopUp => 'Пополнить';

  @override
  String get proSignupTitle => 'Регистрация продавца';

  @override
  String get proSignupIin => 'ИНН / ПИН';

  @override
  String get proSignupIinHint => '14 цифр';

  @override
  String get proIdentityTitle => 'Подтверждение личности';

  @override
  String get proIdentitySelfie => 'Сделайте селфи';

  @override
  String get proIdentityPassport => 'Фото паспорта';

  @override
  String get accountTitle => 'Личные данные';

  @override
  String get accountName => 'Имя и фамилия';

  @override
  String get accountWhatsapp => 'Номер WhatsApp';

  @override
  String get accountChangeAvatar => 'Изменить фото';

  @override
  String get accountChangeCover => 'Изменить обложку';

  @override
  String get accountDeletePhoto => 'Удалить фото';

  @override
  String get accountChangePassword => 'Сменить пароль';

  @override
  String get accountOldPassword => 'Старый пароль';

  @override
  String get accountNewPassword => 'Новый пароль';

  @override
  String get accountRepeatPassword => 'Повторите новый пароль';

  @override
  String get accountPasswordChanged => 'Пароль успешно изменен';

  @override
  String get accountDeleteAccount => 'Удалить аккаунт';

  @override
  String get accountDeleteConfirmTitle => 'Удалить аккаунт?';

  @override
  String get accountDeleteConfirmBody =>
      'Это действие необратимо. Все ваши данные и объявления будут удалены.';

  @override
  String get tariffsTitle => 'Тарифы';

  @override
  String get tariffsCurrent => 'Текущий тариф';

  @override
  String get tariffsConnect => 'Подключить';

  @override
  String get tariffsExtend => 'Продлить';

  @override
  String get tariffsFree => 'Бесплатный';

  @override
  String tariffsPerMonth(String price) {
    return '$price сом/мес';
  }

  @override
  String tariffsPayBricks(int count) {
    return 'Оплатить кирпичами ($count)';
  }

  @override
  String tariffsPaySom(String price) {
    return 'Оплатить $price сом';
  }

  @override
  String get topupTitle => 'Пополнение баланса';

  @override
  String get topupAmount => 'Сумма пополнения (сом)';

  @override
  String get topupBonusHint => '1 сом = 1 кирпич + 10% бонус';

  @override
  String topupYouWillGet(int bricks) {
    return 'Вам будет начислено: $bricks кирпичей';
  }

  @override
  String topupPayButton(String amount) {
    return 'Оплатить $amount сом';
  }

  @override
  String get topupSelectMethod => 'Выберите способ оплаты';

  @override
  String get walletHistoryTitle => 'История пополнения и трат';

  @override
  String get walletTabAll => 'Все операции';

  @override
  String get walletTabTopup => 'Пополнение';

  @override
  String get walletTabSpend => 'Списание';

  @override
  String get walletTabBonus => 'Бонусы';

  @override
  String get walletHistoryEmpty => 'Нет операций';

  @override
  String get supportTitle => 'Служба поддержки';

  @override
  String get supportFaq => 'Часто задаваемые вопросы';

  @override
  String get supportWhatsapp => 'Написать в WhatsApp';

  @override
  String get supportCall => 'Позвонить в поддержку';

  @override
  String get supportEmail => 'Написать на почту';

  @override
  String get dateToday => 'Сегодня';

  @override
  String get dateYesterday => 'Вчера';

  @override
  String dateDaysAgo(int days) {
    return '$days дн. назад';
  }

  @override
  String get filterPlotPurpose => 'Назначение участка';

  @override
  String get filterCommercialPurpose => 'Назначение объекта';

  @override
  String get filterBuildingLine => 'Линия застройки';

  @override
  String get filterSeller => 'Кто продаёт';

  @override
  String get chatTitle => 'Сообщения';

  @override
  String get tariffsSubtitle =>
      'Выберите подходящий тариф для эффективного продвижения объектов';

  @override
  String get historyAllTypes => 'Все типы';

  @override
  String get historySubtitle =>
      'Здесь объекты, которые вы открывали за последние 30 дней. Нажмите «Выбрать», чтобы убрать их из истории.';

  @override
  String get historyClearSelection => 'Выберите объекты';

  @override
  String historyRemovePicked(int count) {
    return 'Убрать из истории ($count)';
  }

  @override
  String get walletFilterAll => 'Все операции';

  @override
  String get walletFilterTopup => 'Пополнение';

  @override
  String get walletFilterSpend => 'Списание';

  @override
  String get walletFilterBonus => 'Бонусы';

  @override
  String get walletHistorySubtitle =>
      'История операций кошелька и начисления бонусов';

  @override
  String get walletEmpty => 'Нет операций';

  @override
  String get filterPropertyType => 'Тип недвижимости';

  @override
  String get filterSecondary => 'Вторичка';

  @override
  String get filterSeries103 => '103 серия';

  @override
  String get filterRoomsCount => 'Количество комнат';

  @override
  String get filterRoomsUnit => 'комн.';

  @override
  String get filterArea => 'Площадь';

  @override
  String get filterCustomArea => 'Своя площадь (м²)';

  @override
  String get filterPrice => 'Стоимость';

  @override
  String get filterPriceFrom => 'От';

  @override
  String get filterPriceTo => 'До';

  @override
  String get langRussian => 'Русский';

  @override
  String get langKyrgyz => 'Кыргызча';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageKyrgyz => 'Кыргызча';

  @override
  String get historySelect => 'Выбрать';

  @override
  String get historyDone => 'Готово';

  @override
  String get historyOrderTitle => 'Сортировка';

  @override
  String get historyOrderNewest => 'Сначала новые';

  @override
  String get historyOrderOldest => 'Сначала старые';

  @override
  String get historyPeriodTitle => 'Период';

  @override
  String get historyPeriodAll => 'За всё время';

  @override
  String get historyPeriodToday => 'За сегодня';

  @override
  String get historyPeriodWeek => 'За неделю';

  @override
  String get historyPeriodMonth => 'За месяц';

  @override
  String get chatStart => 'Начните диалог с продавцом';

  @override
  String get chatEmpty => 'Диалогов пока нет';

  @override
  String get filterTitle => 'Фильтры';

  @override
  String filterShowVariants(int count) {
    return 'Показать $count вариантов';
  }

  @override
  String get contactSeller => 'Связаться с продавцом';

  @override
  String get contactOwner => 'Связаться с собственником';

  @override
  String get contactRealtor => 'Связаться с риелтором';

  @override
  String get contactAgency => 'Связаться с агентством';

  @override
  String sellerObjectsCount(int count) {
    return '$count объектов недвижимости';
  }

  @override
  String sellerSoldCount(int count) {
    return 'Продано: $count объектов';
  }

  @override
  String get sellerNoListings =>
      'У продавца пока нет объявлений в этой категории';

  @override
  String get sellerThisIsYou => 'Это ваш профиль';

  @override
  String get sellerMustLoginToWrite => 'Войдите, чтобы написать продавцу';

  @override
  String get sellerNotFound => 'Продавец не определён';

  @override
  String get sellerNoListingToDiscuss =>
      'Не удалось определить объявление для переписки';
}
