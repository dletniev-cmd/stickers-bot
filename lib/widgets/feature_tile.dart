import 'package:flutter/material.dart';
import '../theme.dart';
import 'solar_icon.dart';

class FeatureTile extends StatelessWidget {
  final String iconName;
  final Gradient gradient;
  final String title;
  final String desc;

  const FeatureTile({
    super.key,
    required this.iconName,
    required this.gradient,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: SolarIcon(iconName, size: 21, color: Colors.white),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.sub(context),
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
