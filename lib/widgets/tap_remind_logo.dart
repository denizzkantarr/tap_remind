import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/screen_util.dart';

class TapRemindLogo extends StatelessWidget {
  final double? size;
  final bool showText;

  const TapRemindLogo({super.key, this.size, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    final resolvedSize = size ?? su.w(40);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: resolvedSize,
          height: resolvedSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: resolvedSize,
              height: resolvedSize,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: AppColors.onPrimary,
                size: resolvedSize * 0.55,
              ),
            );
          },
        ),
        if (showText) ...[
          SizedBox(width: su.w(12)),
          Text(
            'TapRemind',
            style: TextStyle(
              fontSize: su.sp(22),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ],
    );
  }
}
