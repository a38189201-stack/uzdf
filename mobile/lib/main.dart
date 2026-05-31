import 'dart:async';
import 'package:flutter/material.dart';
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
  runApp(const SkyCheckApp());
}

class SkyCheckApp extends StatelessWidget {
  const SkyCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'SkyCheck Tashkent',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: isDark ? const Color(0xFF050814) : const Color(0xFFF0F4FF),
            primaryColor: const Color(0xFF0066FF),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0066FF),
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: const Color(0xFF0066FF),
              secondary: const Color(0xFF0066FF),
              surface: isDark ? const Color(0xFF0A0D1A) : Colors.white,
            ),
            cardTheme: const CardThemeData(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
              clipBehavior: Clip.antiAlias,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
              titleTextStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
              selectedItemColor: const Color(0xFF0066FF),
              unselectedItemColor: const Color(0xFF94A3B8),
              elevation: 10,
              type: BottomNavigationBarType.fixed,
            ),
            fontFamily: 'Inter',
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _hoverController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _textFade;
  late Animation<double> _textLetterSpacing;
  late Animation<double> _subtitleFade;

  late Animation<double> _radarScale;
  late Animation<double> _radarOpacity;

  late Animation<double> _hoverOffset;

  @override
  void initState() {
    super.initState();

    // Main intro animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoScale = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoRotate = Tween<double>(begin: -0.4, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _textLetterSpacing = Tween<double>(begin: 16.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // Pulse/radar controller (infinite loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _radarScale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    _radarOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    // Hover/float controller (infinite loop, reverse)
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _hoverOffset = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeInOut,
      ),
    );

    _mainController.forward();
    
    // Start ambient animations after the logo settles
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _pulseController.repeat();
        _hoverController.repeat(reverse: true);
      }
    });

    // 3.8 seconds delay before navigation to allow animation completion
    Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainNavigation(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme-dependent styles and assets
    final backgroundColor1 = isDark ? const Color(0xFF030712) : const Color(0xFFF4F7FF);
    final backgroundColor2 = isDark ? const Color(0xFF0B1530) : const Color(0xFFFFFFFF);
    
    final primaryColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0066FF);
    final shadowColor = isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : const Color(0xFF0066FF).withValues(alpha: 0.15);
    final cardBgColor = isDark ? const Color(0xFF0A0D1A).withValues(alpha: 0.8) : Colors.white;
    final borderColor = isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.3) : const Color(0xFF0066FF).withValues(alpha: 0.1);
    
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0066FF);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [backgroundColor2, backgroundColor1],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_logoScale, _hoverOffset, _pulseController]),
                builder: (context, child) {
                  final scale = _logoScale.value;
                  final hoverY = _hoverOffset.value;
                  
                  return Transform.translate(
                    offset: Offset(0, hoverY),
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Radar Pulse 2 (slight scale offset)
                          Opacity(
                            opacity: _radarOpacity.value * 0.5,
                            child: Container(
                              width: 90 * _radarScale.value,
                              height: 90 * _radarScale.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                          // Outer Radar Pulse 1
                          Opacity(
                            opacity: _radarOpacity.value,
                            child: Container(
                              width: 130 * _radarScale.value,
                              height: 130 * _radarScale.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.5),
                                  width: 1.0,
                                ),
                              ),
                            ),
                          ),
                          // Main Flight Logo Card
                          RotationTransition(
                            turns: _logoRotate,
                            child: Container(
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: isDark ? 45 : 30,
                                    spreadRadius: isDark ? 5 : 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.flight_takeoff,
                                size: 64,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 54),
              
              // Animated Text (SkyCheck)
              AnimatedBuilder(
                animation: Listenable.merge([_textFade, _textLetterSpacing]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _textFade.value,
                    child: Text(
                      'SkyCheck',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: _textLetterSpacing.value,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 8),
              
              // Animated Subtitle (УЗБЕКИСТАН)
              FadeTransition(
                opacity: _subtitleFade,
                child: Text(
                  'УЗБЕКИСТАН',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: subtitleColor.withValues(alpha: 0.9),
                    letterSpacing: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Список всех экранов приложения
  final List<Widget> _screens = [
    const HomeScreen(),
    const BlogScreen(),
    const MapScreen(),
    const StoreScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: ApiService.tokenNotifier,
      builder: (context, token, child) {
        if (token == null) {
          return AuthScreen(
            onLoginSuccess: () {
              setState(() {
                _currentIndex = 0;
              });
            },
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: AppState().currentLanguage,
          builder: (context, lang, child) {
            final state = AppState();
            return Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.school), label: state.translate('nav_courses')),
                  BottomNavigationBarItem(icon: const Icon(Icons.article), label: state.translate('nav_news')),
                  BottomNavigationBarItem(icon: const Icon(Icons.map), label: state.translate('nav_map')),
                  BottomNavigationBarItem(icon: const Icon(Icons.shopping_cart), label: state.translate('nav_shop')),
                  BottomNavigationBarItem(icon: const Icon(Icons.person), label: state.translate('nav_profile')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}