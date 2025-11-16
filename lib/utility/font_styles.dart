import 'package:flutter/material.dart';

TextStyle headingStyle({Color? color}) {
  return TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: color ?? Colors.black,
  );
}

TextStyle hintStyle({Color? color}) {
  return TextStyle(
    color: color ?? Colors.black38,
  );
}

TextStyle titleStyle() {
  return const TextStyle(
      color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500);
}
