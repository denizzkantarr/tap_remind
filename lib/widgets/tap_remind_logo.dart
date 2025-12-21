import 'package:flutter/material.dart';
import '../utils/screen_util.dart';

class TapRemindLogo extends StatelessWidget {
  final double? size;
  final bool showText;

  const TapRemindLogo({
    super.key,
    this.size,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    final resolvedSize = size ?? su.w(40);
    final gap = su.w(12);
    final textSize = su.sp(24);
    final fallbackRadius = su.r(12);
    final fallbackIconSize = su.sp(24);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo image
        Image.asset(
          'assets/images/logo.png',
          width: resolvedSize,
          height: resolvedSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image is not found
            return Container(
              width: resolvedSize,
              height: resolvedSize,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(fallbackRadius),
              ),
              child: Icon(
                Icons.notifications,
                color: Colors.white,
                size: fallbackIconSize,
              ),
            );
          },
        ),
        if (showText) ...[
          SizedBox(width: gap),
          // Text
          Text(
            'TapRemind',
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}

