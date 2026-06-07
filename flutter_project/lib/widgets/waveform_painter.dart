import 'dart:math';
import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double playbackPosition; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;

  WaveformPainter({
    required this.amplitudes,
    required this.playbackPosition,
    this.activeColor = const Color(0xFF00F2FE), // Cyan
    this.inactiveColor = const Color(0xFF9B51E0), // Deep Purple
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final int totalBars = amplitudes.length;
    final double barSpacing = width / totalBars;
    
    final Paint activePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          activeColor,
          activeColor.withOpacity(0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintStyle.fill;

    final Paint inactivePaint = Paint()
      ..color = inactiveColor.withOpacity(0.25)
      ..style = PaintStyle.fill;

    final Paint stemPaint = Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final double midY = height / 2;

    for (int i = 0; i < totalBars; i++) {
      final double amp = amplitudes[i];
      final double barHeight = amp * height * 0.90; // scale constraint
      
      final double xPos = i * barSpacing;
      final double progressRatio = i / totalBars;
      
      final bool isActive = progressRatio <= playbackPosition;
      
      stemPaint.color = isActive ? activeColor : inactiveColor.withOpacity(0.22);
      
      final double top = midY - (barHeight / 2);
      final double bottom = midY + (barHeight / 2);

      // Draw rounded lines for high-quality audio aesthetic
      canvas.drawLine(
        Offset(xPos, top),
        Offset(xPos, bottom),
        stemPaint,
      );
    }

    // Draw Master Playhead tracking line
    final double playheadX = playbackPosition * width;
    final Paint playheadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, height),
      playheadPaint,
    );

    // Playhead glowing node
    final Paint bulbPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(Offset(playheadX, 0), 4.0, bulbPaint);
    canvas.drawCircle(Offset(playheadX, height), 4.0, bulbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class InteractiveWaveform extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Function(Duration position) onScrub;
  final int segments;

  // Cache deterministic amplitudes so waveform shape looks structured and stable
  final List<double> _waveformAmps;

  InteractiveWaveform({
    Key? key,
    required this.position,
    required this.duration,
    required this.onScrub,
    this.segments = 120,
  })  : _waveformAmps = _generateSampleWaveform(segments),
        super(key: key);

  static List<double> _generateSampleWaveform(int size) {
    // Generates a organic/structured landscape pattern utilizing math sine waves
    final Random rand = Random(42); // Seed guarantees identical waveform look
    return List.generate(size, (index) {
      double waveVal = sin(index * 0.15) * 0.35 + sin(index * 0.05) * 0.25;
      double noise = rand.nextDouble() * 0.40;
      double damp = 1.0 - (pow((index - (size / 2)) / (size / 2), 2) as double); // Edge dampening
      return (waveVal.abs() + noise).clamp(0.08, 0.95) * damp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final double localX = details.localPosition.dx;
        final double width = box.size.width;
        
        double scrubPercent = (localX / width).clamp(0.0, 1.0);
        final targetMs = (scrubPercent * duration.inMilliseconds).round();
        onScrub(Duration(milliseconds: targetMs));
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final double localX = details.localPosition.dx;
        final double width = box.size.width;
        
        double scrubPercent = (localX / width).clamp(0.0, 1.0);
        final targetMs = (scrubPercent * duration.inMilliseconds).round();
        onScrub(Duration(milliseconds: targetMs));
      },
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: WaveformPainter(
            amplitudes: _waveformAmps,
            playbackPosition: progress,
          ),
        ),
      ),
    );
  }
}
