import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/lead_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/quotation_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../services/pdf_generator_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'pdf_viewer_screen.dart';
import 'lead_form_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final LeadModel lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  final ApiService _apiService = ApiService();
  final QuotationService _quotationService = QuotationService();
  bool _isLoading = false;
  late String _currentStatus;
  List<dynamic> _quotations = [];

  final List<String> _statusOptions = [
    'New',
    'Cold',
    'Warm',
    'Hot',
    'Interested',
    'Not Interested',
    'Follow-up',
    'Closed',
    'Converted'
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.lead.status;
    if (!_statusOptions.contains(_currentStatus)) {
      _currentStatus = _statusOptions.first;
    }
    _fetchQuotations();
  }

  void _fetchQuotations() async {
    try {
      final res = await _quotationService.getQuotations(widget.lead.id.toString());
      setState(() => _quotations = res);
    } catch (e) {
      debugPrint('Error fetching quotations: $e');
    }
  }

  void _pickAndUploadQuotation() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() => _isLoading = true);
      try {
        await _quotationService.uploadQuotation(widget.lead.id.toString(), file);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation uploaded!')));
        _fetchQuotations();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.patch('update_lead_status.php', {
        'id': widget.lead.id,
        'status': newStatus,
      });

      if (response['status'] == 'success') {
        setState(() => _currentStatus = newStatus);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCloseDialog(BuildContext context) {
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
                widget.lead.requirement.contains('Quotation No:') ? 'Close Lead' : 'Close Enquiry',
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
                  await _closeLeadOrEnquiry(remark);
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

  Future<void> _closeLeadOrEnquiry(String remark) async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final updatedRequirement = "${widget.lead.requirement}\n\nClose Reason / Remark ($dateStr): $remark";

      final response = await _apiService.patch('update_lead_status.php', {
        'id': widget.lead.id,
        'status': 'Closed',
        'requirement': updatedRequirement,
      });

      if (response['status'] == 'success') {
        setState(() {
          _currentStatus = 'Closed';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record closed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close record: ${response['message'] ?? 'API error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error closing record: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _launchWhatsApp(String phone, String name, String requirement) async {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    
    final message = """
*TRACKFORCE - OFFICIAL QUOTATION*
Date: $dateStr
--------------------------------------
Dear $name,

This is a follow-up regarding your requirement:
_$requirement _

You can reach out here for any further details.

Best Regards,
*TrackForce Team*
--------------------------------------
""";

    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  void _viewQuotationPdf() async {
    final parsed = _parseRequirement(widget.lead.requirement);
    if (parsed == null) return;

    String cleanAmt(String? val) {
      if (val == null || val.isEmpty) return '0.00';
      return val.replaceAll('₹', '').replaceAll(',', '').trim();
    }

    setState(() => _isLoading = true);
    try {
      final File pdfFile = await PdfGeneratorService.generateQuotationPdf(
        quotationNo: parsed['quotationNo'] ?? '',
        dateStr: parsed['date'] ?? '',
        customerName: widget.lead.customerName,
        address: parsed['address'] ?? '',
        phone: widget.lead.phone,
        vehicle: parsed['vehicle'] ?? '',
        exShowroom: cleanAmt(parsed['exShowroom']),
        discount: cleanAmt(parsed['discount']),
        netInvoice: cleanAmt(parsed['netInvoice']),
        speedGovernor: cleanAmt(parsed['speedGovernor']),
        insurance: cleanAmt(parsed['insurance']),
        roadTax: cleanAmt(parsed['roadTax']),
        handling: cleanAmt(parsed['handling']),
        accessories: cleanAmt(parsed['accessories']),
        fasTag: cleanAmt(parsed['fasTag']),
        tcs: cleanAmt(parsed['tcs']),
        totalOnRoad: cleanAmt(parsed['totalOnRoad']),
        amountWords: parsed['amountWords'] ?? '',
        notes: parsed['notes'] ?? '',
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfPath: pdfFile.path,
            title: widget.lead.customerName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLead = widget.lead.requirement.contains('Quotation No:');
    final convertedId = _parseConvertedFromId(widget.lead.requirement);
    return Scaffold(
      appBar: AppBar(
        title: Text(isLead ? 'Lead Details' : 'Enquiry Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          if (isLead)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'View PDF',
              onPressed: _viewQuotationPdf,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF3F51B5),
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.lead.customerName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.lead.phone,
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                  if (widget.lead.alternatePhone != null && widget.lead.alternatePhone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Alt: ${widget.lead.alternatePhone}',
                      style: const TextStyle(fontSize: 15, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                    ),
                  ],
                  if (convertedId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Converted from Enquiry: ID $convertedId',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildRequirementWidget(widget.lead.requirement),
            const SizedBox(height: 24),
            _buildInfoSection('Created At', DateFormat('MMM d, yyyy - hh:mm a').format(widget.lead.createdAt)),
            const SizedBox(height: 32),
            if (_currentStatus == 'Closed')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Closed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              )
            else if (_currentStatus != 'Converted') ...[
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  label: Text(
                    isLead ? 'Close Lead' : 'Close Enquiry',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showCloseDialog(context),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, height: 1.5)),
      ],
    );
  }

  Map<String, String>? _parseRequirement(String req) {
    if (!req.contains('Quotation No:') || !req.contains('Total On Road Price:')) {
      return null;
    }
    
    final Map<String, String> data = {};
    final lines = req.split('\n');
    for (var line in lines) {
      if (line.contains(':')) {
        final index = line.indexOf(':');
        final key = line.substring(0, index).trim();
        final val = line.substring(index + 1).trim();
        
        // Normalize keys
        if (key.contains('Quotation No')) data['quotationNo'] = val;
        else if (key.contains('Date')) data['date'] = val;
        else if (key.contains('Address')) data['address'] = val;
        else if (key.contains('Model')) data['vehicle'] = val;
        else if (key.contains('Ex Showroom Price')) data['exShowroom'] = val;
        else if (key.contains('Discount')) data['discount'] = val;
        else if (key.contains('Net Invoice Price')) data['netInvoice'] = val;
        else if (key.contains('Speed Governor')) data['speedGovernor'] = val;
        else if (key.contains('Insurance')) data['insurance'] = val;
        else if (key.contains('Road Tax')) data['roadTax'] = val;
        else if (key.contains('Handling')) data['handling'] = val;
        else if (key.contains('Accessories')) data['accessories'] = val;
        else if (key.contains('FAS Tag')) data['fasTag'] = val;
        else if (key.contains('TCS')) data['tcs'] = val;
        else if (key.contains('Total On Road Price')) data['totalOnRoad'] = val;
        else if (key.contains('Amount in Words')) data['amountWords'] = val;
        else if (key.contains('Notes')) data['notes'] = val;
      }
    }
    return data;
  }

  Widget _buildEnquiryDetails() {
    final req = widget.lead.requirement;
    final lines = req.split('\n');
    String date = DateFormat('dd/MM/yyyy').format(widget.lead.createdAt);
    String place = 'N/A';
    String vehicle = 'N/A';
    String followUpDate = 'N/A';
    String notes = '';

    for (var line in lines) {
      if (line.contains(':')) {
        final index = line.indexOf(':');
        final key = line.substring(0, index).trim().toLowerCase();
        final val = line.substring(index + 1).trim();
        if (key.contains('date') && !key.contains('follow up')) date = val;
        else if (key.contains('place')) place = val;
        else if (key.contains('vehicle')) vehicle = val;
        else if (key.contains('follow up')) followUpDate = val;
        else if (key.contains('note') && !key.contains('created via')) notes = val;
      }
    }

    Widget buildDetailTile(String label, String value, IconData icon, Color color) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enquiry Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        buildDetailTile('Date of Enquiry', date, Icons.calendar_today_outlined, const Color(0xFF3F51B5)),
        buildDetailTile('Place of Customer', place, Icons.location_on_outlined, const Color(0xFFE91E63)),
        buildDetailTile('Vehicle Model Interested', vehicle, Icons.directions_car_outlined, const Color(0xFF4CAF50)),
        buildDetailTile('Follow Up Date', followUpDate, Icons.notification_important_outlined, const Color(0xFFFF9800)),
        if (widget.lead.alternatePhone != null && widget.lead.alternatePhone!.isNotEmpty)
          buildDetailTile('Alternate Mobile Number', widget.lead.alternatePhone!, Icons.phone_iphone_outlined, const Color(0xFF00BCD4)),
        if (notes.isNotEmpty)
          buildDetailTile('Enquiry Notes', notes, Icons.notes_outlined, const Color(0xFF9C27B0)),
        const SizedBox(height: 24),
        if (_currentStatus == 'Converted')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
                SizedBox(width: 8),
                Text(
                  'Converted to Lead Successfully',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 22),
              label: const Text(
                'Convert to Lead',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    builder: (context) => LeadFormScreen(prefilledEnquiry: widget.lead),
                  ),
                );
                if (result == true) {
                  setState(() {
                    _currentStatus = 'Converted';
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enquiry converted to Lead successfully!')),
                    );
                  }
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLeadDetailsTextFormat(Map<String, String> parsed) {
    String formatAmount(String? val) {
      if (val == null || val.isEmpty) return '₹0.00';
      var clean = val.replaceAll('₹', '').replaceAll(',', '').trim();
      final number = double.tryParse(clean);
      if (number != null) {
        final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
        return formatter.format(number);
      }
      return val.startsWith('₹') ? val : '₹$val';
    }

    Widget buildPriceTile(String label, String? val, {bool isTotal = false}) {
      if (val == null || val.isEmpty || val == '0' || val == '0.0' || val == '0.00') {
        return const SizedBox.shrink();
      }
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? const Color(0xFF3F51B5) : Colors.black87,
              ),
            ),
            Text(
              formatAmount(val),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isTotal ? const Color(0xFF3F51B5) : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Quotation Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),

        // General Info Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFF3F51B5), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quotation Number', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(parsed['quotationNo'] ?? 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Color(0xFF3F51B5), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quotation Date', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(parsed['date'] ?? 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF3F51B5), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Billing Address', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(parsed['address'] ?? 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Vehicle Model
        Card(
          elevation: 0,
          color: const Color(0xFF3F51B5).withOpacity(0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF3F51B5).withOpacity(0.1), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                const Icon(Icons.directions_car_outlined, color: Color(0xFF3F51B5), size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vehicle Model Variant', style: TextStyle(fontSize: 11, color: Color(0xFF3F51B5), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(parsed['vehicle'] ?? 'N/A', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Pricing Breakdown Card
        const Text(
          'Pricing breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                buildPriceTile('Ex Showroom Price', parsed['exShowroom']),
                buildPriceTile('Discount', parsed['discount']),
                buildPriceTile('Net Invoice Price', parsed['netInvoice'], isTotal: true),
                buildPriceTile('Speed Governor', parsed['speedGovernor']),
                buildPriceTile('Insurance', parsed['insurance']),
                buildPriceTile('Road Tax / Registration', parsed['roadTax']),
                buildPriceTile('Handling Charge', parsed['handling']),
                buildPriceTile('Accessories', parsed['accessories']),
                buildPriceTile('FAS Tag', parsed['fasTag']),
                buildPriceTile('TCS', parsed['tcs']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Total Pricing Summary Badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3F51B5).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL ON ROAD PRICE',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                formatAmount(parsed['totalOnRoad']),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              if (parsed['amountWords'] != null && parsed['amountWords']!.isNotEmpty) ...[
                const Divider(color: Colors.white24, height: 24, thickness: 1),
                Text(
                  parsed['amountWords']!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
        if (parsed['notes'] != null && parsed['notes']!.isNotEmpty && parsed['notes'] != 'N/A') ...[
          const SizedBox(height: 24),
          const Text(
            'Special Notes / Remarks',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                parsed['notes']!,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String? _parseConvertedFromId(String req) {
    if (req.contains('Converted from Enquiry:')) {
      final index = req.indexOf('Converted from Enquiry:');
      final substring = req.substring(index + 'Converted from Enquiry:'.length).trim();
      return substring.split('\n').first.trim();
    }
    if (req.contains('Converted from ID:')) {
      final index = req.indexOf('Converted from ID:');
      final substring = req.substring(index + 'Converted from ID:'.length).trim();
      return substring.split('\n').first.trim();
    }
    return null;
  }

  Widget _buildRequirementWidget(String req) {
    if (!widget.lead.requirement.contains('Quotation No:')) {
      return _buildEnquiryDetails();
    }

    final parsed = _parseRequirement(req);
    if (parsed == null) {
      return _buildInfoSection('Requirement / Details', req);
    }

    return _buildLeadDetailsTextFormat(parsed);
  }
}
