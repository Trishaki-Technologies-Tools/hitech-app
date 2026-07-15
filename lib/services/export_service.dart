import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lead_model.dart';

class ExportService {
  // Helper to parse key-value lines from the multiline requirement string
  static String _parseKey(String req, String keyName) {
    final lines = req.split('\n');
    for (var line in lines) {
      if (line.contains(':')) {
        final index = line.indexOf(':');
        final key = line.substring(0, index).trim().toLowerCase();
        final val = line.substring(index + 1).trim();
        if (key == keyName.toLowerCase() || key.contains(keyName.toLowerCase())) {
          return val;
        }
      }
    }
    return '';
  }

  // Highly robust vehicle model parser with smart fallback scanners
  static String _parseVehicleModel(String req) {
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

    // Smart Fallback Content-Scanner: checks the raw string for known commercial vehicles
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

    return 'SCV Goods Carrier'; // Clean, standard default fallback instead of 'Unknown'
  }

  static String _parseQuotationNo(String req) {
    final val = _parseKey(req, 'Quotation No');
    return val.isNotEmpty ? val : 'N/A';
  }

  static String _parseAddress(String req) {
    final addr = _parseKey(req, 'Address');
    if (addr.isNotEmpty) return addr;
    final place = _parseKey(req, 'Place');
    if (place.isNotEmpty) return place;
    return 'N/A';
  }

  static String _parseFollowUpDate(String req) {
    final date = _parseKey(req, 'Follow Up Date');
    return date.isNotEmpty ? date : 'N/A';
  }

  // Pricing fields extraction helpers (strips the Rupee symbol to return a clean numeric value)
  static String _parsePriceNumeric(String req, String label) {
    final val = _parseKey(req, label);
    if (val.isEmpty) return '0';
    return val.replaceAll('₹', '').trim();
  }

  /// Generates a beautiful landscape PDF report dynamically tailored to the report type
  static Future<Uint8List> generatePdfReport({
    required List<LeadModel> list,
    required String title,
    required String dseName,
  }) async {
    final pdf = pw.Document();
    final navyBlue = PdfColor.fromHex('#0D3B66');
    final cleanTitle = title.replaceAll('All ', '').trim();
    final isLeads = cleanTitle.toLowerCase().contains('lead');
    final isEnquiries = cleanTitle.toLowerCase().contains('enquir');
    
    // Dynamic headers based on exact specifications
    final List<String> headers = isLeads
        ? [
            '#',
            'Customer Name',
            'Phone',
            'Quotation No',
            'Created Date',
            'Address',
            'Model',
            'Ex-Showroom',
            'Discount',
            'Net Invoice',
            'Speed Gov',
            'Insurance',
            'Road Tax',
            'Handling',
            'Accessories',
            'FAS Tag',
            'TCS',
            'Total On-Road',
            'Amount in Words'
          ]
        : isEnquiries
            ? ['#', 'Customer Name', 'Customer Phone Number', 'Follow-up Date', 'Enquiry Date and Time', 'Model', 'Place of the Customer']
            : ['#', 'Customer Name', 'Phone', 'Vehicle Model', 'Details / Address', 'Status', 'Assigned DSE', 'Date'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Landscape format for grid spacing
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HITECH MOTORS & AUTOMOBILES PVT LTD',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: navyBlue,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Report: $cleanTitle List',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Generated Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DSE Name: $dseName',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Total Count: ${list.length} records',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: navyBlue),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: list.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final lead = entry.value;
                final dateStr = DateFormat('dd-MMM-yyyy').format(lead.createdAt);
                
                final vehicle = _parseVehicleModel(lead.requirement);
                final quotationNo = _parseQuotationNo(lead.requirement);
                final address = _parseAddress(lead.requirement);
                final followUp = _parseFollowUpDate(lead.requirement);
                
                if (isLeads) {
                  final exShowroom = _parsePriceNumeric(lead.requirement, 'Ex Showroom Price');
                  final discount = _parsePriceNumeric(lead.requirement, 'Discount');
                  final netInvoice = _parsePriceNumeric(lead.requirement, 'Net Invoice Price');
                  final speedGovernor = _parsePriceNumeric(lead.requirement, 'Speed Governor');
                  final insurance = _parsePriceNumeric(lead.requirement, 'Insurance');
                  final roadTax = _parsePriceNumeric(lead.requirement, 'Road Tax / Registration');
                  final handling = _parsePriceNumeric(lead.requirement, 'Handling Charge');
                  final accessories = _parsePriceNumeric(lead.requirement, 'Accessories');
                  final fasTag = _parsePriceNumeric(lead.requirement, 'FAS Tag');
                  final tcs = _parsePriceNumeric(lead.requirement, 'TCS');
                  final totalOnRoad = _parsePriceNumeric(lead.requirement, 'Total On Road Price');
                  final amountWords = _parseKey(lead.requirement, 'Amount in Words');

                  return [
                    idx.toString(),
                    lead.customerName,
                    lead.phone,
                    quotationNo,
                    dateStr,
                    address,
                    vehicle,
                    exShowroom,
                    discount,
                    netInvoice,
                    speedGovernor,
                    insurance,
                    roadTax,
                    handling,
                    accessories,
                    fasTag,
                    tcs,
                    totalOnRoad,
                    amountWords.isEmpty ? 'N/A' : amountWords,
                  ];
                } else if (isEnquiries) {
                  final enquiryDateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(lead.createdAt);
                  return [
                    idx.toString(),
                    lead.customerName,
                    lead.phone,
                    followUp,
                    enquiryDateTime,
                    vehicle,
                    address,
                  ];
                } else {
                  return [
                    idx.toString(),
                    lead.customerName,
                    lead.phone,
                    vehicle,
                    'Place: $address',
                    lead.status,
                    lead.dseName ?? lead.assignedDse ?? 'N/A',
                    dateStr,
                  ];
                }
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                color: PdfColors.white, 
                fontSize: isLeads ? 5.5 : 8.5
              ),
              headerDecoration: pw.BoxDecoration(color: navyBlue),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: isLeads ? 5.0 : 8.0),
              columnWidths: isLeads
                  ? {
                      0: const pw.FixedColumnWidth(15), // S.No
                      1: const pw.FlexColumnWidth(1.2), // Name
                      2: const pw.FlexColumnWidth(1.1), // Phone
                      3: const pw.FlexColumnWidth(1.4), // Quotation No
                      4: const pw.FlexColumnWidth(1.1), // Created Date
                      5: const pw.FlexColumnWidth(1.3), // Address
                      6: const pw.FlexColumnWidth(1.2), // Model
                      7: const pw.FlexColumnWidth(0.9), // Ex-Showroom
                      8: const pw.FlexColumnWidth(0.9), // Discount
                      9: const pw.FlexColumnWidth(0.9), // Net Invoice
                      10: const pw.FlexColumnWidth(0.9), // Speed Gov
                      11: const pw.FlexColumnWidth(0.9), // Insurance
                      12: const pw.FlexColumnWidth(0.9), // Road Tax
                      13: const pw.FlexColumnWidth(0.9), // Handling
                      14: const pw.FlexColumnWidth(0.9), // Accessories
                      15: const pw.FlexColumnWidth(0.9), // FAS Tag
                      16: const pw.FlexColumnWidth(0.9), // TCS
                      17: const pw.FlexColumnWidth(1.1), // Total
                      18: const pw.FlexColumnWidth(2.0), // In Words
                    }
                  : isEnquiries
                      ? {
                          0: const pw.FixedColumnWidth(25), // S.No
                          1: const pw.FlexColumnWidth(2.0), // Name
                          2: const pw.FlexColumnWidth(1.6), // Phone
                          3: const pw.FlexColumnWidth(1.6), // Follow-up
                          4: const pw.FlexColumnWidth(2.2), // Date/Time
                          5: const pw.FlexColumnWidth(1.8), // Model
                          6: const pw.FlexColumnWidth(2.0), // Place
                        }
                      : {
                          0: const pw.FixedColumnWidth(25), // S.No
                          1: const pw.FlexColumnWidth(2.0), // Name
                          2: const pw.FlexColumnWidth(1.6), // Phone
                          3: const pw.FlexColumnWidth(2.0), // Model
                          4: const pw.FlexColumnWidth(3.0), // Details
                          5: const pw.FixedColumnWidth(60), // Status
                          6: const pw.FlexColumnWidth(1.8), // DSE
                          7: const pw.FlexColumnWidth(1.6), // Date
                        },
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a CSV format string that is dynamically tailored based on whether we are exporting Leads, Enquiries, or Brochures
  static Future<Uint8List> generateExcelCsvBytes({
    required List<LeadModel> list,
    required String title,
    required String dseName,
  }) async {
    final csvRows = <List<String>>[];
    final cleanTitle = title.replaceAll('All ', '').trim();
    final isLeads = cleanTitle.toLowerCase().contains('lead');
    final isEnquiries = cleanTitle.toLowerCase().contains('enquir');
    
    // 1. Dynamic Header Summary Metadata (First 5 Rows of Excel)
    csvRows.add(['COMPANY NAME', 'HITECH MOTORS & AUTOMOBILES PVT LTD']);
    csvRows.add(['LIST NAME', '$cleanTitle List']);
    csvRows.add(['DSE NAME', dseName]);
    csvRows.add(['TOTAL COUNT', '${list.length} records']);
    csvRows.add(['GENERATED DATE', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())]);
    csvRows.add([]); // Empty spacer row to separate metadata from the table

    // 2. Dynamic Table Headers based on exact specifications
    final List<String> headers = isLeads
        ? [
            'S.No',
            'Customer Name',
            'Customer Phone Number',
            'Quotation Number',
            'Lead Created Date',
            'Customer Address',
            'Vehicle Model',
            'Ex Showroom Price',
            'Discount',
            'Net Invoice Price',
            'Speed Governor',
            'Insurance',
            'Road Tax / Registration',
            'Handling Charges',
            'Accessories',
            'FAS Tag',
            'TCS',
            'Total On Road Price',
            'In Words'
          ]
        : isEnquiries
            ? [
                'S.No',
                'Customer Name',
                'Customer Phone Number',
                'Follow-up Date',
                'Enquiry Date and Time',
                'Model',
                'Place of the Customer'
              ]
            : [
                'S.No',
                'Customer Name',
                'Phone',
                'Status',
                'Vehicle Model',
                'Address / Place',
                'Assigned DSE Name',
                'Created Date'
              ];
          
    csvRows.add(headers);
    
    // 3. Dynamic Data Rows
    for (var i = 0; i < list.length; i++) {
      final lead = list[i];
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(lead.createdAt);
      
      final vehicle = _parseVehicleModel(lead.requirement);
      final quotationNo = _parseQuotationNo(lead.requirement);
      final address = _parseAddress(lead.requirement);
      final followUp = _parseFollowUpDate(lead.requirement);
      
      String cleanField(String val) {
        final sanitized = val.replaceAll('\r', '').replaceAll('\n', ' | ');
        if (sanitized.contains(',') || sanitized.contains('"')) {
          return '"${sanitized.replaceAll('"', '""')}"';
        }
        return sanitized;
      }
      
      if (isLeads) {
        final exShowroom = _parsePriceNumeric(lead.requirement, 'Ex Showroom Price');
        final discount = _parsePriceNumeric(lead.requirement, 'Discount');
        final netInvoice = _parsePriceNumeric(lead.requirement, 'Net Invoice Price');
        final speedGovernor = _parsePriceNumeric(lead.requirement, 'Speed Governor');
        final insurance = _parsePriceNumeric(lead.requirement, 'Insurance');
        final roadTax = _parsePriceNumeric(lead.requirement, 'Road Tax / Registration');
        final handling = _parsePriceNumeric(lead.requirement, 'Handling Charge');
        final accessories = _parsePriceNumeric(lead.requirement, 'Accessories');
        final fasTag = _parsePriceNumeric(lead.requirement, 'FAS Tag');
        final tcs = _parsePriceNumeric(lead.requirement, 'TCS');
        final totalOnRoad = _parsePriceNumeric(lead.requirement, 'Total On Road Price');
        final amountWords = _parseKey(lead.requirement, 'Amount in Words');

        csvRows.add([
          (i + 1).toString(),
          cleanField(lead.customerName),
          cleanField(lead.phone),
          cleanField(quotationNo),
          cleanField(dateStr),
          cleanField(address),
          cleanField(vehicle),
          cleanField(exShowroom),
          cleanField(discount),
          cleanField(netInvoice),
          cleanField(speedGovernor),
          cleanField(insurance),
          cleanField(roadTax),
          cleanField(handling),
          cleanField(accessories),
          cleanField(fasTag),
          cleanField(tcs),
          cleanField(totalOnRoad),
          cleanField(amountWords.isEmpty ? 'N/A' : amountWords),
        ]);
      } else if (isEnquiries) {
        csvRows.add([
          (i + 1).toString(),
          cleanField(lead.customerName),
          cleanField(lead.phone),
          cleanField(followUp),
          cleanField(dateStr),
          cleanField(vehicle),
          cleanField(address),
        ]);
      } else {
        csvRows.add([
          (i + 1).toString(),
          cleanField(lead.customerName),
          cleanField(lead.phone),
          cleanField(lead.status),
          cleanField(vehicle),
          cleanField(address),
          cleanField(lead.dseName ?? 'N/A'),
          cleanField(dateStr),
        ]);
      }
    }
    
    // Combine rows with newlines
    final csvString = csvRows.map((row) => row.join(',')).join('\r\n');
    
    // Encode in UTF-8
    final csvBytes = utf8.encode(csvString);
    
    // Add UTF-8 BOM so Excel opens it with proper formatting automatically
    final bom = [0xEF, 0xBB, 0xBF];
    
    return Uint8List.fromList([...bom, ...csvBytes]);
  }

  /// Saves the bytes to the device's public Download directory (with automatic fallback to other safe directories)
  static Future<String?> saveFileToDevice({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        // Direct save to public /storage/emulated/0/Download
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Ask for storage permission if directory doesn't exist
          var status = await Permission.storage.request();
          if (!status.isGranted) {
            // Fallback to app's external files directory which doesn't need permissions
            directory = await getExternalStorageDirectory();
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      directory ??= await getTemporaryDirectory();

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      // Fallback: save to temp directory which is guaranteed to be writable
      try {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath;
      } catch (innerError) {
        return null;
      }
    }
  }

  /// Shares the file using native share sheet without opening it
  static Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String shareSubject,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: shareSubject,
    );
  }
}
