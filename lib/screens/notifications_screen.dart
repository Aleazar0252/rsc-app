import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login to view notifications"));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.blue),
            tooltip: "Mark all as read",
            onPressed: () {
              // Logic to clear unread dots would go here
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All marked as read")));
            },
          )
        ],
      ),
      // We listen to the user's specific notification node
      body: StreamBuilder(
        stream: _dbRef.child('notifications/${user.uid}').orderByKey().limitToLast(20).onValue,
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState();
          }

          // Convert Firebase Map to List & Reverse (Newest First)
          Map<dynamic, dynamic> map = snapshot.data!.snapshot.value;
          List<MapEntry<dynamic, dynamic>> list = map.entries.toList();
          list.sort((a, b) => b.key.compareTo(a.key)); // Sort by key (timestamp usually)

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final notif = list[index].value;
              final String title = notif['title'] ?? "System Alert";
              final String body = notif['body'] ?? "You have a new update.";
              final String type = notif['type'] ?? "info"; // alert, success, info
              final int timestamp = notif['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

              return _buildNotificationCard(title, body, type, timestamp);
            },
          );
        },
      ),
    );
  }

  // --- 1. NOTIFICATION CARD DESIGN ---
  Widget _buildNotificationCard(String title, String body, String type, int timestamp) {
    // Determine Color & Icon based on Type
    Color color;
    IconData icon;

    switch (type) {
      case 'danger': // Evacuation, Fire, Etc.
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case 'success': // Mission Resolved, Arrived
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'warning': // Weather updates
        color = Colors.orange;
        icon = Icons.thunderstorm;
        break;
      default: // System info
        color = Colors.blue;
        icon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              _formatTime(timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(body, style: TextStyle(color: Colors.grey[700], height: 1.4)),
        ),
      ),
    );
  }

  // --- 2. EMPTY STATE (No Notifications) ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No Notifications Yet", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Alerts and updates will appear here.", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  // --- 3. TIME FORMATTER ---
  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM d').format(date); // Requires intl package
  }
}