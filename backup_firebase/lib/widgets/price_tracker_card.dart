import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../services/price_service.dart';

class PriceTrackerCard extends StatefulWidget {
  final String gameName;
  final double currentPrice;
  final double originalPrice;
  final double lowestPrice;
  final List<dynamic> priceHistory;
  final String store;
  final String? dealUrl;
  final int? discountPercent;

  const PriceTrackerCard({
    super.key,
    required this.gameName,
    required this.currentPrice,
    required this.originalPrice,
    required this.lowestPrice,
    required this.priceHistory,
    this.store = 'Steam',
    this.dealUrl,
    this.discountPercent,
  });

  @override
  State<PriceTrackerCard> createState() => _PriceTrackerCardState();
}

class _PriceTrackerCardState extends State<PriceTrackerCard> {
  final TextEditingController _alertController = TextEditingController();
  final PriceService _priceService = PriceService();
  String? _userId;
  bool _isSettingAlert = false;

  static const Color cardBg = Color(0xFF1E1E1E);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color inputFill = Color(0xFF2A2A2A);
  static const Color redBadgeBg = Color(0xFFFF334B);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = await _priceService.getUserId();
    if (mounted) {
      setState(() {
        _userId = uid;
      });
    }
  }

  @override
  void dispose() {
    _alertController.dispose();
    super.dispose();
  }

  int get _calculatedDiscount {
    if (widget.discountPercent != null && widget.discountPercent! > 0) {
      return widget.discountPercent!;
    }
    if (widget.originalPrice > widget.currentPrice && widget.originalPrice > 0) {
      return (((widget.originalPrice - widget.currentPrice) / widget.originalPrice) * 100).round();
    }
    return 0;
  }

  int get _currentPriceInPKR {
    return (widget.currentPrice * PriceService.pkrExchangeRate).round();
  }

  Future<void> _saveAlert() async {
    final text = _alertController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final pkr = int.tryParse(text);

    if (pkr == null || pkr <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price in Rs.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSettingAlert = true);

    try {
      await _priceService.setPriceAlert(
        gameName: widget.gameName,
        targetPricePKR: pkr,
        currentPriceUSD: widget.currentPrice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: accentGreen, width: 1.2),
            ),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: accentGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alert set! Hum batayenge jab sasta hoga',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting alert: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettingAlert = false);
    }
  }

  Future<void> _openDeal() async {
    String url = widget.dealUrl ?? '';
    if (url.isEmpty) {
      url = 'https://store.steampowered.com/search/?term=${Uri.encodeComponent(widget.gameName)}';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount = _calculatedDiscount;
    final storeName = widget.store.isNotEmpty ? widget.store : 'Steam';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top row: Game name bold white 18px + red badge "-33% OFF"
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.gameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (discount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: redBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-$discount% OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // 2. Second row: Current price in green $59.99 bold 22px + original strikethrough grey
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${widget.currentPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: accentGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.originalPrice > widget.currentPrice) ...[
                const SizedBox(width: 10),
                Text(
                  '\$${widget.originalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.grey,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                '(~Rs. $_currentPriceInPKR)',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // 3. Third row: "Lowest ever: $23.99 on Steam" in green 12px
          Text(
            'Lowest ever: \$${widget.lowestPrice.toStringAsFixed(2)} on $storeName',
            style: const TextStyle(
              color: accentGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // 4. Middle: 40px height sparkline graph showing priceHistory (use CustomPainter, green line #00FF88, no external package)
          SizedBox(
            height: 40,
            width: double.infinity,
            child: CustomPaint(
              size: const Size(double.infinity, 40),
              painter: _SparklinePainter(
                history: widget.priceHistory,
                currentPrice: widget.currentPrice,
                lowestPrice: widget.lowestPrice,
                originalPrice: widget.originalPrice,
                lineColor: accentGreen,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 5. Bottom: Alert logic (StreamBuilder from user_price_alerts)
          if (_userId == null)
            const SizedBox.shrink()
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _priceService.streamUserAlert(widget.gameName, _userId!),
              builder: (context, snapshot) {
                final alertData = snapshot.data?.data();
                final bool isAlertActive =
                    alertData != null && alertData['isActive'] == true && alertData['targetPricePKR'] != null;

                if (isAlertActive) {
                  final targetPKR = alertData['targetPricePKR'];
                  // If alert SET -> Green container with opacity 0.2 showing "✅ Alert Active at Rs. 8000 - Abhi Rs. 11200 hai"
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentGreen.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: accentGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✅ Alert Active at Rs. $targetPKR - Abhi Rs. $_currentPriceInPKR hai',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // If alert NOT set -> Row with TextField (hint "8000", prefix "Rs. ", fillColor #2A2A2A) + ElevatedButton green #00FF88 text "🔔 Alert Lagao" black.
                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _alertController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: '8000',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            prefixText: 'Rs. ',
                            prefixStyle: TextStyle(color: accentGreen, fontSize: 13, fontWeight: FontWeight.bold),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSettingAlert ? null : _saveAlert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSettingAlert
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              '🔔 Alert Lagao',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 6),

          // 6. Last: TextButton "Buy Now on Steam ->" that opens dealUrl via url_launcher.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openDeal,
              style: TextButton.styleFrom(
                foregroundColor: accentGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Buy Now on $storeName ->',
                    style: const TextStyle(
                      color: accentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<dynamic> history;
  final double currentPrice;
  final double lowestPrice;
  final double originalPrice;
  final Color lineColor;

  _SparklinePainter({
    required this.history,
    required this.currentPrice,
    required this.lowestPrice,
    required this.originalPrice,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    List<double> prices = [];

    if (history.isNotEmpty) {
      for (final item in history) {
        if (item is Map && item['price'] != null) {
          final p = (item['price'] as num).toDouble();
          if (p > 0) prices.add(p);
        } else if (item is num) {
          prices.add(item.toDouble());
        }
      }
    }

    // If history has fewer than 2 points, synthesize a clean 5-point trend
    if (prices.length < 2) {
      final orig = originalPrice > 0 ? originalPrice : currentPrice * 1.35;
      final lowest = lowestPrice > 0 ? lowestPrice : currentPrice * 0.75;
      prices = [
        orig,
        orig * 0.95,
        lowest * 1.15,
        lowest,
        currentPrice,
      ];
    }

    final double w = size.width;
    final double h = size.height;

    final double maxPrice = prices.reduce(math.max);
    final double minPrice = prices.reduce(math.min);
    final double span = (maxPrice - minPrice) == 0 ? 1.0 : (maxPrice - minPrice);

    final List<Offset> points = [];
    final double stepX = w / (prices.length - 1);

    for (int i = 0; i < prices.length; i++) {
      final double x = i * stepX;
      // Invert: higher price is at top (padding 4), lower price at bottom (h - 4)
      final double normalized = (prices[i] - minPrice) / span;
      final double y = (h - 8) - (normalized * (h - 12)) + 4;
      points.add(Offset(x, y));
    }

    // 1. Draw subtle area gradient fill under line
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
          lineColor.withOpacity(0.25),
          lineColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // 2. Draw smooth curved green line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 3. Draw dot at last point (current price)
    final dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(points.last, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
