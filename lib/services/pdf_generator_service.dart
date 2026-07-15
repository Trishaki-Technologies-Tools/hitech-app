import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  static Future<File> generateQuotationPdf({
    required String quotationNo,
    required String dateStr,
    required String customerName,
    required String address,
    required String phone,
    required String vehicle,
    required String exShowroom,
    required String discount,
    required String netInvoice,
    required String speedGovernor,
    required String insurance,
    required String roadTax,
    required String handling,
    required String accessories,
    required String fasTag,
    required String tcs,
    required String totalOnRoad,
    required String amountWords,
    required String notes,
  }) async {
    final pdf = pw.Document();

    final navyBlue = PdfColor.fromHex('#0D3B66');
    final darkGrey = PdfColor.fromHex('#1E1E1E');

    // Load the newly added Hitech image asset
    final hitechLogoBytes = await rootBundle.load('assets/icon/hitech_logo.png');
    final hitechLogoImage = pw.MemoryImage(hitechLogoBytes.buffer.asUint8List());

    // Load the newly added Leyland image asset
    final leylandLogoBytes = await rootBundle.load('assets/icon/leyland_logo.png');
    final leylandLogoImage = pw.MemoryImage(leylandLogoBytes.buffer.asUint8List());

    // Image-based Hitech Group logo (Enlarged and Sexy!)
    pw.Widget buildHitechLogo() {
      return pw.Container(
        width: 120,
        height: 120,
        child: pw.Image(hitechLogoImage, fit: pw.BoxFit.contain),
      );
    }

    // Image-based Ashok Leyland logo (Enlarged and Sexy!)
    pw.Widget buildAshokLeylandLogo() {
      return pw.Container(
        width: 120,
        height: 120,
        child: pw.Image(leylandLogoImage, fit: pw.BoxFit.contain),
      );
    }

    final termsList = [
      "Above prices are current ex showroom prices.",
      "Prices and statutory levis are subject to change without and prior notice and those Prevailing at the time of delivery shall be applicable.",
      "Delivery period will be reckoned from the date of receipt of Payment.",
      "All variant features are subject to change.",
      "Acceptance of advance/deposite by seller is merely an indication of an intention to sell and does not result into a contract of sale.",
      "All disputes arising between the parties hereto shall be referred to arbitration according the arbitration laws of the country.",
      "Only the courts of Belagavi shall have jurisdiction in any proceedings relating to the contract.",
      "The Company shall not be liable due to any prevention, hindrance or delay in manufacture, delivery of vehicles or accessories optional due to shortage of material, strike, riot, civil commotion accident, machenary breakdown Government policies, acts of God and nature. and all events beyond the control of the company.",
      "This is to inform all our esteemed customers that any advance payments for purchase of vehicles made by them to as are our own liabillity and our Principls M/s. Ashok leyland Ltd, are in no way, implicity or explicity responsible for any vicartious liability for there found of advance or delivery of vehicles thereof as they deal with us on a principal basis."
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: buildHitechLogo(),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'HITECH MOTORS & AUTOMOBILES PVT LTD. AL',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: navyBlue,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          "Authorised Dealer's For Ashok Leyland Light Commercial Vehicles,",
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic,
                            color: darkGrey,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          "Belagavi & Bagalkot Districts",
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: darkGrey,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2),
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'GSTIN: ',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkGrey),
                              ),
                              pw.TextSpan(
                                text: '29AAECH9228E1ZF',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Belagavi-Hubli Highway (NH4) Opp. Balaji Concrete, Halaga, Belagavi.',
                          style: pw.TextStyle(fontSize: 8, color: darkGrey),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'Sales : 7618797100/65 | Service : 7618797086 | hitechalsales@gmail.com',
                          style: pw.TextStyle(fontSize: 8, color: darkGrey),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: buildAshokLeylandLogo(),
                  ),
                ],
              ),
              pw.SizedBox(height: 1),

              // Title Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(
                  color: navyBlue,
                  border: pw.Border.all(color: navyBlue, width: 1.5),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'QUOTATION CUM PROFORMA INVOICE',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),

              // Customer Details & Quote Info Grid
              pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(color: navyBlue, width: 1.5),
                  outside: pw.BorderSide(color: navyBlue, width: 1.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(65),
                  1: const pw.FlexColumnWidth(35),
                },
                children: [
                  pw.TableRow(
                    children: [
                      // Left Column: Customer details
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Customer Name : ',
                                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                  ),
                                  pw.TextSpan(
                                    text: customerName,
                                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: darkGrey),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Address : ',
                                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                  ),
                                  pw.TextSpan(
                                    text: address.isEmpty ? 'Not Provided' : address,
                                    style: pw.TextStyle(fontSize: 9.5, color: darkGrey),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Mob : ',
                                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                  ),
                                  pw.TextSpan(
                                    text: phone,
                                    style: pw.TextStyle(fontSize: 9.5, color: darkGrey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right Column: Quotation No and Date (split horizontally)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: navyBlue, width: 1.5),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'QUOTATION No.',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                ),
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  quotationNo,
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: darkGrey),
                                ),
                              ],
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DATE :',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                ),
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  dateStr,
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: darkGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Particulars Table
              pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(color: navyBlue, width: 1.5),
                  outside: pw.BorderSide(color: navyBlue, width: 1.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(65),
                  1: const pw.FlexColumnWidth(10),
                  2: const pw.FlexColumnWidth(25),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: pw.Text(
                          'PARTICULARS',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(
                          'QTY',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: pw.Text(
                          'AMOUNT',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Row 1: Model Distribution (shows selected vehicle model)
                  _buildTableRow('Model Destribution ($vehicle)', '1', '', navyBlue, isBold: true),
                  // Row 2: Ex Showroom Price Including GST
                  _buildTableRow('Ex Showroom Price Including GST', '-', exShowroom, navyBlue),
                  // Row 3: Discount
                  _buildTableRow('Discount', '-', discount, navyBlue),
                  // Row 4: Net Invoice Price
                  _buildTableRow('Net invioce Price', '-', netInvoice, navyBlue, isBold: true, bgColor: PdfColors.grey50),
                  // Row 5: Speed Governor
                  _buildTableRow('Speed Governor', '-', speedGovernor, navyBlue),
                  // Row 6: Insurance
                  _buildTableRow('Insurance', '-', insurance, navyBlue),
                  // Row 7: Road Tax / Registration
                  _buildTableRow('Road Tax / Registation Charges', '-', roadTax, navyBlue),
                  // Row 8: Handling Charge
                  _buildTableRow('Handling Charge', '-', handling, navyBlue),
                  // Row 9: Accessories
                  _buildTableRow('Accessories', '-', accessories, navyBlue),
                  // Row 10: FAS Tag
                  _buildTableRow('FAS Tag', '-', fasTag, navyBlue),
                  // Row 11: TCS
                  _buildTableRow('TCS', '-', tcs, navyBlue),
                  // Row 12: Total On Road Price
                  _buildTableRow('Total On Road Price', '-', totalOnRoad, navyBlue, isBold: true, bgColor: PdfColors.grey100),
                ],
              ),

              // Amount in Words Bar (simulates spanning row immediately below table)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: navyBlue, width: 1.5),
                    right: pw.BorderSide(color: navyBlue, width: 1.5),
                    bottom: pw.BorderSide(color: navyBlue, width: 1.5),
                  ),
                  color: PdfColors.grey50,
                ),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Amount in words : ',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                      ),
                      pw.TextSpan(
                        text: amountWords,
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: darkGrey, fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Notes / Special Requirements (if any)
              if (notes.isNotEmpty && notes != 'N/A') ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: navyBlue, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Notes / Special Requirements:',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        notes,
                        style: pw.TextStyle(fontSize: 9.5, color: darkGrey),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Bank Details & Dealer Stamp/Signature Grid
              pw.Table(
                border: pw.TableBorder.all(color: navyBlue, width: 1.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(65),
                  1: const pw.FlexColumnWidth(35),
                },
                children: [
                  pw.TableRow(
                    children: [
                      // Left Column: Payment & Bank Details
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Cheque / DD Payable in Favour of',
                              style: pw.TextStyle(fontSize: 9.5, color: darkGrey),
                            ),
                            pw.Text(
                              'HITECH MOTORS & AUTOMOBILES PVT LTD. AL',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyBlue),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Payable at ____________________________________',
                              style: pw.TextStyle(fontSize: 9.5, color: darkGrey),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Cash Payment acepted only at showroom cashier and official receipt to be taken.',
                              style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, color: darkGrey),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Bank Details:',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyBlue, decoration: pw.TextDecoration.underline),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 75,
                                  child: pw.Text('Bank Name', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                ),
                                pw.Text(': AXIS BANK', style: pw.TextStyle(fontSize: 9, color: darkGrey)),
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 75,
                                  child: pw.Text('Account No.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                ),
                                pw.Text(': 921020019284327', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkGrey)),
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 75,
                                  child: pw.Text('IFSC CODE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                ),
                                pw.Text(': UTIB0001690', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkGrey)),
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 75,
                                  child: pw.Text('Branch', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                ),
                                pw.Text(': NEHRU NAGAR, BELAGAVI.', style: pw.TextStyle(fontSize: 9, color: darkGrey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Right Column: Authorised Signature
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Align(
                              alignment: pw.Alignment.topRight,
                              child: pw.Text(
                                'For Dealer',
                                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                              ),
                            ),
                            pw.SizedBox(height: 30),
                            pw.Text(
                              'Authorised Signature',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                            ),
                            pw.SizedBox(height: 4),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Name: ',
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                  ),
                                  pw.TextSpan(
                                    text: 'Sachin Patil',
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkGrey),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Mobile No: ',
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                  ),
                                  pw.TextSpan(
                                    text: '9008465065',
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkGrey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Terms & Conditions Section
              pw.Text(
                'Terms & Conditions :',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
              ),
              pw.SizedBox(height: 2),
              ...List.generate(termsList.length, (index) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${index + 1}. ',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          termsList[index],
                          style: pw.TextStyle(fontSize: 8, color: darkGrey, lineSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final cleanCustomerName = customerName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final cleanVehicleName = vehicle.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final file = File("${output.path}/${cleanCustomerName}_${cleanVehicleName}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.TableRow _buildTableRow(String name, String qty, String amount, PdfColor navyBlue, {bool isBold = false, PdfColor? bgColor}) {
    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        // PARTICULARS
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isBold ? navyBlue : PdfColors.black,
            ),
          ),
        ),
        // QTY
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(
            qty,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        // AMOUNT
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: pw.Text(
            amount.isEmpty || amount == '0' || amount == '0.0' || amount == '0.00' ? '-' : 'Rs. $amount',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isBold ? navyBlue : PdfColors.black,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
}

