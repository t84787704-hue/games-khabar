import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdWidget extends StatefulWidget {
  final String adUnitId;
  final EdgeInsetsGeometry? margin;
  final double? height;

  const NativeAdWidget({
    super.key,
    this.adUnitId = 'ca-app-pub-3940256099942544/2247696110', // Standard Google Test Ad Unit
    this.margin,
    this.height,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _adFailedToLoad = false;

  static const Color _cardDark = Color(0xFF1E1E1E);
  static const Color _borderDark = Color(0xFF2A2A2A);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _textGray = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _adFailedToLoad = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _adFailedToLoad = true;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adFailedToLoad) {
      return const SizedBox.shrink();
    }

    final adHeight = widget.height ?? 380.0;
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: adHeight,
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isAdLoaded && _nativeAd != null
          ? AdWidget(ad: _nativeAd!)
          : Container(
              height: adHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_neonGreen),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading Sponsored Ad...',
                    style: TextStyle(
                      color: _textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
