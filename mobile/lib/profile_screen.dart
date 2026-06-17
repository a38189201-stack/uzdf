import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'api_service.dart';
import 'faq_screen.dart';
import 'glass_widgets.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _dataSaverEnabled = false;
  bool _biometricLock = true;
  bool _pushNotifications = true;
  bool _emailReports = false;
  bool _publicProfile = true;
  bool _shareFlightAnalytics = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dataSaverEnabled = prefs.getBool('settings_data_saver') ?? false;
      _biometricLock = prefs.getBool('settings_biometric_lock') ?? true;
      _pushNotifications = prefs.getBool('settings_push_notifications') ?? true;
      _emailReports = prefs.getBool('settings_email_reports') ?? false;
      _publicProfile = prefs.getBool('settings_public_profile') ?? true;
      _shareFlightAnalytics = prefs.getBool('settings_share_flight_analytics') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, bool isDark) {
    final state = AppState();
    final languages = [
      {'code': 'ru', 'name': 'Русский (RU)'},
      {'code': 'uz', 'name': 'O\'zbekcha (UZ)'},
      {'code': 'en', 'name': 'English (EN)'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, idx) {
                final lang = languages[idx];
                final isSelected = state.currentLanguage.value == lang['code'];
                return ListTile(
                  title: Text(
                    lang['name']!,
                    style: GoogleFonts.inter(
                      color: txtColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB))
                      : null,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    state.setLanguage(lang['code']!);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    ApiService.updateProfile({'language': lang['code']!});
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSecuritySettings(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Security Settings',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Icon(Icons.lock_reset_rounded, color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB)),
                      title: Text('Change Password', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('Update account login password', style: TextStyle(color: subColor, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showChangePasswordDialog(isDark);
                      },
                    ),
                    SwitchListTile(
                      value: _biometricLock,
                      activeThumbColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      title: Text('Biometric Lock', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('Unlock app using Face ID or Fingerprint', style: TextStyle(color: subColor, fontSize: 12)),
                      onChanged: (val) {
                        setSheetState(() {
                          _biometricLock = val;
                        });
                        setState(() {});
                        _saveSetting('settings_biometric_lock', val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsSettings(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _pushNotifications,
                      activeThumbColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      title: Text('Push Notifications', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('Receive alerts on flight permits and updates', style: TextStyle(color: subColor, fontSize: 12)),
                      onChanged: (val) {
                        setSheetState(() {
                          _pushNotifications = val;
                        });
                        setState(() {});
                        _saveSetting('settings_push_notifications', val);
                      },
                    ),
                    SwitchListTile(
                      value: _emailReports,
                      activeThumbColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      title: Text('Email Reports', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('Receive weekly training and system digest', style: TextStyle(color: subColor, fontSize: 12)),
                      onChanged: (val) {
                        setSheetState(() {
                          _emailReports = val;
                        });
                        setState(() {});
                        _saveSetting('settings_email_reports', val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacySettings(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Privacy',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _publicProfile,
                      activeThumbColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      title: Text('Public Profile', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('Allow other pilots to search your profile', style: TextStyle(color: subColor, fontSize: 12)),
                      onChanged: (val) {
                        setSheetState(() {
                          _publicProfile = val;
                        });
                        setState(() {});
                        _saveSetting('settings_public_profile', val);
                      },
                    ),
                    SwitchListTile(
                      value: _shareFlightAnalytics,
                      activeThumbColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      title: Text('Share Flight Analytics', style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('Help improve safety mapping services', style: TextStyle(color: subColor, fontSize: 12)),
                      onChanged: (val) {
                        setSheetState(() {
                          _shareFlightAnalytics = val;
                        });
                        setState(() {});
                        _saveSetting('settings_share_flight_analytics', val);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubscriptionSettings(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'My Subscription',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Plan', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('UZDF Pilot Pro', style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.accentLight.withValues(alpha: 0.2) : const Color(0xFF2F54EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your membership renews automatically on 12/12/2026',
                  style: TextStyle(color: subColor, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Manage Billing', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleFreeUpSpace() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = AppState().isDarkMode.value;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const CircularProgressIndicator(color: Color(0xFF2F54EB)),
                const SizedBox(width: 20),
                Text(
                  'Очистка кэша...',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    double clearedSizeMB = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        int bytes = 0;
        await for (var file in tempDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            bytes += await file.length();
          }
        }
        clearedSizeMB = bytes / (1024 * 1024);
        await tempDir.delete(recursive: true);
        tempDir.createSync();
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      Navigator.pop(context); // Close dialog
      if (clearedSizeMB == 0) {
        _showSnackbar('Кэш уже пуст!');
      } else {
        _showSnackbar('Кэш успешно очищен. Освобождено ${clearedSizeMB.toStringAsFixed(1)} МБ!');
      }
    }
  }

  void _showReportProblemDialog(bool isDark) {
    final controller = TextEditingController();
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report a problem',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Опишите проблему...',
                    hintStyle: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx);
                        final ok = await ApiService.sendSupportRequest(text);
                        if (ok) {
                          _showSnackbar('Запрос отправлен. Спасибо!');
                        } else {
                          _showSnackbar('Ошибка при отправке запроса', isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Отправить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrdersDialog(AppState state, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: LiquidGlassCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag_rounded,
                        color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    state.translate('profile_orders'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: FutureBuilder<List<dynamic>>(
                    future: ApiService.fetchMyOrders(),
                    builder: (ctx, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent, strokeWidth: 2));
                      }
                      final orders = snapshot.data ?? [];
                      if (orders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: AppColors.subtextDark),
                              const SizedBox(height: 12),
                              Text(
                                'У вас пока нет заказов',
                                style: GoogleFonts.inter(
                                    color: AppColors.subtextDark),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: orders.length,
                        itemBuilder: (ctx2, idx) {
                          final order = orders[idx];
                          final rawStatus =
                              order['status']?.toString() ?? 'PENDING';
                          final status = rawStatus.split('|').first;
                          final statusLabel = status == 'COMPLETED'
                              ? 'Выполнен'
                              : status == 'CANCELLED'
                                  ? 'Отменён'
                                  : 'Ожидает';
                          final statusColor = status == 'COMPLETED'
                              ? AppColors.success
                              : status == 'CANCELLED'
                                  ? AppColors.danger
                                  : AppColors.warning;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              _showOrderDeliveryForm(order, isDark);
                            },
                            child: _buildOrderTile(
                              'Заказ #${order['id']}',
                              '\$${(order['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                              statusLabel,
                              statusColor,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Закрыть',
                        style: GoogleFonts.inter(color: AppColors.accent)),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDeliveryForm(Map<String, dynamic> order, bool isDark) {
    final addressCtrl = TextEditingController(text: order['deliveryAddress']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: order['deliveryCity']?.toString() ?? '');
    final contactCtrl = TextEditingController(text: order['deliveryContact']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _buildBottomSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Данные доставки — Заказ #${order['id']}',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addressCtrl,
                style: TextStyle(
                    color: isDark ? AppColors.textDark : AppColors.textLight),
                decoration: getGlassInputDecoration(
                  hintText: 'Адрес доставки',
                  prefixIcon: const Icon(Icons.location_on_outlined,
                      color: AppColors.subtextDark, size: 20),
                  context: context,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                style: TextStyle(
                    color: isDark ? AppColors.textDark : AppColors.textLight),
                decoration: getGlassInputDecoration(
                  hintText: 'Город',
                  prefixIcon: const Icon(Icons.location_city_outlined,
                      color: AppColors.subtextDark, size: 20),
                  context: context,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                    color: isDark ? AppColors.textDark : AppColors.textLight),
                decoration: getGlassInputDecoration(
                  hintText: 'Контактный телефон',
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: AppColors.subtextDark, size: 20),
                  context: context,
                ),
              ),
              const SizedBox(height: 24),
              TeslaButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  final ok = await ApiService.updateOrderDelivery(
                    order['id'] as int,
                    addressCtrl.text.trim(),
                    cityCtrl.text.trim(),
                    contactCtrl.text.trim(),
                  );
                  if (ctx.mounted) {
                    navigator.pop();
                    messenger.showSnackBar(SnackBar(
                      content: Text(ok ? 'Данные доставки сохранены' : 'Ошибка при сохранении'),
                      backgroundColor: ok ? AppColors.success : AppColors.danger,
                    ));
                  }
                },
                child: const Text('Сохранить данные доставки'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTile(
      String title, String price, String status, Color statusColor) {
    final isDark = AppState().isDarkMode.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  )),
              const SizedBox(height: 2),
              Text(price,
                  style: GoogleFonts.inter(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog(AppState state, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildBottomSheetContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.telegram,
                  color: Color(0xFF0088CC), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Техническая поддержка',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Наш бот поддержки доступен 24/7 в Telegram. Опишите проблему и мы ответим в кратчайшие сроки.',
              style: GoogleFonts.inter(
                color: AppColors.subtextDark,
                height: 1.5,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TeslaButton(
              backgroundColor: const Color(0xFF0088CC),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final uri = Uri.parse(ApiService.telegramBotUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Telegram launcher error: $e');
                  if (ctx.mounted) {
                    messenger.showSnackBar(SnackBar(
                      content: const Text('Не удалось открыть Telegram.'),
                      backgroundColor: AppColors.danger,
                    ));
                  }
                }
                if (ctx.mounted) navigator.pop();
              },
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('@uzdf_support_bot',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
              ]),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Закрыть',
                  style:
                      GoogleFonts.inter(color: AppColors.subtextDark)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTermsBottomSheet(AppState state, bool isDark) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildBottomSheetContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(),
            const SizedBox(height: 16),
            Text(
              state.translate('profile_terms'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  'Пользовательское соглашение UZDF Uzbekistan.\n\n'
                  '1. Общие положения\nИспользуя данное приложение, вы соглашаетесь с условиями предоставления услуг и требованиями законодательства РУз.\n\n'
                  '2. Ограничение ответственности\nПриложение предоставляет карты зон полётов. Пользователь несёт персональную юридическую ответственность за соблюдение правил безопасности БПЛА.\n\n'
                  '3. Конфиденциальность\nМы сохраняем данные профиля и историю заказов исключительно для обеспечения функционала приложения.',
                  style: GoogleFonts.inter(
                    color: AppColors.subtextDark,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TeslaButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: const Text('Я согласен'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetContainer({required Widget child}) {
    final isDark = AppState().isDarkMode.value;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: child,
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.subtextDark.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  void _showConnectionDialog(BuildContext context, bool isDark) {
    final controller = TextEditingController();
    bool isTesting = false;
    String statusMessage = '';
    Color statusColor = Colors.grey;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: LiquidGlassCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.wifi_rounded,
                            color: AppColors.accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Подключение к ПК',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark ? AppColors.textDark : AppColors.textLight,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    FutureBuilder<String>(
                      future: ApiService.getBaseUrl(),
                      builder: (context, snapshot) {
                        final url = snapshot.data ?? 'Определяется...';
                        return Text(
                          'Текущий: $url',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.subtextDark,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      style: TextStyle(
                          color: isDark
                              ? AppColors.textDark
                              : AppColors.textLight),
                      decoration: getGlassInputDecoration(
                        hintText: 'например, 192.168.1.100:3000',
                        context: context,
                      ),
                    ),
                    if (statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        statusMessage,
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await ApiService.resetBaseUrl();
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showSnackbar('Сброшено к автоматическому поиску');
                              setState(() {});
                            }
                          },
                          child: Text('Сбросить',
                              style: GoogleFonts.inter(
                                  color: AppColors.subtextDark)),
                        ),
                        const SizedBox(width: 8),
                        TeslaButton(
                          onPressed: isTesting
                              ? null
                              : () async {
                                  final input = controller.text.trim();
                                  if (input.isEmpty) return;
                                  setStateDialog(() {
                                    isTesting = true;
                                    statusMessage = 'Проверка подключения...';
                                    statusColor = AppColors.accent;
                                  });
                                  final success =
                                      await ApiService.testAndSetCustomBaseUrl(
                                          input);
                                  setStateDialog(() => isTesting = false);
                                  if (success) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _showSnackbar('Подключено! Адрес сохранён.');
                                      setState(() {});
                                    }
                                  } else {
                                    setStateDialog(() {
                                      statusMessage =
                                          'Ошибка подключения. Проверьте адрес.';
                                      statusColor = AppColors.danger;
                                    });
                                  }
                                },
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppState().currentLanguage,
      builder: (context, lang, child) {
        final state = AppState();
        return ValueListenableBuilder<bool>(
          valueListenable: state.isDarkMode,
          builder: (context, isDark, child) {
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: GlassAppBar(
                title: Text(
                  state.translate('settings_title'),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              body: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 66 + 16 + 24,
                ),
                children: [
                  // --- QUICK PROFILE PANEL ---
                  _buildQuickProfilePanel(isDark),
                  const SizedBox(height: 28),

                  // --- ACCOUNT CATEGORY ---
                  _buildCategoryHeader(state.translate('settings_header_account'), isDark),
                  _buildSettingsGroup(
                    isDark: isDark,
                    items: [
                      _buildSettingsTile(
                        icon: Icons.person_outline_rounded,
                        title: state.translate('settings_edit_profile'),
                        isDark: isDark,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                          );
                          if (updated == true) {
                            setState(() {});
                          }
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.shield_outlined,
                        title: state.translate('settings_security'),
                        isDark: isDark,
                        onTap: () => _showSecuritySettings(isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: state.translate('settings_notifications'),
                        isDark: isDark,
                        onTap: () => _showNotificationsSettings(isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: state.translate('settings_privacy'),
                        isDark: isDark,
                        onTap: () => _showPrivacySettings(isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.language_rounded,
                        title: state.translate('settings_language'),
                        isDark: isDark,
                        onTap: () => _showLanguagePicker(context, isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- SUPPORT & ABOUT CATEGORY ---
                  _buildCategoryHeader(state.translate('settings_header_support'), isDark),
                  _buildSettingsGroup(
                    isDark: isDark,
                    items: [
                      _buildSettingsTile(
                        icon: Icons.credit_card_rounded,
                        title: state.translate('settings_subscription'),
                        isDark: isDark,
                        onTap: () => _showSubscriptionSettings(isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: state.translate('settings_help_support'),
                        isDark: isDark,
                        onTap: () => _showSupportDialog(state, isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: state.translate('settings_terms'),
                        isDark: isDark,
                        onTap: () => _showTermsBottomSheet(state, isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.emoji_events_outlined,
                        title: 'Мои достижения',
                        isDark: isDark,
                        onTap: () => _showAchievementsBottomSheet(context, isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.school_outlined,
                        title: 'Цифровые сертификаты',
                        isDark: isDark,
                        onTap: () => _showCertificatesBottomSheet(context, isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.shopping_bag_outlined,
                        title: state.translate('settings_orders'),
                        isDark: isDark,
                        onTap: () => _showOrdersDialog(state, isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: state.translate('settings_faq'),
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          GlassRoute(page: const FaqScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- CACHE & CELLULAR CATEGORY ---
                  _buildCategoryHeader(state.translate('settings_header_cache'), isDark),
                  _buildSettingsGroup(
                    isDark: isDark,
                    items: [
                      _buildSettingsTile(
                        icon: Icons.delete_outline_rounded,
                        title: state.translate('settings_free_space'),
                        isDark: isDark,
                        onTap: _handleFreeUpSpace,
                      ),
                      _buildSettingsTile(
                        icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        title: state.translate(isDark ? 'theme_dark' : 'theme_light'),
                        isDark: isDark,
                        trailing: Switch(
                          value: isDark,
                          activeThumbColor: isDark ? AppColors.accentLight : AppColors.accent,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            state.toggleTheme();
                          },
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          state.toggleTheme();
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.pie_chart_outline_rounded,
                        title: state.translate('settings_data_saver'),
                        isDark: isDark,
                        trailing: Switch(
                          value: _dataSaverEnabled,
                          activeThumbColor: isDark ? AppColors.accentLight : AppColors.accent,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _dataSaverEnabled = val;
                            });
                            _showSnackbar(_dataSaverEnabled
                                ? 'Режим экономии трафика включен'
                                : 'Режим экономии трафика выключен');
                          },
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- ACTIONS CATEGORY ---
                  _buildCategoryHeader(state.translate('settings_header_actions'), isDark),
                  _buildSettingsGroup(
                    isDark: isDark,
                    items: [
                      _buildSettingsTile(
                        icon: Icons.outlined_flag_rounded,
                        title: state.translate('settings_report_prob'),
                        isDark: isDark,
                        onTap: () => _showReportProblemDialog(isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.person_add_alt_1_outlined,
                        title: state.translate('settings_add_account'),
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showSnackbar('Функция мультиаккаунта находится в разработке');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.wifi_find_rounded,
                        title: state.translate('settings_conn_debug'),
                        isDark: isDark,
                        onTap: () => _showConnectionDialog(context, isDark),
                      ),
                      _buildSettingsTile(
                        icon: Icons.logout_rounded,
                        title: state.translate('settings_logout'),
                        isDark: isDark,
                        iconColor: AppColors.danger,
                        textColor: AppColors.danger,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await ApiService.clearSession();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickProfilePanel(bool isDark) {
    final user = ApiService.currentUser ?? {};
    final name = user['name'] ?? 'Иван Иванов';
    final email = user['email'] ?? 'ivan@uzdf.uz';
    final phone = user['phone'] ?? '';

    return PressScaleWidget(
      onTap: () async {
        HapticFeedback.lightImpact();
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );
        if (updated == true) {
          setState(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            // Circular Avatar (dynamic letter, no default photo!)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.accentLight, AppColors.accent]
                      : [AppColors.accent, AppColors.accentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.accentLight : AppColors.accent).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Name and Phone/Email Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    phone.isNotEmpty ? phone : email,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Mini frame for lives (heart + count)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.hearts,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${user['courseLives'] ?? 3}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Exclamation mark button to go to FAQ attempts
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            GlassRoute(
                              page: const FaqScreen(initialSearchQuery: 'попытки'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.priority_high_rounded,
                            color: isDark ? AppColors.accentLight : AppColors.accent,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // EXP & Level progress bar
                  Builder(
                    builder: (context) {
                      final level = user['level'] ?? 1;
                      final exp = user['exp'] ?? 0;
                      final nextExp = level * 100 + level * level * 15;
                      final percent = (exp / nextExp).clamp(0.0, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Уровень $level • $exp / $nextExp XP',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.accentLight : AppColors.accentDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              color: isDark ? AppColors.accentLight : AppColors.accent,
                              minHeight: 5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Right Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.accentLight : AppColors.accentDeep,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> items, required bool isDark}) {
    return LiquidGlassCard(
      borderRadius: 22.0,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF181C2E),
                const Color(0xFF0F1320),
              ]
            : [
                Colors.white,
                const Color(0xFFF0F6FF),
              ],
      ),
      border: Border.all(
        color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.1),
        width: 1.0,
      ),
      child: Column(
        children: List.generate(items.length, (idx) {
          final showDivider = idx < items.length - 1;
          return Column(
            children: [
              items[idx],
              if (showDivider)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 52,
                  color: isDark ? const Color(0xFF1F2336) : const Color(0xFFE8ECF0),
                ),
            ],
          );
        }),
      ),
    );
  }

  void _showChangePasswordDialog(bool isDark) {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Смена пароля',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: oldPasswordCtrl,
                  obscureText: true,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Старый пароль',
                    hintStyle: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: true,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Новый пароль',
                    hintStyle: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final oldPass = oldPasswordCtrl.text;
                        final newPass = newPasswordCtrl.text;
                        if (oldPass.isEmpty || newPass.isEmpty) return;
                        if (newPass.length < 6) {
                          _showSnackbar('Пароль должен быть не менее 6 символов', isError: true);
                          return;
                        }
                        Navigator.pop(ctx);
                        final result = await ApiService.changePassword(oldPass, newPass);
                        if (result.containsKey('success')) {
                          _showSnackbar('Пароль успешно изменен');
                        } else {
                          _showSnackbar(result['error'] ?? 'Ошибка при смене пароля', isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAchievementsBottomSheet(BuildContext context, bool isDark) {
    final user = ApiService.currentUser ?? {};
    final unlockedSet = (user['achievements'] as List<dynamic>?)
            ?.map((a) => a['achievementId']?.toString())
            .toSet() ??
        {};

    final achievements = [
      {
        'key': 'first_steps',
        'icon': '🚀',
        'name': 'Первый взлет',
        'desc': 'Сделайте свой первый шаг в курсах пилотирования.'
      },
      {
        'key': 'theory_master',
        'icon': '🎓',
        'name': 'Теоретик авиации',
        'desc': 'Успешно пройдите хотя бы 1 учебный курс.'
      },
      {
        'key': 'certified_pilot',
        'icon': '🏆',
        'name': 'Дипломированный ас',
        'desc': 'Пройдите 3 курса обучения.'
      },
      {
        'key': 'all_courses',
        'icon': '👑',
        'name': 'Безопасное небо',
        'desc': 'Полностью пройдите все 5 учебных курсов.'
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'Мои достижения',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: achievements.length,
                    itemBuilder: (context, idx) {
                      final ach = achievements[idx];
                      final isUnlocked = unlockedSet.contains(ach['key']);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                                : (isDark ? Colors.black26 : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUnlocked
                                  ? (isDark ? AppColors.accentLight.withValues(alpha: 0.3) : const Color(0xFF2F54EB).withValues(alpha: 0.2))
                                  : Colors.transparent,
                            ),
                          ),
                          child: Opacity(
                            opacity: isUnlocked ? 1.0 : 0.4,
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isUnlocked
                                        ? (isDark ? AppColors.accentLight.withValues(alpha: 0.15) : const Color(0xFF2F54EB).withValues(alpha: 0.1))
                                        : Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(ach['icon']!, style: const TextStyle(fontSize: 24)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ach['name']!,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ach['desc']!,
                                        style: GoogleFonts.inter(
                                          color: textColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUnlocked)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
                                else
                                  const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCertificatesBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'Цифровые сертификаты БПЛА',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: FutureBuilder<List<dynamic>>(
                    future: ApiService.fetchCompletions(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Color(0xFF2F54EB)),
                        ));
                      }
                      final completions = snapshot.data ?? [];
                      if (completions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'У вас пока нет сертификатов. Пройдите курсы и сдайте экзамены!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: completions.length,
                        itemBuilder: (context, idx) {
                          final c = completions[idx];
                          final completedAt = c['completedAt'] != null
                              ? DateTime.tryParse(c['completedAt']?.toString() ?? '')
                              : null;
                          final dateStr = completedAt != null
                              ? '${completedAt.day}.${completedAt.month}.${completedAt.year}'
                              : '';
                          final score = (c['finalScore'] as num?)?.toStringAsFixed(1) ?? '100';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'UZDF ACADEMY',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Text(
                                        'Балл: $score%',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    c['studentName']?.toString() ?? 'Пилот',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Курс завершен успешно',
                                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              try {
                                                final baseUrl = await ApiService.getBaseUrl();
                                                final verifyUrl = '$baseUrl/verify/${c['certificateUuid']}';
                                                await Clipboard.setData(ClipboardData(text: verifyUrl));
                                                _showSnackbar('Ссылка скопирована в буфер обмена!');
                                              } catch (e) {
                                                _showSnackbar('Ошибка копирования ссылки');
                                              }
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 14),
                                            label: const Text('Копировать ссылку', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              _showSnackbar('Сертификат успешно сохранен в Галерею!');
                                            },
                                            icon: const Icon(Icons.download_rounded, size: 14),
                                            label: const Text('Скачать', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Закрыть', style: GoogleFonts.inter(color: Colors.grey)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
  }) {
    final titleColor = textColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final defaultIconColor = iconColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: defaultIconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark ? Colors.white24 : Colors.black12,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
