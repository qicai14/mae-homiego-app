import 'package:flutter/material.dart';
import 'package:homiego/features/homeowner/views/dashboard_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_account_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_inbox_screen.dart';
import 'package:homiego/features/homeowner/views/my_listings_screen.dart';

class HomeownerMainScreen extends StatefulWidget {
  const HomeownerMainScreen({super.key});

  @override
  State<HomeownerMainScreen> createState() => _HomeownerMainScreenState();
}

class _HomeownerMainScreenState extends State<HomeownerMainScreen> {
  int _selectedIndex = 0;

  // These are the screens for the homeowner
  static const List<Widget> _widgetOptions = <Widget>[
    HomeownerDashboardScreen(), // 'Home' in wireframe
    MyListingsScreen(),      // 'My Listing' in wireframe
    HomeownerInboxScreen(),    // 'Inbox' in wireframe
    HomeownerAccountScreen(),  // 'Account' in wireframe
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // These items match your wireframe (Figure 6)
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'My Listing'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), activeIcon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}

