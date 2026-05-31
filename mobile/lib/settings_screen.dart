import 'package:flutter/material.dart';
import 'app_state.dart';
import 'api_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppState().currentLanguage,
      builder: (context, lang, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppState().isDarkMode,
          builder: (context, isDark, child) {
            final state = AppState();

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  state.translate('settings_title'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        'U',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Иван Иванов",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "+998 90 123 45 67",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Theme toggler
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: const Color(0xFF2563EB),
                      ),
                      title: Text(
                        isDark ? state.translate('theme_dark') : state.translate('theme_light'),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Switch(
                        value: isDark,
                        activeTrackColor: const Color(0xFF2563EB),
                        onChanged: (val) {
                          state.toggleTheme();
                        },
                      ),
                    ),
                  ),

                  // Language selector
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.language,
                        color: Color(0xFF2563EB),
                      ),
                      title: Text(
                        state.translate('profile_lang'),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: DropdownButton<String>(
                        value: lang,
                        underline: const SizedBox(),
                        dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ru', child: Text('RU')),
                          DropdownMenuItem(value: 'uz', child: Text('UZ')),
                          DropdownMenuItem(value: 'en', child: Text('EN')),
                        ],
                        onChanged: (newLang) {
                          if (newLang != null) {
                            state.setLanguage(newLang);
                          }
                        },
                      ),
                    ),
                  ),

                  _settingItem(Icons.emoji_events, state.translate('settings_achievements'), isDark),
                  _settingItem(Icons.shopping_cart, state.translate('settings_cart'), isDark),
                  _settingItem(
                    Icons.settings,
                    state.translate('settings_app_config'),
                    isDark,
                    onTap: () => _showConnectionDialog(context, isDark),
                  ),
                  _settingItem(Icons.help_outline, state.translate('settings_support'), isDark),
                  const Divider(color: Color(0xFF222222)),
                  
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        state.translate('profile_logout'),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () async {
                        await ApiService.clearSession();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.wifi, color: Color(0xFF2563EB)),
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
                    }
                  },
                  child: const Text('Сбросить', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isTesting
                      ? null
                      : () async {
                          final input = controller.text.trim();
                          if (input.isEmpty) return;
                          setState(() {
                            isTesting = true;
                            statusMessage = 'Проверка подключения...';
                            statusColor = const Color(0xFF2563EB);
                          });
                          final success = await ApiService.testAndSetCustomBaseUrl(input);
                          setState(() {
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
                            }
                          } else {
                            setState(() {
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

  Widget _settingItem(IconData icon, String title, bool isDark, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap ?? () {},
      ),
    );
  }
}