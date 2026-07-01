import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_widgets.dart';
import 'app_state.dart';
import 'api_service.dart';
import 'course_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late Future<List<dynamic>> _coursesFuture;
  late AnimationController _listController;
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _coursesFuture = ApiService.fetchCourses();
    _listController = AnimationController(
      duration: kVerySlow,
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: kSlow,
      vsync: this,
    );
    _listController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _refreshCourses() {
    _refreshController.forward(from: 0.0);
    setState(() {
      _coursesFuture = ApiService.fetchCourses();
      _listController.reset();
      _coursesFuture.then((_) {
        if (mounted) _listController.forward();
      });
    });
  }

  Map<String, dynamic>? _findActiveCourse(List<dynamic> courses) {
    for (final c in courses) {
      if (c['isLocked'] == true) continue;
      final steps = c['steps'] as List<dynamic>? ?? [];
      final hasInProgress =
          steps.any((s) => s['userProgress']?['status'] == 'in_progress');
      final hasCompleted =
          steps.any((s) => s['userProgress']?['status'] == 'completed');
      if (hasInProgress || hasCompleted) return c as Map<String, dynamic>;
    }
    for (final c in courses) {
      if (c['isLocked'] != true) return c as Map<String, dynamic>;
    }
    return null;
  }

  bool _hasProgress(Map<String, dynamic> course) {
    final steps = course['steps'] as List<dynamic>? ?? [];
    return steps.any((s) {
      final status = s['userProgress']?['status'];
      return status == 'in_progress' || status == 'completed';
    });
  }

  double _getCourseProgress(Map<String, dynamic> course) {
    final steps = course['steps'] as List<dynamic>? ?? [];
    if (steps.isEmpty) return 0.0;
    final completed =
        steps.where((s) => s['userProgress']?['status'] == 'completed').length;
    return completed / steps.length;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppState().currentLanguage,
      builder: (context, lang, child) {
        final state = AppState();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            strokeWidth: 2.0,
            displacement: 80,
            onRefresh: () async => _refreshCourses(),
            child: FutureBuilder<List<dynamic>>(
              future: _coursesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeletonList();
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return _buildEmptyState(state, isDark);
                }

                final courses = snapshot.data!;
                final activeCourse = _findActiveCourse(courses);
                final bannerCourse = activeCourse ??
                    (courses.isNotEmpty
                        ? courses.first as Map<String, dynamic>
                        : null);

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 750),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        _buildSliverAppBar(state, isDark),
                        SliverPadding(
                          padding: EdgeInsets.only(
                            top: 0,
                            bottom: MediaQuery.of(context).padding.bottom +
                                66 +
                                16 +
                                24,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final delay = index * 70;
                                final itemAnim = CurvedAnimation(
                                  parent: _listController,
                                  curve: Interval(
                                    (delay / 700.0).clamp(0.0, 1.0),
                                    ((delay + 400.0) / 700.0).clamp(0.0, 1.0),
                                    curve: kSpring,
                                  ),
                                );

                                Widget child;
                                if (index == 0) {
                                  child = _buildHeroBanner(
                                    state,
                                    bannerCourse,
                                    isDark,
                                    activeCourse: activeCourse,
                                  );
                                } else if (index == 1) {
                                  child = Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                                    child: Text(
                                      state.translate('courses_all'),
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.textDark
                                            : AppColors.textLight,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                  );
                                } else {
                                  final course =
                                      courses[index - 2] as Map<String, dynamic>;
                                  final isLocked = course['isLocked'] == true;
                                  final steps =
                                      course['steps'] as List<dynamic>? ?? [];
                                  final stepsCount = steps.length;
                                  final completedCount = steps
                                      .where((s) =>
                                          s['userProgress']?['status'] == 'completed')
                                      .length;
                                  final progress = stepsCount > 0
                                      ? completedCount / stepsCount
                                      : 0.0;

                                  String statusLabel;
                                  if (isLocked) {
                                    statusLabel = '🔒';
                                  } else if (completedCount == stepsCount &&
                                      stepsCount > 0) {
                                    statusLabel = '✓ Завершён';
                                  } else if (completedCount > 0) {
                                    statusLabel =
                                        'Продолжить • $completedCount/$stepsCount';
                                  } else {
                                    statusLabel = stepsCount > 0
                                        ? '$stepsCount уроков'
                                        : 'Начать';
                                  }

                                  child = _buildCourseCard(
                                    context,
                                    course,
                                    statusLabel,
                                    progress.toDouble(),
                                    isDark,
                                    isLocked: isLocked,
                                    stepsCount: stepsCount,
                                    completedCount: completedCount,
                                  );
                                }

                                return AnimatedBuilder(
                                  animation: _listController,
                                  builder: (_, childWidget) => FadeTransition(
                                    opacity: Tween(begin: 0.0, end: 1.0)
                                        .animate(itemAnim),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.06),
                                        end: Offset.zero,
                                      ).animate(itemAnim),
                                      child: childWidget,
                                    ),
                                  ),
                                  child: child,
                                );
                              },
                              childCount: courses.length + 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skeleton hero
                      const SkeletonLoader(
                          width: double.infinity, height: 200, borderRadius: 20),
                      const SizedBox(height: 28),
                      const SkeletonLoader(width: 140, height: 22, borderRadius: 8),
                      const SizedBox(height: 16),
                      ...List.generate(4, (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: SkeletonCourseCard(),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppState state, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildSliverAppBar(state, isDark),
            SliverFillRemaining(
              child: Center(
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
                      child: Icon(Icons.school_outlined,
                          size: 36, color: AppColors.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Курсы недоступны',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Потяните вниз чтобы обновить',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.subtextDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(AppState state, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: bgColor,
      elevation: 0,
      expandedHeight: 60,
      shape: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              Text(
                state.translate('courses_title'),
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: RotationTransition(
                  turns: _refreshController,
                  child: Icon(Icons.refresh_rounded,
                      color: textColor, size: 22),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _refreshCourses();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(
    AppState state,
    Map<String, dynamic>? bannerCourse,
    bool isDark, {
    Map<String, dynamic>? activeCourse,
  }) {
    final hasProgress =
        activeCourse != null && _hasProgress(activeCourse);
    final progress = bannerCourse != null
        ? _getCourseProgress(bannerCourse)
        : 0.0;
    final title =
        bannerCourse?['title'] ?? 'Базовый курс пилотирования';
    final desc = bannerCourse?['description'] ?? '';

    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final descColor = isDark
        ? AppColors.subtextDark
        : AppColors.subtextLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: PressScaleWidget(
        scale: 0.98,
        onTap: bannerCourse == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  GlassRoute(
                    page: CourseDetailScreen(course: bannerCourse),
                  ),
                ).then((_) => _refreshCourses());
              },
        child: LiquidGlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(22),
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
            color: AppColors.accent.withValues(alpha: 0.2),
            width: 1.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Progress ring
                  CircleProgressRing(
                    value: progress,
                    size: 54,
                    color: AppColors.accent,
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 10,
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
                        if (hasProgress)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '▶ Продолжается',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: descColor,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              // Progress bar
              AnimatedProgressBar(value: progress),
              const SizedBox(height: 16),
              // CTA button
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accentLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasProgress
                            ? 'Продолжить обучение'
                            : state.translate('courses_start'),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    Map<String, dynamic> course,
    String statusLabel,
    double progress,
    bool isDark, {
    bool isLocked = false,
    int stepsCount = 0,
    int completedCount = 0,
  }) {
    final title = course['title'] ?? '';
    final desc = course['miniDescription']?.toString().trim().isNotEmpty == true
        ? course['miniDescription'].toString()
        : (course['description'] ?? '');
    final authorName = course['authorName'] ?? '';
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final descColor = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final isCompleted = completedCount == stepsCount && stepsCount > 0;

    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: PressScaleWidget(
          scale: 0.97,
          onTap: isLocked
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    GlassRoute(
                      page: CourseDetailScreen(course: course),
                    ),
                  ).then((_) => _refreshCourses());
                },
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.12)
                        : isLocked
                            ? AppColors.subtextDark.withValues(alpha: 0.1)
                            : AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : isLocked
                            ? Icons.lock_rounded
                            : Icons.school_rounded,
                    color: isCompleted
                        ? AppColors.success
                        : isLocked
                            ? AppColors.subtextDark
                            : AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (authorName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                authorName,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: descColor,
                          height: 1.4,
                        ),
                      ),
                      if (!isLocked) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedProgressBar(value: progress),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isLocked)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.subtextDark.withValues(alpha: 0.4),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}