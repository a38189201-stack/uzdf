import 'package:flutter/material.dart';
import 'app_state.dart';
import 'api_service.dart';
import 'course_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = ApiService.fetchCourses();
  }

  void _refreshCourses() {
    setState(() {
      _coursesFuture = ApiService.fetchCourses();
    });
  }

  /// Find the current active course (in_progress or last started)
  Map<String, dynamic>? _findActiveCourse(List<dynamic> courses) {
    // First: find a course with in_progress steps
    for (final c in courses) {
      if (c['isLocked'] == true) continue;
      final steps = c['steps'] as List<dynamic>? ?? [];
      final hasInProgress = steps.any((s) => s['userProgress']?['status'] == 'in_progress');
      final hasCompleted = steps.any((s) => s['userProgress']?['status'] == 'completed');
      if (hasInProgress || hasCompleted) return c as Map<String, dynamic>;
    }
    // Fallback: first unlocked course
    for (final c in courses) {
      if (c['isLocked'] != true) return c as Map<String, dynamic>;
    }
    return null;
  }

  /// True if user has any progress in a course
  bool _hasProgress(Map<String, dynamic> course) {
    final steps = course['steps'] as List<dynamic>? ?? [];
    return steps.any((s) {
      final status = s['userProgress']?['status'];
      return status == 'in_progress' || status == 'completed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppState().currentLanguage,
      builder: (context, lang, child) {
        final state = AppState();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.translate('courses_title'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshCourses,
              )
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => _refreshCourses(),
            child: FutureBuilder<List<dynamic>>(
              future: _coursesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPromoBanner(state, null, isDark),
                      const SizedBox(height: 32),
                      Text(
                        state.translate('courses_all'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      const Center(
                        child: Text(
                          'Нет доступных курсов',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  );
                }

                final courses = snapshot.data!;
                final activeCourse = _findActiveCourse(courses);
                final bannerCourse = activeCourse ?? (courses.isNotEmpty ? courses.first as Map<String, dynamic> : null);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length + 2, // 1 banner + 1 title + courses list
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildPromoBanner(state, bannerCourse, isDark, activeCourse: activeCourse, courses: courses);
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16),
                        child: Text(
                          state.translate('courses_all'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    }
                    
                    final course = courses[index - 2] as Map<String, dynamic>;
                    final isLocked = course['isLocked'] == true;
                    final steps = course['steps'] as List<dynamic>? ?? [];
                    final stepsCount = steps.length;
                    final completedCount = steps.where((s) => s['userProgress']?['status'] == 'completed').length;
                    final progress = stepsCount > 0 ? completedCount / stepsCount : 0.0;
                    
                    String statusLabel;
                    if (isLocked) {
                      statusLabel = '🔒 Заблокировано';
                    } else if (completedCount == stepsCount && stepsCount > 0) {
                      statusLabel = '✅ Завершено';
                    } else if (completedCount > 0) {
                      statusLabel = '$completedCount/$stepsCount шагов';
                    } else {
                      statusLabel = stepsCount > 0 ? 'Шагов: $stepsCount' : 'Без шагов';
                    }
                    
                    return GestureDetector(
                      onTap: () {
                        if (isLocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Этот курс заблокирован. Пройдите предыдущие курсы по порядку!'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(course: course),
                          ),
                        ).then((_) => _refreshCourses());
                      },
                      child: Opacity(
                        opacity: isLocked ? 0.65 : 1.0,
                        child: _buildCourseCard(
                          course['title'] ?? '',
                          course['description'] ?? '',
                          statusLabel,
                          progress.toDouble(),
                          isDark,
                          isLocked: isLocked,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromoBanner(
    AppState state,
    Map<String, dynamic>? bannerCourse,
    bool isDark, {
    Map<String, dynamic>? activeCourse,
    List<dynamic>? courses,
  }) {
    final hasProgress = activeCourse != null && _hasProgress(activeCourse);
    final buttonLabel = hasProgress ? 'Продолжить обучение' : state.translate('courses_start');
    final title = bannerCourse?['title'] ?? 'Базовый курс пилотирования';
    final desc = bannerCourse?['description'] ?? 'Освойте основы управления дроном за 4 недели.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0066FF), Color(0xFF0033AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066FF).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasProgress)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '▶ Продолжается',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0066FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            onPressed: bannerCourse == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(course: bannerCourse),
                      ),
                    ).then((_) => _refreshCourses());
                  },
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCourseCard(String title, String desc, String status, double progress, bool isDark, {bool isLocked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0D1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black87,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!isLocked) ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? const Color(0xFF1B233D) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF0066FF)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                status,
                style: TextStyle(
                  color: isLocked ? Colors.grey : const Color(0xFF0066FF), 
                  fontWeight: FontWeight.w800, 
                  fontSize: 12,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}