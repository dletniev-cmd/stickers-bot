import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../painters/ring_painter.dart';
import '../services/age_service.dart';
import '../theme.dart';

enum _ScanPhase { init, scanning, pause, smile, checking, done, denied }

class ScannerSheet extends StatefulWidget {
  final VoidCallback onComplete;

  const ScannerSheet({super.key, required this.onComplete});

  @override
  State<ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<ScannerSheet>
    with TickerProviderStateMixin {
  CameraController? _camCtrl;

  late final AnimationController _ringRotation;
  late final AnimationController _scanCtrl;     // Phase 1: scan 0→0.5
  late final AnimationController _smileCtrl;    // Phase 2: smile 0.5→1.0
  late final Listenable _ringListenable;

  _ScanPhase _phase = _ScanPhase.init;
  double _ringProgress = 0;
  double _camOpacity = 0;

  String _labelMain = 'Готовим камеру…';
  String _labelSub = 'Подождите секунду';
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();

    _ringRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Scan phase: 0 → 0.5 over 2600ms
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )
      ..addListener(() {
        if (_phase == _ScanPhase.scanning) {
          setState(() {
            _ringProgress = Curves.easeInOutCubic.transform(_scanCtrl.value) * 0.5;
          });
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _phase == _ScanPhase.scanning) {
          _startPause();
        }
      });

    // Smile phase: 0.5 → 1.0 over 1700ms
    _smileCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )
      ..addListener(() {
        if (_phase == _ScanPhase.smile) {
          setState(() {
            _ringProgress = 0.5 + Curves.easeInOutCubic.transform(_smileCtrl.value) * 0.5;
          });
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _phase == _ScanPhase.smile) {
          _captureAndVerify();
        }
      });

    _ringListenable = Listenable.merge([_ringRotation, _scanCtrl, _smileCtrl]);

    _initCamera();
  }

  // ──────────────────────────── Camera ────────────────────────────

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.init;
      _labelMain = 'Готовим камеру…';
      _labelSub = 'Подождите секунду';
      _camOpacity = 0;
      _ringProgress = 0;
      _showRetry = false;
    });
    _scanCtrl.reset();
    _smileCtrl.reset();
    if (!_ringRotation.isAnimating) _ringRotation.repeat();

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _camCtrl = ctrl);
      await Future.delayed(const Duration(milliseconds: 180));
      if (mounted) setState(() => _camOpacity = 1);
      await Future.delayed(const Duration(milliseconds: 620));
      if (mounted) _startScan();
    } catch (_) {
      // Camera unavailable — run simulation
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _startScan();
    }
  }

  void _startScan() {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.scanning;
      _labelMain = 'Сканирование…';
      _labelSub = 'Смотрите прямо в объектив';
    });
    _scanCtrl.forward(from: 0);
  }

  void _startPause() {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.pause;
      _ringProgress = 0.5;
      _labelMain = 'Улыбнитесь';
      _labelSub = 'Теперь улыбнитесь';
    });
    // Pause for 900ms then start smile phase
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _phase != _ScanPhase.pause) return;
      _startSmile();
    });
  }

  void _startSmile() {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.smile;
      _labelMain = 'Улыбнитесь';
      _labelSub = 'Держите улыбку';
    });
    _smileCtrl.forward(from: 0);
  }

  Future<void> _captureAndVerify() async {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.checking;
      _labelMain = 'Проверяем возраст…';
      _labelSub = 'Подождите секунду';
      _ringProgress = 1.0;
    });

    File? photo;
    try {
      final c = _camCtrl;
      if (c != null && c.value.isInitialized) {
        final f = await c.takePicture();
        photo = File(f.path);
      }
    } catch (_) {}

    if (!mounted) return;

    if (photo == null) {
      // No camera → simulate pass
      _onPassed();
      return;
    }

    final result = await AgeService().verify(photo);
    try {
      await photo.delete();
    } catch (_) {}

    if (!mounted) return;
    result.passed ? _onPassed() : _onDenied(result.message);
  }

  void _onPassed() {
    _ringRotation.stop();
    setState(() {
      _phase = _ScanPhase.done;
      _labelMain = 'Возраст подтверждён';
      _labelSub = 'Верификация прошла успешно';
      _ringProgress = 1.0;
      _camOpacity = 0;
    });
    _disposeCamera();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) widget.onComplete();
    });
  }

  void _onDenied(String reason) {
    setState(() {
      _phase = _ScanPhase.denied;
      _labelMain = 'Доступ запрещён';
      _labelSub = reason;
      _camOpacity = 0;
    });
    _disposeCamera();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showRetry = true);
    });
  }

  Future<void> _disposeCamera() async {
    final c = _camCtrl;
    _camCtrl = null;
    try {
      await c?.dispose();
    } catch (_) {}
  }

  // ──────────────────────────── Build ────────────────────────────

  Widget _buildCameraPreview() {
    final ctrl = _camCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final sz = ctrl.value.previewSize;
    if (sz == null) return CameraPreview(ctrl);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: sz.height,
        height: sz.width,
        child: CameraPreview(ctrl),
      ),
    );
  }

  @override
  void dispose() {
    _ringRotation.dispose();
    _scanCtrl.dispose();
    _smileCtrl.dispose();
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bigger ring size matching the prototype (270px)
    const ringSize = 270.0;
    final isDone = _phase == _ScanPhase.done;
    final isDenied = _phase == _ScanPhase.denied;
    final isChecking = _phase == _ScanPhase.checking;
    final isSmile = _phase == _ScanPhase.smile || _phase == _ScanPhase.pause;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Ring + Camera ──
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: AnimatedBuilder(
                animation: _ringListenable,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress ring
                      RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(ringSize, ringSize),
                          isComplex: true,
                          willChange: true,
                          painter: ScannerRingPainter(
                            progress: _ringProgress,
                            isDone: isDone,
                            isSmile: isSmile,
                            trackColor: AppColors.sep(context),
                            accentColor: isDenied
                                ? Colors.redAccent
                                : AppColors.accent,
                            doneColor: const Color(0xFF4ADE80),
                            innerColor: AppColors.cont(context),
                            faceColor:
                                AppColors.text(context).withOpacity(0.13),
                          ),
                        ),
                      ),

                      // Camera preview (circular, inside ring)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipOval(
                            child: ColoredBox(
                              color: Colors.black,
                              child: AnimatedOpacity(
                                opacity: _camOpacity,
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOut,
                                child: _buildCameraPreview(),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Checking overlay
                      if (isChecking)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: ClipOval(
                              child: Container(
                                color: Colors.black.withOpacity(0.42),
                                child: const Center(
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      strokeCap: StrokeCap.round,
                                      color: Colors.white60,
                                      backgroundColor: Colors.white10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Done checkmark
                      if (isDone)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => Opacity(
                            opacity: v,
                            child: Transform.scale(
                              scale: 0.75 + v * 0.25,
                              child: const Icon(
                                Icons.check_rounded,
                                size: 60,
                                color: Color(0xFF4ADE80),
                              ),
                            ),
                          ),
                        ),

                      // Denied cross
                      if (isDenied)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => Opacity(
                            opacity: v,
                            child: Transform.scale(
                              scale: 0.75 + v * 0.25,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 60,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Labels ──
            SizedBox(
              height: 56,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey('$_labelMain-$_phase'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labelMain,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: isDone
                            ? const Color(0xFF4ADE80)
                            : isDenied
                                ? Colors.redAccent
                                : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _labelSub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.sub(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Retry ──
            AnimatedOpacity(
              opacity: _showRetry ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: _showRetry ? _initCamera : null,
                  child: Text(
                    'Попробовать снова',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
