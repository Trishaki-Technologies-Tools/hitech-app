import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/lead_model.dart';
import '../../services/export_service.dart';
import 'lead_detail_screen.dart';
import 'lead_form_screen.dart';
import 'package:intl/intl.dart';

String _parseVehicleModel(String req) {
  final lines = req.split('\n');
  for (var line in lines) {
    if (line.contains(':')) {
      final index = line.indexOf(':');
      final key = line.substring(0, index).trim().toLowerCase();
      final val = line.substring(index + 1).trim();
      if (key.contains('vehicle') || 
          key.contains('model') || 
          key.contains('variant') || 
          key.contains('destribution') || 
          key.contains('distribution')) {
        return val;
      }
    }
  }

  // Smart Fallback Content-Scanner
  final lowerReq = req.toLowerCase();
  if (lowerReq.contains('dost xl')) return 'DOST XL';
  if (lowerReq.contains('dost + xl')) return 'DOST + XL';
  if (lowerReq.contains('dost cng') || lowerReq.contains('dost + xl cng')) return 'DOST + XL CNG';
  if (lowerReq.contains('saathi')) return 'SAATHI';
  if (lowerReq.contains('bada dost')) {
    if (lowerReq.contains('i3')) return 'BADA DOST i3+';
    if (lowerReq.contains('i4')) return 'BADA DOST i4';
    if (lowerReq.contains('i5')) return 'BADA DOST i5';
    return 'BADA DOST';
  }
  if (lowerReq.contains('partner 4')) return 'Partner 4 Tyre';
  if (lowerReq.contains('partner 6')) return 'Partner 6 Tyre';
  if (lowerReq.contains('scv goods')) return 'SCV Goods Carrier';
  if (lowerReq.contains('lcv goods')) return 'LCV Goods Carrier';

  return 'Unknown';
}

String? _parseFollowUpDate(String req) {
  final lines = req.split('\n');
  for (var line in lines) {
    if (line.contains(':')) {
      final index = line.indexOf(':');
      final key = line.substring(0, index).trim();
      final val = line.substring(index + 1).trim();
      if (key.toLowerCase().contains('follow up date') || key.toLowerCase().contains('follow-up date')) {
        return val;
      }
    }
  }
  return null;
}

Widget _buildFollowUpTag(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty || dateStr.toLowerCase() == 'n/a') return const SizedBox.shrink();
  
  try {
    // Expected format: dd/MM/yyyy
    final parts = dateStr.split('/');
    if (parts.length != 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Follow-up: $dateStr",
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    
    final followDate = DateTime(year, month, day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    Color bgColor;
    Color textColor;
    String label;
    
    if (followDate.isBefore(today)) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      label = "Follow-up: $dateStr (Overdue)";
    } else if (followDate.isAfter(today)) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      label = "Follow-up: $dateStr";
    } else {
      bgColor = Colors.amber.shade50;
      textColor = Colors.amber.shade800;
      label = "Follow-up: Today ($dateStr)";
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  } catch (e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "Follow-up: $dateStr",
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class LeadListScreen extends StatefulWidget {
  const LeadListScreen({super.key});

  @override
  State<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends State<LeadListScreen> {
  final ApiService _apiService = ApiService();
  List<LeadModel> _leads = [];
  bool _isLoading = true;
  String _currentTab = 'Enquiries';

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('get_leads.php');
      if (response['status'] == 'success') {
        final List data = response['data'];
        setState(() {
          _leads = data.map((l) => LeadModel.fromJson(l)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Widget _buildTabButton(String tabName, int count) {
    final isSelected = _currentTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = tabName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F51B5) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF3F51B5) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3F51B5).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tabName == 'Leads'
                  ? Icons.assignment_outlined
                  : tabName == 'Enquiries'
                      ? Icons.question_answer_outlined
                      : Icons.menu_book_outlined,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              tabName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard(List<LeadModel> list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 1).subtract(const Duration(microseconds: 1));

    final todayCount = list.where((l) {
      final d = l.createdAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final yesterdayCount = list.where((l) {
      final d = l.createdAt;
      return d.year == yesterdayStart.year && d.month == yesterdayStart.month && d.day == yesterdayStart.day;
    }).length;

    final thisMonthCount = list.where((l) {
      final d = l.createdAt;
      return d.isAfter(startOfMonth.subtract(const Duration(microseconds: 1)));
    }).length;

    final lastMonthCount = list.where((l) {
      final d = l.createdAt;
      return d.isAfter(startOfLastMonth.subtract(const Duration(microseconds: 1))) &&
             d.isBefore(endOfLastMonth.add(const Duration(microseconds: 1)));
    }).length;

    Widget buildMetricCard(String title, int count, Color color, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
 
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.35,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        buildMetricCard('Today', todayCount, const Color(0xFF1E88E5), Icons.today),
        buildMetricCard('Yesterday', yesterdayCount, const Color(0xFFF4511E), Icons.history),
        buildMetricCard('This Month', thisMonthCount, const Color(0xFF3949AB), Icons.calendar_month),
        buildMetricCard('Last Month', lastMonthCount, const Color(0xFF00897B), Icons.date_range),
      ],
    );
  }

  void _showCloseDialog(BuildContext context, LeadModel lead) {
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 10),
              Text(
                lead.requirement.contains('Quotation No:') ? 'Close Lead' : 'Close Enquiry',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please enter the reason or remark for closing this record:',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: remarkController,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter reason/remark here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red.shade600, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Reason/remark is required to close';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final remark = remarkController.text.trim();
                  Navigator.pop(context); // close dialog
                  await _closeLeadOrEnquiry(lead, remark);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeLeadOrEnquiry(LeadModel lead, String remark) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final updatedRequirement = "${lead.requirement}\n\nClose Reason / Remark ($dateStr): $remark";

      final response = await _apiService.patch('update_lead_status.php', {
        'id': lead.id,
        'status': 'Closed',
        'requirement': updatedRequirement,
      });

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loader

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record closed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLeads();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close record: ${response['message'] ?? 'API error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error closing record: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate Leads, Enquiries, and Brochures dynamically
    final leadsOnly = _leads.where((l) => l.requirement.contains('Quotation No:')).toList();
    final brochuresOnly = _leads.where((l) => !l.requirement.contains('Quotation No:') && l.requirement.contains('Brochure')).toList();
    final enquiriesOnly = _leads.where((l) => !l.requirement.contains('Quotation No:') && !l.requirement.contains('Brochure')).toList();

    final filteredList = _currentTab == 'Leads'
        ? leadsOnly
        : _currentTab == 'Enquiries'
            ? enquiriesOnly
            : brochuresOnly;

    // Get top 3 recent items of the selected category
    final sortedLeads = List<LeadModel>.from(filteredList);
    sortedLeads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentLeads = sortedLeads.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _fetchLeads,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Sexy custom tab selector with smooth horizontal scrolling
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTabButton('Enquiries', enquiriesOnly.length),
                          const SizedBox(width: 8),
                          _buildTabButton('Leads', leadsOnly.length),
                          const SizedBox(width: 8),
                          _buildTabButton('Brochures', brochuresOnly.length),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMetricsDashboard(filteredList),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F51B5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentTab == 'Leads'
                                  ? 'Recent Leads'
                                  : _currentTab == 'Enquiries'
                                      ? 'Recent Enquiries'
                                      : 'Recent Brochures',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AllLeadsScreen(
                                  initialLeads: filteredList,
                                  title: _currentTab == 'Leads'
                                      ? 'All Leads'
                                      : _currentTab == 'Enquiries'
                                          ? 'All Enquiries'
                                          : 'All Brochures',
                                ),
                              ),
                            );
                            _fetchLeads();
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF3F51B5)),
                          label: const Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFF3F51B5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (recentLeads.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _currentTab == 'Leads'
                                    ? 'No leads found'
                                    : _currentTab == 'Enquiries'
                                        ? 'No enquiries found'
                                        : 'No brochures found',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentLeads.length,
                        itemBuilder: (context, index) {
                          final lead = recentLeads[index];
                          final quotationNo = _parseQuotationNo(lead.requirement);
                          final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(lead.createdAt);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LeadDetailScreen(lead: lead),
                                  ),
                                );
                                if (result == true) {
                                  _fetchLeads();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lead.customerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3F51B5).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _currentTab == 'Leads'
                                                ? 'PI ID: $quotationNo'
                                                : 'Model: ${_parseVehicleModel(lead.requirement)}',
                                            style: const TextStyle(
                                              color: Color(0xFF3F51B5),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 16, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          lead.phone,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_parseFollowUpDate(lead.requirement) != null) ...[
                                      const SizedBox(height: 10),
                                      _buildFollowUpTag(_parseFollowUpDate(lead.requirement)),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Flexible(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            alignment: WrapAlignment.end,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (lead.status == 'Closed')
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.cancel_outlined, size: 12, color: Colors.red),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Closed',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else if (_currentTab == 'Enquiries') ...[
                                                if (lead.status == 'Converted')
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.check_circle, size: 12, color: Colors.green),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Converted',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else ...[
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF283593),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(30),
                                                      ),
                                                      elevation: 1,
                                                    ),
                                                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                                                    label: const Text(
                                                      'Convert',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                    onPressed: () async {
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible: false,
                                                        builder: (context) => Dialog(
                                                          elevation: 0,
                                                          backgroundColor: Colors.transparent,
                                                          child: Container(
                                                            padding: const EdgeInsets.all(24),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(20),
                                                            ),
                                                            child: const Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                SizedBox(
                                                                  height: 48,
                                                                  width: 48,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 4,
                                                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF283593)),
                                                                  ),
                                                                ),
                                                                SizedBox(height: 20),
                                                                Text(
                                                                  'Converting Enquiry...',
                                                                  style: TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Color(0xFF283593),
                                                                  ),
                                                                ),
                                                                SizedBox(height: 8),
                                                                Text(
                                                                  'Preparing Lead form details...',
                                                                  style: TextStyle(
                                                                    fontSize: 13,
                                                                    color: Colors.grey,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                      await Future.delayed(const Duration(seconds: 2));
                                                      if (!context.mounted) return;
                                                      Navigator.pop(context); // Dismiss loader

                                                      final result = await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => LeadFormScreen(prefilledEnquiry: lead),
                                                        ),
                                                      );
                                                      if (result == true) {
                                                        _fetchLeads();
                                                      }
                                                    },
                                                  ),
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.red.shade600,
                                                      side: BorderSide(color: Colors.red.shade200),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(30),
                                                      ),
                                                    ),
                                                    icon: const Icon(Icons.close_rounded, size: 14),
                                                    label: const Text(
                                                      'Close',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    onPressed: () => _showCloseDialog(context, lead),
                                                  ),
                                                ],
                                              ] else if (_currentTab == 'Leads') ...[
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red.shade600,
                                                    side: BorderSide(color: Colors.red.shade200),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(30),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.close_rounded, size: 14),
                                                  label: const Text(
                                                    'Close',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  onPressed: () => _showCloseDialog(context, lead),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class AllLeadsScreen extends StatefulWidget {
  final List<LeadModel> initialLeads;
  final String title;
  const AllLeadsScreen({super.key, required this.initialLeads, required this.title});

  @override
  State<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends State<AllLeadsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  late List<LeadModel> _allLeads;
  List<LeadModel> _filteredLeads = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('get_leads.php');
      if (response['status'] == 'success') {
        final List data = response['data'];
        setState(() {
          // Re-filter the leads list based on search/filter keywords
          final allLeads = data.map((l) => LeadModel.fromJson(l)).toList();
          if (widget.title.contains('Leads')) {
            _allLeads = allLeads.where((l) => l.requirement.contains('Quotation No:')).toList();
          } else if (widget.title.contains('Enquiries')) {
            _allLeads = allLeads.where((l) => !l.requirement.contains('Quotation No:') && !l.requirement.contains('Brochure')).toList();
          } else {
            _allLeads = allLeads.where((l) => !l.requirement.contains('Quotation No:') && l.requirement.contains('Brochure')).toList();
          }
          _filteredLeads = _allLeads;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCloseDialog(BuildContext context, LeadModel lead) {
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 10),
              Text(
                lead.requirement.contains('Quotation No:') ? 'Close Lead' : 'Close Enquiry',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please enter the reason or remark for closing this record:',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: remarkController,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter reason/remark here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red.shade600, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Reason/remark is required to close';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final remark = remarkController.text.trim();
                  Navigator.pop(context); // close dialog
                  await _closeLeadOrEnquiry(lead, remark);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeLeadOrEnquiry(LeadModel lead, String remark) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final updatedRequirement = "${lead.requirement}\n\nClose Reason / Remark ($dateStr): $remark";

      final response = await _apiService.patch('update_lead_status.php', {
        'id': lead.id,
        'status': 'Closed',
        'requirement': updatedRequirement,
      });

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loader

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record closed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLeads();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close record: ${response['message'] ?? 'API error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error closing record: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _allLeads = widget.initialLeads;
    _filteredLeads = _allLeads;
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleExport(BuildContext context, {required bool isPdf, required bool share}) async {
    Navigator.pop(context); // Close bottom sheet

    // Show clean progress loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 44,
                width: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F51B5)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                share ? 'Preparing for sharing...' : 'Generating report...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F51B5),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPdf ? 'Creating PDF pages...' : 'Formatting Excel columns...',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dseName = authProvider.user?.name ?? 'DSE';

      final titleWithoutAll = widget.title.replaceAll('All ', '');
      final isLeads = titleWithoutAll.toLowerCase().contains('lead');
      final listType = isLeads ? 'leads' : 'enquiries';
      final cleanDse = dseName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
      
      final ext = isPdf ? 'pdf' : 'csv';
      final fileName = '${cleanDse}_$listType.$ext';

      // Generate the bytes in background
      final bytes = isPdf
          ? await ExportService.generatePdfReport(list: _filteredLeads, title: titleWithoutAll, dseName: dseName)
          : await ExportService.generateExcelCsvBytes(list: _filteredLeads, title: titleWithoutAll, dseName: dseName);

      // Close loader
      if (!context.mounted) return;
      Navigator.pop(context);

      if (share) {
        await ExportService.shareFile(
          bytes: bytes,
          fileName: fileName,
          shareSubject: '$titleWithoutAll Exported Report',
        );
      } else {
        final savedPath = await ExportService.saveFileToDevice(
          bytes: bytes,
          fileName: fileName,
        );

        if (savedPath != null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved: $fileName\nLocation: ${savedPath.contains('Download') ? 'Downloads Folder' : 'Documents'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          throw Exception('Could not write file to device storage.');
        }
      }
    } catch (e) {
      // Close loader if it's still open
      if (!context.mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Export failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showExportFormatPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F51B5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.import_export,
                      color: Color(0xFF3F51B5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export ${widget.title.replaceAll('All ', '')}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${_filteredLeads.length} items will be exported',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'SELECT FORMAT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              
              // PDF Option
              _buildPopupOptionCard(
                context: context,
                title: 'PDF Document (.pdf)',
                subtitle: 'Ideal for printing and sharing clean documents',
                icon: Icons.picture_as_pdf,
                iconColor: Colors.red.shade700,
                onTap: () {
                  Navigator.pop(context); // Close Format Dialog
                  _showExportActionPopup(context, isPdf: true); // Open Action Dialog
                },
              ),
              const SizedBox(height: 12),
              
              // Excel Option
              _buildPopupOptionCard(
                context: context,
                title: 'Excel Spreadsheet (.csv)',
                subtitle: 'Perfect for data analysis and Excel imports',
                icon: Icons.table_chart,
                iconColor: Colors.green.shade700,
                onTap: () {
                  Navigator.pop(context); // Close Format Dialog
                  _showExportActionPopup(context, isPdf: false); // Open Action Dialog
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportActionPopup(BuildContext context, {required bool isPdf}) {
    final formatName = isPdf ? 'PDF' : 'Excel';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close Action Dialog
                      _showExportFormatPopup(context); // Go back to Format Dialog
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose Action ($formatName)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'SELECT EXPORT METHOD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              
              // Download Option
              _buildPopupOptionCard(
                context: context,
                title: 'Download File',
                subtitle: 'Save report directly to your device storage',
                icon: Icons.download_rounded,
                iconColor: const Color(0xFF3F51B5),
                onTap: () {
                  Navigator.pop(context); // Close Action Dialog
                  _handleExport(context, isPdf: isPdf, share: false);
                },
              ),
              const SizedBox(height: 12),
              
              // Share Option
              _buildPopupOptionCard(
                context: context,
                title: 'Share / Send File',
                subtitle: 'Send instantly via WhatsApp, Email, or AirDrop',
                icon: Icons.share_rounded,
                iconColor: const Color(0xFF3F51B5),
                onTap: () {
                  Navigator.pop(context); // Close Action Dialog
                  _handleExport(context, isPdf: isPdf, share: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }


  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 1).subtract(const Duration(microseconds: 1));

    setState(() {
      _filteredLeads = _allLeads.where((lead) {
        // Text Search Filter
        final matchesSearch = lead.customerName.toLowerCase().contains(query) ||
            lead.phone.toLowerCase().contains(query) ||
            lead.requirement.toLowerCase().contains(query);

        // Date Category Filter
        bool matchesDate = true;
        if (_selectedFilter == 'Today') {
          matchesDate = lead.createdAt.year == now.year &&
              lead.createdAt.month == now.month &&
              lead.createdAt.day == now.day;
        } else if (_selectedFilter == 'Yesterday') {
          matchesDate = lead.createdAt.year == yesterdayStart.year &&
              lead.createdAt.month == yesterdayStart.month &&
              lead.createdAt.day == yesterdayStart.day;
        } else if (_selectedFilter == 'This Month') {
          matchesDate = lead.createdAt.isAfter(startOfMonth.subtract(const Duration(microseconds: 1)));
        } else if (_selectedFilter == 'Last Month') {
          matchesDate = lead.createdAt.isAfter(startOfLastMonth.subtract(const Duration(microseconds: 1))) &&
              lead.createdAt.isBefore(endOfLastMonth.add(const Duration(microseconds: 1)));
        }

        return matchesSearch && matchesDate;
      }).toList();

      // Sort by descending date
      _filteredLeads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F51B5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3F51B5) : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3F51B5).withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          if (_filteredLeads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3F51B5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Export',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => _showExportFormatPopup(context),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header Box
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Modern Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.title.contains('Leads')
                        ? 'Search by name, phone, or invoice...'
                        : 'Search by name, phone, or model...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Horizontal category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('Today'),
                      _buildFilterChip('Yesterday'),
                      _buildFilterChip('This Month'),
                      _buildFilterChip('Last Month'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // List of Filtered Leads
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLeads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_outlined, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          widget.title.contains('Leads')
                              ? 'No matching leads found'
                              : widget.title.contains('Enquiries')
                                  ? 'No matching enquiries found'
                                  : 'No matching brochures found',
                          style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try adjusting your search query or filters',
                          style: TextStyle(color: Colors.black38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredLeads.length,
                    itemBuilder: (context, index) {
                      final lead = _filteredLeads[index];
                      final quotationNo = _parseQuotationNo(lead.requirement);
                      final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(lead.createdAt);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(lead: lead),
                              ),
                            );
                            if (result == true) {
                              _fetchLeads();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lead.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3F51B5).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        widget.title.contains('Leads')
                                            ? 'PI ID: $quotationNo'
                                            : 'Model: ${_parseVehicleModel(lead.requirement)}',
                                        style: const TextStyle(
                                          color: Color(0xFF3F51B5),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      lead.phone,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_parseFollowUpDate(lead.requirement) != null) ...[
                                  const SizedBox(height: 10),
                                  _buildFollowUpTag(_parseFollowUpDate(lead.requirement)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Flexible(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (lead.status == 'Closed')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.cancel_outlined, size: 12, color: Colors.red),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Closed',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (widget.title.contains('Enquiries')) ...[
                                            if (lead.status == 'Converted')
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.check_circle, size: 12, color: Colors.green),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Converted',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else ...[
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF283593),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(30),
                                                  ),
                                                  elevation: 1,
                                                ),
                                                icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                                                label: const Text(
                                                  'Convert',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (context) => Dialog(
                                                      elevation: 0,
                                                      backgroundColor: Colors.transparent,
                                                      child: Container(
                                                        padding: const EdgeInsets.all(24),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: const Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            SizedBox(
                                                              height: 48,
                                                              width: 48,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 4,
                                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF283593)),
                                                              ),
                                                            ),
                                                            SizedBox(height: 20),
                                                            Text(
                                                              'Converting Enquiry...',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF283593),
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              'Preparing Lead form details...',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                  await Future.delayed(const Duration(seconds: 2));
                                                  if (!context.mounted) return;
                                                  Navigator.pop(context); // Dismiss loader

                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => LeadFormScreen(prefilledEnquiry: lead),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    setState(() {
                                                      lead.status = 'Converted';
                                                    });
                                                  }
                                                },
                                              ),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red.shade600,
                                                  side: BorderSide(color: Colors.red.shade200),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(30),
                                                  ),
                                                ),
                                                icon: const Icon(Icons.close_rounded, size: 14),
                                                label: const Text(
                                                  'Close',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () => _showCloseDialog(context, lead),
                                              ),
                                            ],
                                          ] else if (widget.title.contains('Leads')) ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red.shade600,
                                                side: BorderSide(color: Colors.red.shade200),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(30),
                                                ),
                                              ),
                                              icon: const Icon(Icons.close_rounded, size: 14),
                                              label: const Text(
                                                'Close',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () => _showCloseDialog(context, lead),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
