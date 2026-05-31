import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_state.dart';
import 'api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<Map<String, dynamic>> _allAchievements = [
    {
      'id': 'first_steps',
      'name': 'Первый взлет',
      'desc': 'Пройти любой шаг любого курса',
      'icon': '🚀',
      'reward': '+100 EXP'
    },
    {
      'id': 'theory_master',
      'name': 'Теоретик авиации',
      'desc': 'Завершить хотя бы 1 курс полностью',
      'icon': '📚',
      'reward': '+200 EXP'
    },
    {
      'id': 'certified_pilot',
      'name': 'Дипломированный ас',
      'desc': 'Завершить 3 курса полностью',
      'icon': '🎓',
      'reward': '+500 EXP'
    },
    {
      'id': 'all_courses',
      'name': 'Безопасное небо',
      'desc': 'Завершить все 5 курсов',
      'icon': '🏆',
      'reward': '+800 EXP'
    },
  ];

  int _getRequiredExpForLevel(int level) {
    if (level <= 1) return 0;
    return ((level - 1) * 100 + (level - 1) * (level - 1) * 15);
  }





  void _showOrdersDialog(AppState state, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            state.translate('profile_orders'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<dynamic>>(
              future: ApiService.fetchMyOrders(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)));
                }
                final orders = snapshot.data ?? [];
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'У вас пока нет заказов',
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
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
                    final rawStatus = order['status']?.toString() ?? 'PENDING';
                    final status = rawStatus.split('|').first;
                    final statusLabel = status == 'COMPLETED' ? 'Выполнен' : status == 'CANCELLED' ? 'Отменен' : 'Ожидает доставки';
                    final statusColor = status == 'COMPLETED' ? Colors.green : status == 'CANCELLED' ? Colors.red : Colors.orange;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showOrderDeliveryForm(order, isDark);
                      },
                      child: _buildOrderTile(
                        'Заказ #${order['id']}',
                        '\$${(order['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                        statusLabel,
                        statusColor,
                        isDark,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showOrderDeliveryForm(Map<String, dynamic> order, bool isDark) {
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Данные доставки — Заказ #${order['id']}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildDeliveryField(addressCtrl, 'Адрес доставки', Icons.location_on_outlined, isDark),
            const SizedBox(height: 12),
            _buildDeliveryField(cityCtrl, 'Город', Icons.location_city_outlined, isDark),
            const SizedBox(height: 12),
            _buildDeliveryField(contactCtrl, 'Контактный телефон', Icons.phone_outlined, isDark, inputType: TextInputType.phone),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final ok = await ApiService.updateOrderDelivery(
                  order['id'] as int,
                  addressCtrl.text.trim(),
                  cityCtrl.text.trim(),
                  contactCtrl.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Данные доставки сохранены' : 'Ошибка при сохранении'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Сохранить данные доставки', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryField(TextEditingController ctrl, String hint, IconData icon, bool isDark, {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF050814) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
        ),
      ),
    );
  }


  Widget _buildOrderTile(String title, String price, String status, Color statusColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B233D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(price, style: const TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.w600)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(AppState state, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF0088CC).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Техническая поддержка',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Наш бот поддержки доступен 24/7 в Telegram. Опишите вашу проблему и мы ответим в кратчайшие сроки.',
                style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.open_in_new, color: Colors.white, size: 18),
                label: const Text('@skycheck_support_bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () async {
                  final uri = Uri.parse(ApiService.telegramBotUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Не удалось открыть Telegram. Убедитесь, что он установлен.')),
                      );
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }


  void _showTermsBottomSheet(AppState state, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.translate('profile_terms'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Пользовательское соглашение SkyCheck Tashkent.\n\n'
                    '1. Общие положения\n'
                    'Используя данное мобильное приложение, вы соглашаетесь с условиями предоставления услуг, правилами полетов дронов и требованиями законодательства Республики Узбекистан касательно использования воздушного пространства.\n\n'
                    '2. Ограничение ответственности\n'
                    'Приложение предоставляет информационные карты зон полетов (зеленые, желтые и красные зоны). Пользователь несет персональную юридическую ответственность за соблюдение правил безопасности пилотирования БПЛА.\n\n'
                    '3. Конфиденциальность\n'
                    'Мы сохраняем данные вашего профиля и историю заказов исключительно для обеспечения функционала приложения.',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Я согласен', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppState().currentLanguage,
      builder: (context, lang, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppState().isDarkMode,
          builder: (context, isDark, child) {
            final state = AppState();
            return _buildProfileView(state, isDark, lang);
          },
        );
      },
    );
  }



  Widget _buildProfileView(AppState state, bool isDark, String lang) {
    final user = ApiService.currentUser ?? {};
    final name = user['name'] ?? 'Иван Иванов';
    final email = user['email'] ?? 'ivan@skycheck.uz';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.translate('profile_title'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0A0D1A), const Color(0xFF0F1422)]
                    : [Colors.white, const Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0066FF), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildGamificationSection(user, isDark),
          // Group 1: Settings
          _buildGroupHeader('Настройки системы'),
          _buildCardGroup(
            isDark: isDark,
            children: [
              // Theme
              ListTile(
                leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF0066FF)),
                title: Text(
                  isDark ? state.translate('theme_dark') : state.translate('theme_light'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                ),
                trailing: Switch(
                  value: isDark,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF0066FF),
                  onChanged: (val) {
                    state.toggleTheme();
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              // Language
              ListTile(
                leading: const Icon(Icons.language, color: Color(0xFF0066FF)),
                title: Text(
                  state.translate('profile_lang'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['RU', 'UZ', 'EN'].map((code) {
                    final isSelected = lang == code.toLowerCase();
                    return GestureDetector(
                      onTap: () => state.setLanguage(code.toLowerCase()),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0066FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0066FF) : Colors.grey.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.wifi, color: Color(0xFF0066FF)),
                title: Text(
                  'Настройка подключения',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _showConnectionDialog(context, isDark),
              ),
            ],
          ),

          // Group 2: Account Actions
          _buildGroupHeader('Информационные панели'),
          _buildCardGroup(
            isDark: isDark,
            children: [
              _buildListRow(
                Icons.shopping_bag_outlined,
                state.translate('profile_orders'),
                isDark,
                () => _showOrdersDialog(state, isDark),
              ),
              const Divider(height: 1, indent: 56),
              _buildListRow(
                Icons.support_agent_outlined,
                state.translate('profile_support'),
                isDark,
                () => _showSupportDialog(state, isDark),
              ),
              const Divider(height: 1, indent: 56),
              _buildListRow(
                Icons.description_outlined,
                state.translate('profile_terms'),
                isDark,
                () => _showTermsBottomSheet(state, isDark),
              ),
            ],
          ),

          // Group 3: Log out
          _buildCardGroup(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFF43F5E)),
                title: Text(
                  state.translate('profile_logout'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFF43F5E)),
                onTap: () async {
                  await ApiService.clearSession();
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGamificationSection(Map<String, dynamic> user, bool isDark) {
    final exp = user['exp'] ?? 0;
    final level = user['level'] ?? 1;
    final prevLevelExp = _getRequiredExpForLevel(level);
    final nextLevelExp = _getRequiredExpForLevel(level + 1);
    final range = nextLevelExp - prevLevelExp;
    final progress = exp - prevLevelExp;
    final percent = range > 0 ? (progress / range).clamp(0.0, 1.0) : 0.0;
    
    final userAchievements = user['achievements'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupHeader('Игровой Прогресс'),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0D1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black12 : Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Уровень $level',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '$exp / $nextLevelExp EXP',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF050814) : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
                ),
              ),
            ],
          ),
        ),
        
        _buildGroupHeader('Достижения Пилота'),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0D1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allAchievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, idx) {
              final ach = _allAchievements[idx];
              final isUnlocked = userAchievements.any((ua) => ua['achievementId'] == ach['id']);
              
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnlocked 
                      ? (isDark ? const Color(0xFF132D20) : const Color(0xFFE8F5E9))
                      : (isDark ? const Color(0xFF1B233D) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked 
                        ? Colors.green.withValues(alpha: 0.4) 
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isUnlocked ? ach['icon'] : '🔒',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ach['name'],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        ach['desc'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ach['reward'],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.green : const Color(0xFF0066FF),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCardGroup({required List<Widget> children, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0D1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildListRow(IconData icon, String title, bool isDark, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0066FF)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
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
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.wifi, color: Color(0xFF0066FF)),
                  SizedBox(width: 10),
                  Text(
                    'Подключение к ПК',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: ApiService.getBaseUrl(),
                    builder: (context, snapshot) {
                      final url = snapshot.data ?? 'Определяется...';
                      return Text(
                        'Текущий адрес: $url',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey : Colors.black54,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Введите IP-адрес вашего компьютера:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'например, 192.168.1.100:3000',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  if (statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      statusMessage,
                      style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await ApiService.resetBaseUrl();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Сброшено к автоматическому поиску')),
                      );
                      setState(() {});
                    }
                  },
                  child: const Text('Сбросить', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isTesting
                      ? null
                      : () async {
                          final input = controller.text.trim();
                          if (input.isEmpty) return;
                          setStateDialog(() {
                            isTesting = true;
                            statusMessage = 'Проверка подключения...';
                            statusColor = const Color(0xFF0066FF);
                          });
                          final success = await ApiService.testAndSetCustomBaseUrl(input);
                          setStateDialog(() {
                            isTesting = false;
                          });
                          if (success) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text('Подключено! Новый адрес сохранен.'),
                                ),
                              );
                              setState(() {});
                            }
                          } else {
                            setStateDialog(() {
                              statusMessage = '❌ Ошибка соединения! Проверьте IP и Firewall на ПК.';
                              statusColor = Colors.red;
                            });
                          }
                        },
                  child: isTesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Сохранить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


