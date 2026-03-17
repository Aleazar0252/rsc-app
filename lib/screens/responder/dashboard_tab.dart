import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'mission_report_screen.dart'; // Needed for the "Resolve" button

class ResponderDashboardTab extends StatefulWidget {
  const ResponderDashboardTab({super.key});

  @override
  State<ResponderDashboardTab> createState() => _ResponderDashboardTabState();
}

class _ResponderDashboardTabState extends State<ResponderDashboardTab> {
  final _dbRef = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  // --- 1. VIEW ALERT DETAILS (The "View" Button) ---
  void _viewAlertDetails(String key, Map alert) {
    final type = (alert['type'] ?? 'Emergency').toString().toUpperCase();
    final name = alert['name'] ?? "Unknown";
    final desc = alert['description'] ?? "No additional details provided.";
    final time = DateTime.fromMillisecondsSinceEpoch(alert['timestamp'] ?? 0);
    
    // Color Logic
    Color color = (type == 'FIRE') ? Colors.orange : (type == 'FLOOD') ? Colors.blue : Colors.red;
    IconData icon = (type == 'FIRE') ? Icons.local_fire_department : (type == 'FLOOD') ? Icons.water_drop : Icons.medical_services;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full height if needed
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$type INCIDENT", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(DateFormat('MMM d, y • h:mm a').format(time), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            
            // Details
            _detailRow(Icons.person, "Victim Name", name),
            _detailRow(Icons.location_on, "Location", "Lat: ${alert['latitude']}, Lng: ${alert['longitude']}"),
            _detailRow(Icons.info_outline, "Description", desc),
            
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("RESOLVE"),
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Navigate to Report Screen to finish the mission
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MissionReportScreen(
                        alertId: key,
                        victimName: name,
                        incidentType: type,
                      )));
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. SHOW HISTORY LOG (The Top Right Icon) ---
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Incident History (Resolved)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              
              // LIST OF RESOLVED ALERTS
              Expanded(
                child: StreamBuilder(
                  stream: _dbRef.child('alerts').orderByChild('status').equalTo('resolved').limitToLast(50).onValue,
                  builder: (context, AsyncSnapshot snapshot) {
                    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                      return const Center(child: Text("No history records found.", style: TextStyle(color: Colors.grey)));
                    }

                    Map<dynamic, dynamic> map = snapshot.data!.snapshot.value;
                    List<MapEntry<dynamic, dynamic>> history = map.entries.toList();
                    history.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp'])); // Newest first

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final alert = history[index].value;
                        final type = (alert['type'] ?? 'General').toString().toUpperCase();
                        final time = DateTime.fromMillisecondsSinceEpoch(alert['timestamp'] ?? 0);

                        return ListTile(
                          leading: Icon(Icons.history, color: Colors.grey[400]),
                          title: Text("$type INCIDENT - RESOLVED", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("Reported on ${DateFormat('MMM d, h:mm a').format(time)}"),
                          trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ROBUST POSTING DIALOG (Responsive Fix) ---
  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String type = 'announcement'; 
    String severity = 'info'; 
    String audience = 'public'; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Post Update"),
          // Fix 1: Use SingleChildScrollView to handle vertical overflow (Keyboard)
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // --- AUDIENCE SELECTOR (Fix 2: Use Wrap instead of Row) ---
                // Wrap handles horizontal overflow automatically
                const Text("Target Audience:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0, // Gap between chips
                  runSpacing: 4.0, // Gap between lines if it wraps
                  children: [
                    ChoiceChip(
                      label: const Text("🌍 Public"),
                      selected: audience == 'public',
                      onSelected: (val) => setState(() => audience = 'public'),
                      selectedColor: Colors.blue.shade100,
                    ),
                    ChoiceChip(
                      label: const Text("🔒 Team Only"),
                      selected: audience == 'internal',
                      onSelected: (val) => setState(() => audience = 'internal'),
                      selectedColor: Colors.grey.shade300,
                    ),
                  ],
                ),
                
                const Divider(height: 24),

                // --- TYPE SELECTOR (Fix 3: Use Wrap here too) ---
                const Text("Post Type:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: const Text("Announcement"),
                      selected: type == 'announcement',
                      onSelected: (val) => setState(() => type = 'announcement'),
                      selectedColor: Colors.orange.shade100,
                    ),
                    ChoiceChip(
                      label: const Text("Event"),
                      selected: type == 'event',
                      onSelected: (val) => setState(() => type = 'event'),
                      selectedColor: Colors.green.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // --- INPUTS (Fix 4: Add scrollPadding) ---
                TextField(
                  controller: titleController,
                  // scrollPadding helps push the field up when keyboard opens
                  scrollPadding: const EdgeInsets.only(bottom: 100), 
                  decoration: const InputDecoration(
                    labelText: "Title", 
                    border: OutlineInputBorder(),
                    isDense: true, // Makes it more compact
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  scrollPadding: const EdgeInsets.only(bottom: 100),
                  decoration: const InputDecoration(
                    labelText: "Details / Description", 
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 3,
                ),
                
                // --- SEVERITY DROPDOWN ---
                if (type == 'announcement') ...[
                  const SizedBox(height: 16),
                  const Text("Severity Level:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    width: double.infinity, // Ensures full width usage
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: severity,
                        isExpanded: true, // Prevents overflow
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text("ℹ️ Info (General)", overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'warning', child: Text("⚠️ Warning (Caution)", overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'danger', child: Text("🚨 Danger (Urgent)", overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) => setState(() => severity = val!),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                
                final user = _auth.currentUser;
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                
                final postData = {
                  'title': titleController.text.trim(),
                  'body': bodyController.text.trim(),
                  'author': user?.uid ?? 'Unknown',
                  'timestamp': timestamp,
                  'type': type, 
                  'severity': severity, 
                  'audience': audience,
                  'dateString': DateFormat('MMM d').format(DateTime.now()), 
                };

                await _dbRef.child('community_posts').push().set(postData);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Posted successfully!")));
              },
              child: const Text("Post Update"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Responder Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // HISTORY BUTTON (Previously "Refresh")
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black), 
            tooltip: "Incident History",
            onPressed: _showHistorySheet, // Calls the history sheet
          )
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        icon: const Icon(Icons.edit),
        label: const Text("Post Update"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. MISSION OVERVIEW (Stats) ---
            _buildSectionHeader("Mission Overview", Icons.dashboard),
            const SizedBox(height: 12),
            StreamBuilder(
              stream: _dbRef.child('alerts').onValue,
              builder: (context, AsyncSnapshot snapshot) {
                int activeCount = 0;
                int resolvedCount = 0;
                int pendingCount = 0;

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  Map<dynamic, dynamic> values = snapshot.data!.snapshot.value;
                  values.forEach((key, value) {
                    String status = (value['status'] ?? '').toString().toLowerCase();
                    if (status == 'active') {
                      activeCount++;
                    } else if (status == 'resolved') resolvedCount++;
                    else if (status == 'pending') pendingCount++;
                  });
                }

                return Row(
                  children: [
                    Expanded(child: _buildStatCard("Active", activeCount.toString(), Colors.red)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard("Pending", pendingCount.toString(), Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard("Resolved", resolvedCount.toString(), Colors.green)),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 24),

            // --- 2. LATEST UPDATES ---
            _buildSectionHeader("Latest Updates", Icons.campaign),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: StreamBuilder(
                stream: _dbRef.child('community_posts').orderByChild('type').equalTo('announcement').limitToLast(10).onValue,
                builder: (context, AsyncSnapshot snapshot) {
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return _buildEmptyBox("No updates yet.");
                  }
                  Map<dynamic, dynamic> map = snapshot.data!.snapshot.value;
                  List<MapEntry<dynamic, dynamic>> posts = map.entries.toList();
                  posts.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index].value;
                      return _buildAnnouncementCard(
                        post['title'], 
                        post['body'], 
                        post['severity'] ?? 'info',
                        post['audience'] ?? 'public'
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // --- 3. INCOMING ALERTS (With View Action) ---
            _buildSectionHeader("Incoming Alerts", Icons.notifications_active),
            const SizedBox(height: 10),
            StreamBuilder(
              stream: _dbRef.child('alerts').orderByChild('status').equalTo('active').limitToLast(5).onValue,
              builder: (context, AsyncSnapshot snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return _buildEmptyBox("No active alerts.");
                }
                Map<dynamic, dynamic> map = snapshot.data!.snapshot.value;
                List<MapEntry<dynamic, dynamic>> alerts = map.entries.toList();
                alerts.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index].value;
                    final key = alerts[index].key; // Needed to resolve
                    return _buildAlertTile(key, alert);
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // --- 4. EVENTS ---
            _buildSectionHeader("Upcoming Events", Icons.event),
            const SizedBox(height: 10),
            StreamBuilder(
              stream: _dbRef.child('community_posts').orderByChild('type').equalTo('event').limitToLast(5).onValue,
              builder: (context, AsyncSnapshot snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return _buildEmptyBox("No upcoming events.");
                }
                Map<dynamic, dynamic> map = snapshot.data!.snapshot.value;
                List<MapEntry<dynamic, dynamic>> events = map.entries.toList();
                events.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = events[index].value;
                      return _buildEventTile(
                        event['dateString'] ?? "Now", 
                        event['title'], 
                        event['body'],
                        event['audience'] ?? 'public'
                      );
                    },
                  ),
                );
              },
            ),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[800]),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(text, style: TextStyle(color: Colors.grey[400]))),
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildAnnouncementCard(String title, String subtitle, String severity, String audience) {
    bool isInternal = audience == 'internal';
    Color bg = isInternal ? Colors.grey.shade200 : (severity == 'danger' ? Colors.red.shade50 : (severity == 'warning' ? Colors.orange.shade50 : Colors.blue.shade50));
    Color accent = isInternal ? Colors.grey.shade700 : (severity == 'danger' ? Colors.red : (severity == 'warning' ? Colors.orange : Colors.blue));

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                child: Text(isInternal ? "🔒 TEAM ONLY" : severity.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              if (!isInternal) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.public, size: 14, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildAlertTile(String key, Map alert) {
    final type = (alert['type'] ?? 'Emergency').toString().toUpperCase();
    final time = DateTime.fromMillisecondsSinceEpoch(alert['timestamp'] ?? 0);
    Color color = (type == 'FIRE') ? Colors.orange : (type == 'FLOOD') ? Colors.blue : Colors.red;
    IconData icon = (type == 'FIRE') ? Icons.local_fire_department : (type == 'FLOOD') ? Icons.water_drop : Icons.medical_services;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
        title: Text("$type ALERT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Reported ${DateFormat('h:mm a').format(time)}", style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: () => _viewAlertDetails(key, alert), // Call the View function
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(60, 30)),
          child: const Text("View", style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildEventTile(String date, String title, String time, String audience) {
    bool isInternal = audience == 'internal';
    return ListTile(
      leading: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: isInternal ? Colors.grey.shade200 : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Center(child: isInternal ? const Icon(Icons.lock, size: 20, color: Colors.grey) : Text(date, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13))),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Row(
        children: [
          if (isInternal) const Padding(padding: EdgeInsets.only(right: 4), child: Text("INTERNAL • ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}