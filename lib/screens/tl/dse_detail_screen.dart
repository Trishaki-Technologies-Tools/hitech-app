import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../models/lead_model.dart';
import '../dse/lead_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DseDetailScreen extends StatefulWidget {
  final UserModel dse;
  const DseDetailScreen({super.key, required this.dse});

  @override
  State<DseDetailScreen> createState() => _DseDetailScreenState();
}

class _DseDetailScreenState extends State<DseDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  List<LeadModel> _leads = [];
  List<dynamic> _attendanceLogs = [];
  LatLng? _lastKnownLocation;
  String? _lastLocationTime;

  @override
  void initState() {
    super.initState();
    _loadDseData();
  }

  Future<void> _loadDseData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch DSE Leads
      final leadsRes = await _apiService.get('get_leads.php?assigned_dse=${widget.dse.id}');
      List<LeadModel> fetchedLeads = [];
      if (leadsRes['status'] == 'success') {
        final List data = leadsRes['data'] ?? [];
        fetchedLeads = data.map((l) => LeadModel.fromJson(l)).toList();
      }

      // 2. Fetch DSE Attendance (Last 7 days)
      final today = DateTime.now();
      final sevenDaysAgo = today.subtract(const Duration(days: 7));
      final startStr = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);
      final endStr = DateFormat('yyyy-MM-dd').format(today);
      
      final attendanceRes = await _apiService.get(
        'tracking.php?type=attendance&user_id=${widget.dse.id}&start_date=$startStr&end_date=$endStr'
      );
      List<dynamic> fetchedAttendance = [];
      if (attendanceRes['status'] == 'success') {
        fetchedAttendance = attendanceRes['data'] ?? [];
      }

      // 3. Fetch Last Known Location
      final locationRes = await _apiService.get('tracking.php?type=location&user_id=${widget.dse.id}');
      LatLng? fetchedLocation;
      String? fetchedLocationTime;
      if (locationRes['status'] == 'success') {
        final List data = locationRes['data'] ?? [];
        if (data.isNotEmpty) {
          final latest = data.first;
          final double? lat = double.tryParse(latest['latitude']?.toString() ?? '');
          final double? lng = double.tryParse(latest['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            fetchedLocation = LatLng(lat, lng);
            fetchedLocationTime = latest['timestamp'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _leads = fetchedLeads;
          _attendanceLogs = fetchedAttendance;
          _lastKnownLocation = fetchedLocation;
          _lastLocationTime = fetchedLocationTime;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading DSE data: ${e.toString()}')),
        );
      }
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '--:--';
    try {
      final dt = DateTime.parse(timeStr);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  String _formatDate(String? timeStr) {
    if (timeStr == null) return '--';
    try {
      final dt = DateTime.parse(timeStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dse.name),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDseData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. DSE Profile, Phone & Leads Count Card
                    _buildProfileCard(),
                    const SizedBox(height: 16),

                    // 2. Tracking Status
                    _buildTrackingStatusCard(),
                    const SizedBox(height: 24),

                    // 3. Last Known Location Map
                    if (_lastKnownLocation != null) ...[
                      const Text(
                        'Last Active Location',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      _buildLocationMap(),
                      const SizedBox(height: 24),
                    ],

                    // 4. Attendance Logs Button
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DseAttendanceScreen(
                                attendanceLogs: _attendanceLogs,
                                dseName: widget.dse.name,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3F51B5), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month, color: Color(0xFF3F51B5)),
                        label: const Text(
                          'Attendance Logs - View All',
                          style: TextStyle(
                            color: Color(0xFF3F51B5),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
                child: const Icon(Icons.person, color: Color(0xFF3F51B5), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dse.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.dse.phone,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leads Generated',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_leads.length}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DseLeadsScreen(leads: _leads, dseName: widget.dse.name),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStatusCard() {
    final isOnline = _lastKnownLocation != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.location_on : Icons.location_off_outlined,
                color: isOnline ? Colors.green : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Tracking Status',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMap() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _lastKnownLocation!,
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('last_known'),
                  position: _lastKnownLocation!,
                  infoWindow: InfoWindow(
                    title: widget.dse.name,
                    snippet: 'Active at: ${_formatTime(_lastLocationTime)}',
                  ),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last ping: ${_formatDate(_lastLocationTime)} at ${_formatTime(_lastLocationTime)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DseLeadsScreen extends StatefulWidget {
  final List<LeadModel> leads;
  final String dseName;
  const DseLeadsScreen({super.key, required this.leads, required this.dseName});

  @override
  State<DseLeadsScreen> createState() => _DseLeadsScreenState();
}

class _DseLeadsScreenState extends State<DseLeadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _parseQuotationNo(String req) {
    final lines = req.split('\n');
    for (var line in lines) {
      if (line.contains(':')) {
        final index = line.indexOf(':');
        final key = line.substring(0, index).trim();
        final val = line.substring(index + 1).trim();
        if (key.toLowerCase().contains('quotation no')) {
          return val;
        }
      }
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final filteredLeads = widget.leads.where((lead) {
      final query = _searchQuery.toLowerCase();
      final quotationNo = _parseQuotationNo(lead.requirement).toLowerCase();
      return lead.customerName.toLowerCase().contains(query) ||
          lead.phone.toLowerCase().contains(query) ||
          quotationNo.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Leads of ${widget.dseName}"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search leads...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredLeads.isEmpty
                ? const Center(child: Text('No matching leads found.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredLeads.length,
                    itemBuilder: (context, index) {
                      final lead = filteredLeads[index];
                      final quotationNo = _parseQuotationNo(lead.requirement);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            lead.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${lead.phone} • ${DateFormat('MMM d, yyyy').format(lead.createdAt)}'),
                              if (quotationNo != 'N/A') ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Quotation No: $quotationNo',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DseAttendanceScreen extends StatefulWidget {
  final List<dynamic> attendanceLogs;
  final String dseName;
  const DseAttendanceScreen({super.key, required this.attendanceLogs, required this.dseName});

  @override
  State<DseAttendanceScreen> createState() => _DseAttendanceScreenState();
}

class _DseAttendanceScreenState extends State<DseAttendanceScreen> {
  List<String> _sortedDates = [];
  Map<String, List<dynamic>> _groupedLogs = {};

  @override
  void initState() {
    super.initState();
    _groupLogs();
  }

  void _groupLogs() {
    final Map<String, List<dynamic>> grouped = {};
    for (var log in widget.attendanceLogs) {
      final loginStr = log['login_time'];
      if (loginStr != null) {
        try {
          final dt = DateTime.parse(loginStr);
          final dateStr = DateFormat('yyyy-MM-dd').format(dt);
          grouped.putIfAbsent(dateStr, () => []).add(log);
        } catch (_) {}
      }
    }
    final dates = grouped.keys.toList();
    dates.sort((a, b) => b.compareTo(a));

    setState(() {
      _sortedDates = dates;
      _groupedLogs = grouped;
    });
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '--:--';
    try {
      final dt = DateTime.parse(timeStr);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  String _formatDateString(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _calculateTotalHours(List<dynamic> logs) {
    Duration total = Duration.zero;
    for (var log in logs) {
      final loginStr = log['login_time'];
      final logoutStr = log['logout_time'];
      if (loginStr != null) {
        try {
          final loginTime = DateTime.parse(loginStr);
          final logoutTime = logoutStr != null ? DateTime.parse(logoutStr) : DateTime.now();
          total += logoutTime.difference(loginTime);
        } catch (_) {}
      }
    }
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  dynamic _getFirstLoginLog(List<dynamic> logs) {
    dynamic earliestLog;
    DateTime? earliestTime;
    for (var log in logs) {
      final loginStr = log['login_time'];
      if (loginStr != null) {
        try {
          final dt = DateTime.parse(loginStr);
          if (earliestTime == null || dt.isBefore(earliestTime)) {
            earliestTime = dt;
            earliestLog = log;
          }
        } catch (_) {}
      }
    }
    return earliestLog;
  }

  dynamic _getLastLogoutLog(List<dynamic> logs) {
    dynamic latestLog;
    DateTime? latestTime;
    for (var log in logs) {
      final logoutStr = log['logout_time'];
      if (logoutStr != null) {
        try {
          final dt = DateTime.parse(logoutStr);
          if (latestTime == null || dt.isAfter(latestTime)) {
            latestTime = dt;
            latestLog = log;
          }
        } catch (_) {}
      }
    }
    return latestLog;
  }

  void _showDailyLogs(BuildContext context, String dateStr, List<dynamic> logs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logs for ${_formatDateString(dateStr)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final loginTime = log['login_time'];
                    final logoutTime = log['logout_time'];
                    final isOngoing = logoutTime == null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.login, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Login: ${_formatTime(loginTime)}',
                                    style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              if (log['login_status'] == 'early' && log['early_login_duration'] != null && log['early_login_duration'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 18, top: 2),
                                  child: Text(
                                    'Early Login (${log['early_login_duration']})',
                                    style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                                  ),
                                )
                              else if (log['login_status'] == 'late' && log['late_login_duration'] != null && log['late_login_duration'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 18, top: 2),
                                  child: Text(
                                    'Late Login (${log['late_login_duration']} late)',
                                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isOngoing)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else ...[
                                Row(
                                  children: [
                                    const Icon(Icons.logout, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Logout: ${_formatTime(logoutTime)}',
                                      style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                if (log['logout_status'] == 'early' && log['early_logout_duration'] != null && log['early_logout_duration'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Early Logout (${log['early_logout_duration']} early)',
                                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                                    ),
                                  )
                                else if (log['logout_status'] == 'late' && log['late_logout_duration'] != null && log['late_logout_duration'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Late Logout (${log['late_logout_duration']} late)',
                                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance of ${widget.dseName}"),
      ),
      body: _sortedDates.isEmpty
          ? const Center(child: Text('No attendance logs found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sortedDates.length,
              itemBuilder: (context, index) {
                final dateStr = _sortedDates[index];
                final dailyLogs = _groupedLogs[dateStr] ?? [];
                final firstLog = _getFirstLoginLog(dailyLogs);
                final lastLog = _getLastLogoutLog(dailyLogs);
                final hasOngoing = dailyLogs.any((log) => log['logout_time'] == null);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _formatDateString(dateStr),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F51B5).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Total: ${_calculateTotalHours(dailyLogs)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3F51B5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.login, size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'First Login',
                                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        firstLog != null ? _formatTime(firstLog['login_time']) : '--:--',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      if (firstLog != null) ...[
                                        if (firstLog['login_status'] == 'early' && firstLog['early_login_duration'] != null && firstLog['early_login_duration'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Early: ${firstLog['early_login_duration']}',
                                              style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
                                            ),
                                          )
                                        else if (firstLog['login_status'] == 'late' && firstLog['late_login_duration'] != null && firstLog['late_login_duration'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Late: ${firstLog['late_login_duration']}',
                                              style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.logout, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Last Logout',
                                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasOngoing ? 'Active' : (lastLog != null ? _formatTime(lastLog['logout_time']) : '--:--'),
                                        style: TextStyle(
                                          fontSize: 13, 
                                          fontWeight: FontWeight.bold, 
                                          color: hasOngoing ? Colors.blue : Colors.black87
                                        ),
                                      ),
                                      if (!hasOngoing && lastLog != null) ...[
                                        if (lastLog['logout_status'] == 'early' && lastLog['early_logout_duration'] != null && lastLog['early_logout_duration'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Early: ${lastLog['early_logout_duration']}',
                                              style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500),
                                            ),
                                          )
                                        else if (lastLog['logout_status'] == 'late' && lastLog['late_logout_duration'] != null && lastLog['late_logout_duration'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Late: ${lastLog['late_logout_duration']}',
                                              style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => _showDailyLogs(context, dateStr, dailyLogs),
                            icon: const Icon(Icons.list, size: 16, color: Color(0xFF3F51B5)),
                            label: const Text(
                              'View Logs',
                              style: TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF3F51B5).withOpacity(0.04),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
