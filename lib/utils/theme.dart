import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color.fromARGB(255, 138, 30, 30); 
  static const Color accent = Color(0xFFEF4444); 
  static const Color background = Color(0xFFF3F4F6);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF9CA3AF);
}

final InputDecoration kInputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
);