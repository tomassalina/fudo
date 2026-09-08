import 'package:flutter/material.dart';

/// Bottom navigation shell shared by the three main tabs (Search,
/// My Places, Gifting). Wraps whatever branch go_router is currently
/// showing and drives navigation via [onTap].
class MainShell extends StatelessWidget {
  const MainShell({
    required this.currentIndex,
    required this.onTap,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.place_outlined),
            label: 'Mis Lugares',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            label: 'Regalar',
          ),
        ],
      ),
    );
  }
}
