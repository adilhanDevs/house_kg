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
  String homeGreeting(String name) {
    return 'Здравствуйте, $name!';
  }

  @override
  String get homeGreetingGuest => 'Здравствуйте!';

  @override
  String get homeCategories => 'Категории';

  @override
  String get homePopular => 'Популярные';

  @override
  String get homeFeatured => 'Рекомендованные';

  @override
  String get homeSeeAll => 'Посмотреть все';

  @override
  String get homeNewPositions => 'Новые позиции';

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
  String get homeNoNewListings => 'Пока нет новых объявлений';

  @override
  String cardRoomsShort(int count) {
    return '$count-комн.';
  }

  @override
  String cardAreaMeters(String area) {
    return '$areaм';
  }

  @override
  String cardFloor(int floor) {
    return '$floor этаж';
  }

  @override
  String cardLandAreaSotka(String area) {
    return '$area сот.';
  }

  @override
  String get cardPlot => 'Участок';

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
  String get notificationsProfileEmpty => 'У вас пока нет уведомлений';

  @override
  String get notificationsLoadError => 'Не удалось загрузить уведомления';

  @override
  String get notificationFallbackTitle => 'Уведомление';

  @override
  String get notificationTestPushTitle => 'House KG — проверка прочтения';

  @override
  String get notificationTestPushBody =>
      'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.';

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
  String get profileSettingsTitle => 'Настройки';

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
  String get proAddFirstListing => 'Добавьте первый объект';

  @override
  String get proMyListings => 'Мои объявления';

  @override
  String get proAllListings => 'Все объявления';

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
  String get supportOnlineTitle => 'Мы на связи 24/7';

  @override
  String get supportOnlineBody =>
      'Оперативно ответим на любые вопросы по объектам, балансу кирпичей и PRO подписке';

  @override
  String get supportQuickContact => 'Быстрая связь';

  @override
  String get supportCallShort => 'Позвонить';

  @override
  String get supportDirectQuestion => 'Задать вопрос напрямую';

  @override
  String get supportMessageHint => 'Опишите вашу проблему или вопрос...';

  @override
  String get supportSend => 'Отправить';

  @override
  String get supportSending => 'Отправка...';

  @override
  String get supportSent => 'Сообщение отправлено! Ответим в течение 5 минут.';

  @override
  String get supportOpenLinkError => 'Не удалось открыть ссылку';

  @override
  String get supportFaqBalanceQuestion => 'Как пополнить баланс кирпичей?';

  @override
  String get supportFaqBalanceAnswer =>
      'Перейдите на вкладку «Профиль», нажмите на кнопку «Пополнить» на панели баланса и выберите удобный способ оплаты (MBANK, Элсом, Visa, О!Деньги).';

  @override
  String get supportFaqProQuestion => 'Как получить статус PRO агентства?';

  @override
  String get supportFaqProAnswer =>
      'Пройдите быструю верификацию в профиле, загрузив фото вашего риелторского удостоверения или паспорта.';

  @override
  String get supportFaqBricksQuestion =>
      'Сколько списывается кирпичей за публикацию?';

  @override
  String get supportFaqBricksAnswer =>
      'Списание зависит от категории объекта и дополнительных опций (выделение цветом, топ списка, автоподъем).';

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

  @override
  String get passwordTooShort => 'Пароль должен быть не короче 8 символов';

  @override
  String get addListingSelectDistrictHints => 'Выберите район Бишкека';

  @override
  String get addListingSelectDistrict => 'Выберите район';

  @override
  String get addListingErrDistrict => 'Пожалуйста, выберите район';

  @override
  String get addListingErrArea => 'Пожалуйста, укажите квадратуру объекта';

  @override
  String get addListingErrPlotArea => 'Пожалуйста, укажите площадь участка';

  @override
  String get addListingErrPrice => 'Пожалуйста, укажите цену объекта';

  @override
  String get addListingTitle => 'Добавить недвижимость';

  @override
  String get addListingSubtitle => 'Заполните основные параметры объекта';

  @override
  String get addListingPropertyKind => 'Тип недвижимости';

  @override
  String get addListingDistrict => 'Район';

  @override
  String get addListingArea => 'Квадратура';

  @override
  String get addListingFloor => 'Этаж';

  @override
  String get addListingTotalFloors => 'Кол-во этажей в здании';

  @override
  String get addListingBuilder => 'Строительная компания';

  @override
  String get addListingSelectBuilder => 'Выберите застройщика';

  @override
  String get addListingBuilderHint => 'Ихлас, Авангард, Elite House и др.';

  @override
  String get addListingPlotArea => 'Площадь участка, соток';

  @override
  String get addListingPlotPurpose => 'Назначение участка';

  @override
  String get addListingCommercialPurpose => 'Назначение помещения';

  @override
  String get addListingBuildingLine => 'Линия';

  @override
  String get addListingRoomsCount => 'Количество комнат';

  @override
  String get addListingRoomAreas => 'Площади комнат';

  @override
  String get addListingRoomName => 'Название комнаты';

  @override
  String get addListingSelectRoom => 'Выберите комнату или впишите свою';

  @override
  String get addListingRoomExample => 'Например, гардеробная';

  @override
  String get addListingAreaSqM => 'Площадь (м²)';

  @override
  String get addListingSqM => 'м²';

  @override
  String get addListingOptionalArea => 'Необязательно, например 3.2';

  @override
  String get addListingDelete => 'Удалить';

  @override
  String get addListingAddRoom => 'Добавить комнату';

  @override
  String get addListingRoomsHint => 'Добавьте только те комнаты, которые есть';

  @override
  String get addListingStreet => 'Улица и номер дома';

  @override
  String get addListingStreetHint => 'например, ул. Аалы Токомбаева, 21/3';

  @override
  String get addListingAddressTitle => 'Улица / Адрес';

  @override
  String get addListingSeries => 'Серия дома';

  @override
  String get addListingCondition => 'Состояние / Ремонт';

  @override
  String get addListingConditionTitle => 'Состояние и ремонт';

  @override
  String get addListingHeating => 'Отопление';

  @override
  String get addListingFurniture => 'Мебель';

  @override
  String get addListingAmenities => 'Удобства и состояние';

  @override
  String get addListingCeilingHeight => 'Высота потолков, м';

  @override
  String get addListingSecondary => 'Вторичное жильё';

  @override
  String get addListingSeparateEntrance => 'Отдельный вход';

  @override
  String get addListingHas => 'Есть';

  @override
  String get addListingHasNot => 'Нет';

  @override
  String get addListingPrice => 'Цена';

  @override
  String get addListingPriceUSDTitle => 'Стоимость (\$ USD)';

  @override
  String get addListingMortgagePossible => 'Возможна ипотека';

  @override
  String get addListingMortgageTitle => 'Возможность ипотеки';

  @override
  String get addListingExchangePossible => 'Возможен обмен';

  @override
  String get addListingExchangeTitle => 'Возможность обмена';

  @override
  String get addListingDescTitle => 'Описание';

  @override
  String get addListingDescLabel => 'Описание объекта';

  @override
  String get addListingDescHint =>
      'Расскажите об объекте подробнее: ремонт, вид из окна, соседи, инфраструктура рядом...';

  @override
  String get addListingDescPlaceholder =>
      'Школа, парк, остановка — что рядом с объектом';

  @override
  String get addListingMoreInfo => 'Подробнее об объекте';

  @override
  String get addListingMoreInfoSubtitle =>
      'Расскажите об объекте: ремонт, окружение, что рядом';

  @override
  String get addListingContactsTitle => 'Контакты и ключевые места';

  @override
  String get addListingContactsSubtitle =>
      'Кому звонить и что рядом с объектом';

  @override
  String get addListingContactName => 'Имя для связи';

  @override
  String get addListingContactNameHint => 'Если отличается от профиля';

  @override
  String get addListingContactPhone => 'Телефон для связи';

  @override
  String get addListingKeyPlaces => 'Ключевые места';

  @override
  String get addListingWhoAreYou => 'Вы являетесь?';

  @override
  String get addListingSellerOwner => 'Собственником';

  @override
  String get addListingSellerRealtor => 'Риелтором';

  @override
  String get addListingDirectBuy => 'Прямая покупка';

  @override
  String get addListingNext => 'Далее';

  @override
  String get addListingCancel => 'Отмена';

  @override
  String get addListingSave => 'Сохранить';

  @override
  String get addListingEdit => 'Изменить';

  @override
  String get addListingPhotosTitleMain => 'Фотографии объекта';

  @override
  String get addListingPhotosEdit => 'Добавить/изменить фотографии';

  @override
  String get addListingVideoTitleMain => 'Видеоролик объекта';

  @override
  String get addListingVideoWatch => 'Смотреть видеообзор REELS';

  @override
  String get addListingVideoAdd => 'Добавить видеоролик';

  @override
  String get addListingBasicInfo => 'Основная информация';

  @override
  String get addListingEditTitle => 'Изменить объявление';

  @override
  String get addListingEditingTitle => 'Редактирование объявления';

  @override
  String get addListingSaveChanges => 'Сохранить изменения';

  @override
  String get addListingArchive => 'Снять с публикации (в архив)';

  @override
  String get addListingArchiveConfirm => 'Снять с публикации?';

  @override
  String get addListingArchiveDesc =>
      'Объявление переместится в архив и не будет видно в каталоге.';

  @override
  String get addListingUpdatedSuccess => 'Объявление успешно обновлено!';

  @override
  String get addListingPendingSuccess => 'Объявление отправлено на модерацию!';

  @override
  String get addListingPublishedNoPromo =>
      'Объявление опубликовано, но продвижение не оплачено';

  @override
  String get addListingArchivedSuccess => 'Объявление перемещено в архив';

  @override
  String addListingErrorSave(Object error) {
    return 'Ошибка сохранения: \$e';
  }

  @override
  String addListingErrorArchive(Object error) {
    return 'Ошибка архивации: \$e';
  }

  @override
  String get addListingUnarchivedSuccess =>
      'Объявление возвращено из архива и опубликовано!';

  @override
  String get addListingRepublish => 'Опубликовать снова';

  @override
  String get addListingToPreview => 'К предпросмотру';

  @override
  String get addListingPreview => 'Предпросмотр';

  @override
  String get addListingYourAd => 'Ваше объявление';

  @override
  String get addListingPublishingTitle => 'Публикация объявления';

  @override
  String get addListingPublish => 'Опубликовать';

  @override
  String get addListingPublishing => 'Публикуем...';

  @override
  String addListingErrorPublish(Object error) {
    return 'Ошибка публикации: \$e';
  }

  @override
  String get addListingRetry => 'Повторить';

  @override
  String get addListingPromotion => 'Продвижение';

  @override
  String get addListingContinueNoPromo => 'Продолжить без продвижения';

  @override
  String get addListingPromoTopup => 'Пополнение на продвижение объявления';

  @override
  String get addListingEnterAmount => 'Введите сумму';

  @override
  String get addListingSpendBricks => 'Списать кирпичи';

  @override
  String get addListingPromoDays => 'Количество дней';

  @override
  String get addListingEnterValue => 'Введите значение';

  @override
  String get addListingPromoExact => 'Использовать точное продвижение';

  @override
  String get addListingPromoClientBase => 'Использовать клиентскую базу';

  @override
  String get addListingPromoWhatsapp => 'Использовать Whatsapp базу';

  @override
  String get addListingPublishedPromoSuccess =>
      'Объявление успешно опубликовано и продвинуто!';

  @override
  String get addListingPublishedSuccess2 => 'Объявление успешно опубликовано!';

  @override
  String addListingPromoNotPaid(Object message) {
    return 'Продвижение не оплачено: \$message';
  }

  @override
  String addListingPromoCostError(Object error) {
    return 'Не удалось получить стоимость продвижения: \$e';
  }

  @override
  String get addListingLoadError => 'Не удалось загрузить данные объявления';

  @override
  String addListingLoadErrorDetails(Object error) {
    return 'Не удалось загрузить данные объявления: \$e';
  }

  @override
  String get addListingNotFound => 'Объявление не найдено на сервере';

  @override
  String get addListingAddPhoto => 'Добавить фото';

  @override
  String get addListingCover => 'Обложка';

  @override
  String get addListingMakeCover => 'Сделать обложкой';

  @override
  String get addListingCoverUpdated => 'Обложка обновлена';

  @override
  String get addListingAllowDownload => 'Разрешить скачивать фотографии';

  @override
  String get addListingNoPhotos => 'Пока ни одной фотографии';

  @override
  String get addListingUploaded => 'Загружен на сервер';

  @override
  String get addListingWillUpload => 'Будет загружено при сохранении';

  @override
  String addListingPhotoUploadError(String error) {
    return 'Фото не загрузились: $error';
  }

  @override
  String addListingPhotoSaveError(Object error) {
    return 'Ошибка сохранения фото: \$e';
  }

  @override
  String addListingPhotoDeleteError(String error) {
    return 'Не удалось удалить фото: $error';
  }

  @override
  String addListingCoverChangeError(String error) {
    return 'Не удалось сменить обложку: $error';
  }

  @override
  String get addListingAddVideoItem => 'Добавить видео';

  @override
  String get addListingAddMoreVideo => 'Добавить еще видео (+)';

  @override
  String get addListingNoVideos => 'Пока ни одного ролика';

  @override
  String addListingNewVideo(String number) {
    return 'Новое видео $number';
  }

  @override
  String addListingVideoItem(String number) {
    return 'Видеоролик $number';
  }

  @override
  String get addListingVideoInfo => 'Информация о видео';

  @override
  String get addListingVideoInfoDesc =>
      'Укажите заголовок и краткое описание для REELS';

  @override
  String get addListingVideoTitle => 'Заголовок видео';

  @override
  String get addListingVideoTitleHint => 'Например, обзор дома';

  @override
  String get addListingVideoDesc => 'Описание видео';

  @override
  String get addListingVideoDescHint => 'Расскажите подробнее о видео...';

  @override
  String get addListingAddVideoReels => 'Добавьте видео обзор REELS';

  @override
  String get addListingVideoDummyDesc =>
      'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.';

  @override
  String get addListingUseAdInfo => 'Использовать информацию из объявления';

  @override
  String get addListingWasAdded => 'Было добавлено';

  @override
  String addListingVideoUploadError(String error) {
    return 'Ролик не загрузился: $error';
  }

  @override
  String get addListingSaving => 'Сохранение…';

  @override
  String addListingUploadingVideo(Object percent) {
    return 'Загрузка видео\$percent';
  }

  @override
  String get addListingUploading => 'Загрузка ';

  @override
  String addListingVideoProgress(Object index, Object percent, Object total) {
    return 'Видео \$_videoIndex из \$_videoTotal\$percent';
  }

  @override
  String addListingMaxVideos(String limit) {
    return 'Можно до $limit роликов';
  }

  @override
  String addListingNoMoreVideos(String limit) {
    return 'Больше $limit роликов не добавить';
  }

  @override
  String addListingMaxPhotos(String limit) {
    return 'Можно до $limit фото';
  }

  @override
  String addListingNoMorePhotos(String limit) {
    return 'Больше $limit фото не добавить';
  }

  @override
  String get addListingSavedUploadFailed =>
      'Изменения сохранены, но файлы не загрузились ';

  @override
  String get addListingGotIt => 'Понятно';

  @override
  String get addListingViewStats => 'Просмотр статистики';

  @override
  String get addListingStatsDesc =>
      'Статистика показов и интереса покупателей к вашему объекту обновляется в реальном времени.';

  @override
  String get addListingViews => 'Просмотров';

  @override
  String get addListingSentToClients => 'Клиентам отправлено';

  @override
  String get addListingSold => 'Продано';

  @override
  String get addListingToArchive => 'В архив';

  @override
  String get addListingArchived => 'В архиве';

  @override
  String get addListingPublished => 'Опубликовано';

  @override
  String get addListingModerating => 'На модерации';

  @override
  String get addListingRejected => 'Отклонено';

  @override
  String get addListingDraft => 'Черновик';

  @override
  String get addListingEnterCustomValue => 'Введите свое значение';

  @override
  String get addListingCityBishkek => 'Бишкек';

  @override
  String get addListingExample8 => 'Например, 8';

  @override
  String get addListingFurnitureFull => 'Полностью меблирована';

  @override
  String get addListingFurniturePartial => 'Частично с мебелью';

  @override
  String get addListingFurnitureNone => 'Без мебели';

  @override
  String get addListingConditionEuro => 'Евроремонт';

  @override
  String get addListingConditionGood => 'Хорошее состояние';

  @override
  String get addListingConditionShell => 'Под самоотделку';

  @override
  String get addListingConditionMedium => 'Среднее состояние';

  @override
  String get addListingConditionNone => 'Без ремонта';

  @override
  String get addListingHeatingCentral => 'Центральное';

  @override
  String get addListingHeatingGas => 'Газовое';

  @override
  String get addListingHeatingElectric => 'Электрическое';

  @override
  String get addListingHeatingAutonomous => 'Автономное';

  @override
  String get addListingRoomLiving => 'Гостиная';

  @override
  String get addListingRoomKitchen => 'Кухня';

  @override
  String get addListingRoomBedroom => 'Спальная';

  @override
  String get addListingRoomBalcony => 'Балкон';

  @override
  String get addListingRoomBathroom => 'Сан.узел';

  @override
  String get addListingRoomHall => 'Холл';

  @override
  String get addListingRoomWardrobe => 'Гардеробная';

  @override
  String get addListingRoomTerrace => 'Терраса';

  @override
  String get addListingHasGas => 'Наличие газа';

  @override
  String get addListingAreaHint => 'Введите свою квадратуру...';

  @override
  String get addListingDetailsSubtitle => 'Адрес, описание, ремонт, отопление';

  @override
  String addListingRoomSuffix(String count) {
    return '$count ком.';
  }

  @override
  String addListingAreaSuffix(String area) {
    return '$area м²';
  }

  @override
  String get addListingSchoolExample => 'Например, школа №61';

  @override
  String get addListingAddBtn => 'Добавить';

  @override
  String get addListingBuilderTitle => 'Застройщик / ЖК';

  @override
  String get addListingTotalFloorsLabel => 'Всего этажей';

  @override
  String get addListingPriceUSDLabel => 'Стоимость (\\\$ USD)';

  @override
  String get addListingRoomLabel => 'Комната';

  @override
  String get addListingUnspecified => 'Не указано';
}
