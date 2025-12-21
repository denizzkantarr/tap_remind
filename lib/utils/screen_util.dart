import 'dart:math';
import 'package:flutter/widgets.dart';

class ScreenUtil {
  ScreenUtil._(
    this.size,
    this.padding, {
    this.designWidth = 390,
    this.designHeight = 844,
  });

  factory ScreenUtil.of(
    BuildContext context, {
    double designWidth = 390,
    double designHeight = 844,
  }) {
    final mediaQuery = MediaQuery.of(context);
    return ScreenUtil._(
      mediaQuery.size,
      mediaQuery.padding,
      designWidth: designWidth,
      designHeight: designHeight,
    );
  }

  final Size size;
  final EdgeInsets padding;
  final double designWidth;
  final double designHeight;

  double get width => size.width;
  double get height => size.height;
  double get safeTop => padding.top;
  double get safeBottom => padding.bottom;
  bool get isTablet => size.shortestSide >= 600;

  double get _widthScale => width / designWidth;
  double get _heightScale => height / designHeight;
  double get _textScale => min(_widthScale, _heightScale);

  double w(double value) => value * _widthScale;
  double h(double value) => value * _heightScale;
  double sp(double value) => value * _textScale;
  double r(double value) => value * _textScale;

  EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(
      horizontal: w(horizontal),
      vertical: h(vertical),
    );
  }

  EdgeInsets all(double value) => EdgeInsets.all(r(value));

  EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: w(left),
      top: h(top),
      right: w(right),
      bottom: h(bottom),
    );
  }
}

