import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/utils/theme.dart';

class CaptainDashboard extends StatefulWidget {
  const CaptainDashboard({super.key});

  @override
  State<CaptainDashboard> createState() => _CaptainDashboardState();
}

class _CaptainDashboardState extends State<CaptainDashboard> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  // Function to Approve User
  Future<void> _updateStatus(String uid, String newStatus) async {
    await _usersRef.child(uid).update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Captain Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // AuthWrapper in main.dart handles the redirect
            },
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard Header Stats
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("User Management", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Manage approvals and barangay residents", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Pending Approvals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // The List of Pending Users
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              // Query: Get users where status is 'pending'
              stream: _usersRef.orderByChild('status').equalTo('pending').onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading data"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No pending approvals"),
                      ],
                    ),
                  );
                }

                // Convert Map to List
                Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<Map<String, dynamic>> users = [];
                data.forEach((key, value) {
                  users.add({"uid": key, ...value});
                });

                return ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(child: Text(user['name'][0].toUpperCase())),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("Purok: ${user['purok']}", style: TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _updateStatus(user['uid'], 'rejected'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text("Reject"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _updateStatus(user['uid'], 'approved'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: const Text("Approve"),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}