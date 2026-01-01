import 'package:flutter/material.dart';

import 'app_language.dart';
import 'services/auth_service.dart';

class AppLocalizations extends InheritedWidget {
  final AppLocale locale;
  late final AppStrings strings = AppStrings(locale);

  AppLocalizations({required this.locale, required super.child, super.key});

  static AppStrings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocalizations>();
    assert(scope != null, 'No AppLocalizations found in context');
    return scope!.strings;
  }

  @override
  bool updateShouldNotify(AppLocalizations oldWidget) =>
      oldWidget.locale != locale;
}

class AppStrings {
  final AppLocale locale;
  const AppStrings(this.locale);

  bool get _isRu => locale == AppLocale.ru;

  String authError(AuthServiceException error) {
    final localized = _localizedFromMap(error.localizedMessages);
    return localized ?? _cleanError(error.message) ?? commonErrorTryAgain;
  }

  String backendError(String? rawMessage) =>
      _cleanError(rawMessage) ?? commonErrorTryAgain;

  String? _localizedFromMap(Map<String, String>? map) {
    if (map == null || map.isEmpty) return null;
    final order = _isRu
        ? const ['ru', 'uz', 'en', 'default']
        : const ['uz', 'ru', 'en', 'default'];
    for (final key in order) {
      final value = map[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    for (final value in map.values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _cleanError(String? message) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  // Home
  String get changeBranch => _isRu ? 'Сменить филиал' : 'Filialni tanlang';
  String get changeBranchSubtitle => _isRu ? 'Рядом с вами' : 'Sizga yaqin joy';
  String get searchHint => _isRu ? 'Поиск' : 'Izlash';
  String get loyaltyTitle => _isRu ? 'Моя карта' : 'Mening kartam';
  String get offersTitle => _isRu ? 'Предложения' : 'Takliflar';
  String get cashbackTitle => _isRu ? 'Баланс кешбэка' : 'Keshbek balansi';
  String get cashbackHelper => _isRu
      ? 'Можно использовать при 30 000 сум'
      : '30 000 soʻmdan keyin ishlata olasiz';
  String get membershipTitle => _isRu ? 'Уровень клуба' : 'Klub darajasi';
  String get membershipHelper => _isRu
      ? 'До золота осталось 3 000 баллов'
      : 'Gold darajasi uchun 3 000 ball qolgan';
  String get clubLevelScreenTitle => _isRu ? 'Уровень клуба' : 'Klub darajasi';
  String get clubLevelScreenDescription => _isRu
      ? 'Это демо-информация об уровнях. Собирайте баллы за каждую покупку и открывайте больше привилегий.'
      : 'Bu darajalar uchun demo maʼlumot. Har bir xaridda ball yigʻing va ko‘proq imtiyozlarni oching.';
  String get clubLevelCurrentLabel => _isRu ? 'Текущий балл' : 'Joriy ball';
  String get clubLevelNextLabel =>
      _isRu ? 'До следующего уровня' : 'Keyingi darajagacha';
  String clubLevelPointsToNext(String points) =>
      _isRu ? 'Осталось $points баллов' : '$points ball qoldi';
  String get clubLevelBenefitsTitle =>
      _isRu ? 'Преимущества уровня' : 'Daraja imtiyozlari';
  String get clubLevelBenefitPriority =>
      _isRu ? 'Приоритетная доставка' : 'Ustuvor yetkazib berish';
  String get clubLevelBenefitPriorityDesc => _isRu
      ? 'Заказы обрабатываются быстрее и без очереди.'
      : 'Buyurtmalar navbatsiz va tezroq tayyorlanadi.';
  String get clubLevelBenefitBirthday =>
      _isRu ? 'Подарок на день рождения' : 'Tug‘ilgan kun sovg‘asi';
  String get clubLevelBenefitBirthdayDesc => _isRu
      ? 'Персональный десерт и промокод в вашу неделю.'
      : 'Sizning haftangizda shaxsiy desert va promo kod.';
  String get clubLevelBenefitDiscount =>
      _isRu ? 'Скидка 5% на всё меню' : 'Menyu bo‘yicha 5% chegirma';
  String get clubLevelBenefitDiscountDesc => _isRu
      ? 'Постоянная скидка при заказе в приложении.'
      : 'Ilova orqali buyurtma qilganda doimiy chegirma.';
  String get notificationsTitle => _isRu ? 'Уведомления' : 'Bildirishnomalar';
  String get notificationsEmpty =>
      _isRu ? 'Новых уведомлений нет' : 'Yangi bildirishnoma yoʻq';
  String get birthdayOfferTitle =>
      _isRu ? 'С днём рождения!' : 'Tugʻilgan kun muborak!';
  String get birthdayOfferBody => _isRu
      ? 'Празднуйте у нас и получите скидку 15% на всё меню до конца недели.'
      : 'Biz bilan bayram qiling va hafta oxirigacha barcha menyuga 15% chegirma oling.';
  String get doublePointsBody => _isRu
      ? 'Собирайте двойные баллы за каждую доставку сегодня.'
      : 'Bugun har bir yetkazib berishda ikki baravar koʻp ball toʻplang.';
  String get cheesecakeBannerTitle => _isRu
      ? 'Подарок за регистрацию!'
      : 'Ro‘yxatdan o‘tganingiz uchun sovg‘a!';
  String get cheesecakeBannerSubtitle => _isRu
      ? 'Активируйте профиль и получите бесплатный чизкейк.'
      : 'Profilni faollashtiring va bepul chizkeyk oling.';
  String get cheesecakeBannerButton =>
      _isRu ? '🎁 Забрать подарок' : '🎁 Sovg‘ani olish';
  String get newsBannerButton => _isRu ? 'Подробнее' : 'Batafsil';
  String get cheesecakeSheetTitle =>
      _isRu ? 'Ваш подарочный QR' : 'Sizning sovgʻa QR kodingiz';
  String get cheesecakeSheetDescription => _isRu
      ? 'Покажите QR на кассе чтобы получить десерт.'
      : 'QRni kassaga ko‘rsating va desertni oling.';
  String get cashbackButtonCta => _isRu ? 'Подробнее' : 'Batafsil';
  String get cashbackScreenTitle => _isRu ? 'Кешбэк' : 'Keshbek';
  String get cashbackScreenDescription => _isRu
      ? 'Следите за начислениями и используйте кешбэк в любое время.'
      : 'Keshbek harakatlarini kuzating va istalgan payt foydalaning.';
  String get cashbackUseButton =>
      _isRu ? 'Использовать кешбэк' : 'Keshbekni ishlatish';
  String get cashbackUseLocked => _isRu ? 'Недоступно' : 'Mavjud emas';
  String get cashbackHistoryTitle =>
      _isRu ? 'История начислений' : 'Keshbek tarixi';
  String get cashbackHistoryDemoLabel =>
      _isRu ? 'Демо операции' : 'Demo operatsiyalar';
  String get cashbackHistoryEmpty =>
      _isRu ? 'История пока пуста' : 'Tarix hozircha bo‘sh';
  String get cashbackHistoryLoadError => _isRu
      ? 'Не удалось загрузить историю кешбэка.'
      : 'Keshbek tarixini yuklab boʻlmadi.';
  String cashbackHistoryEarned(String label) =>
      _isRu ? 'Начислено за $label' : '$label uchun qo‘shildi';
  String get cashbackRedeemSuccess =>
      _isRu ? 'Кешбэк применён' : 'Keshbek qo‘llandi';
  String get cashbackStatusPending => _isRu ? 'В ожидании' : 'Kutilmoqda';
  String get cashbackStatusCompleted => _isRu ? 'Зачислено' : 'Qoʻshildi';
  String get cashbackStatusPaid => _isRu ? 'Оплачено' : 'Toʻlandi';
  String get cashbackLoginRequired => _isRu
      ? 'Авторизуйтесь, чтобы увидеть кешбэк.'
      : 'Keshbekni ko‘rish uchun tizimga kiring.';
  String get cashbackSourceQr => _isRu ? 'Скан QR' : 'QR orqali';
  String get cashbackSourceOrder =>
      _isRu ? 'Заказ в ресторане' : 'Restorandagi buyurtma';
  String get cashbackSourceManual =>
      _isRu ? 'Ручное начисление' : 'Qoʻlda qoʻshish';
  String get cashbackSourceUnknown => _isRu ? 'Начисление' : 'Qoʻshildi';

  String get cashbackHistoryCredit => _isRu ? 'Зачислено' : 'Qoʻshildi';
  String get cashbackHistoryDebit => _isRu ? 'Оплачено' : 'Toʻlandi';

  String get languageSheetTitle => _isRu ? 'Выберите язык' : 'Tilni tanlang';
  String get commonCancel => _isRu ? 'Отмена' : 'Bekor qilish';
  String get commonDelete => _isRu ? 'Удалить' : 'Oʻchirish';
  String get commonSave => _isRu ? 'Сохранить' : 'Saqlash';
  String get commonOptional => _isRu ? 'Необязательно' : 'Ixtiyoriy';
  String get commonErrorTryAgain => _isRu
      ? 'Что-то пошло не так. Повторите попытку.'
      : 'Xatolik yuz berdi. Qayta urinib koʻring.';
  String get commonLoading => _isRu ? 'Загрузка...' : 'Yuklanmoqda...';
  String get commonRetry => _isRu ? 'Повторить' : 'Qayta urinish';

  // Catalog
  String get catalogTitle => _isRu ? 'Каталог' : 'Katalog';
  String get catalogBranchLabel =>
      _isRu ? 'Выбранный филиал' : 'Tanlangan filial';
  String get catalogUnavailableInBranch =>
      _isRu ? 'Нет в выбранном филиале' : 'Tanlangan filialda mavjud emas';
  String get catalogTemporarilyDisabled =>
      _isRu ? 'Временно недоступно' : 'Hozircha mavjud emas';
  String get catalogEmpty =>
      _isRu ? 'Здесь пока пусто' : 'Hozircha hech narsa yoʻq';
  String get catalogLoadError =>
      _isRu ? 'Не удалось загрузить каталог.' : 'Katalogni yuklab boʻlmadi.';
  String get catalogRetry => _isRu ? 'Повторить' : 'Qayta urinish';
  String catalogRelatedProducts(String categoryName) => _isRu
      ? 'Ещё из категории $categoryName'
      : '$categoryName boʻlimidan boshqalar';

  // Locations
  String get locationsTitle => _isRu ? 'Наши филиалы' : 'Filiallarimiz';
  String get locationsMapHeader => _isRu ? 'На карте' : 'Xaritada';
  String get locationsListHeader =>
      _isRu ? 'Список филиалов' : 'Filiallar roʻyxati';
  String get locationsSearchHint =>
      _isRu ? 'Поиск филиала...' : 'Filial qidirish...';
  String get locationsEmpty =>
      _isRu ? 'Филиалы не найдены' : 'Filial topilmadi';
  String get openNow => _isRu ? 'Открыто' : 'Ochiq';
  String get dailySchedule =>
      _isRu ? 'Ежедневно 09:00 - 23:00' : 'Har kuni 09:00 - 23:00';
  String get showOnMap => _isRu ? 'Показать на карте' : 'Xaritada koʻrsatish';
  String get locationsDirectionsButton => _isRu ? 'Маршрут' : 'Yoʻnalish';
  String get locationsDirectionsError => _isRu
      ? 'Не удалось открыть приложение карт.'
      : 'Xarita ilovasini ochib boʻlmadi.';
  String get locationPermissionTitle => _isRu
      ? '📍 Необходимо ваше местоположение'
      : '📍 Sizning joylashuvingiz kerak';
  String get locationPermissionDescription => _isRu
      ? 'Разрешите доступ к вашей геолокации, чтобы найти ближайший филиал.'
      : 'Eng yaqin filialni topish uchun joylashuvingizga ruxsat bering.';
  String get locationPermissionAllow => _isRu ? 'Разрешить' : 'Ruxsat berish';
  String get locationPermissionDeny => _isRu ? 'Отклонить' : 'Rad etish';
  String get locationPermissionHint => _isRu
      ? 'Доступ используется только для определения ближайшего филиала.'
      : 'Joylashuv faqat eng yaqin filialni aniqlash uchun ishlatiladi.';
  String get locationPermissionDeniedMessage => _isRu
      ? 'Без доступа к геолокации мы не сможем найти ближайший филиал.'
      : 'Joylashuvga ruxsat bo‘lmasa, eng yaqin filialni topa olmaymiz.';
  String get locationServicesDisabledMessage => _isRu
      ? 'Включите службы геолокации, чтобы показать ближайший филиал.'
      : 'Eng yaqin filialni ko‘rsatish uchun joylashuv xizmatlarini yoqing.';

  // Profile
  String get profileTitle => _isRu ? 'Профиль' : 'Profil';
  String get profileGuestName => _isRu ? 'Гость' : 'Mehmon';
  String profileTierBadge(String tier) =>
      _isRu ? '$tier участник' : '$tier darajasi';
  String get profileAccountSection =>
      _isRu ? 'Учётная запись' : 'Profil maʼlumotlari';
  String get profileSupportSection =>
      _isRu ? 'Поддержка и сервис' : 'Yordam va servis';
  String get profileInfoMenuTitle =>
      _isRu ? 'Данные профиля' : 'Profil maʼlumotlari';
  String get profileInfoMenuSubtitle => _isRu
      ? 'Измените имя, дату рождения'
      : 'Ism, tugʻilgan sanangizni yangilang';
  String get profilePinMenuTitle =>
      _isRu ? 'Сменить PIN' : 'PIN kodni almashtirish';
  String get profilePinMenuSubtitle =>
      _isRu ? 'Обновите защиту аккаунта' : 'Profil xavfsizligini yangilang';
  String get profileNotificationsMenuTitle =>
      _isRu ? 'Уведомления' : 'Bildirishnomalar';
  String get profileNotificationsMenuSubtitle =>
      _isRu ? 'История и настройки рассылок' : 'Tarix va xabarnoma sozlamalari';
  String get profileHelpMenuTitle =>
      _isRu ? 'Справка и поддержка' : 'Qoʻllab-quvvatlash';
  String get profileHelpMenuSubtitle =>
      _isRu ? 'FAQ, чат и контакты' : 'FAQ, chat va aloqa';
  String get profileReferMenuTitle =>
      _isRu ? 'Пригласить друзей' : 'Doʻstlarni taklif qilish';
  String get profileReferMenuSubtitle => _isRu
      ? 'Получайте бонусы за приглашения'
      : 'Takliflar evaziga bonus oling';
  String loyaltyNextLevelLabel(String level) =>
      _isRu ? 'Следующий уровень: $level' : 'Keyingi daraja: $level';
  String loyaltyPointsToNextHelper(String points, String level) => _isRu
      ? 'До уровня $level осталось $points баллов.'
      : '$level darajasi uchun $points ball qolgan.';
  String get loyaltyMaxLevelHelper => _isRu
      ? 'У вас максимальный клубный уровень.'
      : 'Siz eng yuqori klub darajasidasiz.';
  String loyaltyProgressLabel(String current, String total) =>
      _isRu ? 'Прогресс: $current / $total' : 'Jarayon: $current / $total';

  // Help Center
  String get helpCenterTitle =>
      _isRu ? 'Справка и поддержка' : 'Yordam markazi';
  String get helpCenterCallTitle => _isRu ? 'Колл-центр' : 'Qo‘ng‘iroq markazi';
  String get helpCenterCallDescription =>
      _isRu ? 'Наш номер для звонков' : 'Bizning qo‘ng‘iroq markazi raqami';
  String get helpCenterCallButton => _isRu ? 'Позвонить' : 'Qo‘ng‘iroq qilish';
  String get helpCenterCallError => _isRu
      ? 'Не удалось начать звонок'
      : 'Qo‘ng‘iroqni amalga oshirib bo‘lmadi';
  String get profileLogout => _isRu ? 'Выйти из аккаунта' : 'Hisobdan chiqish';
  String get profileLogoutConfirmTitle =>
      _isRu ? 'Выйти из аккаунта?' : 'Hisobdan chiqasizmi?';
  String get profileLogoutConfirmBody => _isRu
      ? 'Мы деактивируем ваш сеанс на этом устройстве.'
      : 'Ushbu qurilmadagi seans yakunlanadi.';
  String get profileLogoutConfirmPrimary => _isRu ? 'Выйти' : 'Chiqish';
  String get profileLogoutConfirmSecondary =>
      _isRu ? 'Остаться' : 'Bekor qilish';
  String get profileDeleteAccount =>
      _isRu ? 'Удалить аккаунт' : 'Profilni o‘chirish';
  String get profileDeleteConfirmTitle =>
      _isRu ? 'Удалить профиль?' : 'Profil o‘chirilsinmi?';
  String get profileDeleteConfirmBody => _isRu
      ? 'Мы удалим ваши персональные данные и кешбэк. Действие нельзя отменить.'
      : 'Shaxsiy maʼlumotlar va keshbek o‘chirib yuboriladi. Bu amalni qaytarib boʻlmaydi.';
  String get profileDeleteConfirmPrimary => _isRu ? 'Удалить' : 'O‘chirish';
  String get profileDeleteConfirmSecondary => _isRu ? 'Отмена' : 'Bekor qilish';
  String get profileDeleteSuccess =>
      _isRu ? 'Аккаунт удалён' : 'Hisob o‘chirildi';
  String get profileAvatarActionTitle =>
      _isRu ? 'Фото профиля' : 'Profil rasmi';
  String get profileAvatarActionCamera =>
      _isRu ? 'Сделать фото' : 'Kamera orqali';
  String get profileAvatarActionGallery =>
      _isRu ? 'Выбрать из галереи' : 'Galereyadan tanlash';
  String get profileAvatarActionRemove =>
      _isRu ? 'Удалить фото' : 'Rasmdan voz kechish';
  String get profileAvatarUploadError =>
      _isRu ? 'Не удалось загрузить фото.' : 'Rasmni yuklab boʻlmadi.';
  String get profileAvatarUploadSuccess =>
      _isRu ? 'Фото обновлено' : 'Rasm yangilandi';
  String get profileAvatarCameraPermissionDenied => _isRu
      ? 'Разрешите приложению доступ к камере, чтобы сфотографировать.'
      : 'Ilovaga kameraga ruxsat bering, rasmga olish uchun.';
  String get profileAvatarGalleryPermissionDenied => _isRu
      ? 'Разрешите приложению доступ к галерее, чтобы выбрать фото.'
      : 'Ilovaga galereyaga ruxsat bering, rasm tanlash uchun.';
  String get profileLoginRequired => _isRu
      ? 'Войдите, чтобы управлять профилем.'
      : 'Profil sozlamalari uchun tizimga kiring.';
  String get profileDobLabel => _isRu ? 'Дата рождения' : 'Tugʻilgan sana';
  String get profileDobPlaceholder =>
      _isRu ? 'Выберите дату' : 'Sanani tanlang';
  String get profileDobValidation =>
      _isRu ? 'Укажите дату рождения' : 'Tugʻilgan sanani kiriting';
  String formatDateDdMMyyyy(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  String get profileInfoSignInHint => _isRu
      ? 'Войдите, чтобы сохранить данные и получить персональный опыт.'
      : 'Maʼlumotlarni saqlash va shaxsiy tajriba uchun tizimga kiring.';
  String get profileInfoSectionTitle =>
      _isRu ? 'Личные данные' : 'Shaxsiy maʼlumotlar';
  String get profileInfoSaveSuccess =>
      _isRu ? 'Профиль обновлён' : 'Profil yangilandi';
  String get profileLanguageSectionTitle =>
      _isRu ? 'Язык приложения' : 'Ilova tili';
  String get profileLanguageSectionSubtitle =>
      _isRu ? 'Выберите язык интерфейса.' : 'Interfeys tilini tanlang.';

  // PIN
  String get pinSetupCreateTitle =>
      _isRu ? 'Создайте PIN-код' : 'Yangi PIN-kod yarating';
  String get pinSetupCreateSubtitle => _isRu
      ? 'Используйте 4 цифры, чтобы защитить аккаунт.'
      : 'Hisobingizni himoyalash uchun 4 xonali kod kiriting.';
  String get pinSetupConfirmTitle =>
      _isRu ? 'Подтвердите PIN-код' : 'PIN-kodni tasdiqlang';
  String get pinSetupConfirmSubtitle =>
      _isRu ? 'Введите PIN ещё раз.' : 'PIN-kodni yana kiriting.';
  String get pinSetupMismatch => _isRu
      ? 'PIN-коды не совпадают. Попробуйте ещё раз.'
      : 'PIN-kodlar mos kelmadi. Qayta urinib ko‘ring.';
  String get pinSetupReset => _isRu ? 'Начать заново' : 'Qaytadan boshlash';
  String get pinSetupClear => _isRu ? 'Очистить' : 'Tozalash';
  String get pinLockTitle => _isRu ? 'Введите PIN-код' : 'PIN-kodni kiriting';
  String get pinLockSubtitle => _isRu
      ? 'Разблокируйте Sardoba, чтобы продолжить.'
      : 'Davom etish uchun Sardobani oching.';
  String get pinLockError => _isRu
      ? 'Неверный PIN. Попробуйте снова.'
      : 'PIN noto‘g‘ri. Qayta urinib ko‘ring.';
  String get pinSwitchAccount =>
      _isRu ? 'Сменить аккаунт' : 'Hisobni almashtirish';
  String get changePinScreenTitle =>
      _isRu ? 'Изменить PIN' : 'PIN-kodni o‘zgartirish';
  String get changePinVerifyTitle =>
      _isRu ? 'Введите текущий PIN-код' : 'Joriy PIN-kodni kiriting';
  String get changePinVerifySubtitle => _isRu
      ? 'Подтвердите свою личность перед сменой PIN-кода.'
      : 'PIN-kodni o‘zgartirishdan oldin o‘zingiz ekanligingizni tasdiqlang.';
  String get changePinNewTitle =>
      _isRu ? 'Придумайте новый PIN-код' : 'Yangi PIN-kodni yarating';
  String get changePinNewSubtitle => _isRu
      ? 'Выберите легко запоминающийся 4-значный код.'
      : 'Yodda saqlash oson bo‘lgan 4 xonali kod tanlang.';
  String get changePinConfirmTitle =>
      _isRu ? 'Подтвердите новый PIN-код' : 'Yangi PIN-kodni tasdiqlang';
  String get changePinConfirmSubtitle => _isRu
      ? 'Введите PIN ещё раз, чтобы убедиться, что он верен.'
      : 'Kod to‘g‘ri ekanligiga ishonch hosil qilish uchun yana kiriting.';
  String get changePinSuccess => _isRu ? 'PIN обновлён' : 'PIN-kod yangilandi';

  // QR
  String get qrScreenTitle => _isRu ? 'Мой QR-код' : 'Mening QR-kodim';
  String get qrScreenInstruction =>
      _isRu ? 'Покажите этот код на кассе.' : 'Ushbu kodni kassaga ko‘rsating.';
  String get qrScreenFooter => _isRu
      ? 'QR-код связывает ваш аккаунт и номер телефона для бонусов.'
      : 'QR-kod hisobingizni telefon raqamingiz bilan bog‘laydi va bonuslarni tezlashtiradi.';
  String get qrScreenAccountFallback =>
      _isRu ? 'Ваш аккаунт' : 'Sizning hisobingiz';
  String get qrScreenPhoneMissingTitle =>
      _isRu ? 'Телефон не найден' : 'Telefon raqami topilmadi';
  String get qrScreenPhoneMissingSubtitle => _isRu
      ? 'Войдите снова, чтобы получить QR-код.'
      : 'QR kodni olish uchun qayta kiring.';
  String get qrScreenErrorTitle =>
      _isRu ? 'Не удалось загрузить QR-код' : 'QR kod yuklanmadi';
  String get qrScreenErrorSubtitle =>
      _isRu ? 'Попробуйте чуть позже.' : 'Birozdan so‘ng qayta urinib ko‘ring.';

  // Forms & Auth
  String get authEnterPhone =>
      _isRu ? 'Введите телефон' : 'Telefon raqamingizni kiriting';
  String get authPhoneHint => _isRu ? '+998 90 123 45 67' : '+998 90 123 45 67';
  String get authOtpInfoLogin => _isRu
      ? 'Мы отправим 4-значный код на этот номер.'
      : 'Ushbu raqamga 4 xonali kod yuboramiz.';
  String get authOtpInfoRegister => _isRu
      ? 'Мы отправим 4-значный код для подтверждения номера.'
      : 'Raqamni tasdiqlash uchun 4 xonali kod yuboramiz.';
  String get authOtpScreenTitle =>
      _isRu ? 'Подтвердите код' : 'Tasdiqlash kodi';
  String authOtpSubtitle(String phoneLabel) => _isRu
      ? 'Введите 4-значный код, отправленный на $phoneLabel.'
      : '$phoneLabel raqamiga yuborilgan 4 xonali kodni kiriting.';
  String authOtpDemoHelper(String code) => _isRu
      ? 'Для демо используйте код $code.'
      : 'Demo uchun $code kodidan foydalaning.';
  String get authOtpResendQuestion =>
      _isRu ? 'Код не пришёл?' : 'Kod kelmadimi?';
  String get authOtpResendCta => _isRu ? 'Отправить ещё раз' : 'Qayta yuborish';
  String get authOtpResent =>
      _isRu ? 'Код отправлен повторно' : 'Kod qayta yuborildi';
  String get authOtpResendFailed => _isRu
      ? 'Не удалось отправить код. Попробуйте ещё раз.'
      : 'Kod yuborilmadi. Qayta urinib koʻring.';
  String get authOtpIncorrect => _isRu ? 'Неверный код' : 'Notoʻgʻri kod';
  String get authOtpTerms => _isRu
      ? 'Продолжая, вы соглашаетесь с условиями и политикой конфиденциальности.'
      : 'Davom etish orqali siz shartlar va maxfiylik siyosatiga rozilik bildirasiz.';
  String get authSignInSubtitle => _isRu
      ? 'Введите номер телефона, чтобы получить код подтверждения.'
      : 'Tasdiqlash kodini olish uchun telefon raqamingizni kiriting.';
  String get authNoAccountQuestion =>
      _isRu ? 'Ещё нет аккаунта?' : 'Hali akkauntingiz yoʻqmi?';
  String get authCreateAccountCta =>
      _isRu ? 'Создать аккаунт' : 'Yangi akkaunt ochish';
  String get authSignUpTitle => _isRu ? 'Создать аккаунт' : 'Akkaunt ochish';
  String get authSignUpSubtitle => _isRu
      ? 'Укажите имя и телефон, чтобы начать.'
      : 'Boshlash uchun ismingiz va telefon raqamingizni kiriting.';
  String get authHaveAccountQuestion =>
      _isRu ? 'Уже есть аккаунт?' : 'Allaqachon akkauntingiz bormi?';
  String get authSignInCta => _isRu ? 'Войти' : 'Kirish';
  String get authSendCode => _isRu ? 'Получить код' : 'Kod olish';
  String get authEnterName => _isRu ? 'Введите имя' : 'Ismingizni kiriting';
  String get authNameHint => _isRu ? 'Саидмурод' : 'Saidmurod';
  String get authNameRequired => _isRu ? 'Введите имя' : 'Ismingizni kiriting';
  String get authNameTooShort =>
      _isRu ? 'Имя слишком короткое' : 'Ism juda qisqa';
  String get authReferralToggle => _isRu ? 'Код официанта' : 'Ofitsiant kodi';
  String get authReferralHint =>
      _isRu ? 'Введите реферальный код' : 'Referal kodni kiriting';
  String get authContinue => _isRu ? 'Продолжить' : 'Davom etish';
  String get authDobLabel => _isRu ? 'Дата рождения' : 'Tugʻilgan sana';
  String get authDobHint => _isRu ? 'Выберите дату' : 'Sanani tanlang';
  String get authDobValidation =>
      _isRu ? 'Укажите дату рождения' : 'Tugʻilgan sanani kiriting';
  String get dobTooYoung =>
      _isRu ? 'Вам должно быть 13 лет или больше' : '13 yoshdan katta bo‘lishingiz kerak';
  String get formFullNameLabel => _isRu ? 'Полное имя' : 'Toʻliq ism';
  String get formFullNameHint => _isRu ? 'Введите имя' : 'Ismingizni kiriting';
  String get formFullNameRequired =>
      _isRu ? 'Введите имя' : 'Ismingizni kiriting';
  String get formFullNameTooShort =>
      _isRu ? 'Имя слишком короткое' : 'Ism juda qisqa';
  String get formSurnameLabel => _isRu ? 'Фамилия' : 'Familiya';
  String get formSurnameHint =>
      _isRu ? 'Введите фамилию' : 'Familiyangizni kiriting';
  String get formSurnameRequired =>
      _isRu ? 'Укажите фамилию' : 'Familiyangizni yozing';
  String get formSurnameTooShort => _isRu
      ? 'Фамилия слишком короткая'
      : 'Familiya kamida 2 ta belgidan iborat bo‘lishi kerak';
  String get formFirstNameLabel => _isRu ? 'Имя' : 'Ism';
  String get formFirstNameHint => _isRu ? 'Введите имя' : 'Ismingizni kiriting';
  String get formFirstNameRequired =>
      _isRu ? 'Укажите имя' : 'Ismingizni yozing';
  String get formFirstNameTooShort => _isRu
      ? 'Имя слишком короткое'
      : 'Ism kamida 2 ta belgidan iborat bo‘lishi kerak';
  String get formMiddleNameLabel => _isRu ? 'Отчество' : 'Otasining ismi';
  String get formMiddleNameHint =>
      _isRu ? 'Введите отчество' : 'Otasining ismini kiriting';
  String get formMiddleNameTooShort => _isRu
      ? 'Отчество слишком короткое'
      : 'Otasining ismi kamida 2 ta belgidan iborat bo‘lishi kerak';
  String get formPhoneLabel => _isRu ? 'Телефон' : 'Telefon';
  String get formReferralLabel => _isRu ? 'Реферальный код' : 'Referal kod';
  String get formReferralHelper => _isRu
      ? 'Делитесь кодом с друзьями и получайте бонусы.'
      : 'Kod bilan oʻrtoqlashing va bonuslar oling.';
  String get formReferralHint => _isRu ? 'Необязательно' : 'Ixtiyoriy';
  String get formSaveChanges =>
      _isRu ? 'Сохранить изменения' : 'Oʻzgarishlarni saqlash';

  // Notifications
  String get notificationsScreenEmpty =>
      _isRu ? 'Пока нет уведомлений.' : 'Hozircha bildirishnoma yoʻq.';
  String get notificationsScreenError => _isRu
      ? 'Не удалось загрузить уведомления.'
      : 'Bildirishnomalarni yuklab boʻlmadi.';
  String get notificationsPullToRefresh =>
      _isRu ? 'Потяните, чтобы обновить' : 'Yangilash uchun torting';

  String languageLabel(AppLocale locale) {
    switch (locale) {
      case AppLocale.ru:
        return _isRu ? 'Русский' : 'Rus tili';
      case AppLocale.uz:
        return _isRu ? 'Узбекский' : 'Oʻzbekcha';
    }
  }
}
