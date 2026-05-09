import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/feature_tile.dart';
import '../widgets/code_input.dart';
import '../widgets/custom_keyboard.dart';
import '../widgets/scanner_sheet.dart';
import '../widgets/faq_sheet.dart';
import '../widgets/permission_sheet.dart';
import '../widgets/solar_icon.dart';
import '../widgets/telegram_icon.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Code input
  final String _correctCode = '12345';
  List<String> _code = [];
  bool _busy = false;
  String _codeState = 'input'; // input, accepted, rejected

  // Verification state
  bool _cameraGranted = false;
  bool _faceScanned = false;
  bool _verified = false;

  // Bottom sheet
  bool _sheetVisible = false;
  String _sheetContent = ''; // perm, scan, faq

  // ── Sheet position controller ────────────────────────────────────
  // A single unbounded controller drives the sheet's vertical translation.
  //   value == 0           → fully open (sits at the top of its slot)
  //   value == _sheetHeight → fully closed (slid off-screen, below the viewport)
  //
  // Both opening and closing are driven by SpringSimulation, so the motion
  // feels organic instead of a rigidly-eased linear ramp. Drag updates write
  // straight into the controller, so there is never a discontinuity between
  // gesture and animation.
  late AnimationController _sheetPosCtrl;
  double _sheetHeight = 0.0;

  static const SpringDescription _openSpring = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 26, // critically-damped feel with a hint of softness
  );
  static const SpringDescription _closeSpring = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 30,
  );
  static const SpringDescription _settleSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 24,
  );

  // Glint animation for button
  late AnimationController _glintController;

  // Shimmer for "face++"
  late AnimationController _shimmerController;

  // Splash screen
  bool _showSplash = true;
  late AnimationController _splashBadgeCtrl;
  late AnimationController _splashMoveCtrl;
  late AnimationController _splashContentCtrl;
  late AnimationController _splashPulseCtrl;

  @override
  void initState() {
    super.initState();

    _sheetPosCtrl = AnimationController.unbounded(
      vsync: this,
      value: 0,
    );

    _glintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Splash animations
    _splashBadgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _splashMoveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _splashContentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _splashPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _startSplash();
  }

  Future<void> _startSplash() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    // Badge fades in
    _splashBadgeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    // Slide out — same curve as page transitions
    _splashMoveCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 560));
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sheetPosCtrl.dispose();
    _glintController.dispose();
    _shimmerController.dispose();
    _splashBadgeCtrl.dispose();
    _splashMoveCtrl.dispose();
    _splashPulseCtrl.dispose();
    _splashContentCtrl.dispose();
    super.dispose();
  }

  void _updateStatusBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  void _toggleTheme() {
    final current = AgeVerifyApp.themeNotifier.value;
    if (current == ThemeMode.system) {
      final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
      AgeVerifyApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    } else if (current == ThemeMode.dark) {
      AgeVerifyApp.themeNotifier.value = ThemeMode.light;
    } else {
      AgeVerifyApp.themeNotifier.value = ThemeMode.dark;
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 520),
      curve: const Cubic(.65, 0, .35, 1),
    );
    setState(() => _currentPage = page);
  }

  // Code input
  void _onKeyPress(String digit) {
    if (_busy || _code.length >= 5) return;
    HapticFeedback.lightImpact();
    setState(() {
      _code.add(digit);
      _codeState = 'input';
    });
    if (_code.length == 5) {
      _busy = true;
      Future.delayed(const Duration(milliseconds: 580), _checkCode);
    }
  }

  void _onBackspace() {
    if (_busy || _code.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _code.removeLast();
      _codeState = 'input';
    });
  }

  void _checkCode() {
    final entered = _code.join();
    if (entered == _correctCode) {
      setState(() => _codeState = 'accepted');
      Future.delayed(const Duration(milliseconds: 600), () {
        _goToPage(2);
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _codeState = 'rejected');
      Future.delayed(const Duration(milliseconds: 480), () {
        setState(() {
          _code.clear();
          _codeState = 'input';
          _busy = false;
        });
      });
    }
  }

  // Sheet
  void _showSheet(String content) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;
    _sheetHeight = sheetHeight;
    // Position the sheet just below the screen before it becomes visible,
    // so the first frame doesn't flash at the open position.
    _sheetPosCtrl.stop();
    _sheetPosCtrl.value = sheetHeight;

    setState(() {
      _sheetContent = content;
      _sheetVisible = true;
    });

    // Defer the animation until the heavy sheet contents (camera init in
    // ScannerSheet, etc.) have finished their first build/layout pass. Without
    // this, the open animation competes with first-frame work and visibly lags.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetVisible) return;
      _sheetPosCtrl.animateWith(
        SpringSimulation(_openSpring, sheetHeight, 0, 0),
      );
    });
  }

  void _closeSheet({double velocity = 0}) {
    if (_sheetHeight <= 0) {
      _sheetHeight = MediaQuery.of(context).size.height * 0.72;
    }
    _sheetPosCtrl.stop();
    final target = _sheetHeight;
    _sheetPosCtrl
        .animateWith(
      SpringSimulation(_closeSpring, _sheetPosCtrl.value, target, velocity),
    )
        .whenComplete(() {
      if (!mounted) return;
      // If the controller was preempted (e.g. user re-opened the sheet
      // while the close spring was still settling), the value won't be at
      // the closed target — in that case do not hide.
      if (_sheetPosCtrl.value < target - 0.5) return;
      setState(() {
        _sheetVisible = false;
        _sheetContent = '';
      });
      _sheetPosCtrl.value = 0;
    });
  }

  void _openScanner() {
    if (_faceScanned) return;
    if (!_cameraGranted) {
      _showSheet('perm');
    } else {
      _showSheet('scan');
    }
  }

  void _grantCamera() {
    _cameraGranted = true;
    setState(() => _sheetContent = 'scan');
  }

  void _onScanComplete() {
    setState(() {
      _faceScanned = true;
      _verified = true;
    });
    Future.delayed(const Duration(milliseconds: 800), _closeSheet);
  }

  void _openFaq() {
    _showSheet('faq');
  }

  void _openTelegram() {
    if (!_verified) return;
    launchUrl(Uri.parse('https://t.me/'), mode: LaunchMode.externalApplication);
  }

  // Open progress in [0, 1]: 0 == off-screen, 1 == fully open. Used for
  // backdrop opacity so it tracks both the spring animation and live drag.
  double get _sheetProgress {
    if (_sheetHeight <= 0) return 0;
    return (1.0 - (_sheetPosCtrl.value / _sheetHeight)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    _updateStatusBar();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          // Main content — slide-in from right during splash exit (same as page transition)
          AnimatedBuilder(
            animation: _splashMoveCtrl,
            builder: (context, child) {
              if (!_showSplash) return child!;
              final slideVal = CurvedAnimation(
                parent: _splashMoveCtrl,
                curve: const Cubic(0.65, 0, 0.35, 1),
              ).value;
              return Transform.translate(
                offset: Offset(
                  MediaQuery.of(context).size.width * (1.0 - slideVal),
                  0,
                ),
                child: child!,
              );
            },
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildScreen1(topPadding, bottomPadding),
                _buildScreen2(topPadding, bottomPadding),
                _buildScreen3(topPadding, bottomPadding),
              ],
            ),
          ),

          // Backdrop
          if (_sheetVisible)
            AnimatedBuilder(
              animation: _sheetPosCtrl,
              builder: (context, _) {
                final opacity = (0.45 * _sheetProgress).clamp(0.0, 1.0);
                return GestureDetector(
                  onTap: () => _closeSheet(),
                  child: Container(
                    color: Colors.black.withOpacity(opacity),
                  ),
                );
              },
            ),

          // Bottom sheet
          if (_sheetVisible)
            _buildBottomSheet(bottomPadding),

          // Splash screen overlay
          if (_showSplash)
            _buildSplashScreen(),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(double bottomPadding) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.72;
    _sheetHeight = sheetHeight;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: sheetHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) {
          _sheetPosCtrl.stop();
        },
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta ?? 0;
          // Only allow dragging down past the open position.
          if (delta > 0 || _sheetPosCtrl.value > 0) {
            _sheetPosCtrl.value =
                (_sheetPosCtrl.value + delta).clamp(0.0, sheetHeight);
          }
        },
        onVerticalDragEnd: (details) {
          final vel = details.velocity.pixelsPerSecond.dy;
          // Either dragged past the threshold OR flicked downward → close.
          if (_sheetPosCtrl.value > sheetHeight * 0.15 || vel > 600) {
            _closeSheet(velocity: vel);
          } else {
            // Snap back to fully open with a soft spring; gesture velocity is
            // fed in so the motion continues naturally from the user's flick.
            _sheetPosCtrl.animateWith(
              SpringSimulation(_settleSpring, _sheetPosCtrl.value, 0, vel),
            );
          }
        },
        child: AnimatedBuilder(
          animation: _sheetPosCtrl,
          // ↓ child is built ONCE — won't rebuild every animation frame
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cont(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.sep(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(child: _buildSheetContent()),
                ],
              ),
            ),
          ),
          builder: (context, child) {
            // Spring drives translation directly: smooth, organic motion with
            // no discontinuity between drag and animation (drag writes the
            // same controller the spring reads from).
            return Transform.translate(
              offset: Offset(0, _sheetPosCtrl.value),
              child: child!,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    switch (_sheetContent) {
      case 'perm':
        return PermissionSheet(onAllow: _grantCamera);
      case 'scan':
        return ScannerSheet(onComplete: _onScanComplete);
      case 'faq':
        return const FaqSheet();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══ SPLASH SCREEN ═══
  Widget _buildSplashScreen() {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: Listenable.merge([_splashBadgeCtrl, _splashMoveCtrl, _splashPulseCtrl]),
      builder: (context, _) {
        final badgeVal = CurvedAnimation(
          parent: _splashBadgeCtrl,
          curve: Curves.easeOut,
        ).value;

        // Slide off to the left — same Cubic curve as page transitions
        final slideVal = CurvedAnimation(
          parent: _splashMoveCtrl,
          curve: const Cubic(0.65, 0, 0.35, 1),
        ).value;

        final pulseVal = CurvedAnimation(
          parent: _splashPulseCtrl,
          curve: Curves.easeInOut,
        ).value;

        final opacity = badgeVal.clamp(0.0, 1.0);
        // Gentle pulse: scale between 1.0 and 1.06
        final pulseScale = 1.0 + pulseVal * 0.06;

        return IgnorePointer(
          child: Transform.translate(
            offset: Offset(-screenWidth * slideVal, 0),
            child: Container(
              color: AppColors.bg(context),
              child: Center(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: pulseScale,
                    child: SolarIcon(SolarIcons.verifiedCheck, size: 96, color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══ SCREEN 1 ═══
  Widget _buildScreen1(double topPadding, double bottomPadding) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: AppColors.bg(context),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(top: topPadding + 12, left: 14, right: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 36),
                _themeButton(),
              ],
            ),
          ),

          // Hero
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
            child: Column(
              children: [
                SolarIcon(SolarIcons.verifiedCheck, size: 96, color: AppColors.accent),
                const SizedBox(height: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                    color: AppColors.text(context),
                  ),
                  child: const Text('Verify Age'),
                ),
                const SizedBox(height: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.sub(context),
                    height: 1.55,
                  ),
                  child: const Text(
                    'Бесплатное и безопасное приложение\nдля подтверждения возраста',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Features
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: AppColors.cont(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  FeatureTile(
                    iconName: SolarIcons.lockKeyhole,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF30D158), Color(0xFF25A244)],
                    ),
                    title: 'Безопасно',
                    desc: 'Мы не собираем данные — всё остаётся только на вашем устройстве',
                  ),
                  Divider(height: 1, thickness: 1, color: AppColors.sep(context), indent: 66),
                  FeatureTile(
                    iconName: SolarIcons.bolt,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B9EFF), Color(0xFF0A7EFF)],
                    ),
                    title: 'Быстро',
                    desc: 'Верификация занимает около 10 секунд',
                  ),
                  Divider(height: 1, thickness: 1, color: AppColors.sep(context), indent: 66),
                  FeatureTile(
                    iconName: SolarIcons.userCheckRounded,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFB340), Color(0xFFF07800)],
                    ),
                    title: '14+',
                    desc: 'Верификация доступна только с 14 лет',
                  ),
                ],
              ),
            ),
          ),

          const Spacer(flex: 2),

          // Bottom
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding + 28),
            child: Column(
              children: [
                // "при поддержке face++"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'при поддержке ',
                      style: TextStyle(fontSize: 12, color: AppColors.sub(context)),
                    ),
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                AppColors.accent,
                                Color(0xFFB8AAEF),
                                AppColors.accent,
                              ],
                              stops: [
                                0.0,
                                _shimmerController.value,
                                1.0,
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'face++',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Start button with glint
                SizedBox(
                  width: double.infinity,
                  child: _AccentButton(
                    text: 'Начать',
                    onTap: () => _goToPage(1),
                    glintController: _glintController,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ SCREEN 2 ═══
  Widget _buildScreen2(double topPadding, double bottomPadding) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: AppColors.bg(context),
      child: Column(
        children: [
          // Header with back button
          Padding(
            padding: EdgeInsets.only(top: topPadding + 12, left: 14, right: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _headerButton(
                  onTap: () {
                    if (!_busy) {
                      _goToPage(0);
                      setState(() {
                        _code.clear();
                        _codeState = 'input';
                        _busy = false;
                      });
                    }
                  },
                  child: Icon(Icons.chevron_left, size: 28, color: AppColors.accent),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 24, right: 24),
            child: Column(
              children: [
                SolarIcon(SolarIcons.chatRoundDots, size: 78, color: AppColors.accent),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.2,
                    color: AppColors.text(context),
                  ),
                  child: const Text('Введите код'),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.sub(context),
                    height: 1.5,
                  ),
                  child: const Text(
                    'Код можно найти в боте,\nон состоит из 5 цифр',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Code boxes
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: CodeInput(
              code: _code,
              codeState: _codeState,
              length: 5,
            ),
          ),

          const Spacer(),

          // Keyboard
          Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: bottomPadding + 20),
            child: CustomKeyboard(
              onKeyPress: _onKeyPress,
              onBackspace: _onBackspace,
            ),
          ),
        ],
      ),
    );
  }

  // ═══ SCREEN 3 ═══
  Widget _buildScreen3(double topPadding, double bottomPadding) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: AppColors.bg(context),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(top: topPadding + 12, left: 14, right: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 36),
                _themeButton(),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        SolarIcon(SolarIcons.verifiedCheck, size: 68, color: AppColors.accent),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            height: 1.2,
                            color: AppColors.text(context),
                          ),
                          child: const Text('Верификация'),
                        ),
                        const SizedBox(height: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.sub(context),
                            height: 1.5,
                          ),
                          child: const Text(
                            'Подтвердите возраст, чтобы получить доступ',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // FAQ card
                  _s3Card(
                    iconName: SolarIcons.questionCircle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8774E1), Color(0xFF6C5CE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    title: 'Что такое Verify Age?',
                    desc: 'Узнайте как работает верификация и зачем она нужна',
                    trailing: Icon(Icons.chevron_right, size: 18, color: AppColors.sub(context).withOpacity(0.5)),
                    onTap: _openFaq,
                  ),
                  const SizedBox(height: 12),
                  // Scan card
                  _s3Card(
                    iconName: SolarIcons.faceScanCircle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B9EFF), Color(0xFF0A7EFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    title: 'Посмотрите в камеру',
                    desc: 'Для подтверждения возраста, необходимо посмотреть в камеру и улыбнуться — займёт примерно 10 секунд',
                    trailing: _faceScanned
                        ? SolarIcon(SolarIcons.checkCircle, size: 22, color: const Color(0xFF4ADE80))
                        : Icon(Icons.chevron_right, size: 18, color: AppColors.sub(context).withOpacity(0.5)),
                    onTap: _faceScanned ? null : _openScanner,
                  ),

                  const Spacer(),

                  // Hint
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.sub(context),
                      height: 1.5,
                    ),
                    child: const Text(
                      'После подтверждения возраста,\nнажмите на кнопку и перейдите в бота',
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // TG button — sized to its content so it doesn't span the
                  // full screen width.
                  Padding(
                    padding: EdgeInsets.only(top: 10, bottom: bottomPadding + 28),
                    child: Center(
                      child: GestureDetector(
                        onTap: _openTelegram,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 26),
                          decoration: BoxDecoration(
                            color: _verified ? AppColors.accent : AppColors.disabled(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TelegramIcon(size: 20, color: _verified ? Colors.white : Colors.white.withOpacity(0.6)),
                              const SizedBox(width: 9),
                              Text(
                                'Перейти в бота',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                  color: _verified ? Colors.white : Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _s3Card({
    required String iconName,
    required Gradient gradient,
    required String title,
    required String desc,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.cont(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: SolarIcon(iconName, size: 24, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.sub(context),
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeButton() {
    return _headerButton(
      onTap: _toggleTheme,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) {
          return ScaleTransition(
            scale: anim,
            child: RotationTransition(
              turns: Tween(begin: 0.25, end: 0.0).animate(anim),
              child: child,
            ),
          );
        },
        child: SolarIcon(
          _isDark ? SolarIcons.sun2 : SolarIcons.moon,
          key: ValueKey(_isDark),
          size: 24,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _headerButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(child: child),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final AnimationController glintController;

  const _AccentButton({
    required this.text,
    required this.onTap,
    required this.glintController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            // Glint effect
            Positioned.fill(
              child: AnimatedBuilder(
                animation: glintController,
                builder: (context, _) {
                  final value = glintController.value;
                  if (value > 0.45) return const SizedBox.shrink();
                  final pos = value / 0.45;
                  return Transform.translate(
                    offset: Offset((pos * 2 - 0.5) * MediaQuery.of(context).size.width, 0),
                    child: Transform(
                      transform: Matrix4.skewX(-0.26),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.22),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
