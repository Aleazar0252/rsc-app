import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import 'dashboard_tab.dart'; 
import '..//map_screen.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';

class ResponderHome extends StatefulWidget {
  const ResponderHome({super.key});

  @override
  State<ResponderHome> createState() => _ResponderHomeState();
}

class _ResponderHomeState extends State<ResponderHome> {
  int _currentIndex = 0;

  // The Pages for the 4 Tabs
  final List<Widget> _pages = [
    const ResponderDashboardTab(),
    const MapScreen(),     
    const NotificationsScreen(),
    const ProfileScreen(),    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Live Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notify',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}