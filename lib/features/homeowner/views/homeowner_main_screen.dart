import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:homiego/features/homeowner/views/dashboard_screen.dart';
import 'package:homiego/features/general/views/profile_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_inbox_screen.dart';
import 'package:homiego/features/homeowner/views/my_listings_screen.dart';
import 'package:homiego/widgets/notification_snackbar_listener.dart';


final homeownerNavIndexProvider = StateProvider<int>((ref) => 0);

class HomeownerMainScreen extends ConsumerStatefulWidget {
  const HomeownerMainScreen({super.key});

  @override
  ConsumerState<HomeownerMainScreen> createState() => _HomeownerMainScreenState();
}


class _HomeownerMainScreenState extends ConsumerState<HomeownerMainScreen> {

  // These are the screens for the homeowner
  static const List<Widget> _widgetOptions = <Widget>[
    HomeownerDashboardScreen(), 
    MyListingsScreen(), 
    HomeownerInboxScreen(), 
    ProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homeownerNavIndexProvider);

    return NotificationSnackbarListener(
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: _widgetOptions,
        ),
        bottomNavigationBar: BottomNavigationBar(
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
        currentIndex: selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        onTap: (index) =>
            ref.read(homeownerNavIndexProvider.notifier).state = index,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      ),
    );
  }
}
