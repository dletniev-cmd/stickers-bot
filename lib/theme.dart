import 'package:flutter/material.dart';

class AppColors {
  static const Color accent = Color(0xFF8774E1);
  
  // Light
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightCont = Color(0xFFF2F2F7);
  static const Color lightText = Color(0xFF000000);
  static const Color lightSub = Color(0xFF6D6D72);
  static const Color lightKeyBg = Color(0xFFE9E9EF);
  static Color lightBoxBorder = const Color(0xFF787882).withOpacity(0.22);
  static Color lightSep = const Color(0xFF787882).withOpacity(0.13);
  static const Color lightDisabled = Color(0xFFB0B0B6);

  // Dark
  static const Color darkBg = Color(0xFF000000);
  static const Color darkCont = Color(0xFF1C1C1E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSub = Color(0xFF8E8E93);
  static const Color darkKeyBg = Color(0xFF2C2C2E);
  static Color darkBoxBorder = const Color(0xFF9696A0).withOpacity(0.18);
  static Color darkSep = const Color(0xFF9696A0).withOpacity(0.11);
  static const Color darkDisabled = Color(0xFF48484A);

  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;
  static Color cont(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCont : lightCont;
  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : lightText;
  static Color sub(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSub : lightSub;
  static Color keyBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkKeyBg : lightKeyBg;
  static Color boxBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBoxBorder : lightBoxBorder;
  static Color sep(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSep : lightSep;
  static Color disabled(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDisabled : lightDisabled;
}
