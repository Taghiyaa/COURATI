// lib/core/painters/educational_background_painter.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

class EducationalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Dessiner des icônes académiques subtiles
    _drawAcademicPatterns(canvas, size, paint);
  }

  void _drawAcademicPatterns(Canvas canvas, Size size, Paint paint) {
    // Motif 1: Lignes diagonales douces
    paint.color = Colors.grey.withOpacity(0.05);
    for (double i = -size.height; i < size.width + size.height; i += 60) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }

    // Motif 2: Cercles académiques
    paint.color = Colors.blue.withOpacity(0.03);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    final circles = [
      {'x': size.width * 0.1, 'y': size.height * 0.2, 'r': 50.0},
      {'x': size.width * 0.85, 'y': size.height * 0.15, 'r': 40.0},
      {'x': size.width * 0.15, 'y': size.height * 0.7, 'r': 45.0},
      {'x': size.width * 0.9, 'y': size.height * 0.8, 'r': 35.0},
    ];

    for (var circle in circles) {
      canvas.drawCircle(
        Offset(circle['x']! as double, circle['y']! as double),
        circle['r']! as double,
        paint,
      );
      
      // Cercle concentrique
      canvas.drawCircle(
        Offset(circle['x']! as double, circle['y']! as double),
        (circle['r']! as double) * 1.5,
        paint..color = Colors.green.withOpacity(0.02),
      );
    }

    // Motif 3: Formes géométriques
    paint.color = Colors.orange.withOpacity(0.03);
    paint.style = PaintingStyle.fill;

    // Triangles
    final path1 = Path()
      ..moveTo(size.width * 0.9, size.height * 0.3)
      ..lineTo(size.width * 0.95, size.height * 0.35)
      ..lineTo(size.width * 0.92, size.height * 0.38)
      ..close();
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.5)
      ..lineTo(size.width * 0.1, size.height * 0.55)
      ..lineTo(size.width * 0.07, size.height * 0.58)
      ..close();
    canvas.drawPath(path2, paint);

    // Motif 4: Points académiques
    paint.color = Colors.purple.withOpacity(0.04);
    paint.style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 2 + random.nextDouble() * 3;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}