import 'package:flutter/widgets.dart';

class AppRadii {
  const AppRadii._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;

  static const BorderRadius card = BorderRadius.all(Radius.circular(20));
  static const BorderRadius button = BorderRadius.all(Radius.circular(16));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(32),
  );
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}
