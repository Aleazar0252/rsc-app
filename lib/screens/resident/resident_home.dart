import 'package:flutter/material.dart';

// --- UTILS & SCREENS ---
import '../../utils/theme.dart';
import 'resident_dashboard.dart';
import '../map_screen.dart';
import '../profile_screen.dart';
import '../camera_screen.dart'; // The screen triggered by the center button

class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {
  int _currentIndex = 0;

  // ---------------------------------------------------------
  // YOUR TABS
  // ---------------------------------------------------------
  final List<Widget> _pages = [
    const ResidentDashboard(), // Index 0: Home
    const MapScreen(),         // Index 1: Live Map
    
    // Index 2: Placeholder for Alerts/History
    const Center(child: Text("Alerts coming soon!", style: TextStyle(color: Colors.grey))), 
    
    const ProfileScreen(),     // Index 3: Profile
  ];

  // ---------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      // 1. The Big Center Button (Now opens camera INSTANTLY for future AI)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomCameraScreen()));
        },
        backgroundColor: Colors.red,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.campaign, color: Colors.white, size: 30),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 2. The Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_filled, label: "Home", index: 0),
              _buildNavItem(icon: Icons.map_rounded, label: "Live Map", index: 1),
              
              const SizedBox(width: 48), // Space for the center button
              
              _buildNavItem(icon: Icons.notifications, label: "Alerts", index: 2),
              _buildNavItem(icon: Icons.person, label: "Profile", index: 3),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER TO BUILD NAV ICONS ---
  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 65, 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
              size: isSelected ? 28 : 24, 
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
              ),
            )
          ],
        ),
      ),
    );
  }
}