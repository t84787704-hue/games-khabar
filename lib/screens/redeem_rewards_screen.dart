import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_wallet_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';

class RedeemRewardsScreen extends StatefulWidget {
  const RedeemRewardsScreen({super.key});

  @override
  State<RedeemRewardsScreen> createState() => _RedeemRewardsScreenState();
}

class _RedeemRewardsScreenState extends State<RedeemRewardsScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  final GamerAuthService _authService = GamerAuthService();

  bool _termsAccepted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkTermsAgreement();
  }

  Future<void> _checkTermsAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('accepted_18plus_terms') ?? false;
    setState(() {
      _termsAccepted = accepted;
    });

    if (!accepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _show18PlusTermsDialog();
      });
    }
  }

  void _show18PlusTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.accentBlue, width: 1.5),
        ),
        title: const Row(
          children: [
            Text('🔞', style: TextStyle(fontSize: 26)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '18+ Skill-Based Platform',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GamerTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMPORTANT COMPLIANCE NOTICE:',
                    style: TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Skill-based platform\n• No gambling\n• No purchase necessary\n• Rewards sponsored by ads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'By continuing, you confirm that you are at least 18 years old and acknowledge that all tournaments are purely skill-based competitive matches with ad-sponsored reward distributions.',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('accepted_18plus_terms', true);
              if (mounted) {
                setState(() => _termsAccepted = true);
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text(
              'I AM 18+ & ACCEPT TERMS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _openKycRedeemDialog({
    required BuildContext context,
    required String rewardType,
    required String rewardTitle,
    required int costCoins,
    required String hintDelivery,
    required String deliveryLabel,
  }) {
    final uid = _authService.currentUid ?? 'guest';
    final user = _authService.currentGamer;

    final nameCtrl = TextEditingController(text: user?.displayName ?? '');
    final idCtrl = TextEditingController();
    final deliveryCtrl = TextEditingController(text: user?.gameId ?? '');
    final contactCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.neonGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: GamerTheme.neonGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KYC & REWARD DELIVERY',
                          style: TextStyle(
                            color: GamerTheme.neonGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          rewardTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Required G-Coins:', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                    Text(
                      '💰 ${NumberFormat("#,###").format(costCoins)} Coins',
                      style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Legal Name
              const Text('1. FULL LEGAL NAME (As per Government ID)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Muhammad Ali',
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Government ID Number
              const Text('2. NATIONAL ID / CNIC / GOVT ID NUMBER', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: idCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. 42101-1234567-1',
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Delivery Method details
              Text('3. $deliveryLabel', style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: deliveryCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: hintDelivery,
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Contact Info
              const Text('4. CONTACT NUMBER / WHATSAPP', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. +92 300 1234567',
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.neonGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        idCtrl.text.trim().isEmpty ||
                        deliveryCtrl.text.trim().isEmpty ||
                        contactCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: GamerTheme.redAccent,
                          content: Text('Please fill all KYC verification fields!'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    final res = await _walletService.requestRedeemReward(
                      userId: uid,
                      rewardType: rewardType,
                      rewardTitle: rewardTitle,
                      costCoins: costCoins,
                      legalName: nameCtrl.text.trim(),
                      govtIdNumber: idCtrl.text.trim(),
                      deliveryDetails: deliveryCtrl.text.trim(),
                      contactNumber: contactCtrl.text.trim(),
                    );

                    if (mounted) {
                      setState(() => _isLoading = false);
                      if (res['success'] == true) {
                        _showRedeemSuccessDialog(
                          rewardTitle: rewardTitle,
                          requestId: res['requestId'] as String? ?? 'REQ-101',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GamerTheme.redAccent,
                            content: Text(res['error'] as String? ?? 'Redeem request failed'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'SUBMIT KYC & CLAIM REWARD 🎁',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRedeemSuccessDialog({required String rewardTitle, required String requestId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.neonGreen, width: 1.5),
        ),
        title: const Row(
          children: [
            Text('🎉', style: TextStyle(fontSize: 26)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Redeem Request Submitted!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your request for $rewardTitle has been successfully submitted for KYC verification.',
              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GamerTheme.bgDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REQUEST REFERENCE:', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    requestId,
                    style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text('STATUS:', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Under KYC Verification (12-24 Hours)',
                    style: TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('GREAT', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid ?? 'guest';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.cardDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🎁', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Skill Tournament Rewards',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '18+ Terms & Compliance',
            icon: const Icon(Icons.verified_user_rounded, color: GamerTheme.neonGreen),
            onPressed: _show18PlusTermsDialog,
          ),
        ],
      ),
      body: StreamBuilder<CoinWallet>(
        stream: _walletService.walletStream(uid),
        initialData: _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000),
        builder: (context, snapshot) {
          final wallet = snapshot.data ?? const CoinWallet(userId: '', coins: 1000);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Balance Card
                _buildWalletCard(wallet),

                const SizedBox(height: 14),

                // 18+ Compliance Banner
                _buildComplianceBanner(),

                const SizedBox(height: 24),

                // SECTION 1: SMALL REDEEM (FOR TRUST)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: GamerTheme.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: GamerTheme.neonGreen, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'QUICK REDEEM',
                            style: TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Small Rewards (Fast Delivery)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Card A: 10,000 Coins = 60 BGMI UC
                _buildSmallRedeemCard(
                  context: context,
                  walletCoins: wallet.coins,
                  icon: '🎮',
                  title: '60 BGMI UC',
                  gameLabel: 'BATTLEGROUNDS MOBILE INDIA',
                  costCoins: 10000,
                  rewardType: 'bgmi_60_uc',
                  deliveryLabel: 'BGMI CHARACTER ID (UID)',
                  hintDelivery: 'e.g. 5123456789 & IGN',
                ),

                const SizedBox(height: 12),

                // Card B: 15,000 Coins = 100 Free Fire Diamonds
                _buildSmallRedeemCard(
                  context: context,
                  walletCoins: wallet.coins,
                  icon: '💎',
                  title: '100 Free Fire Diamonds',
                  gameLabel: 'GARENA FREE FIRE',
                  costCoins: 15000,
                  rewardType: 'ff_100_diamonds',
                  deliveryLabel: 'FREE FIRE PLAYER ID (UID)',
                  hintDelivery: 'e.g. 192837465 & IGN',
                ),

                const SizedBox(height: 28),

                // SECTION 2: MEGA REDEEM ($100 & $200 ONLY - NO $5, $10, $20)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'MEGA REDEEM',
                            style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Official Mega Gift Cards',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Multiples of 1,000,000 Coins only (\$100 & \$200 Digital Gift Cards). No micro-redemptions.',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),

                // Mega Card 1: 1,000,000 Coins = $100 Mega Gift Card
                _buildMegaRedeemCard(
                  context: context,
                  walletCoins: wallet.coins,
                  title: '\$100 Mega Gift Card',
                  subtitle: 'Google Play / Apple / Amazon Digital Gift Card',
                  costCoins: 1000000,
                  rewardType: 'mega_100_giftcard',
                ),

                const SizedBox(height: 14),

                // Mega Card 2: 2,000,000 Coins = $200 Mega Gift Card
                _buildMegaRedeemCard(
                  context: context,
                  walletCoins: wallet.coins,
                  title: '\$200 Mega Gift Card',
                  subtitle: 'Double Mega Milestone (Google Play / Apple / Amazon)',
                  costCoins: 2000000,
                  rewardType: 'mega_200_giftcard',
                ),

                const SizedBox(height: 32),

                // USER'S REDEEM HISTORY
                const Text(
                  'YOUR REDEEM REQUESTS',
                  style: TextStyle(
                    color: GamerTheme.accentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _walletService.getRedeemRequestsStream(uid),
                  builder: (context, reqSnap) {
                    final reqs = reqSnap.data ?? [];
                    if (reqs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: GamerTheme.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: GamerTheme.textMuted, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'No redeem requests submitted yet.',
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reqs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = reqs[i];
                        final title = r['rewardTitle'] as String? ?? 'Reward';
                        final cost = r['costCoins'] as num? ?? 0;
                        final status = r['status'] as String? ?? 'pending';
                        final details = r['deliveryDetails'] as String? ?? '';

                        final isPending = status.contains('pending');

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: GamerTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPending ? GamerTheme.accentOrange.withOpacity(0.4) : GamerTheme.neonGreen.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPending ? GamerTheme.accentOrange.withOpacity(0.15) : GamerTheme.neonGreen.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                                  color: isPending ? GamerTheme.accentOrange : GamerTheme.neonGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Target: $details • 💰 ${NumberFormat("#,###").format(cost)} Coins',
                                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPending ? GamerTheme.accentOrange.withOpacity(0.15) : GamerTheme.neonGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPending ? 'VERIFYING' : 'DELIVERED',
                                  style: TextStyle(
                                    color: isPending ? GamerTheme.accentOrange : GamerTheme.neonGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalletCard(CoinWallet wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF162032), Color(0xFF0F1522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GamerTheme.accentBlue.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: GamerTheme.accentBlue, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'AVAILABLE G-COINS',
                    style: TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GamerTheme.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: GamerTheme.neonGreen, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Trust: ${wallet.trustScore}/100',
                      style: const TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Text(
                NumberFormat('#,###').format(wallet.coins),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Coins',
                style: TextStyle(color: GamerTheme.textMuted, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: GamerTheme.accentBlue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Skill-based platform • No gambling • No purchase necessary • Rewards sponsored by ads',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallRedeemCard({
    required BuildContext context,
    required int walletCoins,
    required String icon,
    required String title,
    required String gameLabel,
    required int costCoins,
    required String rewardType,
    required String deliveryLabel,
    required String hintDelivery,
  }) {
    final canRedeem = walletCoins >= costCoins;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: canRedeem ? GamerTheme.neonGreen.withOpacity(0.5) : GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GamerTheme.borderLight.withOpacity(0.3)),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameLabel,
                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                ),
                child: Text(
                  '${NumberFormat("#,###").format(costCoins)} 🪙',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canRedeem ? GamerTheme.neonGreen : GamerTheme.cardElevated,
                foregroundColor: canRedeem ? Colors.black : GamerTheme.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canRedeem
                  ? () => _openKycRedeemDialog(
                        context: context,
                        rewardType: rewardType,
                        rewardTitle: title,
                        costCoins: costCoins,
                        hintDelivery: hintDelivery,
                        deliveryLabel: deliveryLabel,
                      )
                  : null,
              child: Text(
                canRedeem ? 'REDEEM NOW (KYC) ⚡' : 'NEED ${NumberFormat("#,###").format(costCoins - walletCoins)} MORE COINS',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMegaRedeemCard({
    required BuildContext context,
    required int walletCoins,
    required String title,
    required String subtitle,
    required int costCoins,
    required String rewardType,
  }) {
    final progress = (walletCoins / costCoins).clamp(0.0, 1.0);
    final canRedeem = walletCoins >= costCoins;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canRedeem ? Colors.amber : GamerTheme.borderDark,
          width: canRedeem ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Center(child: Text('🌟', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar: e.g. "750,000 / 1,000,000"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progress:', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(
                '${NumberFormat("#,###").format(walletCoins)} / ${NumberFormat("#,###").format(costCoins)}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: GamerTheme.bgDark,
              color: Colors.amber,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),

          // Button enabled ONLY when progress reaches 100% (costCoins)
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canRedeem ? Colors.amber : GamerTheme.cardElevated,
                foregroundColor: canRedeem ? Colors.black : GamerTheme.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canRedeem
                  ? () => _openKycRedeemDialog(
                        context: context,
                        rewardType: rewardType,
                        rewardTitle: title,
                        costCoins: costCoins,
                        hintDelivery: 'e.g. your_email@gmail.com (Google Play / Apple / Amazon)',
                        deliveryLabel: 'GIFT CARD EMAIL & PREFERRED BRAND',
                      )
                  : null,
              child: Text(
                canRedeem ? 'CLAIM $title (KYC VERIFIED) 🎁' : 'LOCKED (NEED ${NumberFormat("#,###").format(costCoins)} COINS)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
