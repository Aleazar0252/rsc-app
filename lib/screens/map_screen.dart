import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'responder/mission_report_screen.dart'; 
import 'alert_screen.dart';
import 'camera_screen.dart';

// Helper class for search logic
class MapLocation {
  final String name;
  final String address; // NEW: Barangay/Address field
  final String type; 
  final LatLng point;
  final IconData icon;
  final Color color;

  MapLocation({
    required this.name, 
    required this.address, 
    required this.type, 
    required this.point, 
    required this.icon, 
    required this.color
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  final _dbRef = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  final LatLng _currentCenter = const LatLng(7.7844, 122.5870); 
  LatLng? _myLocation;
  
  // Data Storage
  Map<dynamic, dynamic> _rawAlertsData = {}; 
  List<Marker> _alertMarkers = []; 
  final List<MapLocation> _staticLocations = []; 
  
  // State
  bool _isResponderOrCaptain = false;
  
  // MAP LAYER TOGGLES
  bool _showLandmarksLayer = true; 
  bool _showIncidentsLayer = true; 
  bool _showRecentOnly = true; 
  
  // LEGEND VIEW TOGGLE
  bool _viewLegendLandmarks = false; 

  List<MapLocation> _searchResults = []; 
  bool _isSearching = false;

  StreamSubscription? _alertSubscription;

  // The strict camera boundaries (Zamboanga Sibugay)
  final LatLngBounds _sibugayBounds = LatLngBounds(
    const LatLng(7.2000, 122.0000),
    const LatLng(8.2000, 123.5000),
  );

  @override
  void initState() {
    super.initState();
    _loadStaticData(); 
    _determinePosition();
    _checkRoleAndListen();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. DATA & FILTERING ---
  void _listenToAlerts() {
    _alertSubscription = _dbRef.child('alerts').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        _rawAlertsData = data;
        _updateVisibleMarkers();
      }
    });
  }

  void _updateVisibleMarkers() {
    final List<Marker> newMarkers = [];
    final now = DateTime.now();

    _rawAlertsData.forEach((key, value) {
      if (value['status'] == 'active') {
        if (_showRecentOnly) {
          final timestamp = value['timestamp'] ?? 0;
          final alertTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final difference = now.difference(alertTime).inHours;
          if (difference > 24) return; 
        }

        final String type = (value['type'] ?? 'EMERGENCY').toString().toUpperCase();
        final String name = value['name'] ?? "Unknown";
        final lat = value['latitude'];
        final lng = value['longitude'];
        
        newMarkers.add(
          _buildGoogleAlertPin(key, type, name, LatLng(lat, lng))
        );
      }
    });

    if (mounted) {
      setState(() => _alertMarkers = newMarkers);
    }
  }

  void _loadStaticData() {
    // Added specific Barangays/Addresses here
    final rawLandmarks = [
      MapLocation(name: "Municipal Hall", address: "Poblacion, Ipil", type: "GOV", point: const LatLng(7.7844, 122.5870), icon: Icons.account_balance, color: Colors.blueGrey),
      MapLocation(name: "Provincial Hospital", address: "Sanito, Ipil", type: "HOSPITAL", point: const LatLng(7.7860, 122.5900), icon: Icons.local_hospital, color: Colors.pink),
      MapLocation(name: "Ipil Police Station", address: "Don Andres, Ipil", type: "POLICE", point: const LatLng(7.7830, 122.5850), icon: Icons.local_police, color: const Color(0xFF1A237E)),
      MapLocation(name: "Fire Station Main", address: "Poblacion, Ipil", type: "FIRE", point: const LatLng(7.7820, 122.5880), icon: Icons.fire_truck, color: Colors.orange),
      MapLocation(name: "Evacuation Center 1", address: "Taway, Ipil", type: "EVAC", point: const LatLng(7.7900, 122.5800), icon: Icons.home_work, color: Colors.green),
    ];
    setState(() {
      _staticLocations.addAll(rawLandmarks);
    });
  }

  // --- 2. MARKER BUILDERS ---
  Marker _buildGoogleLandmark(MapLocation loc) {
    return Marker(
      point: loc.point,
      width: 60, height: 60,
      child: GestureDetector(
        onTap: () => _showLocationDetails(loc), 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: loc.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Icon(loc.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 2),
            Text(loc.name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black, shadows: [Shadow(color: Colors.white, blurRadius: 2)]), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Marker _buildGoogleAlertPin(String key, String type, String name, LatLng point) {
    final style = _getMarkerStyle(type);
    return Marker(
      point: point, width: 50, height: 50, alignment: Alignment.topCenter, 
      child: GestureDetector(
        onTap: () => _showIncidentDetails(key, type, name, point),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.location_on, size: 50, color: style.color),
            Positioned(top: 8, child: Icon(style.icon, size: 20, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // --- 3. SEARCH LOGIC ---
  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    final results = _staticLocations.where((loc) => 
      loc.name.toLowerCase().contains(query.toLowerCase()) || 
      loc.type.toLowerCase().contains(query.toLowerCase())
    ).toList();
    setState(() { _searchResults = results; _isSearching = true; });
  }

  void _selectSearchResult(MapLocation loc) {
    _searchController.clear();
    setState(() { _isSearching = false; _searchResults = []; });
    FocusScope.of(context).unfocus(); 
    _mapController.move(loc.point, 16.0);
    _showLocationDetails(loc);
  }

  // --- 4. DETAILS SHEETS ---
  void _showLocationDetails(MapLocation loc) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: loc.color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(loc.icon, color: loc.color, size: 30)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(loc.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Name
                      Text(loc.address, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)), // Address / Barangay
                      Text(loc.type, style: TextStyle(color: Colors.grey[600], fontSize: 12)), // Type
                    ]
                  )
                ),
              ],
            ),
            const Divider(height: 30),
            _infoRow(Icons.location_on_outlined, "Coordinates", "${loc.point.latitude.toStringAsFixed(4)}, ${loc.point.longitude.toStringAsFixed(4)}"),
            const SizedBox(height: 20), 
          ],
        ),
      ),
    );
  }

  void _showIncidentDetails(String alertId, String type, String name, LatLng point) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, 
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _getMarkerStyle(type).color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(_getMarkerStyle(type).icon, color: _getMarkerStyle(type).color, size: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text("$type INCIDENT", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text("Ipil, Zamboanga Sibugay", style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)), // Barangay Placeholder
                      Text("Reported by $name", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ]
                  )
                ),
              ],
            ),
            const Divider(height: 30),
            _infoRow(Icons.gps_fixed, "GPS Location", "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}"),
            const SizedBox(height: 24),
            if (_isResponderOrCaptain)
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.assignment_turned_in_outlined), label: const Text("RESOLVE & REPORT", style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => MissionReportScreen(alertId: alertId, victimName: name, incidentType: type))); })),
            const SizedBox(height: 10), 
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(icon, size: 20, color: Colors.grey), const SizedBox(width: 12), Text("$label: ", style: const TextStyle(color: Colors.grey)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Monospace')))]));
  }

  // --- 5. BUILD UI ---
  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      key: _scaffoldKey, 
      resizeToAvoidBottomInset: false, 
      
      // --- DRAWER (MENU) ---
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("Live Map Layers", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("Configure visibility & filters", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            
            // --- 1. LANDMARKS TOGGLE ---
            SwitchListTile(
              title: const Text("Show Landmarks"),
              subtitle: const Text("Hospitals, Police, etc."),
              secondary: const Icon(Icons.location_city, color: Colors.blue),
              value: _showLandmarksLayer,
              activeThumbColor: Colors.blue,
              dense: true,
              onChanged: (val) => setState(() => _showLandmarksLayer = val),
            ),

            // --- 2. INCIDENTS TOGGLE ---
            SwitchListTile(
              title: const Text("Show Incidents"),
              subtitle: const Text("Live emergencies"),
              secondary: const Icon(Icons.warning, color: Colors.red),
              value: _showIncidentsLayer,
              activeThumbColor: Colors.red,
              dense: true,
              onChanged: (val) => setState(() => _showIncidentsLayer = val),
            ),

            // --- 3. RECENT FILTER ---
            if (_showIncidentsLayer)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: SwitchListTile(
                  title: const Text("Recent Only (24h)"),
                  subtitle: const Text("Hide old reports"),
                  secondary: const Icon(Icons.history, color: Colors.orange),
                  value: _showRecentOnly,
                  activeThumbColor: Colors.orange,
                  dense: true,
                  onChanged: (val) {
                    setState(() => _showRecentOnly = val);
                    _updateVisibleMarkers(); 
                  },
                ),
              ),

            const Divider(),

            // --- LEGEND HEADER (With SWAP Button) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text("LEGEND GUIDE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const Spacer(),
                  Text(_viewLegendLandmarks ? "Landmarks" : "Incidents", style: TextStyle(fontSize: 12, color: _viewLegendLandmarks ? Colors.blue : Colors.deepOrange, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => setState(() => _viewLegendLandmarks = !_viewLegendLandmarks),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _viewLegendLandmarks ? Colors.blue.withOpacity(0.1) : Colors.deepOrange.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.swap_horiz, size: 20, color: _viewLegendLandmarks ? Colors.blue : Colors.deepOrange),
                    ),
                  ),
                ],
              ),
            ),

            // --- LEGEND LIST ---
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _viewLegendLandmarks
                ? [
                    _drawerLegendItem(Icons.account_balance, Colors.blueGrey, "Municipal Hall"),
                    _drawerLegendItem(Icons.local_hospital, Colors.pink, "Hospital"),
                    _drawerLegendItem(Icons.local_police, const Color(0xFF1A237E), "Police Station"),
                    _drawerLegendItem(Icons.home_work, Colors.green, "Evacuation Center"),
                  ]
                : [
                    _drawerLegendItem(Icons.local_fire_department, Colors.deepOrange, "Fire Incident"),
                    _drawerLegendItem(Icons.water_drop, Colors.blue, "Flood Area"),
                    _drawerLegendItem(Icons.medical_services, Colors.red, "Medical Emergency"),
                    _drawerLegendItem(Icons.car_crash, Colors.purple, "Accident"),
                    _drawerLegendItem(Icons.shield, Colors.black, "Crime / Hazard"),
                  ],
              ),
            )
          ],
        ),
      ),

      body: Stack(
        children: [
          // MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 14.5,
              cameraConstraint: CameraConstraint.contain(bounds: _sibugayBounds),
              onTap: (_, __) => FocusScope.of(context).unfocus(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'fire.rsc',
              ),
              MarkerLayer(
                markers: [
                  if (_showLandmarksLayer) ..._staticLocations.map((loc) => _buildGoogleLandmark(loc)),
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!, width: 60, height: 60,
                      child: Container(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]), child: const Icon(Icons.my_location, color: Colors.blue, size: 24)),
                    ),
                  if (_showIncidentsLayer) ..._alertMarkers,
                ],
              ),
            ],
          ),

          // SEARCH BAR
          Positioned(
            top: padding.top + 10, left: 16, right: 16,
            child: Column(
              children: [
                Container(
                  height: 50,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _runSearch,
                    decoration: InputDecoration(
                      hintText: "Search Live Map...", 
                      border: InputBorder.none,
                      prefixIcon: IconButton(icon: const Icon(Icons.menu, color: Colors.black54), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
                      suffixIcon: _isSearching ? IconButton(icon: const Icon(Icons.close), onPressed: () { _searchController.clear(); _runSearch(""); }) : const CircleAvatar(radius: 12, backgroundColor: Colors.transparent, child: Icon(Icons.search, color: Colors.grey)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero, shrinkWrap: true, itemCount: _searchResults.length,
                      itemBuilder: (ctx, index) {
                        final loc = _searchResults[index];
                        return ListTile(
                          leading: Icon(loc.icon, color: Colors.grey),
                          title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(loc.address, style: const TextStyle(fontSize: 10)), // Show Address in Search
                          onTap: () => _selectSearchResult(loc),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // REPORT BUTTON
          Positioned(
            bottom: padding.bottom + 20, right: 20,
            child: FloatingActionButton.extended(
              heroTag: "sos",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomCameraScreen())),
              backgroundColor: Colors.white, foregroundColor: Colors.red, elevation: 4,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text("REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          
          // GPS BUTTON
          Positioned(
            bottom: padding.bottom + 90, right: 20,
            child: FloatingActionButton.small(heroTag: "gps", backgroundColor: Colors.white, onPressed: _determinePosition, child: const Icon(Icons.my_location, color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _drawerLegendItem(IconData icon, Color color, String label) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  // --- UPDATED GEOLOCATOR WITH SAFETY CHECK ---
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
      
      // FIX: Only move the camera if the GPS is actually inside Zamboanga!
      if (_sibugayBounds.contains(_myLocation!)) {
         _mapController.move(_myLocation!, 15.0);
      } else {
         debugPrint("User is outside the map boundaries. Centering on default.");
         _mapController.move(_currentCenter, 14.5);
      }
    }
  }

  Future<void> _checkRoleAndListen() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _dbRef.child('users/${user.uid}/role').get();
      final role = snapshot.value as String?;
      if (role == 'responder' || role == 'captain' || role == 'resident') {
        if (mounted) setState(() => _isResponderOrCaptain = (role != 'resident'));
        _listenToAlerts();
      }
    }
  }

  ({IconData icon, Color color}) _getMarkerStyle(String type) {
    switch (type) {
      case 'FIRE': return (icon: Icons.local_fire_department, color: Colors.deepOrange);
      case 'FLOOD': return (icon: Icons.water_drop, color: Colors.blue);
      case 'MEDICAL': return (icon: Icons.medical_services, color: Colors.red);
      case 'ACCIDENT': return (icon: Icons.car_crash, color: Colors.purple);
      default: return (icon: Icons.warning_amber_rounded, color: Colors.red);
    }
  }
}