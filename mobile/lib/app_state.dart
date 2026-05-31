import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);
  final ValueNotifier<String> currentLanguage = ValueNotifier<String>('ru');

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode.value = prefs.getBool('isDarkMode') ?? true;
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
      
      'courses_title': 'SkyCheck Курсы',
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
      
      'settings_title': 'Настройки',
      'settings_achievements': 'Достижения',
      'settings_cart': 'Корзина',
      'settings_app_config': 'Настройки приложения',
      'settings_support': 'Тех. поддержка',
      'theme_dark': 'Темная тема',
      'theme_light': 'Светлая тема',
    },
    'uz': {
      'nav_courses': 'Kurslar',
      'nav_news': 'Yangiliklar',
      'nav_map': 'Xarita',
      'nav_shop': 'Do\'kon',
      'nav_profile': 'Profil',
      
      'courses_title': 'SkyCheck Kurslari',
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
      
      'settings_title': 'Sozlamalar',
      'settings_achievements': 'Yutuqlar',
      'settings_cart': 'Savat',
      'settings_app_config': 'Ilova sozlamalari',
      'settings_support': 'Qo\'llab-quvvatlash',
      'theme_dark': 'Tungi rejim',
      'theme_light': 'Kunduzgi rejim',
    },
    'en': {
      'nav_courses': 'Courses',
      'nav_news': 'News',
      'nav_map': 'Map',
      'nav_shop': 'Shop',
      'nav_profile': 'Profile',
      
      'courses_title': 'SkyCheck Courses',
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
      
      'settings_title': 'Settings',
      'settings_achievements': 'Achievements',
      'settings_cart': 'Cart',
      'settings_app_config': 'App Settings',
      'settings_support': 'Support',
      'theme_dark': 'Dark Mode',
      'theme_light': 'Light Mode',
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
