import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// Placeholder screen for the "Buscar" tab: natural-language search
/// (dark style + violet glow, coming later) with a results list and map.
/// For now this only wires up a functional dark map, no search bar,
/// no markers, no business logic yet.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Buscar'),
          ),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: AppConstants.defaultMapCenter,
                initialZoom: AppConstants.defaultMapZoom,
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.cartoDarkMatterTileUrl,
                  userAgentPackageName: 'com.fudo.mobile',
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'CARTO',
                      onTap: () => _openLink('https://carto.com/attributions'),
                    ),
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () =>
                          _openLink('https://www.openstreetmap.org/copyright'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
