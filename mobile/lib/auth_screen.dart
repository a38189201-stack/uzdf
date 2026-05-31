import 'package:flutter/material.dart';
import 'api_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isLoginTab = true;
  bool _isLoading = false;
  String? _verificationEmail;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Заполните все поля');
      return;
    }

    if (!email.contains('@')) {
      _showSnackbar('Неверный формат Email');
      return;
    }

    setState(() => _isLoading = true);

    if (_isLoginTab) {
      // Log in
      final success = await ApiService.login(email, password);
      if (success) {
        await ApiService.fetchProfile();
        widget.onLoginSuccess();
      } else {
        _showSnackbar('Ошибка авторизации. Проверьте учетные данные.');
      }
    } else {
      // Register
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final confirmPass = _confirmPasswordController.text;

      if (name.isEmpty) {
        _showSnackbar('Заполните имя');
        setState(() => _isLoading = false);
        return;
      }
      if (phone.isEmpty || phone.length < 7) {
        _showSnackbar('Введите номер телефона');
        setState(() => _isLoading = false);
        return;
      }
      if (password.length < 6) {
        _showSnackbar('Пароль должен быть не менее 6 символов');
        setState(() => _isLoading = false);
        return;
      }
      if (password != confirmPass) {
        _showSnackbar('Пароли не совпадают');
        setState(() => _isLoading = false);
        return;
      }

      final result = await ApiService.register(name, email, password, phone);
      if (result != null) {
        if (result['message'] == 'VERIFICATION_REQUIRED') {
          setState(() {
            _verificationEmail = email;
            _codeController.clear();
          });
          _showSnackbar('Код подтверждения отправлен на вашу почту');
        } else if (result.containsKey('error')) {
          _showSnackbar(result['error']);
        } else {
          await ApiService.fetchProfile();
          widget.onLoginSuccess();
        }
      } else {
        _showSnackbar('Ошибка регистрации. Возможно, email уже используется.');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      _showSnackbar('Введите 6-значный код подтверждения');
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.verifyCode(_verificationEmail!, code);
    if (result != null && result['success'] == true) {
      await ApiService.fetchProfile();
      widget.onLoginSuccess();
    } else {
      final errMsg = result?['error'] ?? 'Неверный код подтверждения';
      _showSnackbar(errMsg);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Show a mock Google accounts chooser sheet
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, String>? selectedAccount = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Вход через Google',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Выберите аккаунт для входа в приложение SkyCheck:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _buildGoogleAccountTile(
                context,
                'Тимур Каримов',
                'timur.skycheck@gmail.com',
                isDark,
              ),
              _buildGoogleAccountTile(
                context,
                'Елена Пак',
                'elena.fpv@gmail.com',
                isDark,
              ),
              _buildGoogleAccountTile(
                context,
                'Алишер Усманов',
                'alisher.pilot@gmail.com',
                isDark,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selectedAccount != null) {
      setState(() => _isLoading = true);
      final name = selectedAccount['name']!;
      final email = selectedAccount['email']!;
      
      final success = await ApiService.loginWithGoogle(name, email);
      if (success) {
        await ApiService.fetchProfile();
        widget.onLoginSuccess();
      } else {
        _showSnackbar('Ошибка авторизации через Google');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGoogleAccountTile(BuildContext context, String name, String email, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? const Color(0xFF141C33) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0066FF).withValues(alpha: 0.15),
          child: Text(name[0], style: const TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        onTap: () => Navigator.pop(context, {'name': name, 'email': email}),
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF0A1128), Color(0xFF000000)],
                )
              : const RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFFF0F4FF), Color(0xFFFFFFFF)],
                ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flight, size: 36, color: Color(0xFF0066FF)),
                      const SizedBox(width: 12),
                      Text(
                        'SkyCheck',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _verificationEmail != null
                        ? 'Подтвердите ваш адрес электронной почты'
                        : (_isLoginTab ? 'Войдите в аккаунт пилота БПЛА' : 'Создайте новый аккаунт пилота'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 36),

                  // Auth Card Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0D1A).withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black54 : Colors.black12,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _verificationEmail != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Подтверждение почты',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Мы отправили 6-значный код подтверждения на почту:\n$_verificationEmail',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              _buildTextField(
                                controller: _codeController,
                                hintText: 'Код подтверждения (6 цифр)',
                                icon: Icons.security_outlined,
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0066FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _handleVerifyCode,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Подтвердить',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _verificationEmail = null;
                                          _codeController.clear();
                                        });
                                      },
                                child: const Text(
                                  'Изменить почту / Назад',
                                  style: TextStyle(color: Color(0xFF0066FF)),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Tabs selector
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isLoginTab = true),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Войти',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _isLoginTab
                                                  ? const Color(0xFF0066FF)
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            height: 2,
                                            color: _isLoginTab
                                                ? const Color(0xFF0066FF)
                                                : Colors.transparent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isLoginTab = false),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Регистрация',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: !_isLoginTab
                                                  ? const Color(0xFF0066FF)
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            height: 2,
                                            color: !_isLoginTab
                                                ? const Color(0xFF0066FF)
                                                : Colors.transparent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Form Inputs
                              if (!_isLoginTab) ...[
                                _buildTextField(
                                  controller: _nameController,
                                  hintText: 'Имя',
                                  icon: Icons.person_outline,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _phoneController,
                                  hintText: 'Номер телефона (+998...)',
                                  icon: Icons.phone_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                              ],
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Email',
                                icon: Icons.email_outlined,
                                isDark: isDark,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                hintText: 'Пароль',
                                icon: Icons.lock_outline,
                                isDark: isDark,
                                obscureText: true,
                              ),
                              if (!_isLoginTab) ...[
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  hintText: 'Подтвердите пароль',
                                  icon: Icons.lock_outline,
                                  isDark: isDark,
                                  obscureText: true,
                                ),
                              ],
                              const SizedBox(height: 32),

                              // Submit Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0066FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _handleAuth,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        _isLoginTab ? 'Войти в аккаунт' : 'Зарегистрироваться',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                  ),
                  if (_verificationEmail == null) ...[
                    const SizedBox(height: 24),

                    // Divider "или"
                    Row(
                      children: [
                        Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('или', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Google Sign-In Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
                      ),
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                        height: 18,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata),
                      ),
                      label: Text(
                        'Войти через Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF050814) : const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
    );
  }
}
