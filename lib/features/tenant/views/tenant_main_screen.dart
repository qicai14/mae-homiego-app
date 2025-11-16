import 'package:flutter/material.dart';
import 'package:homiego/features/tenant/views/account_screen.dart';
import 'package:homiego/features/tenant/views/inbox_screen.dart';
import 'package:homiego/features/tenant/views/tenant_home_screen.dart';
import 'package:homiego/features/tenant/views/wishlist_screen.dart';
import 'package:homiego/widgets/booking_monitor_wrapper.dart';

class TenantMainScreen extends StatefulWidget {
  const TenantMainScreen({super.key});

  @override
  State<TenantMainScreen> createState() => _TenantMainScreenState();
}

class _TenantMainScreenState extends State<TenantMainScreen> {
  int _selectedIndex = 0;
  final GlobalKey _wishlistKey = GlobalKey();

  // These are the screens for the tenant
  late final List<Widget> _widgetOptions = [
    const TenantHomeScreen(),
    TenantWishlistScreen(key: _wishlistKey),
    const TenantInboxScreen(),
    const TenantAccountScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh wishlist when switching to wishlist tab
    if (index == 1) {
      final wishlistState = _wishlistKey.currentState;
      if (wishlistState != null) {
        (wishlistState as dynamic).refreshWishlist();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BookingMonitorWrapper(
      child: Scaffold(
        // IndexedStack keeps the state of the screens when switching tabs
        body: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
      bottomNavigationBar: BottomNavigationBar(
        // These items match your wireframe (Figure 3)
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Wishlist'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), activeIcon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Good for 4+ items
        showUnselectedLabels: true,
      ),
      ),
    );
  }
}

