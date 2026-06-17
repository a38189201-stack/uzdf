import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_state.dart';

// ═══════════════════════════════════════
// DESIGN TOKENS — TESLA + APPLE + DUOLINGO
// ═══════════════════════════════════════

class AppColors {
  // Dark surfaces (Tesla)
  static const darkBg       = Color(0xFF0C0E14);
  static const darkSurface  = Color(0xFF13161F);
  static const darkSurface2 = Color(0xFF1A1D28);
  static const darkBorder   = Color(0xFF1F2336);

  // Light surfaces
  static const lightBg      = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFE8ECF0);

  // Accent (Tesla Blue)
  static const accent       = Color(0xFF3B82F6);
  static const accentLight  = Color(0xFF60A5FA);
  static const accentDeep   = Color(0xFF2563EB);

  // Semantic
  static const success      = Color(0xFF22C55E);
  static const successLight = Color(0xFF4ADE80);
  static const warning      = Color(0xFFF59E0B);
  static const danger       = Color(0xFFEF4444);
  static const dangerLight  = Color(0xFFFCA5A5);

  // Duolingo
  static const streak       = Color(0xFFFF9600);
  static const hearts       = Color(0xFFFF4B4B);
  static const xp           = Color(0xFF58CC02);

  // Text
  static const textDark     = Color(0xFFF1F5F9);
  static const subtextDark  = Color(0xFF94A3B8);
  static const textLight    = Color(0xFF0F172A);
  static const subtextLight = Color(0xFF475569);
}

// ═══════════════════════════════════════
// ANIMATION CONSTANTS
// ═══════════════════════════════════════

const Duration kFast     = Duration(milliseconds: 150);
const Duration kNormal   = Duration(milliseconds: 300);
const Duration kSlow     = Duration(milliseconds: 500);
const Duration kVerySlow = Duration(milliseconds: 800);

const Curve kSpring  = Curves.easeOutCubic;
const Curve kBounce  = Curves.elasticOut;
const Curve kSmooth  = Curves.easeInOutCubic;
const Curve kEaseOut = Curves.easeOut;

// ═══════════════════════════════════════
// THEME HELPERS
// ═══════════════════════════════════════

TextStyle interStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double letterSpacing = -0.2,
  double height = 1.5,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// ═══════════════════════════════════════
// PRESS FEEDBACK WIDGET
// ═══════════════════════════════════════

class PressScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressScaleWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<PressScaleWidget> createState() => _PressScaleWidgetState();
}

class _PressScaleWidgetState extends State<PressScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kFast);
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: kSpring),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          _ctrl.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════
// LIQUID GLASS CARD (TESLA SURFACE)
// ═══════════════════════════════════════

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
  final AlignmentGeometry? alignment;
  final bool showShimmer;
  final Color? color;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.blur = 0.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
    this.shadow,
    this.gradient,
    this.alignment,
    this.showShimmer = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, _) {
        final cardColor = color ??
            (isDark ? AppColors.darkSurface : AppColors.lightSurface);

        final defaultBorder = border ??
            Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              width: 1.0,
            );

        final defaultShadow = shadow ??
            (isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]);

        return Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            color: cardColor,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: defaultBorder,
            boxShadow: defaultShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1),
            child: Container(
              padding: padding,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// GLASS CONTAINER (BACKWARD COMPAT)
// ═══════════════════════════════════════

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 40.0,
    this.opacity = -1.0,
    this.borderRadius = 18.0,
    this.border,
    this.shadow,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: borderRadius,
      blur: blur,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      border: border,
      shadow: shadow,
      gradient: gradient,
      alignment: alignment,
      child: child,
    );
  }
}

// ═══════════════════════════════════════
// TESLA PRIMARY BUTTON
// ═══════════════════════════════════════

class TeslaButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool isOutlined;
  final bool isDestructive;

  const TeslaButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 14.0,
    this.padding,
    this.isOutlined = false,
    this.isDestructive = false,
  });

  @override
  State<TeslaButton> createState() => _TeslaButtonState();
}

class _TeslaButtonState extends State<TeslaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kFast);
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: kSpring),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode.value;
    final accent = AppColors.accent;
    final isEnabled = widget.onPressed != null;

    Color bg;
    Color fg;
    Border? border;

    if (widget.isDestructive) {
      bg = widget.isOutlined
          ? Colors.transparent
          : AppColors.danger;
      fg = widget.isOutlined ? AppColors.danger : Colors.white;
      border = widget.isOutlined
          ? Border.all(color: AppColors.danger, width: 1.5)
          : null;
    } else if (widget.isOutlined) {
      bg = Colors.transparent;
      fg = isDark ? AppColors.accentLight : AppColors.accentDeep;
      border = Border.all(
        color: isDark
            ? AppColors.accentLight.withValues(alpha: 0.5)
            : AppColors.accent.withValues(alpha: 0.4),
        width: 1.5,
      );
    } else {
      bg = widget.backgroundColor ?? accent;
      fg = widget.foregroundColor ?? Colors.white;
    }

    return GestureDetector(
      onTapDown: (_) {
        if (isEnabled) {
          _ctrl.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.45,
          duration: kFast,
          child: Container(
            padding: widget.padding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: border,
              boxShadow: (!widget.isOutlined && !widget.isDestructive && isEnabled)
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: DefaultTextStyle(
                style: GoogleFonts.inter(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// GLASS BUTTON (BACKWARD COMPAT)
// ═══════════════════════════════════════

class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 14.0,
    this.blur = 0.0,
    this.opacity = -1.0,
    this.gradient,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode.value;
    final btnColor = color ?? AppColors.accent;
    final isPrimary = color == null || color == AppColors.accent;

    return TeslaButton(
      onPressed: onPressed,
      backgroundColor: isPrimary ? btnColor : (color ?? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
      foregroundColor: isPrimary ? Colors.white : (isDark ? Colors.white : AppColors.textLight),
      borderRadius: borderRadius,
      padding: padding,
      isOutlined: !isPrimary && color == null,
      child: child,
    );
  }
}

// ═══════════════════════════════════════
// LIQUID BUTTON (BACKWARD COMPAT)
// ═══════════════════════════════════════

class LiquidButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double pressedOpacity;
  final double normalOpacity;

  const LiquidButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 14.0,
    this.pressedOpacity = 0.22,
    this.normalOpacity = 0.14,
  });

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kFast);
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: kSpring),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, _) {
        return GestureDetector(
          onTapDown: (_) {
            if (isClickable) {
              setState(() => _pressed = true);
              _ctrl.forward();
              HapticFeedback.lightImpact();
            }
          },
          onTapUp: (_) {
            if (isClickable) {
              setState(() => _pressed = false);
              _ctrl.reverse();
              widget.onTap!();
            }
          },
          onTapCancel: () {
            if (isClickable) {
              setState(() => _pressed = false);
              _ctrl.reverse();
            }
          },
          child: AnimatedBuilder(
            animation: _scale,
            builder: (_, child) =>
                Transform.scale(scale: _scale.value, child: child),
            child: AnimatedContainer(
              duration: kFast,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: _pressed ? widget.pressedOpacity : widget.normalOpacity)
                    : Colors.black.withValues(alpha: _pressed ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: _pressed ? 0.2 : 0.1)
                      : Colors.black.withValues(alpha: _pressed ? 0.15 : 0.06),
                ),
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// SKELETON LOADER (SHIMMER)
// ═══════════════════════════════════════

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode.value;
    final base = isDark ? AppColors.darkSurface2 : const Color(0xFFE8ECF0);
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// SKELETON CARD (HOME SCREEN LOADING)
// ═══════════════════════════════════════

class SkeletonCourseCard extends StatelessWidget {
  const SkeletonCourseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonLoader(width: MediaQuery.of(context).size.width * 0.5, height: 16),
              const SizedBox(height: 8),
              SkeletonLoader(width: MediaQuery.of(context).size.width * 0.3, height: 12),
            ]),
          ]),
          const SizedBox(height: 16),
          const SkeletonLoader(width: double.infinity, height: 6, borderRadius: 3),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// ANIMATED PROGRESS BAR (TESLA STYLE)
// ═══════════════════════════════════════

class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color? color;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6.0,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kVerySlow);
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: kSmooth),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: kSmooth),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode.value;
    final barColor = widget.color ?? AppColors.accent;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _anim.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [barColor, barColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: barColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Aviation progress bar (backward compat)
class AviationProgressBar extends StatelessWidget {
  final double value;

  const AviationProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedProgressBar(value: value);
  }
}

// ═══════════════════════════════════════
// HEART WIDGET (DUOLINGO LIVES)
// ═══════════════════════════════════════

class HeartWidget extends StatefulWidget {
  final int count;
  final int maxCount;
  final double size;

  const HeartWidget({
    super.key,
    required this.count,
    this.maxCount = 5,
    this.size = 18,
  });

  @override
  State<HeartWidget> createState() => _HeartWidgetState();
}

class _HeartWidgetState extends State<HeartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Transform.scale(
          scale: widget.count > 0 ? _pulse.value : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.maxCount, (i) {
              final isFilled = i < widget.count;
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  isFilled ? Icons.favorite : Icons.favorite_border,
                  color: isFilled
                      ? AppColors.hearts
                      : AppColors.hearts.withValues(alpha: 0.3),
                  size: widget.size,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// STREAK COUNTER (DUOLINGO FIRE)
// ═══════════════════════════════════════

class StreakBadge extends StatefulWidget {
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _wobble = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak == 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _wobble,
      builder: (_, child) {
        return Transform.rotate(angle: _wobble.value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.streak.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.streak.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '${widget.streak}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.streak,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// XP LEVEL BADGE
// ═══════════════════════════════════════

class XpLevelBadge extends StatelessWidget {
  final int level;
  final int exp;
  final int prevLevelExp;
  final int nextLevelExp;

  const XpLevelBadge({
    super.key,
    required this.level,
    required this.exp,
    required this.prevLevelExp,
    required this.nextLevelExp,
  });

  @override
  Widget build(BuildContext context) {
    final range = nextLevelExp - prevLevelExp;
    final progress = exp - prevLevelExp;
    final percent = range > 0 ? (progress / range).clamp(0.0, 1.0) : 0.0;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$level',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'Уровень $level',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppState().isDarkMode.value ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  Text(
                    '$exp XP',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.xp,
                    ),
                  ),
                ]),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.xp.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(percent * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.xp,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedProgressBar(value: percent.toDouble(), color: AppColors.xp),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$prevLevelExp XP',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.subtextDark,
                ),
              ),
              Text(
                '$nextLevelExp XP',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.subtextDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// ACHIEVEMENT CARD
// ═══════════════════════════════════════

class AchievementCard extends StatefulWidget {
  final Map<String, dynamic> achievement;
  final bool isUnlocked;

  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kSlow);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: kBounce),
    );
    if (widget.isUnlocked) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode.value;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        color: widget.isUnlocked
            ? (isDark ? const Color(0xFF1A2040) : const Color(0xFFEFF6FF))
            : null,
        border: widget.isUnlocked
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.5)
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: widget.isUnlocked ? 1.0 : 0.3,
              child: Text(
                widget.achievement['icon'] ?? '🏅',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.achievement['name'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isUnlocked
                    ? (isDark ? AppColors.textDark : AppColors.textLight)
                    : AppColors.subtextDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            if (widget.isUnlocked) ...[
              const SizedBox(height: 4),
              Text(
                widget.achievement['reward'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.xp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// LIQUID BACKGROUND (TESLA DARK MESH)
// ═══════════════════════════════════════

class LiquidBackground extends StatefulWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, child) {
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  ),
                ),
                // Accent glow blob top-right
                Positioned(
                  top: -80 + 40 * _anim.value,
                  right: -60 + 20 * _anim.value,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: isDark ? 0.07 : 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Secondary glow blob bottom-left
                Positioned(
                  bottom: -120 - 30 * _anim.value,
                  left: -80 + 30 * _anim.value,
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark
                                  ? const Color(0xFF7C3AED)
                                  : AppColors.accentLight)
                              .withValues(alpha: isDark ? 0.05 : 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                widget.child,
              ],
            );
          },
          child: widget.child,
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// FLOATING HERO (AMBIENT FLOAT)
// ═══════════════════════════════════════

class FloatingHero extends StatefulWidget {
  final Widget child;
  const FloatingHero({super.key, required this.child});

  @override
  State<FloatingHero> createState() => _FloatingHeroState();
}

class _FloatingHeroState extends State<FloatingHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _float.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════
// GLASS APP BAR (iOS LARGE TITLE STYLE)
// ═══════════════════════════════════════

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState().isDarkMode,
      builder: (context, isDark, _) {
        final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textColor = isDark ? AppColors.textDark : AppColors.textLight;
        final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: AppBar(
              title: title,
              actions: actions,
              leading: leading,
              automaticallyImplyLeading: automaticallyImplyLeading,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: textColor,
                letterSpacing: -0.5,
              ),
              iconTheme: IconThemeData(color: textColor),
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

// ═══════════════════════════════════════
// GLASS ROUTE TRANSITIONS
// ═══════════════════════════════════════

class GlassRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  GlassRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: kSlow,
          reverseTransitionDuration: kNormal,
          transitionsBuilder: (context, animation, secondary, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: kSpring,
            ));
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.06, 0),
            ).animate(CurvedAnimation(
              parent: secondary,
              curve: kSmooth,
            ));
            return SlideTransition(
              position: secondarySlide,
              child: FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: slide,
                  child: child,
                ),
              ),
            );
          },
        );
}

// ═══════════════════════════════════════
// INPUT FIELD DECORATION
// ═══════════════════════════════════════

InputDecoration getGlassInputDecoration({
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  required BuildContext context,
}) {
  final isDark = AppState().isDarkMode.value;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04),
    hintStyle: GoogleFonts.inter(
      color: isDark
          ? AppColors.subtextDark.withValues(alpha: 0.6)
          : AppColors.subtextLight.withValues(alpha: 0.6),
      fontSize: 15,
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1.0,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppColors.accent.withValues(alpha: 0.7),
        width: 1.5,
      ),
    ),
  );
}

// ═══════════════════════════════════════
// NOISE PAINTER (BACKWARD COMPAT)
// ═══════════════════════════════════════

class NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;
    final double width = size.width;
    final double height = size.height;
    if (width <= 0 || height <= 0) return;
    int seed = 42;
    int nextRandom() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }
    final List<Offset> points = [];
    for (int i = 0; i < 600; i++) {
      final x = (nextRandom() % 10000) / 10000.0 * width;
      final y = (nextRandom() % 10000) / 10000.0 * height;
      points.add(Offset(x, y));
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════
// LIQUID BORDER PAINTER (BACKWARD COMPAT)
// ═══════════════════════════════════════

class LiquidBorderPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;

  LiquidBorderPainter({required this.borderRadius, this.strokeWidth = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.05),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════
// CIRCLE PROGRESS INDICATOR (RING)
// ═══════════════════════════════════════

class CircleProgressRing extends StatefulWidget {
  final double value;
  final double size;
  final Color? color;
  final Widget? child;

  const CircleProgressRing({
    super.key,
    required this.value,
    this.size = 60,
    this.color,
    this.child,
  });

  @override
  State<CircleProgressRing> createState() => _CircleProgressRingState();
}

class _CircleProgressRingState extends State<CircleProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kVerySlow);
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: kSmooth),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.color ?? AppColors.accent;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  value: _anim.value,
                  color: ringColor,
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color.withValues(alpha: 0.15);
    final double sweepAngle = 2 * math.pi * value;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (sweepAngle > 0.001) {
      progressPaint.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: [color.withValues(alpha: 0.6), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      progressPaint.color = color;
    }

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

// ═══════════════════════════════════════
// TYPE ICON WIDGET (STEP TYPE)
// ═══════════════════════════════════════

class StepTypeIcon extends StatelessWidget {
  final String type;
  final bool isCompleted;
  final bool isLocked;
  final bool isFinalExam;

  const StepTypeIcon({
    super.key,
    required this.type,
    this.isCompleted = false,
    this.isLocked = false,
    this.isFinalExam = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    if (isCompleted) {
      bgColor = AppColors.success.withValues(alpha: 0.15);
      iconColor = AppColors.success;
      icon = Icons.check_rounded;
    } else if (isLocked) {
      bgColor = AppColors.subtextDark.withValues(alpha: 0.10);
      iconColor = AppColors.subtextDark;
      icon = Icons.lock_rounded;
    } else if (isFinalExam) {
      bgColor = AppColors.warning.withValues(alpha: 0.15);
      iconColor = AppColors.warning;
      icon = Icons.emoji_events_rounded;
    } else if (type == 'quiz') {
      bgColor = const Color(0xFF7C3AED).withValues(alpha: 0.15);
      iconColor = const Color(0xFF7C3AED);
      icon = Icons.quiz_rounded;
    } else if (type == 'video') {
      bgColor = AppColors.danger.withValues(alpha: 0.12);
      iconColor = AppColors.danger;
      icon = Icons.play_circle_rounded;
    } else {
      bgColor = AppColors.accent.withValues(alpha: 0.12);
      iconColor = AppColors.accent;
      icon = Icons.article_rounded;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

// ═══════════════════════════════════════
// APPLE SETTINGS ROW
// ═══════════════════════════════════════

class AppleSettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const AppleSettingsRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode.value;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = AppColors.subtextDark;

    return PressScaleWidget(
      scale: 0.98,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subColor,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(
                            Icons.chevron_right_rounded,
                            color: subColor.withValues(alpha: 0.5),
                            size: 20,
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 0.5,
              indent: 62,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
        ],
      ),
    );
  }
}
