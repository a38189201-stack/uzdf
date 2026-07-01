import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_widgets.dart';
import 'app_state.dart';
import 'api_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _currentCourse;
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
    _staggerCtrl = AnimationController(vsync: this, duration: kVerySlow);
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshCourse() async {
    if (!mounted) return;
    final courses = await ApiService.fetchCourses();
    if (!mounted) return;
    if (courses.isNotEmpty) {
      final updated = courses.firstWhere(
        (c) => c['id'].toString() == _currentCourse['id'].toString(),
        orElse: () => null,
      );
      if (updated != null) {
        setState(() {
          _currentCourse = updated;
        });
      }
    }
  }

  double _getCourseProgress() {
    final steps = _currentCourse['steps'] as List<dynamic>? ?? [];
    if (steps.isEmpty) return 0.0;
    final completed =
        steps.where((s) => s['userProgress']?['status'] == 'completed').length;
    return completed / steps.length;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = _currentCourse['steps'] as List<dynamic>? ?? [];
    final progress = _getCourseProgress();
    final completedCount =
        steps.where((s) => s['userProgress']?['status'] == 'completed').length;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(
          _currentCourse['title'] ?? '',
          style: const TextStyle(letterSpacing: -0.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    color: AppColors.hearts, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${ApiService.currentUser?['courseLives'] ?? 3}',
                  style: GoogleFonts.inter(
                    color: AppColors.hearts,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: LiquidBackground(
        child: steps.isEmpty
            ? _buildEmptyState(isDark)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildCourseHeader(
                        progress, completedCount, steps.length,
                        isDark: isDark),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                state.translate('courses_steps'),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            );
                          }
                          final step = steps[index - 1];
                          final delay = (index - 1) * 60;
                          final itemAnim = CurvedAnimation(
                            parent: _staggerCtrl,
                            curve: Interval(
                              (delay / 600.0).clamp(0.0, 1.0),
                              ((delay + 350.0) / 600.0).clamp(0.0, 1.0),
                              curve: kSpring,
                            ),
                          );
                          return AnimatedBuilder(
                            animation: _staggerCtrl,
                            builder: (_, child) => FadeTransition(
                              opacity: Tween(begin: 0.0, end: 1.0)
                                  .animate(itemAnim),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero,
                                ).animate(itemAnim),
                                child: child,
                              ),
                            ),
                            child: _buildStepTile(
                                step, index - 1, steps, isDark),
                          );
                        },
                        childCount: steps.length + 1,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCourseHeader(
      double progress, int completedCount, int totalSteps,
      {required bool isDark}) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF181C2E), const Color(0xFF0F1320)]
              : [Colors.white, const Color(0xFFEFF6FF)],
        ),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
          width: 1.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleProgressRing(
                  value: progress,
                  size: 60,
                  color: AppColors.accent,
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completedCount из $totalSteps уроков',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentCourse['description'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.subtextDark,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedProgressBar(value: progress),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.menu_book_rounded,
                size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text(
            'В этом курсе пока нет уроков',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(
      dynamic step, int stepIndex, List<dynamic> allSteps, bool isDark) {
    final stepStatus = step['userProgress']?['status'] ?? 'not_started';
    final isCompleted = stepStatus == 'completed';
    final isInProgress = stepStatus == 'in_progress';
    final isLocked = step['isLocked'] == true;
    final isFinalExam = step['isFinalExam'] == true;
    final type = step['type'] ?? 'text';
    final isLastStep = stepIndex >= allSteps.length - 1;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Road-map line
        Column(
          children: [
            StepTypeIcon(
              type: type,
              isCompleted: isCompleted,
              isLocked: isLocked,
              isFinalExam: isFinalExam,
            ),
            if (!isLastStep)
              Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isCompleted
                        ? [AppColors.success, AppColors.success.withValues(alpha: 0.3)]
                        : [
                            AppColors.darkBorder,
                            AppColors.darkBorder.withValues(alpha: 0.3),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PressScaleWidget(
              scale: isLocked ? 1.0 : 0.98,
              onTap: isLocked
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Завершите предыдущий урок, чтобы разблокировать этот шаг',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  : () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        GlassRoute(
                          page: StepDetailScreen(
                            steps: allSteps,
                            initialIndex: stepIndex,
                            onStepCompleted: _refreshCourse,
                          ),
                        ),
                      ).then((_) => _refreshCourse());
                    },
              child: Opacity(
                opacity: isLocked ? 0.45 : 1.0,
                child: LiquidGlassCard(
                  padding: const EdgeInsets.all(14),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.3)
                        : isFinalExam
                            ? AppColors.warning.withValues(alpha: 0.3)
                            : isInProgress
                                ? AppColors.accent.withValues(alpha: 0.3)
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                    width: isCompleted || isFinalExam || isInProgress ? 1.5 : 1.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isLocked
                                    ? AppColors.subtextDark
                                    : textColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isFinalExam
                                        ? AppColors.warning.withValues(alpha: 0.12)
                                        : type == 'quiz'
                                            ? const Color(0xFF7C3AED)
                                                .withValues(alpha: 0.12)
                                            : type == 'video'
                                                ? AppColors.danger
                                                    .withValues(alpha: 0.1)
                                                : AppColors.accent
                                                    .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isFinalExam
                                        ? 'Финальный экзамен'
                                        : type == 'quiz'
                                            ? 'Тест'
                                            : type == 'video'
                                                ? 'Видеоурок'
                                                : 'Теория',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isFinalExam
                                          ? AppColors.warning
                                          : type == 'quiz'
                                              ? const Color(0xFF7C3AED)
                                              : type == 'video'
                                                  ? AppColors.danger
                                                  : AppColors.accent,
                                    ),
                                  ),
                                ),
                                if (isInProgress && !isCompleted) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.warning.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'В процессе',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isLocked)
                        Icon(Icons.lock_rounded,
                            color: AppColors.subtextDark
                                .withValues(alpha: 0.4),
                            size: 18)
                      else if (isCompleted)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 16),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color:
                              AppColors.subtextDark.withValues(alpha: 0.4),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════
// STEP DETAIL SCREEN — DUOLINGO STYLE
// ═══════════════════════════════════════

class StepDetailScreen extends StatefulWidget {
  final List<dynamic> steps;
  final int initialIndex;
  final VoidCallback? onStepCompleted;

  const StepDetailScreen({
    super.key,
    required this.steps,
    required this.initialIndex,
    this.onStepCompleted,
  });

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen>
    with TickerProviderStateMixin {
  late int _currentIndex;

  Map<String, dynamic> get _currentStep =>
      widget.steps[_currentIndex] as Map<String, dynamic>;

  bool _isLoading = true;
  bool _isBlocked = false;
  String _blockMessage = '';

  String _status = 'not_started';
  bool _scrollCompleted = false;
  int _secondsSpent = 0;
  int _estimatedReadTime = 0;
  int _remainingVideoSeconds = 0;
  int _videoDuration = 0;

  Timer? _readingTimer;
  Timer? _videoTimer;
  ScrollController? _scrollController;

  bool _isQuiz = false;
  bool _isFinalExam = false;
  List<dynamic> _quizQuestions = [];
  final Map<String, String> _selectedAnswers = {};
  bool _quizSubmitted = false;
  bool _quizPassed = false;
  double _quizScore = 0.0;
  int _attemptsUsed = 0;
  List<dynamic> _failedTopics = [];
  DateTime? _cooldownUntil;

  // For reading progress bar
  double _readProgress = 0.0;

  static const _securityChannel = MethodChannel('uzdf.security');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isQuiz = _currentStep['type'] == 'quiz';
    _isFinalExam = _currentStep['isFinalExam'] ?? false;
    _activateSecureMode();
    _securityChannel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshotTaken') {
        _simulateViolation();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStepData());
  }

  void _initForCurrentIndex() {
    _readingTimer?.cancel();
    _videoTimer?.cancel();
    _scrollController?.dispose();
    _scrollController = null;

    final currentStep = widget.steps[_currentIndex] as Map<String, dynamic>;

    setState(() {
      _isLoading = true;
      _isBlocked = false;
      _blockMessage = '';
      _status = 'not_started';
      _scrollCompleted = false;
      _secondsSpent = 0;
      _estimatedReadTime = 0;
      _remainingVideoSeconds = 0;
      _videoDuration = 0;
      _isQuiz = currentStep['type'] == 'quiz';
      _isFinalExam = currentStep['isFinalExam'] ?? false;
      _quizQuestions = [];
      _selectedAnswers.clear();
      _quizSubmitted = false;
      _quizPassed = false;
      _quizScore = 0.0;
      _attemptsUsed = 0;
      _failedTopics = [];
      _cooldownUntil = null;
      _readProgress = 0.0;
    });

    _loadStepData();
  }

  @override
  void dispose() {
    _deactivateSecureMode();
    _securityChannel.setMethodCallHandler(null);
    _readingTimer?.cancel();
    _videoTimer?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  Future<void> _activateSecureMode() async {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        try {
          await FlutterWindowManagerPlus.addFlags(
              FlutterWindowManagerPlus.FLAG_SECURE);
        } catch (e) {
          debugPrint('Error setting FLAG_SECURE: $e');
        }
      } else if (Platform.isIOS) {
        try {
          await _securityChannel.invokeMethod('setSecure', true);
        } catch (e) {
          debugPrint('Error setting secure mode on iOS: $e');
        }
      }
    }
  }

  Future<void> _deactivateSecureMode() async {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        try {
          await FlutterWindowManagerPlus.clearFlags(
              FlutterWindowManagerPlus.FLAG_SECURE);
        } catch (e) {
          debugPrint('Error clearing FLAG_SECURE: $e');
        }
      } else if (Platform.isIOS) {
        try {
          await _securityChannel.invokeMethod('setSecure', false);
        } catch (e) {
          debugPrint('Error clearing secure mode on iOS: $e');
        }
      }
    }
  }

  Future<void> _loadStepData() async {
    setState(() {
      _isLoading = true;
      _isBlocked = false;
      _blockMessage = '';
      _quizSubmitted = false;
    });

    final stepId = _currentStep['id'];

    final startRes = await ApiService.startStep(stepId);
    if (startRes == null) {
      setState(() {
        _isBlocked = true;
        _blockMessage = 'Не удалось подключиться к серверу';
        _isLoading = false;
      });
      return;
    }

    if (startRes.containsKey('error')) {
      setState(() {
        _isBlocked = true;
        _blockMessage = startRes['error'];
        _isLoading = false;
      });
      return;
    }

    final progress = startRes['progress'] as Map<String, dynamic>;
    _status = progress['status'] ?? 'not_started';
    _scrollCompleted = progress['scrollCompleted'] ?? false;
    _attemptsUsed = progress['quizAttempts'] ?? 0;

    if (progress['cooldownUntil'] != null) {
      _cooldownUntil = DateTime.parse(progress['cooldownUntil']);
    }

    if (_isQuiz) {
      if (_status == 'completed') {
        _quizSubmitted = true;
        _quizPassed = true;
        _quizScore =
            (progress['timeSpentSeconds'] as num?)?.toDouble() ?? 100.0;
      }

      final quizRes = await ApiService.fetchQuiz(stepId);
      if (quizRes == null) {
        setState(() {
          _isBlocked = true;
          _blockMessage = 'Не удалось получить вопросы теста';
          _isLoading = false;
        });
        return;
      }
      if (quizRes.containsKey('error')) {
        setState(() {
          _isBlocked = true;
          _blockMessage = quizRes['error'];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _quizQuestions = quizRes['questions'] as List<dynamic>? ?? [];
        _attemptsUsed = quizRes['attemptsUsed'] ?? _attemptsUsed;
        _isLoading = false;
      });
    } else {
      if (_currentStep['type'] == 'text') {
        _estimatedReadTime = startRes['estimatedReadTimeSeconds'] ?? 0;
        _scrollController = ScrollController();
        _scrollController!.addListener(_onScroll);

        _secondsSpent = progress['timeSpentSeconds'] ?? 0;
        _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_status != 'completed') {
            setState(() {
              _secondsSpent++;
              if (_estimatedReadTime > 0) {
                _readProgress = (_secondsSpent / _estimatedReadTime).clamp(0.0, 1.0);
              }
            });
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController != null && _scrollController!.hasClients) {
            final maxExtent = _scrollController!.position.maxScrollExtent;
            if (maxExtent < 20) {
              setState(() => _scrollCompleted = true);
            }
          }
        });
      } else if (_currentStep['type'] == 'video') {
        _videoDuration = startRes['videoDurationSeconds'] ?? 0;

        if (progress['lessonStartedAt'] != null) {
          final startedAt = DateTime.parse(progress['lessonStartedAt']);
          final elapsed =
              DateTime.now().difference(startedAt).inSeconds;
          _remainingVideoSeconds = _videoDuration - elapsed;
          if (_remainingVideoSeconds < 0) _remainingVideoSeconds = 0;
        } else {
          _remainingVideoSeconds = _videoDuration;
        }

        if (_remainingVideoSeconds > 0 && _status != 'completed') {
          _videoTimer =
              Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_remainingVideoSeconds > 0) {
              setState(() => _remainingVideoSeconds--);
            } else {
              _videoTimer?.cancel();
            }
          });
        }
      }

      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    final currentScroll = _scrollController!.position.pixels;
    if (maxScroll < 20 || currentScroll >= maxScroll - 40) {
      if (!_scrollCompleted) {
        setState(() => _scrollCompleted = true);
      }
    }
    // Update scroll-based read progress
    if (maxScroll > 0) {
      setState(() {
        final scrollFraction = (currentScroll / maxScroll).clamp(0.0, 1.0);
        if (scrollFraction > _readProgress) {
          _readProgress = scrollFraction;
        }
      });
    }
  }

  Future<void> _completeLesson() async {
    setState(() => _isLoading = true);

    final res = await ApiService.completeStepSecure(
      stepId: _currentStep['id'],
      scrollCompleted: _scrollCompleted,
      timeSpentSeconds: _secondsSpent,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Ошибка соединения с сервером', isError: true),
      );
      return;
    }

    if (res.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(res['error'], isError: true),
      );
      return;
    }

    setState(() => _status = 'completed');
    widget.onStepCompleted?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(res['message'] ?? 'Урок завершён! ✓', isError: false),
    );
  }

  Future<void> _submitQuizAnswers() async {
    if (_selectedAnswers.length < _quizQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
            'Пожалуйста, ответьте на все вопросы перед отправкой.',
            isError: true),
      );
      return;
    }

    setState(() => _isLoading = true);

    final answersPayload = _selectedAnswers.entries
        .map((e) => {'question': e.key, 'selectedOption': e.value})
        .toList();

    final res = await ApiService.submitQuiz(_currentStep['id'], answersPayload);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Ошибка соединения с сервером', isError: true),
      );
      return;
    }

    if (res.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(res['error'], isError: true),
      );
      return;
    }

    setState(() {
      _quizSubmitted = true;
      _quizPassed = res['success'] ?? false;
      _quizScore = (res['score'] as num?)?.toDouble() ?? 0.0;
      _attemptsUsed = res['attemptsUsed'] ?? _attemptsUsed + 1;
      _failedTopics = res['failedTopics'] ?? [];

      if (res['cooldownUntil'] != null) {
        _cooldownUntil = DateTime.parse(res['cooldownUntil']);
      }

      if (_quizPassed) {
        _status = 'completed';
        widget.onStepCompleted?.call();
        if (res['certificateIssued'] == true) {
          _showCertificateIssuedDialog(res['certificateUuid']);
        }
      }
    });
  }

  SnackBar _buildSnackBar(String message, {required bool isError}) {
    return SnackBar(
      content: Text(message,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    );
  }

  void _showCertificateIssuedDialog(String? uuid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: LiquidGlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.military_tech_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Поздравляем!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Вы успешно прошли все испытания курса и получили официальный сертификат!',
                  style: GoogleFonts.inter(
                    color: AppColors.subtextDark,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (uuid != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'UUID: $uuid',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TeslaButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  child: const Text('Отлично! 🎉'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _simulateViolation() async {
    final res = await ApiService.logViolation(_currentStep['id']);
    if (res == null) return;
    if (!mounted) return;

    final violationCount = res['violationCount'] ?? 0;
    final blocked = res['blocked'] ?? false;

    if (blocked) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildViolationDialog(
          title: 'ДОСТУП ЗАБЛОКИРОВАН',
          message:
              'Система зафиксировала 5 нарушений политики безопасности.\n\nДоступ к курсу заблокирован на 24 часа.',
          color: AppColors.danger,
          onClose: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    } else if (violationCount >= 3) {
      showDialog(
        context: context,
        builder: (context) => _buildViolationDialog(
          title: 'ПРЕДУПРЕЖДЕНИЕ',
          message:
              'Скриншоты и запись экрана в приложении запрещены!\n\nЗафиксировано $violationCount из 5 нарушений.',
          color: AppColors.warning,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
            '⚠️ Скриншот зафиксирован! Попытка $violationCount из 5.',
            isError: true),
      );
    }
  }

  Widget _buildViolationDialog({
    required String title,
    required String message,
    required Color color,
    required VoidCallback onClose,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: LiquidGlassCard(
        borderRadius: 22,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              color == AppColors.danger
                  ? Icons.block_rounded
                  : Icons.warning_rounded,
              color: color,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                color: AppColors.subtextDark,
                height: 1.5,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TeslaButton(
              onPressed: onClose,
              backgroundColor: color,
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = step['type'] ?? 'text';
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    Widget mainContent;

    if (_isBlocked) {
      mainContent = Scaffold(
        appBar: const GlassAppBar(),
        body: LiquidBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        size: 36, color: AppColors.danger),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Доступ заблокирован',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _blockMessage,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.subtextDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TeslaButton(
                    onPressed: () => Navigator.of(context).pop(),
                    isOutlined: true,
                    child: const Text('Назад'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (_isLoading) {
      mainContent = Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2.5,
          ),
        ),
      );
    } else {
      mainContent = Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              GlassAppBar(
                title: Text(step['title'] ?? '',
                    style: const TextStyle(letterSpacing: -0.5)),
                actions: [
                  if (type == 'video')
                    IconButton(
                      icon: Icon(Icons.screenshot_monitor,
                          color: AppColors.subtextDark, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _simulateViolation();
                      },
                    ),
                ],
              ),
              // Reading progress bar (for text type)
              if (type == 'text')
                AnimatedProgressBar(
                  value: _scrollCompleted ? 1.0 : _readProgress,
                  height: 3,
                  color: _scrollCompleted ? AppColors.success : AppColors.accent,
                ),
            ],
          ),
        ),
        body: LiquidBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (step['imageUrl'] != null &&
                            step['imageUrl'].toString().trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              step['imageUrl'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SkeletonLoader(
                                    width: double.infinity,
                                    height: 200,
                                    borderRadius: 16);
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(Icons.broken_image,
                                      color: AppColors.danger),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (!_isQuiz) ...[
                          // Video timer display
                          if (type == 'video' && _remainingVideoSeconds > 0) ...[
                            LiquidGlassCard(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                children: [
                                  Text(
                                    'Посмотрите видео перед продолжением',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.subtextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${(_remainingVideoSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingVideoSeconds % 60).toString().padLeft(2, '0')}',
                                    style: GoogleFonts.inter(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedProgressBar(
                                    value: _videoDuration > 0
                                        ? 1 -
                                            (_remainingVideoSeconds /
                                                _videoDuration)
                                        : 0,
                                    color: AppColors.accent,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ] else ...[
                        if (_quizSubmitted)
                          _buildQuizResults()
                        else
                          _buildQuizQuestionsList(isDark),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_isQuiz) _buildBottomActionBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizQuestionsList(bool isDark) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final answeredCount = _selectedAnswers.length;
    final totalCount = _quizQuestions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quiz header
        LiquidGlassCard(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          border: Border.all(
            color: (_isFinalExam ? AppColors.warning : const Color(0xFF7C3AED))
                .withValues(alpha: 0.3),
            width: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_isFinalExam
                              ? AppColors.warning
                              : const Color(0xFF7C3AED))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isFinalExam ? '🏆 Финальный экзамен' : '📝 Тест',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _isFinalExam
                            ? AppColors.warning
                            : const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$answeredCount / $totalCount',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedProgressBar(
                value: totalCount > 0 ? answeredCount / totalCount : 0,
                color: _isFinalExam
                    ? AppColors.warning
                    : const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 8),
              Text(
                'Минимальный проходной балл: ${_isFinalExam ? "95%" : "80%"}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.subtextDark,
                ),
              ),
            ],
          ),
        ),
        // Questions
        ..._quizQuestions.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final q = entry.value;
          final questionText = q['question'];
          final options = q['options'] as List<dynamic>;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _selectedAnswers.containsKey(questionText)
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.subtextDark.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${qIndex + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _selectedAnswers.containsKey(questionText)
                                  ? AppColors.accent
                                  : AppColors.subtextDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          questionText,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...options.map((opt) {
                    final isSelected =
                        _selectedAnswers[questionText] == opt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PressScaleWidget(
                        scale: 0.97,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedAnswers[questionText] = opt.toString();
                          });
                        },
                        child: AnimatedContainer(
                          duration: kFast,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: kFast,
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.accent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.subtextDark
                                            .withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 12)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opt.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isSelected ? AppColors.accent : textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TeslaButton(
          onPressed: answeredCount < _quizQuestions.length
              ? null
              : _submitQuizAnswers,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Сдать тест',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              if (answeredCount < _quizQuestions.length) ...[
                const SizedBox(width: 8),
                Text(
                  '($answeredCount/$totalCount)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildQuizResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final remainingCooldownMinutes = _cooldownUntil != null
        ? _cooldownUntil!.difference(DateTime.now()).inMinutes
        : 0;
    final isLastStep = _currentIndex >= widget.steps.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: (_quizPassed ? AppColors.success : AppColors.danger)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (_quizPassed ? AppColors.success : AppColors.danger)
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _quizPassed ? Icons.check_rounded : Icons.close_rounded,
                size: 44,
                color: _quizPassed ? AppColors.success : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _quizPassed ? 'Тест сдан! 🎉' : 'Тест не пройден',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _quizPassed ? AppColors.success : AppColors.danger,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LiquidGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildResultRow(
                    'Ваш результат',
                    '${_quizScore.toStringAsFixed(0)}%',
                    isDark,
                    color: _quizPassed ? AppColors.success : AppColors.danger),
                Divider(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    height: 24),
                _buildResultRow('Попыток использовано',
                    '$_attemptsUsed из 5', isDark),
                if (!_quizPassed &&
                    _cooldownUntil != null &&
                    remainingCooldownMinutes > 0) ...[
                  Divider(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      height: 24),
                  _buildResultRow('Повтор доступен через',
                      '$remainingCooldownMinutes мин', isDark,
                      color: AppColors.warning),
                ],
              ],
            ),
          ),
          if (!_quizPassed && _failedTopics.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Темы для повторения:',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            ..._failedTopics.map((topic) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          topic.toString(),
                          style: GoogleFonts.inter(
                            color: AppColors.subtextDark,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 24),
          if (!_quizPassed)
            TeslaButton(
              isDestructive: false,
              isOutlined: remainingCooldownMinutes > 0 || _attemptsUsed >= 5,
              onPressed: remainingCooldownMinutes > 0 || _attemptsUsed >= 5
                  ? null
                  : () {
                      setState(() {
                        _quizSubmitted = false;
                        _selectedAnswers.clear();
                      });
                    },
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                _attemptsUsed >= 5
                    ? 'Попытки исчерпаны'
                    : (remainingCooldownMinutes > 0
                        ? 'Кулдаун: $remainingCooldownMinutes мин'
                        : 'Попробовать снова'),
              ),
            ),
          if (_quizPassed) ...[
            TeslaButton(
              backgroundColor:
                  isLastStep ? AppColors.accent : AppColors.success,
              onPressed: () {
                HapticFeedback.lightImpact();
                if (isLastStep) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _currentIndex++;
                    _initForCurrentIndex();
                  });
                }
              },
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastStep ? 'Завершить курс' : 'Следующий урок',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Вернуться к списку уроков',
                style: GoogleFonts.inter(color: AppColors.accent),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildResultRow(String title, String value, bool isDark,
      {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.subtextDark,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    final bgColor = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.9)
        : AppColors.lightSurface.withValues(alpha: 0.9);

    if (_status == 'completed') {
      final isLastStep = _currentIndex >= widget.steps.length - 1;
      return Container(
        color: bgColor,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: TeslaButton(
          backgroundColor:
              isLastStep ? AppColors.accent : AppColors.success,
          onPressed: () {
            HapticFeedback.lightImpact();
            if (isLastStep) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _currentIndex++;
                _initForCurrentIndex();
              });
            }
          },
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLastStep ? 'Завершить курс' : 'Следующий урок',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    }

    final isText = _currentStep['type'] == 'text';

    if (isText) {
      final textReady =
          _scrollCompleted && _secondsSpent >= _estimatedReadTime;
      final remainingRead = (_estimatedReadTime - _secondsSpent).clamp(0, 9999);

      return Container(
        color: bgColor,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!textReady) ...[
              if (!_scrollCompleted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.swipe_down_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Прокрутите весь текст до конца',
                          style: GoogleFonts.inter(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (remainingRead > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: AppColors.accent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Осталось: $remainingReadс',
                        style: GoogleFonts.inter(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            TeslaButton(
              onPressed: textReady ? _completeLesson : null,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'Завершить урок',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Video
      final videoReady = _remainingVideoSeconds <= 0;
      final m = (_remainingVideoSeconds / 60).floor().toString().padLeft(2, '0');
      final s = (_remainingVideoSeconds % 60).toString().padLeft(2, '0');

      return Container(
        color: bgColor,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!videoReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Следующий шаг через $m:$s',
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            TeslaButton(
              onPressed: videoReady ? _completeLesson : null,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'Следующий шаг',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
