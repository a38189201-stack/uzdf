import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_widgets.dart';
import 'api_service.dart';
import 'app_state.dart';

enum AuthScreenState {
  onboarding,
  login,
  register,
  verify,
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // iOS Client ID — создан в Google Cloud Console для Bundle ID com.example.mobile
  static const String _iosClientId =
      '623890287900-80i2011gle3j68gsmdp0tmnbh2vpafo1.apps.googleusercontent.com';
  // Web Client ID — используется как serverClientId для получения idToken
  static const String _webClientId =
      '623890287900-og7m9d6pi7i6ptk525afmc7kdalp2php.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId: _webClientId,
        )
      : GoogleSignIn(
          scopes: ['email', 'profile'],
          // On iOS: clientId tells the SDK which iOS OAuth client to use (from Info.plist GIDClientID)
          // serverClientId tells the SDK to request an idToken for backend verification
          clientId: !kIsWeb && !Platform.isAndroid ? _iosClientId : null,
          serverClientId: !kIsWeb && !Platform.isAndroid ? _webClientId : null,
        );

  AuthScreenState _screenState = AuthScreenState.onboarding;
  bool _isLoading = false;
  String? _verificationEmail;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _keepMeSignedIn = true;
  int _onboardingIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToState(AuthScreenState state) {
    HapticFeedback.lightImpact();
    setState(() {
      _screenState = state;
    });
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

    if (_screenState == AuthScreenState.login) {
      final success = await ApiService.login(email, password);
      if (success) {
        await ApiService.fetchProfile();
        widget.onLoginSuccess();
      } else {
        _showSnackbar('Ошибка авторизации. Проверьте учётные данные.');
      }
    } else if (_screenState == AuthScreenState.register) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final confirmPass = _confirmPasswordController.text;

      if (name.isEmpty) {
        _showSnackbar('Введите имя');
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
            _screenState = AuthScreenState.verify;
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

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      _showSnackbar('Введите 6-значный код подтверждения');
      return;
    }

    setState(() => _isLoading = true);
    final result =
        await ApiService.verifyCode(_verificationEmail!, code);
    if (result != null && result['success'] == true) {
      await ApiService.fetchProfile();
      widget.onLoginSuccess();
    } else {
      _showSnackbar(result?['error'] ?? 'Неверный код подтверждения');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      // Sign out first to force account picker (important for iPad)
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      debugPrint('[GoogleSignIn] idToken is ${idToken != null ? "present" : "NULL"}');
      debugPrint('[GoogleSignIn] accessToken is ${googleAuth.accessToken != null ? "present" : "NULL"}');

      if (idToken != null) {
        final success = await ApiService.loginWithGoogleReal(idToken);
        if (success) {
          await ApiService.fetchProfile();
          if (mounted) widget.onLoginSuccess();
        } else {
          _showSnackbar('Ошибка авторизации на сервере UZDF');
        }
      } else {
        // idToken is null — this happens on iOS when serverClientId is wrong
        // Fallback: use name+email auth if idToken is unavailable
        debugPrint('[GoogleSignIn] idToken null — falling back to email auth');
        final success = await ApiService.loginWithGoogle(
          googleUser.displayName ?? googleUser.email.split('@')[0],
          googleUser.email,
        );
        if (success) {
          await ApiService.fetchProfile();
          if (mounted) widget.onLoginSuccess();
        } else {
          _showSnackbar('Ошибка входа через Google. Попробуйте войти по email.');
        }
      }
    } on PlatformException catch (e) {
      debugPrint('[GoogleSignIn] PlatformException: ${e.code} — ${e.message}');
      if (e.code == 'sign_in_canceled') {
        // User cancelled — don't show error
      } else if (e.code == 'network_error') {
        _showSnackbar('Нет подключения к интернету');
      } else {
        _showSnackbar('Ошибка Google: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('[GoogleSignIn] Error: $e');
      _showSnackbar('Ошибка входа через Google');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
                          fontSize: 17,
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      style: TextStyle(
                          color: isDark
                              ? AppColors.textDark
                              : AppColors.textLight),
                      decoration: getGlassInputDecoration(
                        hintText: 'например, 190.191.3.112:3000',
                        context: context,
                      ),
                    ),
                    if (statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        statusMessage,
                        style: GoogleFonts.inter(
                            color: statusColor, fontSize: 12),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Сброшено к автоматическому поиску')),
                              );
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
                                    statusMessage = 'Проверка...';
                                    statusColor = AppColors.accent;
                                  });
                                  final success =
                                      await ApiService.testAndSetCustomBaseUrl(
                                          input);
                                  setStateDialog(() => isTesting = false);
                                  if (success) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.success,
                                          content: const Text(
                                              'Подключено! Адрес сохранён.'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      );
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
                              horizontal: 18, vertical: 10),
                          child: isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text('Готово'),
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
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, _) {
        final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
        final sysBarBrightness = isDark ? Brightness.dark : Brightness.light;

        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: sysBarBrightness,
        ));

        return PopScope(
          canPop: _screenState == AuthScreenState.onboarding,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_screenState == AuthScreenState.verify) {
              setState(() {
                _verificationEmail = null;
                _codeController.clear();
                _screenState = AuthScreenState.register;
              });
            } else {
              setState(() {
                _screenState = AuthScreenState.onboarding;
              });
            }
          },
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.08, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: slide,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: _buildCurrentScreen(isDark),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen(bool isDark) {
    switch (_screenState) {
      case AuthScreenState.onboarding:
        return _buildOnboardingScreen(isDark, key: const ValueKey('onboarding'));
      case AuthScreenState.login:
        return _buildLoginScreen(isDark, key: const ValueKey('login'));
      case AuthScreenState.register:
        return _buildRegisterScreen(isDark, key: const ValueKey('register'));
      case AuthScreenState.verify:
        return _buildVerifyScreen(isDark, key: const ValueKey('verify'));
    }
  }

  // ═══════════════════════════════════════
  // ONBOARDING SCREEN
  // ═══════════════════════════════════════
  Widget _buildOnboardingScreen(bool isDark, {required Key key}) {
    return Column(
      key: key,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: Icon(
                Icons.wifi_find_rounded,
                color: isDark ? Colors.white30 : Colors.black26,
                size: 22,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showConnectionDialog(context, isDark);
              },
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() {
                _onboardingIndex = idx;
              });
            },
            children: [
              _buildOnboardingSlide(
                title: 'Welcome to the app',
                subtitle: "We're excited to help you book and manage your service appointments with ease.",
                isDark: isDark,
              ),
              _buildOnboardingSlide(
                title: 'Monitor Drone Flights',
                subtitle: 'Real-time updates, restricted zones mapping, and pilot federation tracking.',
                isDark: isDark,
              ),
              _buildOnboardingSlide(
                title: 'Register Flights Instantly',
                subtitle: 'Apply for permissions and check status reports directly on your phone.',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (idx) {
            final isActive = _onboardingIndex == idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 10 : 8,
              height: isActive ? 10 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (isDark ? AppColors.accentLight : const Color(0xFF2F54EB))
                    : (isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
              ),
            );
          }),
        ),
        const SizedBox(height: 36),
        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _buildPrimaryButton(
            text: 'Login',
            onPressed: () => _navigateToState(AuthScreenState.login),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _navigateToState(AuthScreenState.register),
          child: Text(
            'Create an account',
            style: GoogleFonts.inter(
              color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOnboardingSlide({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 3),
        FloatingWidget(
          child: const VectorDrone(size: 240),
        ),
        const Spacer(flex: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: subColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  // ═══════════════════════════════════════
  // LOGIN SCREEN
  // ═══════════════════════════════════════
  Widget _buildLoginScreen(bool isDark, {required Key key}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => _navigateToState(AuthScreenState.onboarding),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Login',
              style: GoogleFonts.inter(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Welcome back to the app',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: subColor,
              ),
            ),
            const SizedBox(height: 36),
            _buildCustomTextField(
              label: 'Email Address',
              controller: _emailController,
              hintText: 'hello@example.com',
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildCustomTextField(
              label: 'Password',
              controller: _passwordController,
              hintText: '............',
              isDark: isDark,
              isPassword: true,
              showForgotPassword: true,
              isObscured: _obscurePassword,
              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 20),
            // Keep me signed in Checkbox
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _keepMeSignedIn,
                    activeColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _keepMeSignedIn = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Keep me signed in',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(color: Color(0xFF2F54EB)),
                ),
              )
            else
              _buildPrimaryButton(
                text: 'Login',
                onPressed: _handleAuth,
                isDark: isDark,
              ),
            const SizedBox(height: 28),
            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'or sign in with',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildGoogleButton(
              onPressed: _handleGoogleSignIn,
              isDark: isDark,
            ),
            const SizedBox(height: 28),
            // Link to create account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => _navigateToState(AuthScreenState.register),
                  child: Text(
                    'Create an account',
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // REGISTER SCREEN
  // ═══════════════════════════════════════
  Widget _buildRegisterScreen(bool isDark, {required Key key}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => _navigateToState(AuthScreenState.onboarding),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register',
              style: GoogleFonts.inter(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a new pilot account',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: subColor,
              ),
            ),
            const SizedBox(height: 32),
            _buildCustomTextField(
              label: 'Full Name',
              controller: _nameController,
              hintText: 'John Doe',
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              label: 'Phone Number',
              controller: _phoneController,
              hintText: '+998 90 123 45 67',
              isDark: isDark,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              label: 'Email Address',
              controller: _emailController,
              hintText: 'hello@example.com',
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              label: 'Password',
              controller: _passwordController,
              hintText: '............',
              isDark: isDark,
              isPassword: true,
              isObscured: _obscurePassword,
              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              hintText: '............',
              isDark: isDark,
              isPassword: true,
              isObscured: _obscureConfirmPassword,
              onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            const SizedBox(height: 28),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(color: Color(0xFF2F54EB)),
                ),
              )
            else
              _buildPrimaryButton(
                text: 'Register',
                onPressed: _handleAuth,
                isDark: isDark,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => _navigateToState(AuthScreenState.login),
                  child: Text(
                    'Login',
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // VERIFY SCREEN
  // ═══════════════════════════════════════
  Widget _buildVerifyScreen(bool isDark, {required Key key}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _verificationEmail = null;
              _codeController.clear();
              _screenState = AuthScreenState.register;
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.accentLight : const Color(0xFF2F54EB)).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Verify Email',
              style: GoogleFonts.inter(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We\'ve sent a 6-digit confirmation code to:\n$_verificationEmail',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: subColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            _buildCustomTextField(
              label: 'Confirmation Code',
              controller: _codeController,
              hintText: '123456',
              isDark: isDark,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 28),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(color: Color(0xFF2F54EB)),
                ),
              )
            else
              _buildPrimaryButton(
                text: 'Verify',
                onPressed: _handleVerifyCode,
                isDark: isDark,
              ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _verificationEmail = null;
                    _codeController.clear();
                    _screenState = AuthScreenState.register;
                  });
                },
                child: Text(
                  'Change Email / Back',
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // REUSABLE HELPER WIDGETS
  // ═══════════════════════════════════════
  Widget _buildCustomTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    bool isPassword = false,
    bool showForgotPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final focusColor = isDark ? AppColors.accentLight : const Color(0xFF2F54EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            if (showForgotPassword)
              GestureDetector(
                onTap: () {
                  _showSnackbar('Восстановление пароля временно недоступно');
                },
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && isObscured,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              fontSize: 15,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: focusColor,
                width: 1.5,
              ),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.accentLight : const Color(0xFF2F54EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton({
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GoogleLogo(size: 18),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// FLOATING MICRO-ANIMATION
// ═══════════════════════════════════════
class FloatingWidget extends StatefulWidget {
  final Widget child;
  const FloatingWidget({super.key, required this.child});

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════
// VECTOR GOOGLE 'G' LOGO
// ═══════════════════════════════════════
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double radius = width / 2;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.24
      ..strokeCap = StrokeCap.butt;

    final Rect rect = Rect.fromCircle(center: Offset(radius, radius), radius: radius - paint.strokeWidth / 2);

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.25, false, paint);

    // Yellow arc (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.8, 1.4, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.4, false, paint);

    // Blue arc (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.9, 1.7, false, paint);

    // Horizontal bar
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final double barHeight = paint.strokeWidth;
    final double barWidth = radius;
    canvas.drawRect(
      Rect.fromLTWH(radius, radius - barHeight / 2, barWidth, barHeight),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════
// ANIMATED VECTOR DRONE WIDGET
// ═══════════════════════════════════════

class VectorDrone extends StatefulWidget {
  final double size;
  const VectorDrone({super.key, this.size = 200});

  @override
  State<VectorDrone> createState() => _VectorDroneState();
}

class _VectorDroneState extends State<VectorDrone> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _DronePainter(progress: _animCtrl.value),
        );
      },
    );
  }
}

class _DronePainter extends CustomPainter {
  final double progress;
  _DronePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final paintArm = Paint()
      ..color = const Color(0xFF475569) // Dark Slate
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final paintArmLight = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;

    // 1. Draw 4 Arms extending diagonally
    final armLength = r * 0.75;
    final angles = [math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4];

    for (var angle in angles) {
      final targetX = cx + math.cos(angle) * armLength;
      final targetY = cy + math.sin(angle) * armLength;

      // Draw main arm structure
      canvas.drawLine(Offset(cx, cy), Offset(targetX, targetY), paintArm);
      
      // Draw neon glow line on the arm
      canvas.drawLine(
        Offset(cx + math.cos(angle) * (r * 0.2), cy + math.sin(angle) * (r * 0.2)),
        Offset(cx + math.cos(angle) * (r * 0.65), cy + math.sin(angle) * (r * 0.65)),
        paintArmLight,
      );

      // Draw motor pod at the end of each arm
      final paintPod = Paint()
        ..color = const Color(0xFF1E293B) // Darker Slate
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(targetX, targetY), r * 0.12, paintPod);

      // Draw motor cap (accent metal)
      final paintCap = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(targetX, targetY), r * 0.05, paintCap);

      // Draw rotating propellers (semi-transparent blur arcs)
      final paintPropellerBlur1 = Paint()
        ..color = AppColors.accentLight.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03;
      
      final paintPropellerBlur2 = Paint()
        ..color = AppColors.accentLight.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.015;

      final propRadius = r * 0.28;
      final rotAngle = progress * 2 * math.pi * 5; // Spin fast!

      canvas.drawArc(
        Rect.fromCircle(center: Offset(targetX, targetY), radius: propRadius),
        rotAngle,
        math.pi / 2,
        false,
        paintPropellerBlur1,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(targetX, targetY), radius: propRadius),
        rotAngle + math.pi,
        math.pi / 2,
        false,
        paintPropellerBlur1,
      );

      // Draw sharper blades inside the blur
      canvas.drawArc(
        Rect.fromCircle(center: Offset(targetX, targetY), radius: propRadius),
        rotAngle + math.pi / 4,
        math.pi / 6,
        false,
        paintPropellerBlur2,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(targetX, targetY), radius: propRadius),
        rotAngle + 5 * math.pi / 4,
        math.pi / 6,
        false,
        paintPropellerBlur2,
      );
    }

    // 2. Draw Drone Central Body (Sleek aerodynamic oval/fuselage)
    final bodyHeight = r * 0.9;
    final bodyWidth = r * 0.55;

    // Body base shadow
    final paintBodyShadow = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 4), width: bodyWidth + 6, height: bodyHeight + 6),
      paintBodyShadow,
    );

    // Body main shell (Premium Silver-Blue gradient)
    final paintBody = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFF1F5F9), const Color(0xFFCBD5E1), const Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: bodyHeight))
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: bodyHeight),
      paintBody,
    );

    // Inner detail: dark center accent panel
    final paintInnerPanel = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - r * 0.05), width: bodyWidth * 0.65, height: bodyHeight * 0.7),
      paintInnerPanel,
    );

    // Glowing Neon Core / Logo line in the center of body
    final pulseGlow = (math.sin(progress * 2 * math.pi) * 0.2 + 0.8);
    final paintCoreGlow = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.8 * pulseGlow)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - r * 0.05), width: bodyWidth * 0.3, height: bodyHeight * 0.4),
      paintCoreGlow,
    );

    final paintCoreLine = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // Minimalist glowing vector logo inside the core
    final path = Path()
      ..moveTo(cx - 8, cy - 10)
      ..lineTo(cx, cy + 4)
      ..lineTo(cx + 8, cy - 10);
    canvas.drawPath(path, paintCoreLine);

    // 3. Draw Camera Head at the front
    final cameraRadius = r * 0.16;
    final cameraY = cy - bodyHeight / 2 + 5;

    final paintCameraShell = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cameraY), cameraRadius, paintCameraShell);

    // Camera Lens glow (cybernetic blue eye)
    final paintLensGlow = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx, cameraY), cameraRadius * 0.6, paintLensGlow);

    // Lens highlight
    final paintLensHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 2, cameraY - 2), cameraRadius * 0.2, paintLensHighlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
