import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:homiego/features/homeowner/views/dashboard_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_account_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_inbox_screen.dart';
import 'package:homiego/features/homeowner/views/my_listings_screen.dart';

// --- ADDED ---
/// Manages the selected index of the homeowner's bottom navigation bar.
final homeownerNavIndexProvider = StateProvider<int>((ref) => 0);
// --- END ADDED ---

// --- CHANGED: Converted to ConsumerStatefulWidget ---
class HomeownerMainScreen extends ConsumerStatefulWidget {
  const HomeownerMainScreen({super.key});

  @override
  ConsumerState<HomeownerMainScreen> createState() => _HomeownerMainScreenState();
}

// --- CHANGED: Converted to ConsumerState ---
class _HomeownerMainScreenState extends ConsumerState<HomeownerMainScreen> {
  // --- REMOVED: Local state variables ---
  // int _selectedIndex = 0;
  // void _onItemTapped(int index) { ... }
  // --- END REMOVED ---

  // These are the screens for the homeowner
  static const List<Widget> _widgetOptions = <Widget>[
    HomeownerDashboardScreen(), // 'Home' in wireframe (Index 0)
    MyListingsScreen(), // 'My Listing' in wireframe (Index 1)
    HomeownerInboxScreen(), // 'Inbox' in wireframe (Index 2)
    HomeownerAccountScreen(), // 'Account' in wireframe (Index 3)
  ];

  @override
  Widget build(BuildContext context) {
    // --- ADDED: Watch the new provider ---
    final selectedIndex = ref.watch(homeownerNavIndexProvider);
    // --- END ADDED ---

    return Scaffold(
      body: IndexedStack(
        // --- CHANGED: Use provider value ---
        index: selectedIndex,
        // --- END CHANGED ---
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // These items match your wireframe (Figure 6)
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'My Listing'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inbox_outlined),
              activeIcon: Icon(Icons.inbox),
              label: 'Inbox'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account'),
        ],
        // --- CHANGED: Use provider value ---
        currentIndex: selectedIndex,
        // --- END CHANGED ---
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        // --- CHANGED: Update provider state on tap ---
        onTap: (index) =>
            ref.read(homeownerNavIndexProvider.notifier).state = index,
        // --- END CHANGED ---
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}