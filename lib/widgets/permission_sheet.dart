import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import 'solar_icon.dart';

class PermissionSheet extends StatefulWidget {
  final VoidCallback onAllow;

  const PermissionSheet({super.key, required this.onAllow});

  @override
  State<PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<PermissionSheet> {
  bool _requesting = false;

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    final status = await Permission.camera.request();

    if (!mounted) return;
    setState(() => _requesting = false);

    if (status.isGranted) {
      widget.onAllow();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SolarIcon(SolarIcons.camera, size: 72, color: AppColors.accent),
            const SizedBox(height: 28),
            Text(
              'Доступ к камере',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Для сканирования лица приложению\nнеобходим доступ к вашей камере',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.sub(context),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 36),
            _permFeature(
              context,
              iconName: SolarIcons.shieldCheck,
              gradient: const [Color(0xFF30D158), Color(0xFF25A244)],
              title: 'Безопасно',
              subtitle: 'Видео не записывается и не сохраняется',
            ),
            const SizedBox(height: 16),
            _permFeature(
              context,
              iconName: SolarIcons.eye,
              gradient: const [Color(0xFF3B9EFF), Color(0xFF0A7EFF)],
              title: 'Только на устройстве',
              subtitle: 'Обработка происходит локально',
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _requestPermission,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _requesting
                        ? AppColors.accent.withOpacity(0.7)
                        : AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _requesting
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Разрешить камеру',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
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

  Widget _permFeature(
    BuildContext context, {
    required String iconName,
    required List<Color> gradient,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SolarIcon(iconName, size: 20, color: Colors.white),
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
                  fontSize: 13.5,
                  color: AppColors.text(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.sub(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
