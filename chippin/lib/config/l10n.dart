import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

final l10nProvider = Provider<AppStrings>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final lang = user?.language ?? 'en';
  return lang == 'ru' ? const AppStringsRu() : const AppStringsEn();
});

class AppStrings {
  // Common
  final String appName;
  final String next;
  final String done;
  final String retry;
  final String share;
  final String cancel;
  final String you;
  final String organizer;
  final String participant;
  final String everyone;
  final String error;

  // Bottom nav
  final String navHome;
  final String navHistory;
  final String navProfile;

  // Login
  final String loginSubtitle;
  final String continueWithGoogle;
  final String continueWithApple;
  final String continueWithTelegram;
  final String devLogin;
  final String signInFailed;
  final String termsIntro;
  final String termsOfService;
  final String privacyPolicy;

  // Home
  final String myBills;
  final String bills;
  final String totalSpent;
  final String recent;
  final String newestFirst;
  final String noBillsYet;
  final String noBillsDescription;
  final String failedToLoadBills;
  final String people; // "{n} people"

  // New Bill
  final String newBill;
  final String billName;
  final String billNameHint;
  final String date;
  final String today;
  final String yesterday;
  final String tomorrow;
  final String nextStepHint;
  final String tagDinner;
  final String tagTrip;
  final String tagParty;
  final String tagGroceries;
  final String tagRent;

  // Participants
  final String addParticipants;
  final String enterName;
  final String participants;
  final String addPersonHint;

  // Items
  final String addItems;
  final String scanReceipt;
  final String addManually;
  final String cameraRequired;
  final String scanHint;
  final String itemName;
  final String itemNameHint;
  final String qty;
  final String pricePerUnit;
  final String update;
  final String addItem;
  final String items;
  final String total;
  final String noItemsHint;
  final String takePhoto;
  final String chooseFromGallery;
  final String dictate;
  final String scanningReceipt;
  final String scanFailed;
  final String noItemsRecognized;
  final String saveAll;
  final String reviewItems;
  final String recording;
  final String processingVoice;
  final String voiceFailed;
  final String noItemsFromVoice;
  final String micPermissionRequired;

  // Split
  final String splitItems;
  final String splitEqually;
  final String divideAmongEveryone;
  final String choosePeople;
  final String pickWhoPays;
  final String selectParticipants;
  final String distributed;

  // Paid By
  final String whoPaid;
  final String billTotal;
  final String selectWhoPaid;
  final String paid;
  final String finish;

  // Summary
  final String billSummary;
  final String grandTotal;
  final String paidBy;
  final String coveredFullBill;
  final String eachPersonShare;
  final String whoOwesWhat;
  final String owes;
  final String failedToLoadSummary;
  final String deleteBill;
  final String deleteBillConfirm;
  final String delete;

  // History
  final String history;
  final String searchBills;
  final String noBillsFound;
  final String settled;
  final String pending;

  // Profile
  final String profile;
  final String preferences;
  final String currency;
  final String currencySubtitle;
  final String language;
  final String languageSubtitle;
  final String general;
  final String aboutApp;
  final String aboutAppSubtitle;
  final String rateApp;
  final String rateAppSubtitle;
  final String logOut;

  const AppStrings({
    required this.appName,
    required this.next,
    required this.done,
    required this.retry,
    required this.share,
    required this.cancel,
    required this.you,
    required this.organizer,
    required this.participant,
    required this.everyone,
    required this.error,
    required this.navHome,
    required this.navHistory,
    required this.navProfile,
    required this.loginSubtitle,
    required this.continueWithGoogle,
    required this.continueWithApple,
    required this.continueWithTelegram,
    required this.devLogin,
    required this.signInFailed,
    required this.termsIntro,
    required this.termsOfService,
    required this.privacyPolicy,
    required this.myBills,
    required this.bills,
    required this.totalSpent,
    required this.recent,
    required this.newestFirst,
    required this.noBillsYet,
    required this.noBillsDescription,
    required this.failedToLoadBills,
    required this.people,
    required this.newBill,
    required this.billName,
    required this.billNameHint,
    required this.date,
    required this.today,
    required this.yesterday,
    required this.tomorrow,
    required this.nextStepHint,
    required this.tagDinner,
    required this.tagTrip,
    required this.tagParty,
    required this.tagGroceries,
    required this.tagRent,
    required this.addParticipants,
    required this.enterName,
    required this.participants,
    required this.addPersonHint,
    required this.addItems,
    required this.scanReceipt,
    required this.addManually,
    required this.cameraRequired,
    required this.scanHint,
    required this.itemName,
    required this.itemNameHint,
    required this.qty,
    required this.pricePerUnit,
    required this.update,
    required this.addItem,
    required this.items,
    required this.total,
    required this.noItemsHint,
    required this.takePhoto,
    required this.chooseFromGallery,
    required this.dictate,
    required this.scanningReceipt,
    required this.scanFailed,
    required this.noItemsRecognized,
    required this.saveAll,
    required this.reviewItems,
    required this.recording,
    required this.processingVoice,
    required this.voiceFailed,
    required this.noItemsFromVoice,
    required this.micPermissionRequired,
    required this.splitItems,
    required this.splitEqually,
    required this.divideAmongEveryone,
    required this.choosePeople,
    required this.pickWhoPays,
    required this.selectParticipants,
    required this.distributed,
    required this.whoPaid,
    required this.billTotal,
    required this.selectWhoPaid,
    required this.paid,
    required this.finish,
    required this.billSummary,
    required this.grandTotal,
    required this.paidBy,
    required this.coveredFullBill,
    required this.eachPersonShare,
    required this.whoOwesWhat,
    required this.owes,
    required this.failedToLoadSummary,
    required this.deleteBill,
    required this.deleteBillConfirm,
    required this.delete,
    required this.history,
    required this.searchBills,
    required this.noBillsFound,
    required this.settled,
    required this.pending,
    required this.profile,
    required this.preferences,
    required this.currency,
    required this.currencySubtitle,
    required this.language,
    required this.languageSubtitle,
    required this.general,
    required this.aboutApp,
    required this.aboutAppSubtitle,
    required this.rateApp,
    required this.rateAppSubtitle,
    required this.logOut,
  });

  String itemsOfTotal(int assigned, int total) => '$assigned of $total items assigned';
  String itemsAndPeople(int itemCount, int peopleCount) => '$itemCount items · $peopleCount people';
  String nPeople(int n) => '$n $people';
  String nBills(int n) => '$n $bills';
}

class AppStringsEn extends AppStrings {
  const AppStringsEn()
      : super(
          appName: 'Chippin',
          next: 'Next',
          done: 'Done',
          retry: 'Retry',
          share: 'Share',
          cancel: 'Cancel',
          you: 'You',
          organizer: 'Organizer',
          participant: 'Participant',
          everyone: 'Everyone',
          error: 'Error',
          navHome: 'Home',
          navHistory: 'History',
          navProfile: 'Profile',
          loginSubtitle: 'Split bills effortlessly',
          continueWithGoogle: 'Continue with Google',
          continueWithApple: 'Continue with Apple',
          continueWithTelegram: 'Continue with Telegram',
          devLogin: 'Dev Login (test@test.com)',
          signInFailed: 'Sign in failed. Please try again.',
          termsIntro: 'By continuing, you agree to our\n',
          termsOfService: 'Terms of Service',
          privacyPolicy: 'Privacy Policy',
          myBills: 'My Bills',
          bills: 'BILLS',
          totalSpent: 'TOTAL SPENT',
          recent: 'RECENT',
          newestFirst: 'Newest first',
          noBillsYet: 'No bills yet',
          noBillsDescription: 'Create your first one and start\nsplitting with friends!',
          failedToLoadBills: 'Failed to load bills',
          people: 'people',
          newBill: 'New Bill',
          billName: 'BILL NAME',
          billNameHint: 'e.g. Friday Dinner',
          date: 'DATE',
          today: 'Today',
          yesterday: 'Yesterday',
          tomorrow: 'Tomorrow',
          nextStepHint: 'Next step — add people to split with',
          tagDinner: 'Dinner',
          tagTrip: 'Trip',
          tagParty: 'Party',
          tagGroceries: 'Groceries',
          tagRent: 'Rent',
          addParticipants: 'Add Participants',
          enterName: 'Enter name...',
          participants: 'PARTICIPANTS',
          addPersonHint: 'Add at least one person\nto split the bill with',
          addItems: 'Add Items',
          scanReceipt: 'Scan Receipt',
          addManually: 'Add Manually',
          cameraRequired: 'Camera access required',
          scanHint: 'Point your camera at the receipt\nto auto-detect items and prices',
          itemName: 'ITEM NAME',
          itemNameHint: 'e.g. Caesar Salad',
          qty: 'QTY',
          pricePerUnit: 'PRICE PER UNIT',
          update: 'Update',
          addItem: 'Add Item',
          items: 'ITEMS',
          total: 'Total',
          noItemsHint: 'No items added yet.\nScan a receipt or add manually',
          takePhoto: 'Photo',
          chooseFromGallery: 'Gallery',
          dictate: 'Voice',
          scanningReceipt: 'Scanning receipt...',
          scanFailed: 'Could not scan receipt',
          noItemsRecognized: 'No items recognized. Try another photo',
          saveAll: 'Save All',
          reviewItems: 'Review Items',
          recording: 'Recording...',
          processingVoice: 'Processing voice...',
          voiceFailed: 'Could not process voice',
          noItemsFromVoice: 'No items recognized. Try again',
          micPermissionRequired: 'Microphone access required',
          splitItems: 'Split Items',
          splitEqually: 'Split equally',
          divideAmongEveryone: 'Divide among everyone',
          choosePeople: 'Choose people',
          pickWhoPays: 'Pick who pays for this item',
          selectParticipants: 'SELECT PARTICIPANTS',
          distributed: 'Distributed',
          whoPaid: 'Who Paid?',
          billTotal: 'BILL TOTAL',
          selectWhoPaid: 'SELECT WHO PAID THE BILL',
          paid: 'PAID',
          finish: 'Finish',
          billSummary: 'Bill Summary',
          grandTotal: 'Grand Total',
          paidBy: 'PAID BY',
          coveredFullBill: 'Covered the full bill',
          eachPersonShare: "EACH PERSON'S SHARE",
          whoOwesWhat: 'WHO OWES WHAT',
          owes: 'owes',
          failedToLoadSummary: 'Failed to load summary',
          deleteBill: 'Delete Bill',
          deleteBillConfirm: 'Are you sure you want to delete this bill? This action cannot be undone.',
          delete: 'Delete',
          history: 'History',
          searchBills: 'Search bills...',
          noBillsFound: 'No bills found',
          settled: 'SETTLED',
          pending: 'PENDING',
          profile: 'Profile',
          preferences: 'PREFERENCES',
          currency: 'Currency',
          currencySubtitle: 'Default currency for new bills',
          language: 'Language',
          languageSubtitle: 'Interface language',
          general: 'GENERAL',
          aboutApp: 'About App',
          aboutAppSubtitle: 'Version, licenses, credits',
          rateApp: 'Rate Chippin',
          rateAppSubtitle: 'Help us grow on the App Store',
          logOut: 'Log Out',
        );

  @override
  String itemsOfTotal(int assigned, int total) => '$assigned of $total items assigned';
  @override
  String itemsAndPeople(int itemCount, int peopleCount) => '$itemCount items · $peopleCount people';
}

class AppStringsRu extends AppStrings {
  const AppStringsRu()
      : super(
          appName: 'Chippin',
          next: 'Далее',
          done: 'Готово',
          retry: 'Повторить',
          share: 'Поделиться',
          cancel: 'Отмена',
          you: 'Вы',
          organizer: 'Организатор',
          participant: 'Участник',
          everyone: 'Все',
          error: 'Ошибка',
          navHome: 'Главная',
          navHistory: 'История',
          navProfile: 'Профиль',
          loginSubtitle: 'Делите счета легко',
          continueWithGoogle: 'Войти через Google',
          continueWithApple: 'Войти через Apple',
          continueWithTelegram: 'Войти через Telegram',
          devLogin: 'Dev вход (test@test.com)',
          signInFailed: 'Ошибка входа. Попробуйте снова.',
          termsIntro: 'Продолжая, вы соглашаетесь с\n',
          termsOfService: 'Условиями использования',
          privacyPolicy: 'Политикой конфиденциальности',
          myBills: 'Мои счета',
          bills: 'СЧЕТА',
          totalSpent: 'ВСЕГО',
          recent: 'НЕДАВНИЕ',
          newestFirst: 'Сначала новые',
          noBillsYet: 'Пока нет счетов',
          noBillsDescription: 'Создайте первый и начните\nделить с друзьями!',
          failedToLoadBills: 'Не удалось загрузить счета',
          people: 'чел.',
          newBill: 'Новый счёт',
          billName: 'НАЗВАНИЕ',
          billNameHint: 'напр. Ужин в пятницу',
          date: 'ДАТА',
          today: 'Сегодня',
          yesterday: 'Вчера',
          tomorrow: 'Завтра',
          nextStepHint: 'Далее — добавьте людей для разделения',
          tagDinner: 'Ужин',
          tagTrip: 'Поездка',
          tagParty: 'Вечеринка',
          tagGroceries: 'Продукты',
          tagRent: 'Аренда',
          addParticipants: 'Участники',
          enterName: 'Введите имя...',
          participants: 'УЧАСТНИКИ',
          addPersonHint: 'Добавьте хотя бы одного\nчеловека для разделения',
          addItems: 'Позиции',
          scanReceipt: 'Сканировать чек',
          addManually: 'Добавить вручную',
          cameraRequired: 'Нужен доступ к камере',
          scanHint: 'Наведите камеру на чек\nдля автоматического распознавания',
          itemName: 'НАЗВАНИЕ',
          itemNameHint: 'напр. Цезарь салат',
          qty: 'КОЛ-ВО',
          pricePerUnit: 'ЦЕНА ЗА ЕД.',
          update: 'Обновить',
          addItem: 'Добавить',
          items: 'ПОЗИЦИИ',
          total: 'Итого',
          noItemsHint: 'Позиций пока нет.\nОтсканируйте чек или добавьте вручную',
          takePhoto: 'Фото',
          chooseFromGallery: 'Галерея',
          dictate: 'Голос',
          scanningReceipt: 'Распознаём чек...',
          scanFailed: 'Не удалось распознать чек',
          noItemsRecognized: 'Позиции не найдены. Попробуйте другое фото',
          saveAll: 'Сохранить всё',
          reviewItems: 'Проверьте позиции',
          recording: 'Запись...',
          processingVoice: 'Обработка голоса...',
          voiceFailed: 'Не удалось обработать голос',
          noItemsFromVoice: 'Позиции не распознаны. Попробуйте снова',
          micPermissionRequired: 'Нужен доступ к микрофону',
          splitItems: 'Разделение',
          splitEqually: 'Поровну',
          divideAmongEveryone: 'Разделить между всеми',
          choosePeople: 'Выбрать людей',
          pickWhoPays: 'Выберите кто платит за эту позицию',
          selectParticipants: 'ВЫБЕРИТЕ УЧАСТНИКОВ',
          distributed: 'Распределено',
          whoPaid: 'Кто заплатил?',
          billTotal: 'СУММА СЧЁТА',
          selectWhoPaid: 'ВЫБЕРИТЕ КТО ОПЛАТИЛ СЧЁТ',
          paid: 'ОПЛАТИЛ',
          finish: 'Завершить',
          billSummary: 'Итоги счёта',
          grandTotal: 'Общий итог',
          paidBy: 'ОПЛАТИЛ',
          coveredFullBill: 'Оплатил весь счёт',
          eachPersonShare: 'ДОЛЯ КАЖДОГО',
          whoOwesWhat: 'КТО КОМУ ДОЛЖЕН',
          owes: 'должен',
          failedToLoadSummary: 'Не удалось загрузить итоги',
          deleteBill: 'Удалить счёт',
          deleteBillConfirm: 'Вы уверены, что хотите удалить этот счёт? Это действие нельзя отменить.',
          delete: 'Удалить',
          history: 'История',
          searchBills: 'Поиск счетов...',
          noBillsFound: 'Счета не найдены',
          settled: 'ОПЛАЧЕН',
          pending: 'ОЖИДАЕТ',
          profile: 'Профиль',
          preferences: 'НАСТРОЙКИ',
          currency: 'Валюта',
          currencySubtitle: 'Валюта по умолчанию для новых счетов',
          language: 'Язык',
          languageSubtitle: 'Язык интерфейса',
          general: 'ОБЩЕЕ',
          aboutApp: 'О приложении',
          aboutAppSubtitle: 'Версия, лицензии',
          rateApp: 'Оценить Chippin',
          rateAppSubtitle: 'Помогите нам расти в App Store',
          logOut: 'Выйти',
        );

  @override
  String itemsOfTotal(int assigned, int total) => '$assigned из $total позиций назначено';
  @override
  String itemsAndPeople(int itemCount, int peopleCount) => '$itemCount поз. · $peopleCount чел.';
}
