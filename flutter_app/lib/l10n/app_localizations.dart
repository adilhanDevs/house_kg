import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ky.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ky'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'House KGZ'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// No description provided for @next.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get next;

  /// No description provided for @error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get error;

  /// No description provided for @success.
  ///
  /// In ru, this message translates to:
  /// **'Успешно'**
  String get success;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @apply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get apply;

  /// No description provided for @reset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get reset;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @all.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get all;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get loading;

  /// No description provided for @empty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get empty;

  /// No description provided for @tryAgain.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать снова'**
  String get tryAgain;

  /// No description provided for @dataLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные'**
  String get dataLoadError;

  /// No description provided for @noInternet.
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к интернету'**
  String get noInternet;

  /// No description provided for @fillAllFields.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все поля'**
  String get fillAllFields;

  /// No description provided for @tabHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get tabHome;

  /// No description provided for @tabCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get tabCatalog;

  /// No description provided for @tabHistory.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get tabHistory;

  /// No description provided for @tabFavourites.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get tabFavourites;

  /// No description provided for @tabProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get tabProfile;

  /// No description provided for @langTitle.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get langTitle;

  /// No description provided for @langRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRu;

  /// No description provided for @langKy.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызский'**
  String get langKy;

  /// No description provided for @langKyShort.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызча'**
  String get langKyShort;

  /// No description provided for @langRuShort.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRuShort;

  /// No description provided for @roleClient.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get roleClient;

  /// No description provided for @roleOwner.
  ///
  /// In ru, this message translates to:
  /// **'Собственник'**
  String get roleOwner;

  /// No description provided for @roleRealtor.
  ///
  /// In ru, this message translates to:
  /// **'Риелтор'**
  String get roleRealtor;

  /// No description provided for @roleAgency.
  ///
  /// In ru, this message translates to:
  /// **'Агентство'**
  String get roleAgency;

  /// No description provided for @rolePro.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get rolePro;

  /// No description provided for @kindHouse.
  ///
  /// In ru, this message translates to:
  /// **'Дома'**
  String get kindHouse;

  /// No description provided for @kindApartment.
  ///
  /// In ru, this message translates to:
  /// **'Квартиры'**
  String get kindApartment;

  /// No description provided for @kindPlot.
  ///
  /// In ru, this message translates to:
  /// **'Участки'**
  String get kindPlot;

  /// No description provided for @kindNewBuilding.
  ///
  /// In ru, this message translates to:
  /// **'Новостройки'**
  String get kindNewBuilding;

  /// No description provided for @kindRoom.
  ///
  /// In ru, this message translates to:
  /// **'Комната'**
  String get kindRoom;

  /// No description provided for @kindCommercial.
  ///
  /// In ru, this message translates to:
  /// **'Коммерция'**
  String get kindCommercial;

  /// No description provided for @sellerOwner.
  ///
  /// In ru, this message translates to:
  /// **'Только собственник'**
  String get sellerOwner;

  /// No description provided for @sellerRealtor.
  ///
  /// In ru, this message translates to:
  /// **'Риелторы'**
  String get sellerRealtor;

  /// No description provided for @sellerAgency.
  ///
  /// In ru, this message translates to:
  /// **'Агентство недвижимости'**
  String get sellerAgency;

  /// No description provided for @statusDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get statusDraft;

  /// No description provided for @statusPending.
  ///
  /// In ru, this message translates to:
  /// **'На модерации'**
  String get statusPending;

  /// No description provided for @statusActive.
  ///
  /// In ru, this message translates to:
  /// **'Активно'**
  String get statusActive;

  /// No description provided for @statusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get statusRejected;

  /// No description provided for @statusArchived.
  ///
  /// In ru, this message translates to:
  /// **'В архиве'**
  String get statusArchived;

  /// No description provided for @statusSold.
  ///
  /// In ru, this message translates to:
  /// **'Продано'**
  String get statusSold;

  /// No description provided for @welcomeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поиск недвижимости в Кыргызстане'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Квартиры, дома, участки и коммерческая недвижимость'**
  String get welcomeSubtitle;

  /// No description provided for @login.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get register;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In ru, this message translates to:
  /// **'+996 000 000 000'**
  String get phoneHint;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get passwordHint;

  /// No description provided for @passwordConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение пароля'**
  String get passwordConfirm;

  /// No description provided for @passwordConfirmHint.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get passwordConfirmHint;

  /// No description provided for @name.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get name;

  /// No description provided for @nameHint.
  ///
  /// In ru, this message translates to:
  /// **'Как к вам обращаться'**
  String get nameHint;

  /// No description provided for @forgotPassword.
  ///
  /// In ru, this message translates to:
  /// **'Забыли пароль?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт?'**
  String get alreadyHaveAccount;

  /// No description provided for @consentPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Я согласен с '**
  String get consentPrefix;

  /// No description provided for @consentTermsLink.
  ///
  /// In ru, this message translates to:
  /// **'условиями обработки персональных данных'**
  String get consentTermsLink;

  /// No description provided for @consentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Примите условия соглашения'**
  String get consentRequired;

  /// No description provided for @invalidPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный номер телефона'**
  String get invalidPhone;

  /// No description provided for @invalidPasswordLength.
  ///
  /// In ru, this message translates to:
  /// **'Пароль должен быть не менее 6 символов'**
  String get invalidPasswordLength;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get passwordsDoNotMatch;

  /// No description provided for @enterName.
  ///
  /// In ru, this message translates to:
  /// **'Введите ваше имя'**
  String get enterName;

  /// No description provided for @loginError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка авторизации'**
  String get loginError;

  /// No description provided for @passwordResetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление пароля'**
  String get passwordResetTitle;

  /// No description provided for @passwordResetSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Укажите номер телефона, и мы отправим код для сброса пароля'**
  String get passwordResetSubtitle;

  /// No description provided for @sendCode.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код'**
  String get sendCode;

  /// No description provided for @newPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get newPassword;

  /// No description provided for @newPasswordHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите новый пароль'**
  String get newPasswordHint;

  /// No description provided for @repeatNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите новый пароль'**
  String get repeatNewPassword;

  /// No description provided for @savePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить пароль'**
  String get savePassword;

  /// No description provided for @codeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Код подтверждения'**
  String get codeTitle;

  /// No description provided for @codeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Введите 4-значный код, отправленный на номер {phone}'**
  String codeSubtitle(String phone);

  /// No description provided for @resendCodeIn.
  ///
  /// In ru, this message translates to:
  /// **'Повторить через {seconds} сек.'**
  String resendCodeIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код повторно'**
  String get resendCode;

  /// No description provided for @codeSending.
  ///
  /// In ru, this message translates to:
  /// **'Отправка кода...'**
  String get codeSending;

  /// No description provided for @homeGreeting.
  ///
  /// In ru, this message translates to:
  /// **'Здравствуйте, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingGuest.
  ///
  /// In ru, this message translates to:
  /// **'Здравствуйте!'**
  String get homeGreetingGuest;

  /// No description provided for @homeCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get homeCategories;

  /// No description provided for @homePopular.
  ///
  /// In ru, this message translates to:
  /// **'Популярные'**
  String get homePopular;

  /// No description provided for @homeFeatured.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендованные'**
  String get homeFeatured;

  /// No description provided for @homeSeeAll.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть все'**
  String get homeSeeAll;

  /// No description provided for @homeNewPositions.
  ///
  /// In ru, this message translates to:
  /// **'Новые позиции'**
  String get homeNewPositions;

  /// No description provided for @homeNewBuildings.
  ///
  /// In ru, this message translates to:
  /// **'Новостройки'**
  String get homeNewBuildings;

  /// No description provided for @homeSecondary.
  ///
  /// In ru, this message translates to:
  /// **'Вторичка'**
  String get homeSecondary;

  /// No description provided for @homeHouses.
  ///
  /// In ru, this message translates to:
  /// **'Дома'**
  String get homeHouses;

  /// No description provided for @homePlots.
  ///
  /// In ru, this message translates to:
  /// **'Участки'**
  String get homePlots;

  /// No description provided for @homeCommercial.
  ///
  /// In ru, this message translates to:
  /// **'Коммерция'**
  String get homeCommercial;

  /// No description provided for @homeSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по адресу, району...'**
  String get homeSearchHint;

  /// No description provided for @homeNoNewListings.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет новых объявлений'**
  String get homeNoNewListings;

  /// No description provided for @cardRoomsShort.
  ///
  /// In ru, this message translates to:
  /// **'{count}-комн.'**
  String cardRoomsShort(int count);

  /// No description provided for @cardAreaMeters.
  ///
  /// In ru, this message translates to:
  /// **'{area}м'**
  String cardAreaMeters(String area);

  /// No description provided for @cardFloor.
  ///
  /// In ru, this message translates to:
  /// **'{floor} этаж'**
  String cardFloor(int floor);

  /// No description provided for @cardLandAreaSotka.
  ///
  /// In ru, this message translates to:
  /// **'{area} сот.'**
  String cardLandAreaSotka(String area);

  /// No description provided for @cardPlot.
  ///
  /// In ru, this message translates to:
  /// **'Участок'**
  String get cardPlot;

  /// No description provided for @catalogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get catalogTitle;

  /// No description provided for @catalogFilters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get catalogFilters;

  /// No description provided for @catalogPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get catalogPrice;

  /// No description provided for @catalogPriceFrom.
  ///
  /// In ru, this message translates to:
  /// **'от'**
  String get catalogPriceFrom;

  /// No description provided for @catalogPriceTo.
  ///
  /// In ru, this message translates to:
  /// **'до'**
  String get catalogPriceTo;

  /// No description provided for @catalogRooms.
  ///
  /// In ru, this message translates to:
  /// **'Комнатность'**
  String get catalogRooms;

  /// No description provided for @catalogArea.
  ///
  /// In ru, this message translates to:
  /// **'Площадь, м²'**
  String get catalogArea;

  /// No description provided for @catalogFloor.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get catalogFloor;

  /// No description provided for @catalogSeries.
  ///
  /// In ru, this message translates to:
  /// **'Серия дома'**
  String get catalogSeries;

  /// No description provided for @catalogSeries103.
  ///
  /// In ru, this message translates to:
  /// **'Только 103 серия'**
  String get catalogSeries103;

  /// No description provided for @catalogSecondaryOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только вторичка'**
  String get catalogSecondaryOnly;

  /// No description provided for @catalogSeller.
  ///
  /// In ru, this message translates to:
  /// **'Продавец'**
  String get catalogSeller;

  /// No description provided for @catalogPlotPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение участка'**
  String get catalogPlotPurpose;

  /// No description provided for @catalogCommercialPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение помещения'**
  String get catalogCommercialPurpose;

  /// No description provided for @catalogBuildingLine.
  ///
  /// In ru, this message translates to:
  /// **'Линия'**
  String get catalogBuildingLine;

  /// No description provided for @catalogFoundCount.
  ///
  /// In ru, this message translates to:
  /// **'Найдено объявлений: {count}'**
  String catalogFoundCount(int count);

  /// No description provided for @catalogShowListings.
  ///
  /// In ru, this message translates to:
  /// **'Показать объявления'**
  String get catalogShowListings;

  /// No description provided for @catalogClearFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get catalogClearFilters;

  /// No description provided for @catalogSaveFilter.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить фильтр'**
  String get catalogSaveFilter;

  /// No description provided for @catalogSaveFilterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение фильтра'**
  String get catalogSaveFilterTitle;

  /// No description provided for @catalogFilterName.
  ///
  /// In ru, this message translates to:
  /// **'Название фильтра'**
  String get catalogFilterName;

  /// No description provided for @catalogFilterNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 2-комн. в центре'**
  String get catalogFilterNameHint;

  /// No description provided for @catalogSavedFilters.
  ///
  /// In ru, this message translates to:
  /// **'Мои фильтры'**
  String get catalogSavedFilters;

  /// No description provided for @catalogNoSavedFilters.
  ///
  /// In ru, this message translates to:
  /// **'Нет сохраненных фильтров'**
  String get catalogNoSavedFilters;

  /// No description provided for @listingCharacteristics.
  ///
  /// In ru, this message translates to:
  /// **'Характеристики'**
  String get listingCharacteristics;

  /// No description provided for @listingDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get listingDescription;

  /// No description provided for @listingLocation.
  ///
  /// In ru, this message translates to:
  /// **'Расположение'**
  String get listingLocation;

  /// No description provided for @listingSeller.
  ///
  /// In ru, this message translates to:
  /// **'Продавец'**
  String get listingSeller;

  /// No description provided for @listingWrite.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get listingWrite;

  /// No description provided for @listingCall.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get listingCall;

  /// No description provided for @listingShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get listingShare;

  /// No description provided for @listingToFavourites.
  ///
  /// In ru, this message translates to:
  /// **'В избранное'**
  String get listingToFavourites;

  /// No description provided for @listingInFavourites.
  ///
  /// In ru, this message translates to:
  /// **'В избранном'**
  String get listingInFavourites;

  /// No description provided for @listingSimilar.
  ///
  /// In ru, this message translates to:
  /// **'Похожие объявления'**
  String get listingSimilar;

  /// No description provided for @listingPriceDrop.
  ///
  /// In ru, this message translates to:
  /// **'Снижение цены'**
  String get listingPriceDrop;

  /// No description provided for @listingRedBook.
  ///
  /// In ru, this message translates to:
  /// **'Красная книга'**
  String get listingRedBook;

  /// No description provided for @listingBelowMarket.
  ///
  /// In ru, this message translates to:
  /// **'Ниже рынка'**
  String get listingBelowMarket;

  /// No description provided for @listingPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Фотообзор'**
  String get listingPhotos;

  /// No description provided for @listingVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видеообзор'**
  String get listingVideo;

  /// No description provided for @listingDownloadPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Скачать фото'**
  String get listingDownloadPhoto;

  /// No description provided for @listingDownloadAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Скачивание разрешено'**
  String get listingDownloadAllowed;

  /// No description provided for @listingViewsCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество просмотров: {count}'**
  String listingViewsCount(int count);

  /// No description provided for @listingPublishedAt.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовано: {date}'**
  String listingPublishedAt(String date);

  /// No description provided for @listingRoomsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count}-комн.'**
  String listingRoomsCount(int count);

  /// No description provided for @listingAreaSqM.
  ///
  /// In ru, this message translates to:
  /// **'{area} м²'**
  String listingAreaSqM(String area);

  /// No description provided for @listingFloorOf.
  ///
  /// In ru, this message translates to:
  /// **'{floor}/{total} этаж'**
  String listingFloorOf(int floor, int total);

  /// No description provided for @adCreate.
  ///
  /// In ru, this message translates to:
  /// **'Подать объявление'**
  String get adCreate;

  /// No description provided for @adEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить объявление'**
  String get adEdit;

  /// No description provided for @adPublish.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать'**
  String get adPublish;

  /// No description provided for @adSaveDraft.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить черновик'**
  String get adSaveDraft;

  /// No description provided for @adCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get adCategory;

  /// No description provided for @adCity.
  ///
  /// In ru, this message translates to:
  /// **'Город'**
  String get adCity;

  /// No description provided for @adDistrict.
  ///
  /// In ru, this message translates to:
  /// **'Район'**
  String get adDistrict;

  /// No description provided for @adAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get adAddress;

  /// No description provided for @adPriceUSD.
  ///
  /// In ru, this message translates to:
  /// **'Цена в \$'**
  String get adPriceUSD;

  /// No description provided for @adPriceKGS.
  ///
  /// In ru, this message translates to:
  /// **'Цена в сомах'**
  String get adPriceKGS;

  /// No description provided for @adRooms.
  ///
  /// In ru, this message translates to:
  /// **'Количество комнат'**
  String get adRooms;

  /// No description provided for @adTotalArea.
  ///
  /// In ru, this message translates to:
  /// **'Общая площадь (м²)'**
  String get adTotalArea;

  /// No description provided for @adLivingArea.
  ///
  /// In ru, this message translates to:
  /// **'Жилая площадь (м²)'**
  String get adLivingArea;

  /// No description provided for @adKitchenArea.
  ///
  /// In ru, this message translates to:
  /// **'Площадь кухни (м²)'**
  String get adKitchenArea;

  /// No description provided for @adFloor.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get adFloor;

  /// No description provided for @adFloorsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Этажность дома'**
  String get adFloorsTotal;

  /// No description provided for @adSeries.
  ///
  /// In ru, this message translates to:
  /// **'Серия'**
  String get adSeries;

  /// No description provided for @adDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание объекта'**
  String get adDescription;

  /// No description provided for @adDescriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Расскажите подробнее об объекте...'**
  String get adDescriptionHint;

  /// No description provided for @adPhotosTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фотографии'**
  String get adPhotosTitle;

  /// No description provided for @adPhotosSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте до 20 фотографий. Первое фото станет обложкой.'**
  String get adPhotosSubtitle;

  /// No description provided for @adAddPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get adAddPhotos;

  /// No description provided for @adAddVideo.
  ///
  /// In ru, this message translates to:
  /// **'Добавить видео'**
  String get adAddVideo;

  /// No description provided for @adMakeCover.
  ///
  /// In ru, this message translates to:
  /// **'Сделать обложкой'**
  String get adMakeCover;

  /// No description provided for @adDeleteMedia.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get adDeleteMedia;

  /// No description provided for @adCoverBadge.
  ///
  /// In ru, this message translates to:
  /// **'Обложка'**
  String get adCoverBadge;

  /// No description provided for @adPromoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продвижение объявления'**
  String get adPromoTitle;

  /// No description provided for @adPromoDays.
  ///
  /// In ru, this message translates to:
  /// **'{days} дней'**
  String adPromoDays(int days);

  /// No description provided for @adPromoCost.
  ///
  /// In ru, this message translates to:
  /// **'{cost} кирпичей'**
  String adPromoCost(int cost);

  /// No description provided for @adPreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр'**
  String get adPreview;

  /// No description provided for @adPublishedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление успешно опубликовано!'**
  String get adPublishedSuccess;

  /// No description provided for @adSavedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление сохранено'**
  String get adSavedSuccess;

  /// No description provided for @adMustHavePhotos.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте хотя бы одну фотографию'**
  String get adMustHavePhotos;

  /// No description provided for @adMustSelectCategory.
  ///
  /// In ru, this message translates to:
  /// **'Выберите категорию'**
  String get adMustSelectCategory;

  /// No description provided for @favouritesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вам понравилось'**
  String get favouritesTitle;

  /// No description provided for @favouritesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет избранных объявлений'**
  String get favouritesEmpty;

  /// No description provided for @favouritesEmptySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Нажимайте на сердечко в карточках объектов, чтобы сохранить их здесь'**
  String get favouritesEmptySubtitle;

  /// No description provided for @historyTitle.
  ///
  /// In ru, this message translates to:
  /// **'История просмотров'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Вы еще не просматривали объявления'**
  String get historyEmpty;

  /// No description provided for @historyClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить историю'**
  String get historyClear;

  /// No description provided for @historyClearConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить историю просмотров?'**
  String get historyClearConfirmTitle;

  /// No description provided for @historyClearConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Все просмотренные объявления будут удалены из истории.'**
  String get historyClearConfirmBody;

  /// No description provided for @notificationsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notificationsTitle;

  /// No description provided for @notificationsLatest.
  ///
  /// In ru, this message translates to:
  /// **'Последние уведомления'**
  String get notificationsLatest;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлений пока нет'**
  String get notificationsEmpty;

  /// No description provided for @notificationsProfileEmpty.
  ///
  /// In ru, this message translates to:
  /// **'У вас пока нет уведомлений'**
  String get notificationsProfileEmpty;

  /// No description provided for @notificationsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить уведомления'**
  String get notificationsLoadError;

  /// No description provided for @notificationFallbackTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомление'**
  String get notificationFallbackTitle;

  /// No description provided for @notificationTestPushTitle.
  ///
  /// In ru, this message translates to:
  /// **'House KG — проверка прочтения'**
  String get notificationTestPushTitle;

  /// No description provided for @notificationTestPushBody.
  ///
  /// In ru, this message translates to:
  /// **'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.'**
  String get notificationTestPushBody;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In ru, this message translates to:
  /// **'Отметить все как прочитанные'**
  String get notificationsMarkAllRead;

  /// No description provided for @priceDecreased.
  ///
  /// In ru, this message translates to:
  /// **'Цена снизилась'**
  String get priceDecreased;

  /// No description provided for @messagesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения'**
  String get messagesTitle;

  /// No description provided for @messagesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет сообщений'**
  String get messagesEmpty;

  /// No description provided for @chatInputHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите сообщение...'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get chatSend;

  /// No description provided for @chatNoDialogs.
  ///
  /// In ru, this message translates to:
  /// **'Диалогов пока нет'**
  String get chatNoDialogs;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ваш профиль'**
  String get profileTitle;

  /// No description provided for @profileNoName.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get profileNoName;

  /// No description provided for @profileFavoritesRow.
  ///
  /// In ru, this message translates to:
  /// **'Вам понравилось'**
  String get profileFavoritesRow;

  /// No description provided for @profileTariffsRow.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы'**
  String get profileTariffsRow;

  /// No description provided for @profileNotificationsRow.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get profileNotificationsRow;

  /// No description provided for @profileAccountRow.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get profileAccountRow;

  /// No description provided for @profileSupportRow.
  ///
  /// In ru, this message translates to:
  /// **'Служба поддержки'**
  String get profileSupportRow;

  /// No description provided for @profileHistoryRow.
  ///
  /// In ru, this message translates to:
  /// **'История пополнения и трат'**
  String get profileHistoryRow;

  /// No description provided for @profileLanguageRow.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get profileLanguageRow;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get profileSettingsTitle;

  /// No description provided for @profileSellButton.
  ///
  /// In ru, this message translates to:
  /// **'Продать недвижимость'**
  String get profileSellButton;

  /// No description provided for @profileLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get profileLogout;

  /// No description provided for @profileLogoutConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get profileLogoutConfirmTitle;

  /// No description provided for @profileLogoutConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Избранное и фильтры этого сеанса будут забыты.'**
  String get profileLogoutConfirmBody;

  /// No description provided for @profileLoggingOut.
  ///
  /// In ru, this message translates to:
  /// **'Выход...'**
  String get profileLoggingOut;

  /// No description provided for @proProfileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль продавца'**
  String get proProfileTitle;

  /// No description provided for @proSold.
  ///
  /// In ru, this message translates to:
  /// **'Продано: {count}'**
  String proSold(int count);

  /// No description provided for @proObjectsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} объектов недвижимости'**
  String proObjectsCount(int count);

  /// No description provided for @proAddListing.
  ///
  /// In ru, this message translates to:
  /// **'Добавить объявление'**
  String get proAddListing;

  /// No description provided for @proAddFirstListing.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый объект'**
  String get proAddFirstListing;

  /// No description provided for @proMyListings.
  ///
  /// In ru, this message translates to:
  /// **'Мои объявления'**
  String get proMyListings;

  /// No description provided for @proAllListings.
  ///
  /// In ru, this message translates to:
  /// **'Все объявления'**
  String get proAllListings;

  /// No description provided for @proEmptyNewBuildings.
  ///
  /// In ru, this message translates to:
  /// **'Нет новостроек'**
  String get proEmptyNewBuildings;

  /// No description provided for @proEmptyApartments.
  ///
  /// In ru, this message translates to:
  /// **'Нет квартир'**
  String get proEmptyApartments;

  /// No description provided for @proEmptyCommercial.
  ///
  /// In ru, this message translates to:
  /// **'Нет коммерческих объектов'**
  String get proEmptyCommercial;

  /// No description provided for @proEmptyHouses.
  ///
  /// In ru, this message translates to:
  /// **'Нет домов'**
  String get proEmptyHouses;

  /// No description provided for @proEmptyPlots.
  ///
  /// In ru, this message translates to:
  /// **'Нет участков'**
  String get proEmptyPlots;

  /// No description provided for @proEmptyRooms.
  ///
  /// In ru, this message translates to:
  /// **'Нет комнат'**
  String get proEmptyRooms;

  /// No description provided for @proWalletBalance.
  ///
  /// In ru, this message translates to:
  /// **'{count} кирпичей'**
  String proWalletBalance(int count);

  /// No description provided for @proWalletTitle.
  ///
  /// In ru, this message translates to:
  /// **'Баланс'**
  String get proWalletTitle;

  /// No description provided for @proTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Пополнить'**
  String get proTopUp;

  /// No description provided for @proSignupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация продавца'**
  String get proSignupTitle;

  /// No description provided for @proSignupIin.
  ///
  /// In ru, this message translates to:
  /// **'ИНН / ПИН'**
  String get proSignupIin;

  /// No description provided for @proSignupIinHint.
  ///
  /// In ru, this message translates to:
  /// **'14 цифр'**
  String get proSignupIinHint;

  /// No description provided for @proIdentityTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение личности'**
  String get proIdentityTitle;

  /// No description provided for @proIdentitySelfie.
  ///
  /// In ru, this message translates to:
  /// **'Сделайте селфи'**
  String get proIdentitySelfie;

  /// No description provided for @proIdentityPassport.
  ///
  /// In ru, this message translates to:
  /// **'Фото паспорта'**
  String get proIdentityPassport;

  /// No description provided for @accountTitle.
  ///
  /// In ru, this message translates to:
  /// **'Личные данные'**
  String get accountTitle;

  /// No description provided for @accountName.
  ///
  /// In ru, this message translates to:
  /// **'Имя и фамилия'**
  String get accountName;

  /// No description provided for @accountWhatsapp.
  ///
  /// In ru, this message translates to:
  /// **'Номер WhatsApp'**
  String get accountWhatsapp;

  /// No description provided for @accountChangeAvatar.
  ///
  /// In ru, this message translates to:
  /// **'Изменить фото'**
  String get accountChangeAvatar;

  /// No description provided for @accountChangeCover.
  ///
  /// In ru, this message translates to:
  /// **'Изменить обложку'**
  String get accountChangeCover;

  /// No description provided for @accountDeletePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get accountDeletePhoto;

  /// No description provided for @accountChangePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get accountChangePassword;

  /// No description provided for @accountOldPassword.
  ///
  /// In ru, this message translates to:
  /// **'Старый пароль'**
  String get accountOldPassword;

  /// No description provided for @accountNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get accountNewPassword;

  /// No description provided for @accountRepeatPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите новый пароль'**
  String get accountRepeatPassword;

  /// No description provided for @accountPasswordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль успешно изменен'**
  String get accountPasswordChanged;

  /// No description provided for @accountDeleteAccount.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт'**
  String get accountDeleteAccount;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Это действие необратимо. Все ваши данные и объявления будут удалены.'**
  String get accountDeleteConfirmBody;

  /// No description provided for @tariffsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы'**
  String get tariffsTitle;

  /// No description provided for @tariffsCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущий тариф'**
  String get tariffsCurrent;

  /// No description provided for @tariffsConnect.
  ///
  /// In ru, this message translates to:
  /// **'Подключить'**
  String get tariffsConnect;

  /// No description provided for @tariffsExtend.
  ///
  /// In ru, this message translates to:
  /// **'Продлить'**
  String get tariffsExtend;

  /// No description provided for @tariffsFree.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатный'**
  String get tariffsFree;

  /// No description provided for @tariffsPerMonth.
  ///
  /// In ru, this message translates to:
  /// **'{price} сом/мес'**
  String tariffsPerMonth(String price);

  /// No description provided for @tariffsPayBricks.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить кирпичами ({count})'**
  String tariffsPayBricks(int count);

  /// No description provided for @tariffsPaySom.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить {price} сом'**
  String tariffsPaySom(String price);

  /// No description provided for @topupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пополнение баланса'**
  String get topupTitle;

  /// No description provided for @topupAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма пополнения (сом)'**
  String get topupAmount;

  /// No description provided for @topupBonusHint.
  ///
  /// In ru, this message translates to:
  /// **'1 сом = 1 кирпич + 10% бонус'**
  String get topupBonusHint;

  /// No description provided for @topupYouWillGet.
  ///
  /// In ru, this message translates to:
  /// **'Вам будет начислено: {bricks} кирпичей'**
  String topupYouWillGet(int bricks);

  /// No description provided for @topupPayButton.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить {amount} сом'**
  String topupPayButton(String amount);

  /// No description provided for @topupSelectMethod.
  ///
  /// In ru, this message translates to:
  /// **'Выберите способ оплаты'**
  String get topupSelectMethod;

  /// No description provided for @walletHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'История пополнения и трат'**
  String get walletHistoryTitle;

  /// No description provided for @walletTabAll.
  ///
  /// In ru, this message translates to:
  /// **'Все операции'**
  String get walletTabAll;

  /// No description provided for @walletTabTopup.
  ///
  /// In ru, this message translates to:
  /// **'Пополнение'**
  String get walletTabTopup;

  /// No description provided for @walletTabSpend.
  ///
  /// In ru, this message translates to:
  /// **'Списание'**
  String get walletTabSpend;

  /// No description provided for @walletTabBonus.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы'**
  String get walletTabBonus;

  /// No description provided for @walletHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет операций'**
  String get walletHistoryEmpty;

  /// No description provided for @supportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Служба поддержки'**
  String get supportTitle;

  /// No description provided for @supportFaq.
  ///
  /// In ru, this message translates to:
  /// **'Часто задаваемые вопросы'**
  String get supportFaq;

  /// No description provided for @supportWhatsapp.
  ///
  /// In ru, this message translates to:
  /// **'Написать в WhatsApp'**
  String get supportWhatsapp;

  /// No description provided for @supportCall.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить в поддержку'**
  String get supportCall;

  /// No description provided for @supportEmail.
  ///
  /// In ru, this message translates to:
  /// **'Написать на почту'**
  String get supportEmail;

  /// No description provided for @supportOnlineTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мы на связи 24/7'**
  String get supportOnlineTitle;

  /// No description provided for @supportOnlineBody.
  ///
  /// In ru, this message translates to:
  /// **'Оперативно ответим на любые вопросы по объектам, балансу кирпичей и PRO подписке'**
  String get supportOnlineBody;

  /// No description provided for @supportQuickContact.
  ///
  /// In ru, this message translates to:
  /// **'Быстрая связь'**
  String get supportQuickContact;

  /// No description provided for @supportCallShort.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get supportCallShort;

  /// No description provided for @supportDirectQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Задать вопрос напрямую'**
  String get supportDirectQuestion;

  /// No description provided for @supportMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Опишите вашу проблему или вопрос...'**
  String get supportMessageHint;

  /// No description provided for @supportSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get supportSend;

  /// No description provided for @supportSending.
  ///
  /// In ru, this message translates to:
  /// **'Отправка...'**
  String get supportSending;

  /// No description provided for @supportSent.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение отправлено! Ответим в течение 5 минут.'**
  String get supportSent;

  /// No description provided for @supportOpenLinkError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть ссылку'**
  String get supportOpenLinkError;

  /// No description provided for @supportFaqBalanceQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Как пополнить баланс кирпичей?'**
  String get supportFaqBalanceQuestion;

  /// No description provided for @supportFaqBalanceAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Перейдите на вкладку «Профиль», нажмите на кнопку «Пополнить» на панели баланса и выберите удобный способ оплаты (MBANK, Элсом, Visa, О!Деньги).'**
  String get supportFaqBalanceAnswer;

  /// No description provided for @supportFaqProQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Как получить статус PRO агентства?'**
  String get supportFaqProQuestion;

  /// No description provided for @supportFaqProAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Пройдите быструю верификацию в профиле, загрузив фото вашего риелторского удостоверения или паспорта.'**
  String get supportFaqProAnswer;

  /// No description provided for @supportFaqBricksQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Сколько списывается кирпичей за публикацию?'**
  String get supportFaqBricksQuestion;

  /// No description provided for @supportFaqBricksAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Списание зависит от категории объекта и дополнительных опций (выделение цветом, топ списка, автоподъем).'**
  String get supportFaqBricksAnswer;

  /// No description provided for @dateToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get dateYesterday;

  /// No description provided for @dateDaysAgo.
  ///
  /// In ru, this message translates to:
  /// **'{days} дн. назад'**
  String dateDaysAgo(int days);

  /// No description provided for @filterPlotPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение участка'**
  String get filterPlotPurpose;

  /// No description provided for @filterCommercialPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение объекта'**
  String get filterCommercialPurpose;

  /// No description provided for @filterBuildingLine.
  ///
  /// In ru, this message translates to:
  /// **'Линия застройки'**
  String get filterBuildingLine;

  /// No description provided for @filterSeller.
  ///
  /// In ru, this message translates to:
  /// **'Кто продаёт'**
  String get filterSeller;

  /// No description provided for @chatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения'**
  String get chatTitle;

  /// No description provided for @tariffsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите подходящий тариф для эффективного продвижения объектов'**
  String get tariffsSubtitle;

  /// No description provided for @historyAllTypes.
  ///
  /// In ru, this message translates to:
  /// **'Все типы'**
  String get historyAllTypes;

  /// No description provided for @historySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Здесь объекты, которые вы открывали за последние 30 дней. Нажмите «Выбрать», чтобы убрать их из истории.'**
  String get historySubtitle;

  /// No description provided for @historyClearSelection.
  ///
  /// In ru, this message translates to:
  /// **'Выберите объекты'**
  String get historyClearSelection;

  /// No description provided for @historyRemovePicked.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из истории ({count})'**
  String historyRemovePicked(int count);

  /// No description provided for @walletFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все операции'**
  String get walletFilterAll;

  /// No description provided for @walletFilterTopup.
  ///
  /// In ru, this message translates to:
  /// **'Пополнение'**
  String get walletFilterTopup;

  /// No description provided for @walletFilterSpend.
  ///
  /// In ru, this message translates to:
  /// **'Списание'**
  String get walletFilterSpend;

  /// No description provided for @walletFilterBonus.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы'**
  String get walletFilterBonus;

  /// No description provided for @walletHistorySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'История операций кошелька и начисления бонусов'**
  String get walletHistorySubtitle;

  /// No description provided for @walletEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет операций'**
  String get walletEmpty;

  /// No description provided for @filterPropertyType.
  ///
  /// In ru, this message translates to:
  /// **'Тип недвижимости'**
  String get filterPropertyType;

  /// No description provided for @filterSecondary.
  ///
  /// In ru, this message translates to:
  /// **'Вторичка'**
  String get filterSecondary;

  /// No description provided for @filterSeries103.
  ///
  /// In ru, this message translates to:
  /// **'103 серия'**
  String get filterSeries103;

  /// No description provided for @filterRoomsCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество комнат'**
  String get filterRoomsCount;

  /// No description provided for @filterRoomsUnit.
  ///
  /// In ru, this message translates to:
  /// **'комн.'**
  String get filterRoomsUnit;

  /// No description provided for @filterArea.
  ///
  /// In ru, this message translates to:
  /// **'Площадь'**
  String get filterArea;

  /// No description provided for @filterCustomArea.
  ///
  /// In ru, this message translates to:
  /// **'Своя площадь (м²)'**
  String get filterCustomArea;

  /// No description provided for @filterPrice.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get filterPrice;

  /// No description provided for @filterPriceFrom.
  ///
  /// In ru, this message translates to:
  /// **'От'**
  String get filterPriceFrom;

  /// No description provided for @filterPriceTo.
  ///
  /// In ru, this message translates to:
  /// **'До'**
  String get filterPriceTo;

  /// No description provided for @langRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRussian;

  /// No description provided for @langKyrgyz.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызча'**
  String get langKyrgyz;

  /// No description provided for @languageRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageKyrgyz.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызча'**
  String get languageKyrgyz;

  /// No description provided for @historySelect.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get historySelect;

  /// No description provided for @historyDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get historyDone;

  /// No description provided for @historyOrderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get historyOrderTitle;

  /// No description provided for @historyOrderNewest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала новые'**
  String get historyOrderNewest;

  /// No description provided for @historyOrderOldest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала старые'**
  String get historyOrderOldest;

  /// No description provided for @historyPeriodTitle.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get historyPeriodTitle;

  /// No description provided for @historyPeriodAll.
  ///
  /// In ru, this message translates to:
  /// **'За всё время'**
  String get historyPeriodAll;

  /// No description provided for @historyPeriodToday.
  ///
  /// In ru, this message translates to:
  /// **'За сегодня'**
  String get historyPeriodToday;

  /// No description provided for @historyPeriodWeek.
  ///
  /// In ru, this message translates to:
  /// **'За неделю'**
  String get historyPeriodWeek;

  /// No description provided for @historyPeriodMonth.
  ///
  /// In ru, this message translates to:
  /// **'За месяц'**
  String get historyPeriodMonth;

  /// No description provided for @chatStart.
  ///
  /// In ru, this message translates to:
  /// **'Начните диалог с продавцом'**
  String get chatStart;

  /// No description provided for @chatEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Диалогов пока нет'**
  String get chatEmpty;

  /// No description provided for @filterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filterTitle;

  /// No description provided for @filterShowVariants.
  ///
  /// In ru, this message translates to:
  /// **'Показать {count} вариантов'**
  String filterShowVariants(int count);

  /// No description provided for @contactSeller.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с продавцом'**
  String get contactSeller;

  /// No description provided for @contactOwner.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с собственником'**
  String get contactOwner;

  /// No description provided for @contactRealtor.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с риелтором'**
  String get contactRealtor;

  /// No description provided for @contactAgency.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с агентством'**
  String get contactAgency;

  /// No description provided for @sellerObjectsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} объектов недвижимости'**
  String sellerObjectsCount(int count);

  /// No description provided for @sellerSoldCount.
  ///
  /// In ru, this message translates to:
  /// **'Продано: {count} объектов'**
  String sellerSoldCount(int count);

  /// No description provided for @sellerNoListings.
  ///
  /// In ru, this message translates to:
  /// **'У продавца пока нет объявлений в этой категории'**
  String get sellerNoListings;

  /// No description provided for @sellerThisIsYou.
  ///
  /// In ru, this message translates to:
  /// **'Это ваш профиль'**
  String get sellerThisIsYou;

  /// No description provided for @sellerMustLoginToWrite.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы написать продавцу'**
  String get sellerMustLoginToWrite;

  /// No description provided for @sellerNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Продавец не определён'**
  String get sellerNotFound;

  /// No description provided for @sellerNoListingToDiscuss.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить объявление для переписки'**
  String get sellerNoListingToDiscuss;

  /// No description provided for @passwordTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Пароль должен быть не короче 8 символов'**
  String get passwordTooShort;

  /// No description provided for @addListingSelectDistrictHints.
  ///
  /// In ru, this message translates to:
  /// **'Выберите район Бишкека'**
  String get addListingSelectDistrictHints;

  /// No description provided for @addListingSelectDistrict.
  ///
  /// In ru, this message translates to:
  /// **'Выберите район'**
  String get addListingSelectDistrict;

  /// No description provided for @addListingErrDistrict.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, выберите район'**
  String get addListingErrDistrict;

  /// No description provided for @addListingErrArea.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, укажите квадратуру объекта'**
  String get addListingErrArea;

  /// No description provided for @addListingErrPlotArea.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, укажите площадь участка'**
  String get addListingErrPlotArea;

  /// No description provided for @addListingErrPrice.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, укажите цену объекта'**
  String get addListingErrPrice;

  /// No description provided for @addListingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить недвижимость'**
  String get addListingTitle;

  /// No description provided for @addListingSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Заполните основные параметры объекта'**
  String get addListingSubtitle;

  /// No description provided for @addListingPropertyKind.
  ///
  /// In ru, this message translates to:
  /// **'Тип недвижимости'**
  String get addListingPropertyKind;

  /// No description provided for @addListingDistrict.
  ///
  /// In ru, this message translates to:
  /// **'Район'**
  String get addListingDistrict;

  /// No description provided for @addListingArea.
  ///
  /// In ru, this message translates to:
  /// **'Квадратура'**
  String get addListingArea;

  /// No description provided for @addListingFloor.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get addListingFloor;

  /// No description provided for @addListingTotalFloors.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во этажей в здании'**
  String get addListingTotalFloors;

  /// No description provided for @addListingBuilder.
  ///
  /// In ru, this message translates to:
  /// **'Строительная компания'**
  String get addListingBuilder;

  /// No description provided for @addListingSelectBuilder.
  ///
  /// In ru, this message translates to:
  /// **'Выберите застройщика'**
  String get addListingSelectBuilder;

  /// No description provided for @addListingBuilderHint.
  ///
  /// In ru, this message translates to:
  /// **'Ихлас, Авангард, Elite House и др.'**
  String get addListingBuilderHint;

  /// No description provided for @addListingPlotArea.
  ///
  /// In ru, this message translates to:
  /// **'Площадь участка, соток'**
  String get addListingPlotArea;

  /// No description provided for @addListingPlotPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение участка'**
  String get addListingPlotPurpose;

  /// No description provided for @addListingCommercialPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение помещения'**
  String get addListingCommercialPurpose;

  /// No description provided for @addListingBuildingLine.
  ///
  /// In ru, this message translates to:
  /// **'Линия'**
  String get addListingBuildingLine;

  /// No description provided for @addListingRoomsCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество комнат'**
  String get addListingRoomsCount;

  /// No description provided for @addListingRoomAreas.
  ///
  /// In ru, this message translates to:
  /// **'Площади комнат'**
  String get addListingRoomAreas;

  /// No description provided for @addListingRoomName.
  ///
  /// In ru, this message translates to:
  /// **'Название комнаты'**
  String get addListingRoomName;

  /// No description provided for @addListingSelectRoom.
  ///
  /// In ru, this message translates to:
  /// **'Выберите комнату или впишите свою'**
  String get addListingSelectRoom;

  /// No description provided for @addListingRoomExample.
  ///
  /// In ru, this message translates to:
  /// **'Например, гардеробная'**
  String get addListingRoomExample;

  /// No description provided for @addListingAreaSqM.
  ///
  /// In ru, this message translates to:
  /// **'Площадь (м²)'**
  String get addListingAreaSqM;

  /// No description provided for @addListingSqM.
  ///
  /// In ru, this message translates to:
  /// **'м²'**
  String get addListingSqM;

  /// No description provided for @addListingOptionalArea.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно, например 3.2'**
  String get addListingOptionalArea;

  /// No description provided for @addListingDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get addListingDelete;

  /// No description provided for @addListingAddRoom.
  ///
  /// In ru, this message translates to:
  /// **'Добавить комнату'**
  String get addListingAddRoom;

  /// No description provided for @addListingRoomsHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте только те комнаты, которые есть'**
  String get addListingRoomsHint;

  /// No description provided for @addListingStreet.
  ///
  /// In ru, this message translates to:
  /// **'Улица и номер дома'**
  String get addListingStreet;

  /// No description provided for @addListingStreetHint.
  ///
  /// In ru, this message translates to:
  /// **'например, ул. Аалы Токомбаева, 21/3'**
  String get addListingStreetHint;

  /// No description provided for @addListingAddressTitle.
  ///
  /// In ru, this message translates to:
  /// **'Улица / Адрес'**
  String get addListingAddressTitle;

  /// No description provided for @addListingSeries.
  ///
  /// In ru, this message translates to:
  /// **'Серия дома'**
  String get addListingSeries;

  /// No description provided for @addListingCondition.
  ///
  /// In ru, this message translates to:
  /// **'Состояние / Ремонт'**
  String get addListingCondition;

  /// No description provided for @addListingConditionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Состояние и ремонт'**
  String get addListingConditionTitle;

  /// No description provided for @addListingHeating.
  ///
  /// In ru, this message translates to:
  /// **'Отопление'**
  String get addListingHeating;

  /// No description provided for @addListingFurniture.
  ///
  /// In ru, this message translates to:
  /// **'Мебель'**
  String get addListingFurniture;

  /// No description provided for @addListingAmenities.
  ///
  /// In ru, this message translates to:
  /// **'Удобства и состояние'**
  String get addListingAmenities;

  /// No description provided for @addListingCeilingHeight.
  ///
  /// In ru, this message translates to:
  /// **'Высота потолков, м'**
  String get addListingCeilingHeight;

  /// No description provided for @addListingSecondary.
  ///
  /// In ru, this message translates to:
  /// **'Вторичное жильё'**
  String get addListingSecondary;

  /// No description provided for @addListingSeparateEntrance.
  ///
  /// In ru, this message translates to:
  /// **'Отдельный вход'**
  String get addListingSeparateEntrance;

  /// No description provided for @addListingHas.
  ///
  /// In ru, this message translates to:
  /// **'Есть'**
  String get addListingHas;

  /// No description provided for @addListingHasNot.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get addListingHasNot;

  /// No description provided for @addListingPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get addListingPrice;

  /// No description provided for @addListingPriceUSDTitle.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость (\$ USD)'**
  String get addListingPriceUSDTitle;

  /// No description provided for @addListingMortgagePossible.
  ///
  /// In ru, this message translates to:
  /// **'Возможна ипотека'**
  String get addListingMortgagePossible;

  /// No description provided for @addListingMortgageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Возможность ипотеки'**
  String get addListingMortgageTitle;

  /// No description provided for @addListingExchangePossible.
  ///
  /// In ru, this message translates to:
  /// **'Возможен обмен'**
  String get addListingExchangePossible;

  /// No description provided for @addListingExchangeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Возможность обмена'**
  String get addListingExchangeTitle;

  /// No description provided for @addListingDescTitle.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get addListingDescTitle;

  /// No description provided for @addListingDescLabel.
  ///
  /// In ru, this message translates to:
  /// **'Описание объекта'**
  String get addListingDescLabel;

  /// No description provided for @addListingDescHint.
  ///
  /// In ru, this message translates to:
  /// **'Расскажите об объекте подробнее: ремонт, вид из окна, соседи, инфраструктура рядом...'**
  String get addListingDescHint;

  /// No description provided for @addListingDescPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Школа, парк, остановка — что рядом с объектом'**
  String get addListingDescPlaceholder;

  /// No description provided for @addListingMoreInfo.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее об объекте'**
  String get addListingMoreInfo;

  /// No description provided for @addListingMoreInfoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Расскажите об объекте: ремонт, окружение, что рядом'**
  String get addListingMoreInfoSubtitle;

  /// No description provided for @addListingContactsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Контакты и ключевые места'**
  String get addListingContactsTitle;

  /// No description provided for @addListingContactsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Кому звонить и что рядом с объектом'**
  String get addListingContactsSubtitle;

  /// No description provided for @addListingContactName.
  ///
  /// In ru, this message translates to:
  /// **'Имя для связи'**
  String get addListingContactName;

  /// No description provided for @addListingContactNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Если отличается от профиля'**
  String get addListingContactNameHint;

  /// No description provided for @addListingContactPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон для связи'**
  String get addListingContactPhone;

  /// No description provided for @addListingKeyPlaces.
  ///
  /// In ru, this message translates to:
  /// **'Ключевые места'**
  String get addListingKeyPlaces;

  /// No description provided for @addListingWhoAreYou.
  ///
  /// In ru, this message translates to:
  /// **'Вы являетесь?'**
  String get addListingWhoAreYou;

  /// No description provided for @addListingSellerOwner.
  ///
  /// In ru, this message translates to:
  /// **'Собственником'**
  String get addListingSellerOwner;

  /// No description provided for @addListingSellerRealtor.
  ///
  /// In ru, this message translates to:
  /// **'Риелтором'**
  String get addListingSellerRealtor;

  /// No description provided for @addListingDirectBuy.
  ///
  /// In ru, this message translates to:
  /// **'Прямая покупка'**
  String get addListingDirectBuy;

  /// No description provided for @addListingNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get addListingNext;

  /// No description provided for @addListingCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get addListingCancel;

  /// No description provided for @addListingSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get addListingSave;

  /// No description provided for @addListingEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get addListingEdit;

  /// No description provided for @addListingPhotosTitleMain.
  ///
  /// In ru, this message translates to:
  /// **'Фотографии объекта'**
  String get addListingPhotosTitleMain;

  /// No description provided for @addListingPhotosEdit.
  ///
  /// In ru, this message translates to:
  /// **'Добавить/изменить фотографии'**
  String get addListingPhotosEdit;

  /// No description provided for @addListingVideoTitleMain.
  ///
  /// In ru, this message translates to:
  /// **'Видеоролик объекта'**
  String get addListingVideoTitleMain;

  /// No description provided for @addListingVideoWatch.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть видеообзор REELS'**
  String get addListingVideoWatch;

  /// No description provided for @addListingVideoAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить видеоролик'**
  String get addListingVideoAdd;

  /// No description provided for @addListingBasicInfo.
  ///
  /// In ru, this message translates to:
  /// **'Основная информация'**
  String get addListingBasicInfo;

  /// No description provided for @addListingEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить объявление'**
  String get addListingEditTitle;

  /// No description provided for @addListingEditingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование объявления'**
  String get addListingEditingTitle;

  /// No description provided for @addListingSaveChanges.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get addListingSaveChanges;

  /// No description provided for @addListingArchive.
  ///
  /// In ru, this message translates to:
  /// **'Снять с публикации (в архив)'**
  String get addListingArchive;

  /// No description provided for @addListingArchiveConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Снять с публикации?'**
  String get addListingArchiveConfirm;

  /// No description provided for @addListingArchiveDesc.
  ///
  /// In ru, this message translates to:
  /// **'Объявление переместится в архив и не будет видно в каталоге.'**
  String get addListingArchiveDesc;

  /// No description provided for @addListingUpdatedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление успешно обновлено!'**
  String get addListingUpdatedSuccess;

  /// No description provided for @addListingPendingSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление отправлено на модерацию!'**
  String get addListingPendingSuccess;

  /// No description provided for @addListingPublishedNoPromo.
  ///
  /// In ru, this message translates to:
  /// **'Объявление опубликовано, но продвижение не оплачено'**
  String get addListingPublishedNoPromo;

  /// No description provided for @addListingArchivedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление перемещено в архив'**
  String get addListingArchivedSuccess;

  /// No description provided for @addListingErrorSave.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: \$e'**
  String addListingErrorSave(Object error);

  /// No description provided for @addListingErrorArchive.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка архивации: \$e'**
  String addListingErrorArchive(Object error);

  /// No description provided for @addListingUnarchivedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление возвращено из архива и опубликовано!'**
  String get addListingUnarchivedSuccess;

  /// No description provided for @addListingRepublish.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать снова'**
  String get addListingRepublish;

  /// No description provided for @addListingToPreview.
  ///
  /// In ru, this message translates to:
  /// **'К предпросмотру'**
  String get addListingToPreview;

  /// No description provided for @addListingPreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр'**
  String get addListingPreview;

  /// No description provided for @addListingYourAd.
  ///
  /// In ru, this message translates to:
  /// **'Ваше объявление'**
  String get addListingYourAd;

  /// No description provided for @addListingPublishingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Публикация объявления'**
  String get addListingPublishingTitle;

  /// No description provided for @addListingPublish.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать'**
  String get addListingPublish;

  /// No description provided for @addListingPublishing.
  ///
  /// In ru, this message translates to:
  /// **'Публикуем...'**
  String get addListingPublishing;

  /// No description provided for @addListingErrorPublish.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка публикации: \$e'**
  String addListingErrorPublish(Object error);

  /// No description provided for @addListingRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get addListingRetry;

  /// No description provided for @addListingPromotion.
  ///
  /// In ru, this message translates to:
  /// **'Продвижение'**
  String get addListingPromotion;

  /// No description provided for @addListingContinueNoPromo.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить без продвижения'**
  String get addListingContinueNoPromo;

  /// No description provided for @addListingPromoTopup.
  ///
  /// In ru, this message translates to:
  /// **'Пополнение на продвижение объявления'**
  String get addListingPromoTopup;

  /// No description provided for @addListingEnterAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get addListingEnterAmount;

  /// No description provided for @addListingSpendBricks.
  ///
  /// In ru, this message translates to:
  /// **'Списать кирпичи'**
  String get addListingSpendBricks;

  /// No description provided for @addListingPromoDays.
  ///
  /// In ru, this message translates to:
  /// **'Количество дней'**
  String get addListingPromoDays;

  /// No description provided for @addListingEnterValue.
  ///
  /// In ru, this message translates to:
  /// **'Введите значение'**
  String get addListingEnterValue;

  /// No description provided for @addListingPromoExact.
  ///
  /// In ru, this message translates to:
  /// **'Использовать точное продвижение'**
  String get addListingPromoExact;

  /// No description provided for @addListingPromoClientBase.
  ///
  /// In ru, this message translates to:
  /// **'Использовать клиентскую базу'**
  String get addListingPromoClientBase;

  /// No description provided for @addListingPromoWhatsapp.
  ///
  /// In ru, this message translates to:
  /// **'Использовать Whatsapp базу'**
  String get addListingPromoWhatsapp;

  /// No description provided for @addListingPublishedPromoSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Объявление успешно опубликовано и продвинуто!'**
  String get addListingPublishedPromoSuccess;

  /// No description provided for @addListingPublishedSuccess2.
  ///
  /// In ru, this message translates to:
  /// **'Объявление успешно опубликовано!'**
  String get addListingPublishedSuccess2;

  /// No description provided for @addListingPromoNotPaid.
  ///
  /// In ru, this message translates to:
  /// **'Продвижение не оплачено: \$message'**
  String addListingPromoNotPaid(Object message);

  /// No description provided for @addListingPromoCostError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить стоимость продвижения: \$e'**
  String addListingPromoCostError(Object error);

  /// No description provided for @addListingLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные объявления'**
  String get addListingLoadError;

  /// No description provided for @addListingLoadErrorDetails.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные объявления: \$e'**
  String addListingLoadErrorDetails(Object error);

  /// No description provided for @addListingNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Объявление не найдено на сервере'**
  String get addListingNotFound;

  /// No description provided for @addListingAddPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get addListingAddPhoto;

  /// No description provided for @addListingCover.
  ///
  /// In ru, this message translates to:
  /// **'Обложка'**
  String get addListingCover;

  /// No description provided for @addListingMakeCover.
  ///
  /// In ru, this message translates to:
  /// **'Сделать обложкой'**
  String get addListingMakeCover;

  /// No description provided for @addListingCoverUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Обложка обновлена'**
  String get addListingCoverUpdated;

  /// No description provided for @addListingAllowDownload.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить скачивать фотографии'**
  String get addListingAllowDownload;

  /// No description provided for @addListingNoPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Пока ни одной фотографии'**
  String get addListingNoPhotos;

  /// No description provided for @addListingUploaded.
  ///
  /// In ru, this message translates to:
  /// **'Загружен на сервер'**
  String get addListingUploaded;

  /// No description provided for @addListingWillUpload.
  ///
  /// In ru, this message translates to:
  /// **'Будет загружено при сохранении'**
  String get addListingWillUpload;

  /// No description provided for @addListingPhotoUploadError.
  ///
  /// In ru, this message translates to:
  /// **'Фото не загрузились: {error}'**
  String addListingPhotoUploadError(String error);

  /// No description provided for @addListingPhotoSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения фото: \$e'**
  String addListingPhotoSaveError(Object error);

  /// No description provided for @addListingPhotoDeleteError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить фото: {error}'**
  String addListingPhotoDeleteError(String error);

  /// No description provided for @addListingCoverChangeError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сменить обложку: {error}'**
  String addListingCoverChangeError(String error);

  /// No description provided for @addListingAddVideoItem.
  ///
  /// In ru, this message translates to:
  /// **'Добавить видео'**
  String get addListingAddVideoItem;

  /// No description provided for @addListingAddMoreVideo.
  ///
  /// In ru, this message translates to:
  /// **'Добавить еще видео (+)'**
  String get addListingAddMoreVideo;

  /// No description provided for @addListingNoVideos.
  ///
  /// In ru, this message translates to:
  /// **'Пока ни одного ролика'**
  String get addListingNoVideos;

  /// No description provided for @addListingNewVideo.
  ///
  /// In ru, this message translates to:
  /// **'Новое видео {number}'**
  String addListingNewVideo(String number);

  /// No description provided for @addListingVideoItem.
  ///
  /// In ru, this message translates to:
  /// **'Видеоролик {number}'**
  String addListingVideoItem(String number);

  /// No description provided for @addListingVideoInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация о видео'**
  String get addListingVideoInfo;

  /// No description provided for @addListingVideoInfoDesc.
  ///
  /// In ru, this message translates to:
  /// **'Укажите заголовок и краткое описание для REELS'**
  String get addListingVideoInfoDesc;

  /// No description provided for @addListingVideoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок видео'**
  String get addListingVideoTitle;

  /// No description provided for @addListingVideoTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, обзор дома'**
  String get addListingVideoTitleHint;

  /// No description provided for @addListingVideoDesc.
  ///
  /// In ru, this message translates to:
  /// **'Описание видео'**
  String get addListingVideoDesc;

  /// No description provided for @addListingVideoDescHint.
  ///
  /// In ru, this message translates to:
  /// **'Расскажите подробнее о видео...'**
  String get addListingVideoDescHint;

  /// No description provided for @addListingAddVideoReels.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте видео обзор REELS'**
  String get addListingAddVideoReels;

  /// No description provided for @addListingVideoDummyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.'**
  String get addListingVideoDummyDesc;

  /// No description provided for @addListingUseAdInfo.
  ///
  /// In ru, this message translates to:
  /// **'Использовать информацию из объявления'**
  String get addListingUseAdInfo;

  /// No description provided for @addListingWasAdded.
  ///
  /// In ru, this message translates to:
  /// **'Было добавлено'**
  String get addListingWasAdded;

  /// No description provided for @addListingVideoUploadError.
  ///
  /// In ru, this message translates to:
  /// **'Ролик не загрузился: {error}'**
  String addListingVideoUploadError(String error);

  /// No description provided for @addListingSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение…'**
  String get addListingSaving;

  /// No description provided for @addListingUploadingVideo.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка видео\$percent'**
  String addListingUploadingVideo(Object percent);

  /// No description provided for @addListingUploading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка '**
  String get addListingUploading;

  /// No description provided for @addListingVideoProgress.
  ///
  /// In ru, this message translates to:
  /// **'Видео \$_videoIndex из \$_videoTotal\$percent'**
  String addListingVideoProgress(Object index, Object percent, Object total);

  /// No description provided for @addListingMaxVideos.
  ///
  /// In ru, this message translates to:
  /// **'Можно до {limit} роликов'**
  String addListingMaxVideos(String limit);

  /// No description provided for @addListingNoMoreVideos.
  ///
  /// In ru, this message translates to:
  /// **'Больше {limit} роликов не добавить'**
  String addListingNoMoreVideos(String limit);

  /// No description provided for @addListingMaxPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Можно до {limit} фото'**
  String addListingMaxPhotos(String limit);

  /// No description provided for @addListingNoMorePhotos.
  ///
  /// In ru, this message translates to:
  /// **'Больше {limit} фото не добавить'**
  String addListingNoMorePhotos(String limit);

  /// No description provided for @addListingSavedUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Изменения сохранены, но файлы не загрузились '**
  String get addListingSavedUploadFailed;

  /// No description provided for @addListingGotIt.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get addListingGotIt;

  /// No description provided for @addListingViewStats.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр статистики'**
  String get addListingViewStats;

  /// No description provided for @addListingStatsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Статистика показов и интереса покупателей к вашему объекту обновляется в реальном времени.'**
  String get addListingStatsDesc;

  /// No description provided for @addListingViews.
  ///
  /// In ru, this message translates to:
  /// **'Просмотров'**
  String get addListingViews;

  /// No description provided for @addListingSentToClients.
  ///
  /// In ru, this message translates to:
  /// **'Клиентам отправлено'**
  String get addListingSentToClients;

  /// No description provided for @addListingSold.
  ///
  /// In ru, this message translates to:
  /// **'Продано'**
  String get addListingSold;

  /// No description provided for @addListingToArchive.
  ///
  /// In ru, this message translates to:
  /// **'В архив'**
  String get addListingToArchive;

  /// No description provided for @addListingArchived.
  ///
  /// In ru, this message translates to:
  /// **'В архиве'**
  String get addListingArchived;

  /// No description provided for @addListingPublished.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовано'**
  String get addListingPublished;

  /// No description provided for @addListingModerating.
  ///
  /// In ru, this message translates to:
  /// **'На модерации'**
  String get addListingModerating;

  /// No description provided for @addListingRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get addListingRejected;

  /// No description provided for @addListingDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get addListingDraft;

  /// No description provided for @addListingEnterCustomValue.
  ///
  /// In ru, this message translates to:
  /// **'Введите свое значение'**
  String get addListingEnterCustomValue;

  /// No description provided for @addListingCityBishkek.
  ///
  /// In ru, this message translates to:
  /// **'Бишкек'**
  String get addListingCityBishkek;

  /// No description provided for @addListingExample8.
  ///
  /// In ru, this message translates to:
  /// **'Например, 8'**
  String get addListingExample8;

  /// No description provided for @addListingFurnitureFull.
  ///
  /// In ru, this message translates to:
  /// **'Полностью меблирована'**
  String get addListingFurnitureFull;

  /// No description provided for @addListingFurniturePartial.
  ///
  /// In ru, this message translates to:
  /// **'Частично с мебелью'**
  String get addListingFurniturePartial;

  /// No description provided for @addListingFurnitureNone.
  ///
  /// In ru, this message translates to:
  /// **'Без мебели'**
  String get addListingFurnitureNone;

  /// No description provided for @addListingConditionEuro.
  ///
  /// In ru, this message translates to:
  /// **'Евроремонт'**
  String get addListingConditionEuro;

  /// No description provided for @addListingConditionGood.
  ///
  /// In ru, this message translates to:
  /// **'Хорошее состояние'**
  String get addListingConditionGood;

  /// No description provided for @addListingConditionShell.
  ///
  /// In ru, this message translates to:
  /// **'Под самоотделку'**
  String get addListingConditionShell;

  /// No description provided for @addListingConditionMedium.
  ///
  /// In ru, this message translates to:
  /// **'Среднее состояние'**
  String get addListingConditionMedium;

  /// No description provided for @addListingConditionNone.
  ///
  /// In ru, this message translates to:
  /// **'Без ремонта'**
  String get addListingConditionNone;

  /// No description provided for @addListingHeatingCentral.
  ///
  /// In ru, this message translates to:
  /// **'Центральное'**
  String get addListingHeatingCentral;

  /// No description provided for @addListingHeatingGas.
  ///
  /// In ru, this message translates to:
  /// **'Газовое'**
  String get addListingHeatingGas;

  /// No description provided for @addListingHeatingElectric.
  ///
  /// In ru, this message translates to:
  /// **'Электрическое'**
  String get addListingHeatingElectric;

  /// No description provided for @addListingHeatingAutonomous.
  ///
  /// In ru, this message translates to:
  /// **'Автономное'**
  String get addListingHeatingAutonomous;

  /// No description provided for @addListingRoomLiving.
  ///
  /// In ru, this message translates to:
  /// **'Гостиная'**
  String get addListingRoomLiving;

  /// No description provided for @addListingRoomKitchen.
  ///
  /// In ru, this message translates to:
  /// **'Кухня'**
  String get addListingRoomKitchen;

  /// No description provided for @addListingRoomBedroom.
  ///
  /// In ru, this message translates to:
  /// **'Спальная'**
  String get addListingRoomBedroom;

  /// No description provided for @addListingRoomBalcony.
  ///
  /// In ru, this message translates to:
  /// **'Балкон'**
  String get addListingRoomBalcony;

  /// No description provided for @addListingRoomBathroom.
  ///
  /// In ru, this message translates to:
  /// **'Сан.узел'**
  String get addListingRoomBathroom;

  /// No description provided for @addListingRoomHall.
  ///
  /// In ru, this message translates to:
  /// **'Холл'**
  String get addListingRoomHall;

  /// No description provided for @addListingRoomWardrobe.
  ///
  /// In ru, this message translates to:
  /// **'Гардеробная'**
  String get addListingRoomWardrobe;

  /// No description provided for @addListingRoomTerrace.
  ///
  /// In ru, this message translates to:
  /// **'Терраса'**
  String get addListingRoomTerrace;

  /// No description provided for @addListingHasGas.
  ///
  /// In ru, this message translates to:
  /// **'Наличие газа'**
  String get addListingHasGas;

  /// No description provided for @addListingAreaHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите свою квадратуру...'**
  String get addListingAreaHint;

  /// No description provided for @addListingDetailsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Адрес, описание, ремонт, отопление'**
  String get addListingDetailsSubtitle;

  /// No description provided for @addListingRoomSuffix.
  ///
  /// In ru, this message translates to:
  /// **'{count} ком.'**
  String addListingRoomSuffix(String count);

  /// No description provided for @addListingAreaSuffix.
  ///
  /// In ru, this message translates to:
  /// **'{area} м²'**
  String addListingAreaSuffix(String area);

  /// No description provided for @addListingSchoolExample.
  ///
  /// In ru, this message translates to:
  /// **'Например, школа №61'**
  String get addListingSchoolExample;

  /// No description provided for @addListingAddBtn.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get addListingAddBtn;

  /// No description provided for @addListingBuilderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Застройщик / ЖК'**
  String get addListingBuilderTitle;

  /// No description provided for @addListingTotalFloorsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Всего этажей'**
  String get addListingTotalFloorsLabel;

  /// No description provided for @addListingPriceUSDLabel.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость (\\\$ USD)'**
  String get addListingPriceUSDLabel;

  /// No description provided for @addListingRoomLabel.
  ///
  /// In ru, this message translates to:
  /// **'Комната'**
  String get addListingRoomLabel;

  /// No description provided for @addListingUnspecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get addListingUnspecified;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ky', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ky':
      return AppLocalizationsKy();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
