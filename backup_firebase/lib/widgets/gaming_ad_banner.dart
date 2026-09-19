import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_free_service.dart';

class GamingAdBanner extends StatefulWidget {
  const GamingAdBanner({super.key});

  @override
  State<GamingAdBanner> createState() => _GamingAdBannerState();
}

class _GamingAdBannerState extends State<GamingAdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (AdFreeService().isAdFree) return;

    try {
      _bannerAd = BannerAd(
        adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test AdMob Banner Unit ID
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _isAdLoaded = true);
          },
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            if (mounted) setState(() => _isAdLoaded = false);
          },
        ),
      )..load();
    } catch (_) {
      // Ignored if platform doesn't support Google Mobile Ads (e.g. testing)
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: AdFreeService.adFreeUntilNotifier,
      builder: (context, adFreeUntil, _) {
        if (AdFreeService().isAdFree) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          child: _isAdLoaded && _bannerAd != null
              ? Container(
                  height: 50,
                  width: 320,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F29),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262E3D)),
                  ),
                  child: AdWidget(ad: _bannerAd!),
                )
              : _buildAdMobTestPlaceholder(),
        );
      },
    );
  }

  Widget _buildAdMobTestPlaceholder() {
    return Container(
      width: double.infinity,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141923),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF283244), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Ad',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.ads_click_rounded, size: 16, color: Color(0xFF00FF88)),
          const SizedBox(width: 8),
          const Text(
            'Google AdMob Test Ad • 320x50',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
