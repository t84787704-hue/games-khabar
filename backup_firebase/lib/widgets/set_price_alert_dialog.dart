import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../services/price_alert_service.dart';
import '../services/theme_service.dart';

class SetPriceAlertDialog extends StatefulWidget {
  final NewsModel news;

  const SetPriceAlertDialog({super.key, required this.news});

  @override
  State<SetPriceAlertDialog> createState() => _SetPriceAlertDialogState();
}

class _SetPriceAlertDialogState extends State<SetPriceAlertDialog> {
  late TextEditingController _controller;
  double? _targetPrice;
  bool _isLoading = false;

  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  void initState() {
    super.initState();
    final existingAlert = PriceAlertService().getAlertPrice(widget.news.id);
    final currPrice = widget.news.displayCurrentPrice ?? 2999.0;
    _targetPrice = existingAlert ?? (currPrice * 0.8).roundToDouble();
    _controller = TextEditingController(text: _targetPrice?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyDiscount(double factor) {
    final currPrice = widget.news.displayCurrentPrice ?? 2999.0;
    final calc = (currPrice * (1.0 - factor)).roundToDouble();
    setState(() {
      _targetPrice = calc;
      _controller.text = calc.toStringAsFixed(0);
    });
  }

  Future<void> _saveAlert() async {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(RegExp(r'[^0-9.]'), ''));
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price in Rs.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    await PriceAlertService().setAlert(
      gameId: widget.news.id,
      gameName: widget.news.gameName ?? widget.news.category,
      targetPrice: parsed,
      currentPrice: widget.news.displayCurrentPrice,
      store: widget.news.displayStore,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: neonGreen, width: 1.2),
          ),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: neonGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alert set at Rs. ${parsed.toStringAsFixed(0)}! Sasta hote hi notification aayega 🔥',
                  style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _removeAlert() async {
    setState(() => _isLoading = true);
    await PriceAlertService().removeAlert(widget.news.id);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark,
          content: Text('Price alert removed', style: TextStyle(color: textWhite)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currPrice = widget.news.displayCurrentPrice ?? 2999.0;
    final gameTitle = widget.news.gameName ?? widget.news.category;
    final hasAlert = PriceAlertService().hasAlert(widget.news.id);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F141C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderDark),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Game
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: neonGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_alert_rounded, color: neonGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SET PRICE DROP ALERT',
                        style: TextStyle(
                          color: neonGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        gameTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Current price reference
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Store Price:', style: TextStyle(color: textGray, fontSize: 13)),
                  Text(
                    'Rs. ${currPrice.toStringAsFixed(0)}',
                    style: TextStyle(color: textWhite, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Input Field
            Text(
              'Notify me when price drops to or below:',
              style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neonGreen, width: 1.2),
              ),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: 'Rs. ',
                  prefixStyle: TextStyle(color: neonGreen, fontSize: 18, fontWeight: FontWeight.bold),
                  hintText: '2499',
                  hintStyle: TextStyle(color: textGray.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) {
                  setState(() {
                    _targetPrice = double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), ''));
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // Quick percent chips
            Row(
              children: [
                _buildQuickChip('-15% (Rs. ${(currPrice * 0.85).round()})', 0.15),
                const SizedBox(width: 8),
                _buildQuickChip('-30% (Rs. ${(currPrice * 0.70).round()})', 0.30),
                const SizedBox(width: 8),
                _buildQuickChip('-50% (Rs. ${(currPrice * 0.50).round()})', 0.50),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (hasAlert) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _removeAlert,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neonGreen,
                      foregroundColor: const Color(0xFF05080D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF05080D)),
                          )
                        : Text(
                            hasAlert ? 'Update Alert' : 'Save Alert (Rs. ${_targetPrice?.toStringAsFixed(0) ?? ''})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, double factor) {
    return Expanded(
      child: InkWell(
        onTap: () => _applyDiscount(factor),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderDark),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: textGray, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
