import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'api_service.dart';
import 'glass_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  String _selectedDob = '23/05/1995';
  String _selectedCountry = 'Uzbekistan';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ApiService.currentUser ?? {};
    _nameController = TextEditingController(text: user['name'] ?? '');
    _emailController = TextEditingController(text: user['email'] ?? '');

    _loadLocalProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalProfileData() async {
    try {
      final user = ApiService.currentUser ?? {};
      final userId = user['id']?.toString() ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedDob = user['dob']?.toString() ?? prefs.getString('user_dob_$userId') ?? '23/05/1995';
        _selectedCountry = user['country']?.toString() ?? prefs.getString('user_country_$userId') ?? 'Uzbekistan';
      });
    } catch (e) {
      debugPrint('Error loading local profile data: $e');
    }
  }

  Future<void> _saveLocalProfileData() async {
    try {
      final user = ApiService.currentUser ?? {};
      final userId = user['id']?.toString() ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_dob_$userId', _selectedDob);
      await prefs.setString('user_country_$userId', _selectedCountry);
    } catch (e) {
      debugPrint('Error saving local profile data: $e');
    }
  }

  void _showDatePicker(BuildContext context) async {
    final currentParts = _selectedDob.split('/');
    DateTime initialDate = DateTime(1995, 5, 23);
    if (currentParts.length == 3) {
      final day = int.tryParse(currentParts[0]) ?? 23;
      final month = int.tryParse(currentParts[1]) ?? 5;
      final year = int.tryParse(currentParts[2]) ?? 1995;
      initialDate = DateTime(year, month, day);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = AppState().isDarkMode.value;
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final dayStr = picked.day.toString().padLeft(2, '0');
      final monthStr = picked.month.toString().padLeft(2, '0');
      setState(() {
        _selectedDob = '$dayStr/$monthStr/${picked.year}';
      });
    }
  }

  void _showCountryPicker(BuildContext context, bool isDark) {
    final countries = ['Uzbekistan', 'Russia', 'Kazakhstan', 'Nigeria', 'Turkey', 'United States'];
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
              itemCount: countries.length,
              itemBuilder: (context, idx) {
                final country = countries[idx];
                return ListTile(
                  title: Text(
                    country,
                    style: GoogleFonts.inter(
                      color: txtColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  trailing: _selectedCountry == country
                      ? Icon(Icons.check_rounded, color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCountry = country;
                    });
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      _showSnackbar('Имя и Email обязательны', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final updated = await ApiService.updateProfile({
      'name': name,
      'email': email,
      'dob': _selectedDob,
      'country': _selectedCountry,
    });

    if (updated) {
      await _saveLocalProfileData();
      if (mounted) {
        _showSnackbar('Профиль сохранен успешно');
        Navigator.pop(context, true);
      }
    } else {
      _showSnackbar('Не удалось сохранить изменения', isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
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

  @override
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, _) {
        final state = AppState();
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
        final name = _nameController.text.trim();

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(
            title: Text(
              state.translate('edit_profile_title'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          body: LiquidBackground(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).padding.bottom + 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar Area (Dynamic Letter Circle, no default picture!)
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.accentLight, AppColors.accent]
                              : [AppColors.accent, AppColors.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? AppColors.accentLight : AppColors.accent).withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.inter(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Name field
                  _buildFieldLabel(state.translate('edit_profile_name'), labelColor),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: titleColor),
                    decoration: getGlassInputDecoration(
                      hintText: state.translate('edit_profile_name_hint'),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.subtextDark, size: 20),
                      context: context,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email field
                  _buildFieldLabel(state.translate('edit_profile_email'), labelColor),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: titleColor),
                    decoration: getGlassInputDecoration(
                      hintText: state.translate('edit_profile_email_hint'),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.subtextDark, size: 20),
                      context: context,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date of Birth field
                  _buildFieldLabel(state.translate('edit_profile_dob'), labelColor),
                  _buildSelectorField(
                    text: _selectedDob,
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _showDatePicker(context),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // Country/Region field
                  _buildFieldLabel(state.translate('edit_profile_country'), labelColor),
                  _buildSelectorField(
                    text: _selectedCountry,
                    icon: Icons.public_rounded,
                    onTap: () => _showCountryPicker(context, isDark),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 48),

                  // Save button
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  else
                    TeslaButton(
                      onPressed: _handleSave,
                      child: Text(state.translate('edit_profile_save')),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSelectorField({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.subtextDark, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
