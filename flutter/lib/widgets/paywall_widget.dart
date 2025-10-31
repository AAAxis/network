import 'package:flutter/material.dart';
import '../services/native_paywall_service.dart';

/// Placeholder paywall widget (using native paywall service instead)
class PaywallWidget extends StatelessWidget {
  const PaywallWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget is not used directly - we use NativePaywallService.presentPaywall instead
    return const SizedBox.shrink();
  }
}

