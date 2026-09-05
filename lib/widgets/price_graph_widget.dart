import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/news_model.dart';
import '../services/price_alert_service.dart';
import '../services/theme_service.dart';
import 'set_price_alert_dialog.dart';

class PriceGraphWidget extends StatelessWidget {
  final NewsModel news;

  const PriceGraphWidget({super.key, required this.news});

  Color get cardDark => ThemeService.card;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  Widget build(BuildContext context) {
    final history = news.effectivePriceHistory;
    final currPrice = news.displayCurrentPrice ?? 2999.0;
    final origPrice = news.displayOriginalPrice ?? (currPrice * 1.35);
    final discountPercent = origPrice > currPrice
        ? (((origPrice - currPrice) / origPrice) * 100).round()
        : 0;

    double lowestPrice = currPrice;
    for (final pt in history) {
      final p = (pt['price'] as num?)?.toDouble() ?? currPrice;
      if (p < lowestPrice) lowestPrice = p;
    }

    final store = news.displayStore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonGreen.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: neonGreen.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: neonGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: neonGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_down_rounded, color: neonGreen, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'PRICE TRACKER',
                        style: TextStyle(
                          color: neonGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2838),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF66C0F4).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        store.toLowerCase().contains('ps')
                            ? Icons.gamepad_rounded
                            : Icons.cloud_download_rounded,
                        color: store.toLowerCase().contains('ps')
                            ? const Color(0xFF0070D1)
                            : const Color(0xFF66C0F4),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF66C0F4),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Price Summary Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT PRICE',
                      style: TextStyle(color: textGray, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Rs. ${currPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (origPrice > currPrice) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Rs. ${origPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: textGray,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: textGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (discountPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: neonGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-$discountPercent% OFF',
                      style: const TextStyle(
                        color: Color(0xFF05080D),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Lowest Ever Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Lowest Ever: Rs. ${lowestPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Custom Price Chart Canvas
          Container(
            height: 130,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CustomPaint(
              size: const Size(double.infinity, 114),
              painter: _PriceChartPainter(
                history: history,
                neonGreen: neonGreen,
                textGray: textGray,
              ),
            ),
          ),

          // Set Alert Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: ValueListenableBuilder<Map<String, double>>(
              valueListenable: PriceAlertService.alertsNotifier,
              builder: (context, alerts, _) {
                final hasAlert = alerts.containsKey(news.id);
                final alertPrice = alerts[news.id];

                return SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SetPriceAlertDialog(news: news),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAlert ? cardDark : neonGreen,
                      foregroundColor: hasAlert ? neonGreen : const Color(0xFF05080D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: neonGreen,
                          width: hasAlert ? 1.5 : 0,
                        ),
                      ),
                    ),
                    icon: Icon(
                      hasAlert ? Icons.notifications_active_rounded : Icons.notification_add_rounded,
                      size: 18,
                    ),
                    label: Text(
                      hasAlert
                          ? 'Alert Active: Rs. ${alertPrice?.toStringAsFixed(0) ?? 'Target'}'
                          : 'Set Alert at Rs. ___',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;
  final Color neonGreen;
  final Color textGray;

  _PriceChartPainter({
    required this.history,
    required this.neonGreen,
    required this.textGray,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final prices = history.map((e) => ((e['price'] as num?) ?? 0).toDouble()).toList();
    final double maxPrice = prices.reduce(math.max);
    final double minPrice = prices.reduce(math.min);
    final double priceSpan = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);

    final double w = size.width;
    final double h = size.height - 20; // 20px reserved for labels at bottom

    final List<Offset> points = [];
    final stepX = w / (prices.length - 1 == 0 ? 1 : prices.length - 1);

    for (int i = 0; i < prices.length; i++) {
      final double x = i * stepX;
      // Invert Y: higher price = closer to top (0), lower price = closer to h
      final double normalized = (prices[i] - minPrice) / priceSpan;
      final double y = h - (normalized * (h - 20)) - 10;
      points.add(Offset(x, y));
    }

    // 1. Draw Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 10), Offset(w, 10), gridPaint);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), gridPaint);
    canvas.drawLine(Offset(0, h), Offset(w, h), gridPaint);

    // 2. Draw Gradient Fill under line
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    path.lineTo(points.last.dx, h);
    path.lineTo(points.first.dx, h);
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          neonGreen.withOpacity(0.35),
          neonGreen.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // 3. Draw Spline Line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = neonGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, strokePaint);

    // 4. Draw Points & Labels
    final dotFillPaint = Paint()..color = const Color(0xFF05080D);
    final dotStrokePaint = Paint()
      ..color = neonGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, 4, dotFillPaint);
      canvas.drawCircle(pt, 4, dotStrokePaint);

      // Price Tag above point
      final priceStr = 'Rs. ${prices[i].toStringAsFixed(0)}';
      final pricePainter = TextPainter(
        text: TextSpan(
          text: priceStr,
          style: TextStyle(
            color: i == points.length - 1 ? neonGreen : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      double px = pt.dx - (pricePainter.width / 2);
      if (px < 0) px = 0;
      if (px + pricePainter.width > w) px = w - pricePainter.width;
      pricePainter.paint(canvas, Offset(px, pt.dy - 16));

      // Date Label below chart
      final dateStr = history[i]['date']?.toString() ?? '';
      final datePainter = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(color: textGray, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      double dx = pt.dx - (datePainter.width / 2);
      if (dx < 0) dx = 0;
      if (dx + datePainter.width > w) dx = w - datePainter.width;
      datePainter.paint(canvas, Offset(dx, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) => true;
}
