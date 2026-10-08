import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_strings.dart';
import '../models/shareable_run.dart';
import '../services/run_card_export_result.dart';
import '../services/share_card_export_service.dart';
import '../utils/duration_format.dart';

class ShareableRunCard extends StatefulWidget {
  const ShareableRunCard({
    required this.run,
    super.key,
  });

  final ShareableRun run;

  @override
  State<ShareableRunCard> createState() => _ShareableRunCardState();
}

class _ShareableRunCardState extends State<ShareableRunCard> {
  final _cardKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _exportCard() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      final renderObject = _cardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('The run card is not ready to export.');
      }

      final image = await renderObject.toImage(pixelRatio: 3);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw Exception('The run card image could not be created.');
        }
        final result = await exportRunCard(
          pngBytes: byteData.buffer.asUint8List(),
          fileName: 'runcoach-run-'
              '${widget.run.date.toLocal().toIso8601String().split('T').first}.png',
          shareText:
              'My ${widget.run.distanceKm.toStringAsFixed(1)} km run with RunCoach AI.',
        );
        if (mounted) {
          final message = switch (result) {
            RunCardExportResult.shared => AppStrings.of(context).cardShared,
            RunCardExportResult.downloaded =>
              AppStrings.of(context).cardDownloaded,
            RunCardExportResult.dismissed =>
              AppStrings.of(context).sharingCancelled,
            RunCardExportResult.shareStatusUnavailable =>
              AppStrings.of(context).shareResultUnknown,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } finally {
        image.dispose();
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.of(context).exportFailed}: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: _RunCardArtwork(run: widget.run),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isExporting ? null : _exportCard,
              icon: _isExporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(
                _isExporting
                    ? strings.preparingCard
                    : kIsWeb
                        ? strings.downloadRunCard
                        : strings.shareRunCard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunCardArtwork extends StatelessWidget {
  const _RunCardArtwork({required this.run});

  final ShareableRun run;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(run.date.toLocal());

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF133B2B),
              Color(0xFF0B211A),
              Color(0xFF071510),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7F36A),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      color: Color(0xFF143523),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'RUNCOACH AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Text(
                    dateLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFB3C7BA),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                run.distanceKm.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                strings.kilometersOfProgress,
                style: const TextStyle(
                  color: Color(0xFFD7F36A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                height: 108,
                width: double.infinity,
                key: ValueKey('share-card-route-graphic'),
                child: CustomPaint(painter: _RoutePainter()),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _RunMetric(
                      label: strings.pace.toUpperCase(),
                      value: '${run.pace} /km',
                    ),
                  ),
                  Expanded(
                    child: _RunMetric(
                      label: strings.duration.toUpperCase(),
                      value: formatRunDuration(run.timeSeconds),
                    ),
                  ),
                  Expanded(
                    child: _RunMetric(
                      label: strings.calories,
                      value: '${run.estimatedCalories} kcal*',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withAlpha(24)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFD7F36A),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        run.coachComment,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.calorieDisclaimer,
                style: const TextStyle(
                  color: Color(0xFF91A69A),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunMetric extends StatelessWidget {
  const _RunMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF91A69A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(16)
      ..strokeWidth = 1;
    final routePaint = Paint()
      ..color = const Color(0xFFD7F36A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final routePath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.72)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.62,
        size.width * 0.23,
        size.height * 0.22,
        size.width * 0.43,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.48,
        size.width * 0.68,
        size.height * 0.8,
        size.width * 0.88,
        size.height * 0.25,
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(18),
      ),
      backgroundPaint,
    );
    for (var index = 1; index < 5; index++) {
      final x = size.width * index / 5;
      canvas.drawLine(Offset(x, 8), Offset(x, size.height - 8), gridPaint);
    }
    for (var index = 1; index < 3; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), gridPaint);
    }
    canvas.drawPath(routePath, routePaint);

    final markerPaint = Paint()..color = const Color(0xFFD7F36A);
    final start = Offset(size.width * 0.08, size.height * 0.72);
    final finish = Offset(size.width * 0.88, size.height * 0.25);
    for (final point in [start, finish]) {
      canvas.drawCircle(point, 7, markerPaint);
      canvas.drawCircle(
        point,
        3,
        Paint()..color = const Color(0xFF133B2B),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => false;
}
