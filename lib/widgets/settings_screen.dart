import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'solar_icon.dart';

class SettingsScreen extends StatelessWidget {
  final double topPadding;
  final double bottomPadding;
  final bool isDark;
  final bool notificationsEnabled;
  final VoidCallback onBack;
  final VoidCallback onToggleTheme;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<Color> onAccentChanged;

  const SettingsScreen({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.isDark,
    required this.notificationsEnabled,
    required this.onBack,
    required this.onToggleTheme,
    required this.onNotificationsChanged,
    required this.onAccentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: AppColors.bg(context),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPadding + 12, left: 14, right: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeaderButton(
                  onTap: onBack,
                  child: Icon(Icons.chevron_left, size: 28, color: AppColors.accent),
                ),
                _HeaderButton(
                  onTap: onToggleTheme,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
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
                      isDark ? SolarIcons.sun2 : SolarIcons.moon,
                      key: ValueKey(isDark),
                      size: 24,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding + 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Настройте акцентный цвет и поведение интерфейса под себя.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: AppColors.sub(context),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionCard(
                    context: context,
                    title: 'Акцентный цвет',
                    subtitle: '12 мягких оттенков, равномерно разложенных по палитре.',
                    child: _AccentPalettePicker(
                      colors: AppColors.accentPalette,
                      selectedColor: AppColors.accent,
                      onChanged: onAccentChanged,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    context: context,
                    title: 'Уведомления',
                    subtitle: 'Включите push-уведомления, чтобы не пропускать важные события.',
                    child: _NotificationCard(
                      enabled: notificationsEnabled,
                      onChanged: onNotificationsChanged,
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
}

class _HeaderButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HeaderButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
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

class _SectionCard extends StatelessWidget {
  final BuildContext context;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.context,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext _) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cont(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.sub(context),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg(context).withOpacity(0.26),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B7A), Color(0xFFFF4F66)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Уведомления',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enabled ? 'Уведомления включены' : 'Уведомления выключены',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.sub(context),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _NotificationSwitch(enabled: enabled),
          ],
        ),
      ),
    );
  }
}

class _NotificationSwitch extends StatelessWidget {
  final bool enabled;

  const _NotificationSwitch({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 62,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: enabled ? AppColors.accent.withOpacity(0.75) : AppColors.sep(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _AccentPalettePicker extends StatefulWidget {
  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  const _AccentPalettePicker({
    required this.colors,
    required this.selectedColor,
    required this.onChanged,
  });

  @override
  State<_AccentPalettePicker> createState() => _AccentPalettePickerState();
}

class _AccentPalettePickerState extends State<_AccentPalettePicker> {
  late final List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.colors.length, (_) => GlobalKey());
  }

  void _selectNearest(Offset globalPosition) {
    var bestIndex = -1;
    var bestDistance = double.infinity;

    for (var i = 0; i < _itemKeys.length; i++) {
      final itemContext = _itemKeys[i].currentContext;
      if (itemContext == null) continue;
      final renderObject = itemContext.findRenderObject();
      if (renderObject is! RenderBox) continue;

      final center = renderObject.localToGlobal(renderObject.size.center(Offset.zero));
      final distance = (center - globalPosition).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    if (bestIndex == -1 || bestDistance > 42) return;
    final selected = widget.colors[bestIndex];
    if (selected.value == widget.selectedColor.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) => _selectNearest(details.globalPosition),
      onPanUpdate: (details) => _selectNearest(details.globalPosition),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(widget.colors.length, (index) {
          final color = widget.colors[index];
          final selected = color.value == widget.selectedColor.value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onChanged(color);
            },
            child: SizedBox(
              key: _itemKeys[index],
              width: 60,
              height: 60,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? color.withOpacity(0.95) : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.24),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: selected ? 0.82 : 1,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
