import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_widgets.dart';
import 'app_state.dart';
import 'api_service.dart';
import 'news_detail_screen.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  late Future<List<dynamic>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsFuture = ApiService.fetchNews();
  }

  void _refreshNews() {
    setState(() {
      _newsFuture = ApiService.fetchNews();
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
          appBar: GlassAppBar(
            title: Text(
              state.translate('news_title'),
              style: const TextStyle(fontWeight: FontWeight.w400, letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _refreshNews();
                },
              )
            ],
          ),
          body: LiquidBackground(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              strokeWidth: 2.0,
              onRefresh: () async => _refreshNews(),
              child: FutureBuilder<List<dynamic>>(
                future: _newsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: List.generate(4, (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: LiquidGlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            const SkeletonLoader(width: double.infinity, height: 160, borderRadius: 18),
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                SkeletonLoader(width: MediaQuery.of(context).size.width * 0.7, height: 18, borderRadius: 6),
                                const SizedBox(height: 10),
                                const SkeletonLoader(width: double.infinity, height: 12, borderRadius: 4),
                                const SizedBox(height: 6),
                                SkeletonLoader(width: MediaQuery.of(context).size.width * 0.5, height: 12, borderRadius: 4),
                              ]),
                            ),
                          ]),
                        ),
                      )),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.article_outlined, size: 36, color: AppColors.accent),
                        ),
                        const SizedBox(height: 16),
                        Text('Нет доступных новостей', style: GoogleFonts.inter(color: AppColors.subtextDark, fontSize: 15)),
                      ]),
                    );
                  }

                  final newsList = snapshot.data!;
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.only(
                      left: 16, right: 16, top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 68 + 24 + 20,
                    ),
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final item = newsList[index];
                      final author = item['author'] ?? 'UZDF';
                      return PressScaleWidget(
                        scale: 0.98,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, GlassRoute(page: NewsDetailScreen(news: item)));
                        },
                        child: _buildNewsCard(item['title'] ?? '', item['content'] ?? '', author, item['imageUrl'], isDark),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsCard(String title, String desc, String author, String? imageUrl, bool isDark) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    return LiquidGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: Container(
              height: 180,
              color: isDark ? AppColors.darkSurface2 : const Color(0xFFEBF0F7),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(Icons.image_outlined, size: 48, color: AppColors.subtextDark),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.article_rounded, size: 48, color: AppColors.subtextDark.withValues(alpha: 0.4)),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: textColor, letterSpacing: -0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppColors.subtextDark, height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    author.toUpperCase(),
                    style: GoogleFonts.inter(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.accent, size: 16),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}