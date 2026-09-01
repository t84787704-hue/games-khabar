import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdWidget extends StatefulWidget {
  final String adUnitId;

  const NativeAdWidget({
    super.key,
    this.adUnitId = 'ca-app-pub-3940256099942544/2247696110', // Standard Google Test Ad Unit
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
  static const Color _textWhite = Colors.white;
  static const Color _textBlack = Color(0xFF05080D);
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
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: _cardDark,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: _textBlack,
          backgroundColor: _neonGreen,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: _textWhite,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: _textGray,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: _textGray,
          style: NativeTemplateFontStyle.normal,
          size: 10.0,
        ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isAdLoaded && _nativeAd != null
          ? ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 320,
                minHeight: 120,
                maxHeight: 340,
                maxWidth: 400,
              ),
              child: AdWidget(ad: _nativeAd!),
            )
          : Container(
              height: 120,
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
