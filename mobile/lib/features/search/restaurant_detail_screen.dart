import 'package:flutter/material.dart';

/// Restaurant detail screen (`docs/design-brief.md` §2.5): full-width photo
/// header, hours accordion, WhatsApp/delivery actions, and "Mis visitas"
/// (loyalty)/"Menú" sub-tabs.
///
/// Placeholder for now — wired into the router ahead of the real
/// implementation (backlog item 7) so search results/map cards have a real
/// navigation target. Reads [merchantId] from the route; the real build
/// will pull the merchant from `merchantProvider(merchantId)` once the
/// Riverpod data providers land.
class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({required this.merchantId, super.key});

  final int merchantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Restaurante #$merchantId')),
      body: const Center(child: Text('Detalle de restaurante — próximamente')),
    );
  }
}
