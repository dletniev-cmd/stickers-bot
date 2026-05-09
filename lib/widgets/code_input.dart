import 'package:flutter/material.dart';
import '../theme.dart';

class CodeInput extends StatelessWidget {
  final List<String> code;
  final String codeState; // input, accepted, rejected
  final int length;

  const CodeInput({
    super.key,
    required this.code,
    required this.codeState,
    required this.length,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final hasValue = i < code.length;
        final isCurrent = i == code.length && code.length < length;

        Color borderColor;
        if (codeState == 'accepted') {
          borderColor = AppColors.accent;
        } else if (codeState == 'rejected') {
          borderColor = AppColors.accent.withOpacity(0.18);
        } else if (isCurrent) {
          borderColor = AppColors.accent;
        } else {
          borderColor = AppColors.boxBorder(context);
        }

        Color textColor;
        if (codeState == 'rejected') {
          textColor = Colors.transparent;
        } else {
          textColor = AppColors.text(context);
        }

        return Padding(
          padding: EdgeInsets.only(right: i < length - 1 ? 9 : 0),
          child: AnimatedContainer(
            duration: Duration(milliseconds: codeState == 'accepted' ? 400 : 320),
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 320),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                child: Text(hasValue ? code[i] : ''),
              ),
            ),
          ),
        );
      }),
    );
  }
}
