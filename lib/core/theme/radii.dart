import 'package:flutter/widgets.dart';

class AppRadii {
  const AppRadii._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius card = BorderRadius.all(Radius.circular(8));
  static const BorderRadius button = BorderRadius.all(Radius.circular(8));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(24),
  );
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}
