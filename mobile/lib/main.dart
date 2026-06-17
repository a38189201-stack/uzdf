import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_widgets.dart';
import 'app_state.dart';
import 'map_screen.dart';
import 'home_screen.dart';
import 'blog_screen.dart';
import 'store_screen.dart';
import 'profile_screen.dart';
import 'api_service.dart';
import 'auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  await AppState().init();
  runApp(const UzdfApp());
}

class UzdfApp extends StatelessWidget {
  const UzdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'UZDF',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(isDark),
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            Widget? screen;
            if (settings.name == '/navigation') {
              screen = const MainNavigation();
            }
            if (screen == null) return null;
            return PageRouteBuilder(
              transitionDuration: kSlow,
              reverseTransitionDuration: kNormal,
              pageBuilder: (context, animation, secondaryAnimation) => screen!,
              transitionsBuilder: (_, animation, secondary, child) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: kSpring));
                final secondarySlide = Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(-0.06, 0),
                ).animate(CurvedAnimation(parent: secondary, curve: kSmooth));
                return SlideTransition(
                  position: secondarySlide,
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(bool isDark) {
    final base = ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBg : AppColors.lightBg,
      primaryColor: AppColors.accent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: AppColors.accent,
        secondary: AppColors.accentLight,
        surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        onSurface: isDark ? AppColors.textDark : AppColors.textLight,
        onSurfaceVariant:
            isDark ? AppColors.subtextDark : AppColors.subtextLight,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textDark : AppColors.textLight,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
        headlineLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
        headlineMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
        titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
        bodyLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
        bodyMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// PARTICLE SYSTEM FOR SPLASH
// ═══════════════════════════════════════

class _Particle {
  double x, y, vx, vy, size, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;

  _ParticlePainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ═══════════════════════════════════════
// SPLASH SCREEN — TESLA + PARTICLES
// ═══════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textFade;
  late Animation<double> _textLetterSpacing;
  late Animation<double> _subtitleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _radarScale;
  late Animation<double> _radarOpacity;

  final math.Random _rng = math.Random(42);
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    // Init particles
    _particles = List.generate(8, (i) => _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      vx: (_rng.nextDouble() - 0.5) * 0.0003,
      vy: (_rng.nextDouble() - 0.5) * 0.0003,
      size: 1.5 + _rng.nextDouble() * 2,
      opacity: 0.2 + _rng.nextDouble() * 0.3,
    ));

    // Main intro controller
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.4, 0.75, curve: Curves.easeIn),
      ),
    );

    _textLetterSpacing = Tween<double>(begin: 18.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    // Pulse radar controller
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _radarScale = Tween<double>(begin: 1.0, end: 2.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    _radarOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    // Particle animation
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);

    _mainCtrl.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _pulseCtrl.repeat();
        _particleCtrl.repeat();
      }
    });

    Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigation(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0 || p.x > 1) p.vx = -p.vx;
        if (p.y < 0 || p.y > 1) p.vy = -p.vy;
      }
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : const Color(0xFFF0F4FF);
    final accentColor = AppColors.accent;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: Stack(
          children: [
            // Ambient glow
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Particles
            Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  color: accentColor,
                ),
              ),
            ),
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with pulse
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_logoScale, _logoOpacity, _pulseCtrl]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse ring outer
                              Opacity(
                                opacity: _radarOpacity.value * 0.4,
                                child: Container(
                                  width: 140 * _radarScale.value,
                                  height: 140 * _radarScale.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accentColor,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              // Pulse ring inner
                              Opacity(
                                opacity: _radarOpacity.value * 0.7,
                                child: Container(
                                  width: 100 * _radarScale.value,
                                  height: 100 * _radarScale.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.6),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              // Logo card
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.2),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 52),

                  // UZDF Title with letter spacing animation
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_textFade, _textLetterSpacing]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFade.value,
                        child: Text(
                          'UZDF',
                          style: GoogleFonts.inter(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: _textLetterSpacing.value,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Subtitle with slide-up animation
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_subtitleFade, _subtitleSlide]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _subtitleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _subtitleSlide.value),
                          child: Column(
                            children: [
                              Text(
                                'Uzbekistan Drone Federation',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 48),
                              // Loading indicator
                              SizedBox(
                                width: 32,
                                height: 2,
                                child: LinearProgressIndicator(
                                  backgroundColor: accentColor.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// MAIN NAVIGATION — TESLA BOTTOM BAR
// ═══════════════════════════════════════

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const BlogScreen(),
    const MapScreen(),
    const StoreScreen(),
    const ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.school_rounded, Icons.school_outlined, 'Курсы'),
    _NavItem(Icons.article_rounded, Icons.article_outlined, 'Новости'),
    _NavItem(Icons.map_rounded, Icons.map_outlined, 'Карта'),
    _NavItem(Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, 'Магазин'),
    _NavItem(Icons.person_rounded, Icons.person_outlined, 'Профиль'),
  ];

  late AnimationController _iconCtrl;
  late Animation<double> _iconBounce;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(vsync: this, duration: kNormal);
    _iconBounce = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _iconCtrl, curve: kBounce),
    );
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() {
      _prevIndex = _currentIndex;
      _currentIndex = index;
    });
    _iconCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String?>(
      valueListenable: ApiService.tokenNotifier,
      builder: (context, token, child) {
        if (token == null) {
          return AuthScreen(
            onLoginSuccess: () => setState(() => _currentIndex = 0),
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: AppState().currentLanguage,
          builder: (context, lang, child) {
            return Scaffold(
              body: LiquidBackground(
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: kNormal,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                              parent: animation, curve: Curves.easeIn),
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_currentIndex),
                        child: _screens[_currentIndex],
                      ),
                    ),
                    // Bottom Navigation Bar
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      child: _buildNavBar(isDark),
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

  Widget _buildNavBar(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : Colors.white)
                .withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (i) {
              return _buildNavItem(i, isDark);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, bool isDark) {
    final isSelected = _currentIndex == index;
    final item = _navItems[index];
    final activeColor = AppColors.accent;
    final inactiveColor = AppColors.subtextDark;

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        height: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _iconBounce,
              builder: (_, child) {
                final scale =
                    (isSelected && _currentIndex != _prevIndex)
                        ? _iconBounce.value
                        : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: AnimatedContainer(
                duration: kNormal,
                curve: kSpring,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.inactiveIcon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: kFast,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _NavItem(this.activeIcon, this.inactiveIcon, this.label);
}