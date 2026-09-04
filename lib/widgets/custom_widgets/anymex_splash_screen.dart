import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:anymex/controllers/services/anilist/anilist_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Animated AniList Splash Screen with cached profile, step-by-step loading progress,
/// smooth exit animations, and interactive error recovery (retry/skip).
class AnymeXSplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const AnymeXSplashScreen({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<AnymeXSplashScreen> createState() => _AnymeXSplashScreenState();
}

class _AnymeXSplashScreenState extends State<AnymeXSplashScreen>
    with TickerProviderStateMixin {
  late final AnilistAuth _anilistAuth;
  late final AnimationController _pulseController;
  late final AnimationController _exitController;
  late final Animation<double> _exitFadeAnimation;
  late final Animation<double> _exitScaleAnimation;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _anilistAuth = Get.find<AnilistAuth>();

    // Ambient breathing pulse animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Splash exit transition controller
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Listen to status changes to trigger exit animation on completion or skip
    ever(_anilistAuth.splashAuthStatus, _handleStatusChange);

    // Initiate the auto-login & profile sequence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAuthSequence();
    });
  }

  void _handleStatusChange(SplashAuthStatus status) {
    if (!mounted || _isExiting) return;

    if (status == SplashAuthStatus.completed) {
      HapticFeedback.lightImpact();
      // Brief pause on "Completed" for user satisfaction, then animate exit
      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted && !_isExiting) {
          _animateExit();
        }
      });
    } else if (status == SplashAuthStatus.skipped) {
      if (!_isExiting) {
        _animateExit();
      }
    }
  }

  Future<void> _startAuthSequence() async {
    await _anilistAuth.initAutoLoginSequence();
  }

  Future<void> _animateExit() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      await _exitController.forward();
    } catch (_) {}
    if (mounted) {
      widget.onAnimationComplete?.call();
    }
  }

  void _onRetryPressed() {
    HapticFeedback.mediumImpact();
    _anilistAuth.retryLogin();
  }

  void _onSkipPressed() {
    HapticFeedback.lightImpact();
    _anilistAuth.skipLogin();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 650;

    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      body: AnimatedBuilder(
        animation: _exitController,
        builder: (context, child) {
          return Opacity(
            opacity: _exitFadeAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _exitScaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ambient glow circles
            _buildAmbientGlow(theme, size),

            // Main splash content
            Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 440 : 380,
                  ),
                  child: Obx(() {
                    final status = _anilistAuth.splashAuthStatus.value;
                    final profile = _anilistAuth.profileData.value;
                    final hasProfile =
                        (profile.avatar != null && profile.avatar!.isNotEmpty) ||
                        (profile.name != null && profile.name!.isNotEmpty);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Profile Avatar or Animated Logo
                        _buildIdentityHeader(context, profile, hasProfile, status, theme),

                        const SizedBox(height: 28),

                        // Username & Subtitle
                        _buildUserGreeting(context, profile, hasProfile, status, theme),

                        const SizedBox(height: 32),

                        // Step-by-step progress or Error recovery card
                        if (status == SplashAuthStatus.error)
                          _buildErrorCard(context, theme)
                        else
                          _buildProgressSection(context, status, theme),
                      ],
                    );
                  }),
                ),
              ),
            ),

            // Bottom subtle branding watermark
            Positioned(
              bottom: 24,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AnymeX  •  AniList Sync',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.35),
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

  /// Ambient background radial gradients using app theme colors
  Widget _buildAmbientGlow(ColorScheme theme, Size size) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final glowRadius = 0.55 + (pulse * 0.15);
        final glowOpacity = 0.16 + (pulse * 0.08);
        final primaryColor = theme.primary;
        final secondaryColor = theme.secondary != theme.primary
            ? theme.secondary
            : theme.primary.withValues(alpha: 0.7);

        return Stack(
          children: [
            Positioned(
              top: size.height * 0.25,
              left: size.width * 0.5 - 200,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    radius: glowRadius,
                    colors: [
                      primaryColor.withValues(alpha: glowOpacity),
                      secondaryColor.withValues(alpha: glowOpacity * 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Identity header displaying circular glowing avatar or animated logo
  Widget _buildIdentityHeader(
      BuildContext context, dynamic profile, bool hasProfile, SplashAuthStatus status, ColorScheme theme) {
    final avatarUrl = profile.avatar as String?;
    final isError = status == SplashAuthStatus.error;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final glowBlur = 18.0 + (pulse * 12.0);
        final glowSpread = 2.0 + (pulse * 3.0);
        final ringColor = isError
            ? theme.error
            : theme.primary;
        final secondaryRingColor = isError
            ? theme.error.withValues(alpha: 0.5)
            : (theme.secondary != theme.primary ? theme.secondary : theme.primary.withValues(alpha: 0.7));

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer breathing glow ring
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withValues(alpha: isError ? 0.35 : 0.3 + (pulse * 0.2)),
                    blurRadius: glowBlur,
                    spreadRadius: glowSpread,
                  ),
                ],
              ),
            ),

            // Rotating subtle gradient border ring
            Transform.rotate(
              angle: _pulseController.value * math.pi * 2,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      ringColor,
                      secondaryRingColor,
                      ringColor.withValues(alpha: 0.1),
                      ringColor,
                    ],
                  ),
                ),
              ),
            ),

            // Inner dark backdrop holding avatar or logo
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFF10131C),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: hasProfile && avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: 112,
                        height: 112,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF161B26),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(22),
                          child: Image.asset(
                            'assets/images/anilist-icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(22),
                        child: Image.asset(
                          'assets/images/anilist-icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),

            // AniList badge on bottom-right of avatar - white background with theme primary border & shadow for crystal-clear visibility
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.primary,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/anilist-icon.png',
                  width: 14,
                  height: 14,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Username and welcome typography
  Widget _buildUserGreeting(
      BuildContext context, dynamic profile, bool hasProfile, SplashAuthStatus status, ColorScheme theme) {
    final userName = profile.name as String?;
    final isCompleted = status == SplashAuthStatus.completed;

    return Column(
      children: [
        Text(
          hasProfile && userName != null && userName.isNotEmpty
              ? 'Welcome back,'
              : 'Connecting to',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            hasProfile && userName != null && userName.isNotEmpty
                ? userName
                : 'AniList',
            key: ValueKey(userName ?? 'AniList'),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF00E676).withValues(alpha: 0.12)
                : theme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF00E676).withValues(alpha: 0.35)
                  : theme.primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            isCompleted
                ? 'Profile Synchronized'
                : 'AniList Synchronizing',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: isCompleted
                  ? const Color(0xFF00E676)
                  : theme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Step-by-step animated progress bar and status indicator
  Widget _buildProgressSection(BuildContext context, SplashAuthStatus status, ColorScheme theme) {
    final progress = _anilistAuth.splashProgress.value.clamp(0.0, 1.0);
    final stepMessage = _anilistAuth.splashStepMessage.value;
    final isCompleted = status == SplashAuthStatus.completed;

    IconData stepIcon;
    Color statusColor;

    if (isCompleted) {
      stepIcon = Icons.check_circle_rounded;
      statusColor = const Color(0xFF00E676);
    } else if (status == SplashAuthStatus.loadingProfile) {
      stepIcon = Icons.cloud_sync_rounded;
      statusColor = theme.secondary != theme.primary ? theme.secondary : theme.primary;
    } else {
      stepIcon = Icons.vpn_key_rounded;
      statusColor = theme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step status row with animated icon and percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      stepIcon,
                      key: ValueKey(stepIcon),
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.2),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        stepMessage,
                        key: ValueKey(stepMessage),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Gradient Linear Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 6,
            color: Colors.white.withValues(alpha: 0.08),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: progress),
              builder: (context, val, _) {
                final secondaryColor = theme.secondary != theme.primary
                    ? theme.secondary
                    : theme.primary.withValues(alpha: 0.7);

                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: val,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [
                                const Color(0xFF00E676),
                                const Color(0xFF69F0AE),
                              ]
                            : [
                                theme.primary,
                                secondaryColor,
                                theme.primary,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted
                                  ? const Color(0xFF00E676)
                                  : theme.primary)
                              .withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Glassmorphic error recovery card shown if authentication or network fails
  Widget _buildErrorCard(BuildContext context, ColorScheme theme) {
    final errorMessage = _anilistAuth.splashErrorMessage.value.isNotEmpty
        ? _anilistAuth.splashErrorMessage.value
        : 'Failed to synchronize AniList profile.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.error.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.error.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: theme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AniList Sync Failed',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.error,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Error description
          Text(
            errorMessage,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 18),

          // Interactive action buttons: Retry Login and Skip Login
          Row(
            children: [
              // Skip Login button
              Expanded(
                child: OutlinedButton(
                  onPressed: _onSkipPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Skip Login',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Retry Login button
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: _onRetryPressed,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Retry Login',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: theme.primary,
                    elevation: 4,
                    shadowColor: theme.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
