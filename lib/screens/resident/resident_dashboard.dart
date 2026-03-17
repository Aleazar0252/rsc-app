import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:url_launcher/url_launcher.dart'; // NEW: For making phone calls

// --- UTILS & SCREENS ---
import '../../utils/theme.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  
  String _userName = "Resident";
  String _userAddress = "Loading location...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 1. LOAD USER DATA ---
  void _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final snapshot = await _dbRef.child('profiles/${user.uid}').get();
        if (snapshot.exists && mounted) {
          final data = snapshot.value as Map;
          setState(() {
            _userName = data['fullname'] ?? "Resident";
            _userAddress = data['address'] ?? "Unknown Location";
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint("Error loading profile: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- 2. EMERGENCY CALL LOGIC ---
  void _showContactDialog(String title, String number, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("You are about to call the $title emergency hotline:"),
            const SizedBox(height: 16),
            Text(number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1)),
          ]
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              final Uri launchUri = Uri(scheme: 'tel', path: number);
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(launchUri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch dialer.")));
                }
              }
            },
            icon: const Icon(Icons.call),
            label: const Text("CALL NOW", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // --- HEADER SECTION (SliverAppBar) ---
          SliverAppBar(
            automaticallyImplyLeading: false, // Ensures no back button appears!
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hello,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(
                      _isLoading ? "Loading..." : _userName, 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _isLoading ? "Fetching address..." : _userAddress, 
                          style: const TextStyle(color: Colors.white, fontSize: 12)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- BODY SECTION ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NEW EMERGENCY HOTLINES SECTION ---
                  const Text("Emergency Hotlines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Replace these numbers with the actual Ipil emergency numbers
                        _buildContactBtn("POLICE", Icons.local_police, Colors.blue, "09985987050"),
                        _buildContactBtn("FIRE", Icons.local_fire_department, Colors.orange, "09420601234"),
                        _buildContactBtn("HOSPITAL", Icons.medical_services, Colors.red, "09171234567"),
                        _buildContactBtn("MDRRMO", Icons.support, Colors.green, "09123456789"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // FEED HEADER
                  const Text("Community Updates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // --- ANNOUNCEMENT FEED LIST ---
          SliverFillRemaining(
            child: FirebaseAnimatedList(
              query: _dbRef.child('announcements').orderByChild('timestamp'),
              sort: (a, b) => b.key!.compareTo(a.key!), // Sort Newest First
              defaultChild: const Center(child: CircularProgressIndicator()),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemBuilder: (context, snapshot, animation, index) {
                if (snapshot.value == null) return const SizedBox.shrink();
                final post = Map<String, dynamic>.from(snapshot.value as Map);
                return _buildFeedItem(post);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER: CONTACT BUTTONS ---
  Widget _buildContactBtn(String label, IconData icon, Color color, String number) {
    return InkWell(
      onTap: () => _showContactDialog(label, number, icon, color),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 55, height: 55,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87))
        ],
      ),
    );
  }

  // --- WIDGET HELPER: FEED ITEM ---
  Widget _buildFeedItem(Map post) {
    final bool hasImage = post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty;
    final String dateStr = post['date'] ?? "Just Now";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE (If exists)
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                post['imageUrl'], 
                height: 180, 
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180, 
                  color: Colors.grey[200], 
                  child: const Icon(Icons.broken_image, color: Colors.grey)
                ),
              ),
            ),

          // CONTENT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        post['type']?.toString().toUpperCase() ?? "NEWS", 
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const Spacer(),
                    Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(post['title'] ?? "No Title", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(post['body'] ?? "", style: TextStyle(color: Colors.grey[700], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}