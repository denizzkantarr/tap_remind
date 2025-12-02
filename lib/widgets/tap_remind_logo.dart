import 'package:flutter/material.dart';

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
    const iconSize = 40.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo image
        Image.asset(
          'assets/images/logo.png',
          width: size ?? iconSize,
          height: size ?? iconSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image is not found
            return Container(
              width: size ?? iconSize,
              height: size ?? iconSize,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 24,
              ),
            );
          },
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          // Text
          const Text(
            'TapRemind',
            style: TextStyle(
              fontSize: 24,
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

