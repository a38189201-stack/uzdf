import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
  final ValueNotifier<String> currentLanguage = ValueNotifier<String>('ru');

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
      currentLanguage.value = prefs.getString('currentLanguage') ?? 'ru';
    } catch (e) {
      debugPrint('Failed to load shared preferences: $e');
    }
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'ru': {
      'nav_courses': 'Курсы',
      'nav_news': 'Новости',
      'nav_map': 'Карта',
      'nav_shop': 'Магазин',
      'nav_profile': 'Профиль',
      
      'courses_title': 'UZDF Курсы',
      'courses_all': 'Все курсы',
      'courses_start': 'Начать обучение',
      
      'news_title': 'Новости',
      
      'shop_title': 'Магазин дронов',
      'shop_in_stock': 'В НАЛИЧИИ',
      'shop_out_of_stock': 'ЗАКОНЧИЛСЯ',
      'shop_add_to_cart': 'В КОРЗИНУ',
      'shop_reviews': 'Отзывы покупателей',
      
      'profile_login_title': 'Вход',
      'profile_login_prompt': 'Войдите в аккаунт',
      'profile_login_desc': 'Для оформления заказов и сохранения прогресса требуется авторизация.',
      'profile_login_btn': 'Войти',
      'profile_title': 'Профиль',
      'profile_settings': 'Настройки профиля',
      'profile_orders': 'Мои заказы',
      'profile_lang': 'Смена языка',
      'profile_support': 'Поддержка',
      'profile_terms': 'Соглашение',
      'profile_logout': 'Выйти',
      'profile_save': 'Сохранить',
      'profile_save_success': 'Профиль успешно обновлен',
      'profile_save_error': 'Ошибка сохранения',
      'form_name': 'Имя',
      'form_phone': 'Телефон',
      'profile_faq': 'Инструкция и FAQ',
      
      'settings_title': 'Настройки',
      'settings_achievements': 'Достижения',
      'settings_cart': 'Корзина',
      'settings_app_config': 'Настройки приложения',
      'settings_support': 'Тех. поддержка',
      'theme_dark': 'Темная тема',
      'theme_light': 'Светлая тема',

      // Settings Screen
      'settings_header_account': 'Аккаунт',
      'settings_header_support': 'Поддержка и инфо',
      'settings_header_cache': 'Оформление и кэш',
      'settings_header_actions': 'Действия',
      'settings_edit_profile': 'Редактировать профиль',
      'settings_security': 'Безопасность',
      'settings_notifications': 'Уведомления',
      'settings_privacy': 'Конфиденциальность',
      'settings_language': 'Язык приложения',
      'settings_subscription': 'Моя подписка',
      'settings_help_support': 'Помощь и поддержка',
      'settings_terms': 'Условия и политика',
      'settings_orders': 'Мои заказы',
      'settings_faq': 'Инструкция и FAQ',
      'settings_free_space': 'Очистить кэш',
      'settings_data_saver': 'Экономия трафика',
      'settings_report_prob': 'Сообщить о проблеме',
      'settings_add_account': 'Добавить аккаунт',
      'settings_conn_debug': 'Отладка подключения',
      'settings_logout': 'Выйти из аккаунта',

      // Edit Profile Screen
      'edit_profile_title': 'Редактирование профиля',
      'edit_profile_name': 'Имя',
      'edit_profile_name_hint': 'Введите ваше имя',
      'edit_profile_email': 'Email',
      'edit_profile_email_hint': 'Введите email',
      'edit_profile_password': 'Пароль',
      'edit_profile_dob': 'Дата рождения',
      'edit_profile_country': 'Страна / Регион',
      'edit_profile_save': 'Сохранить изменения',
    },
    'uz': {
      'nav_courses': 'Kurslar',
      'nav_news': 'Yangiliklar',
      'nav_map': 'Xarita',
      'nav_shop': 'Do\'kon',
      'nav_profile': 'Profil',
      
      'courses_title': 'UZDF Kurslari',
      'courses_all': 'Barcha kurslar',
      'courses_start': 'O\'rganishni boshlash',
      
      'news_title': 'Yangiliklar',
      
      'shop_title': 'Dronlar do\'koni',
      'shop_in_stock': 'MAVJUD',
      'shop_out_of_stock': 'TUGAGAN',
      'shop_add_to_cart': 'SAVATGA QO\'SHISH',
      'shop_reviews': 'Xaridorlar sharhlari',
      
      'profile_login_title': 'Kirish',
      'profile_login_prompt': 'Hisobga kiring',
      'profile_login_desc': 'Buyurtma berish va natijalarni saqlash uchun tizimga kirish talab etiladi.',
      'profile_login_btn': 'Kirish',
      'profile_title': 'Profil',
      'profile_settings': 'Profil sozlamalari',
      'profile_orders': 'Mening buyurtmalarim',
      'profile_lang': 'Tilni almashtirish',
      'profile_support': 'Qo\'llab-quvvatlash',
      'profile_terms': 'Shartnoma',
      'profile_logout': 'Chiqish',
      'profile_save': 'Saqlash',
      'profile_save_success': 'Profil muvaffaqiyatli yangilandi',
      'profile_save_error': 'Saqlashda xatolik',
      'form_name': 'Ism',
      'form_phone': 'Telefon raqami',
      'profile_faq': 'Qo\'llanma va FAQ',
      
      'settings_title': 'Sozlamalar',
      'settings_achievements': 'Yutuqlar',
      'settings_cart': 'Savat',
      'settings_app_config': 'Ilova sozlamalari',
      'settings_support': 'Qo\'llab-quvvatlash',
      'theme_dark': 'Tungi rejim',
      'theme_light': 'Kunduzgi rejim',

      // Settings Screen
      'settings_header_account': 'Hisob',
      'settings_header_support': 'Yordam va ma\'lumot',
      'settings_header_cache': 'Dizayn va kesh',
      'settings_header_actions': 'Harakatlar',
      'settings_edit_profile': 'Profilni tahrirlash',
      'settings_security': 'Xavfsizlik',
      'settings_notifications': 'Bildirishnomalar',
      'settings_privacy': 'Maxfiylik',
      'settings_language': 'Ilova tili',
      'settings_subscription': 'Mening obunam',
      'settings_help_support': 'Yordam va qo\'llab-quvvatlash',
      'settings_terms': 'Foydalanish shartlari',
      'settings_orders': 'Mening buyurtmalarim',
      'settings_faq': 'Qo\'llanma va FAQ',
      'settings_free_space': 'Keshni tozalash',
      'settings_data_saver': 'Trafikni tejash',
      'settings_report_prob': 'Muammo haqida xabar berish',
      'settings_add_account': 'Hisob qo\'shish',
      'settings_conn_debug': 'Ulanish sozlamalari',
      'settings_logout': 'Hisobdan chiqish',

      // Edit Profile Screen
      'edit_profile_title': 'Profilni tahrirlash',
      'edit_profile_name': 'Ism',
      'edit_profile_name_hint': 'Ismingizni kiriting',
      'edit_profile_email': 'Email',
      'edit_profile_email_hint': 'Emailingizni kiriting',
      'edit_profile_password': 'Parol',
      'edit_profile_dob': 'Tug\'ilgan sana',
      'edit_profile_country': 'Mamlakat / Hudud',
      'edit_profile_save': 'O\'zgarishlarni saqlash',
    },
    'en': {
      'nav_courses': 'Courses',
      'nav_news': 'News',
      'nav_map': 'Map',
      'nav_shop': 'Shop',
      'nav_profile': 'Profile',
      
      'courses_title': 'UZDF Courses',
      'courses_all': 'All Courses',
      'courses_start': 'Start Learning',
      
      'news_title': 'News',
      
      'shop_title': 'Drone Shop',
      'shop_in_stock': 'IN STOCK',
      'shop_out_of_stock': 'OUT OF STOCK',
      'shop_add_to_cart': 'ADD TO CART',
      'shop_reviews': 'Customer Reviews',
      
      'profile_login_title': 'Sign In',
      'profile_login_prompt': 'Sign In to Account',
      'profile_login_desc': 'Authentication is required to place orders and save progress.',
      'profile_login_btn': 'Sign In',
      'profile_title': 'Profile',
      'profile_settings': 'Profile Settings',
      'profile_orders': 'My Orders',
      'profile_lang': 'Change Language',
      'profile_support': 'Support',
      'profile_terms': 'Agreement',
      'profile_logout': 'Logout',
      'profile_save': 'Save',
      'profile_save_success': 'Profile updated successfully',
      'profile_save_error': 'Error saving profile',
      'form_name': 'Name',
      'form_phone': 'Phone Number',
      'profile_faq': 'Guidelines & FAQ',
      
      'settings_title': 'Settings',
      'settings_achievements': 'Achievements',
      'settings_cart': 'Cart',
      'settings_app_config': 'App Settings',
      'settings_support': 'Support',
      'theme_dark': 'Dark Mode',
      'theme_light': 'Light Mode',

      // Settings Screen
      'settings_header_account': 'Account',
      'settings_header_support': 'Support & Info',
      'settings_header_cache': 'Theme & Cache',
      'settings_header_actions': 'Actions',
      'settings_edit_profile': 'Edit profile',
      'settings_security': 'Security',
      'settings_notifications': 'Notifications',
      'settings_privacy': 'Privacy',
      'settings_language': 'App Language',
      'settings_subscription': 'My Subscription',
      'settings_help_support': 'Help & Support',
      'settings_terms': 'Terms and Policies',
      'settings_orders': 'My Orders',
      'settings_faq': 'FAQ & Guidelines',
      'settings_free_space': 'Free up space',
      'settings_data_saver': 'Data Saver',
      'settings_report_prob': 'Report a problem',
      'settings_add_account': 'Add account',
      'settings_conn_debug': 'Connection Debug',
      'settings_logout': 'Log out',

      // Edit Profile Screen
      'edit_profile_title': 'Edit Profile',
      'edit_profile_name': 'Name',
      'edit_profile_name_hint': 'Your full name',
      'edit_profile_email': 'Email',
      'edit_profile_email_hint': 'Your email address',
      'edit_profile_password': 'Password',
      'edit_profile_dob': 'Date of Birth',
      'edit_profile_country': 'Country/Region',
      'edit_profile_save': 'Save changes',
    }
  };

  String translate(String key) {
    final lang = currentLanguage.value;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  void toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode.value);
    } catch (e) {
      debugPrint('Failed to save theme: $e');
    }
  }

  void setLanguage(String lang) async {
    if (_localizedValues.containsKey(lang)) {
      currentLanguage.value = lang;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentLanguage', lang);
      } catch (e) {
        debugPrint('Failed to save language: $e');
      }
    }
  }
}
