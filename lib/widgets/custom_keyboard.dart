import 'package:flutter/material.dart';
import '../theme.dart';
import 'solar_icon.dart';

class CustomKeyboard extends StatelessWidget {
  final Function(String) onKeyPress;
  final VoidCallback onBackspace;

  const CustomKeyboard({
    super.key,
    required this.onKeyPress,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            children: List.generate(row.length * 2 - 1, (i) {
              if (i.isOdd) return const SizedBox(width: 7);
              final key = row[i ~/ 2];
              if (key.isEmpty) {
                return Expanded(child: SizedBox(height: 46));
              }
              if (key == 'back') {
                return Expanded(
                  child: _KeyButton(
                    onTap: onBackspace,
                    child: SolarIcon(SolarIcons.backspace, size: 22, color: AppColors.text(context)),
                  ),
                );
              }
              return Expanded(
                child: _KeyButton(
                  onTap: () => onKeyPress(key),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text(context),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeyButton({required this.onTap, required this.child});

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.keyBg(context),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
