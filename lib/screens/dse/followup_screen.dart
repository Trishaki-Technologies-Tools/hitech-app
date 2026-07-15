import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/lead_model.dart';
import 'lead_detail_screen.dart';
import 'lead_form_screen.dart';
import 'package:intl/intl.dart';

class FollowupScreen extends StatefulWidget {
  const FollowupScreen({super.key});

  @override
  State<FollowupScreen> createState() => _FollowupScreenState();
}

class _FollowupScreenState extends State<FollowupScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<LeadModel> _leads = [];
  bool _isLoading = true;
  late TabController _tabController;
  final Map<String, bool> _expandedSections = {
    'enq_today': false,
    'enq_yesterday': false,
    'enq_week': false,
    'enq_month': false,
    'lead_today': false,
    'lead_yesterday': false,
    'lead_week': false,
    'lead_month': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLeads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('get_leads.php');
      if (response['status'] == 'success') {
        final List data = response['data'];
        if (mounted) {
          setState(() {
            _leads = data.map((l) => LeadModel.fromJson(l)).toList();
          });
        }
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

  Widget _buildFollowUpTag(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.toLowerCase() == 'n/a') return const SizedBox.shrink();
    
    try {
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

  DateTime? _getFollowUpDateTime(String req) {
    final dateStr = _parseFollowUpDate(req);
    if (dateStr == null || dateStr.isEmpty || dateStr.toLowerCase() == 'n/a') return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  Widget _buildStatsSummaryGrid({
    required int todayCount,
    required int overdueCount,
    required int weekCount,
    required int monthCount,
  }) {
    Widget buildStatCard(String label, String count, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            buildStatCard("Today", "$todayCount", const Color(0xFF3F51B5), Icons.today_rounded),
            const SizedBox(width: 12),
            buildStatCard("Overdue", "$overdueCount", const Color(0xFFE53935), Icons.history_rounded),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            buildStatCard("This Week", "$weekCount", const Color(0xFF4CAF50), Icons.date_range_rounded),
            const SizedBox(width: 12),
            buildStatCard("This Month", "$monthCount", const Color(0xFF00ACC1), Icons.calendar_month_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<LeadModel> items,
    required String sectionKey,
  }) {
    final isExpanded = _expandedSections[sectionKey] ?? false;
    final displayItems = isExpanded ? items : items.take(3).toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items.isEmpty
                            ? 'No pending follow-ups'
                            : '${items.length} follow-up${items.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F5)),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'All caught up! No tasks here.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Column(
                  children: displayItems.map((lead) => _buildLeadItem(lead)).toList(),
                ),
              ),
              if (items.length > 3) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _expandedSections[sectionKey] = !isExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18),
                    label: Text(
                      isExpanded ? 'Show Less' : 'View All (${items.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeadItem(LeadModel lead) {
    final quotationNo = _parseQuotationNo(lead.requirement);
    final isEnquiry = !lead.requirement.contains('Quotation No:') && !lead.requirement.contains('Brochure');
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(lead.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
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
                        fontSize: 15,
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
                      isEnquiry
                          ? 'Model: ${_parseVehicleModel(lead.requirement)}'
                          : 'PI ID: $quotationNo',
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
                  const Icon(Icons.phone_outlined, size: 14, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    lead.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFollowUpTag(_parseFollowUpDate(lead.requirement)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 11,
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
                                Icon(Icons.cancel_outlined, size: 11, color: Colors.red),
                                SizedBox(width: 4),
                                Text(
                                  'Closed',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isEnquiry) ...[
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
                                  Icon(Icons.check_circle, size: 11, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Converted',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 9,
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 1,
                              ),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 12),
                              label: const Text(
                                'Convert',
                                style: TextStyle(
                                  fontSize: 10,
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 12),
                              label: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _showCloseDialog(context, lead),
                            ),
                          ],
                        ] else ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 12),
                            label: const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 10,
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
  }

  Widget _buildCategorizedFollowupView(List<LeadModel> list, String prefix) {


    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final endOfWeek = todayDate.add(Duration(days: 7 - todayDate.weekday));

    List<LeadModel> todayList = [];
    List<LeadModel> yesterdayList = [];
    List<LeadModel> weekList = [];
    List<LeadModel> monthList = [];

    for (var lead in list) {
      final fDate = _getFollowUpDateTime(lead.requirement);
      if (fDate == null) continue;

      if (fDate.isAtSameMomentAs(todayDate)) {
        todayList.add(lead);
      } else if (fDate.isBefore(todayDate)) {
        yesterdayList.add(lead);
      } else if (fDate.isAfter(todayDate) && !fDate.isAfter(endOfWeek)) {
        weekList.add(lead);
      } else {
        monthList.add(lead);
      }
    }

    int compareFollowUpDates(LeadModel a, LeadModel b) {
      final dateA = _getFollowUpDateTime(a.requirement) ?? DateTime(1970);
      final dateB = _getFollowUpDateTime(b.requirement) ?? DateTime(1970);
      return dateA.compareTo(dateB);
    }

    todayList.sort(compareFollowUpDates);
    weekList.sort(compareFollowUpDates);
    monthList.sort(compareFollowUpDates);
    yesterdayList.sort((a, b) {
      final dateA = _getFollowUpDateTime(a.requirement) ?? DateTime(1970);
      final dateB = _getFollowUpDateTime(b.requirement) ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      children: [
        _buildStatsSummaryGrid(
          todayCount: todayList.length,
          overdueCount: yesterdayList.length,
          weekCount: weekList.length,
          monthCount: monthList.length,
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: "Today's Follow-ups",
          icon: Icons.today_rounded,
          color: const Color(0xFF3F51B5),
          items: todayList,
          sectionKey: '${prefix}_today',
        ),
        _buildSectionCard(
          title: "Yesterday & Overdue",
          icon: Icons.history_rounded,
          color: const Color(0xFFE53935),
          items: yesterdayList,
          sectionKey: '${prefix}_yesterday',
        ),
        _buildSectionCard(
          title: "This Week",
          icon: Icons.date_range_rounded,
          color: const Color(0xFF4CAF50),
          items: weekList,
          sectionKey: '${prefix}_week',
        ),
        _buildSectionCard(
          title: "This Month & Beyond",
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF00ACC1),
          items: monthList,
          sectionKey: '${prefix}_month',
        ),
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
    final enquiriesFollowup = _leads.where((l) {
      final hasFollowUp = _parseFollowUpDate(l.requirement) != null;
      final isLead = l.requirement.contains('Quotation No:');
      final isBrochure = l.requirement.contains('Brochure');
      return !isLead && !isBrochure && hasFollowUp && l.status != 'Closed';
    }).toList();

    final leadsFollowup = _leads.where((l) {
      final hasFollowUp = _parseFollowUpDate(l.requirement) != null;
      final isLead = l.requirement.contains('Quotation No:');
      return isLead && hasFollowUp && l.status != 'Closed';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Follow-up Tasks'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3F51B5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3F51B5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(
              text: 'Enquiries',
              icon: Icon(Icons.question_answer_outlined),
            ),
            Tab(
              text: 'Leads',
              icon: Icon(Icons.assignment_outlined),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeads,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildCategorizedFollowupView(enquiriesFollowup, 'enq'),
                  _buildCategorizedFollowupView(leadsFollowup, 'lead'),
                ],
              ),
      ),
    );
  }
}
