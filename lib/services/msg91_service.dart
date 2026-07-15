import 'dart:convert';
import 'package:http/http.dart' as http;

class Msg91Service {
  // Replace with your actual MSG91 Auth Key
  static const String _defaultAuthKey = "505779A1ub8cCvYYrQ6a0cc3a8P1";
  
  // Replace with your integrated WhatsApp Sender Number (including country code)
  static const String _defaultSenderNumber = "917618797108";

  /// Sends a direct session WhatsApp message with a message and hosted PDF link.
  /// 
  /// MSG91 uses the Outbound Message API for WhatsApp session messages.
  static Future<bool> sendWhatsAppPdfDirect({
    required String customerPhone,
    required String pdfUrl,
    required String filename,
    required String messageText,
    String? customAuthKey,
    String? senderNumber,
  }) async {
    final authKey = customAuthKey ?? _defaultAuthKey;
    final integratedNumber = senderNumber ?? _defaultSenderNumber;
    
    // Format recipient phone number (remove +, spaces, ensure country code)
    var recipient = customerPhone.replaceAll(RegExp(r'[\s\+\-]'), '');
    if (recipient.length == 10) {
      recipient = "91$recipient"; // Default to India country code if 10 digits
    }

    final url = Uri.parse("https://control.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/");

    final headers = {
      "accept": "application/json",
      "content-type": "application/json",
      "authkey": authKey,
    };

    // First send the PDF media card
    final mediaBody = {
      "integrated_number": integratedNumber,
      "content_type": "media_card",
      "recipient_number": recipient,
      "media_card": {
        "media_type": "document",
        "media_url": pdfUrl,
        "filename": filename,
        "caption": messageText
      }
    };

    try {
      print('MSG91: Sending media card to $recipient');
      final mediaResponse = await http.post(
        url,
        headers: headers,
        body: jsonEncode(mediaBody),
      );

      print('MSG91 Response Code: ${mediaResponse.statusCode}');
      print('MSG91 Response Body: ${mediaResponse.body}');

      if (mediaResponse.statusCode == 200) {
        final resData = jsonDecode(mediaResponse.body);
        return resData['status'] == 'success' || resData['type'] == 'success';
      }
      return false;
    } catch (e) {
      print('MSG91 Error: $e');
      return false;
    }
  }

  /// Sends a WhatsApp message using a pre-approved MSG91 Template with dynamic parameters and Document Header.
  /// 
  /// Use this if you are initiating a conversation outside the 24-hour window.
  static Future<bool> sendWhatsAppPdfTemplate({
    required String customerPhone,
    required String templateName,
    required String pdfUrl,
    required String filename,
    required List<String> bodyVariables,
    String? customAuthKey,
  }) async {
    final authKey = customAuthKey ?? _defaultAuthKey;

    var recipient = customerPhone.replaceAll(RegExp(r'[\s\+\-]'), '');
    if (recipient.length == 10) {
      recipient = "91$recipient";
    }

    final url = Uri.parse("https://api.msg91.com/api/v5/whatsapp/message");

    final headers = {
      "accept": "application/json",
      "content-type": "application/json",
      "authkey": authKey,
    };

    // Construct template parameters
    final bodyParameters = bodyVariables.map((val) => {
      "type": "text",
      "text": val
    }).toList();

    final body = {
      "template": {
        "name": templateName,
        "language": {
          "code": "en"
        },
        "components": [
          {
            "type": "header",
            "parameters": [
              {
                "type": "document",
                "document": {
                  "link": pdfUrl,
                  "filename": filename
                }
              }
            ]
          },
          {
            "type": "body",
            "parameters": bodyParameters
          }
        ]
      },
      "messaging_product": "whatsapp",
      "recipient_type": "individual",
      "to": recipient,
      "type": "template"
    };

    try {
      print('MSG91 Template: Sending $templateName to $recipient');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      print('MSG91 Template Response Code: ${response.statusCode}');
      print('MSG91 Template Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['status'] == 'success' || resData['type'] == 'success';
      }
      return false;
    } catch (e) {
      print('MSG91 Template Error: $e');
      return false;
    }
  }

  static Future<bool> sendWhatsAppProformaInvoiceTemplate({
    required String customerPhone,
    required String pdfUrl,
    required String filename,
    required String value1,
    required String value2,
    required String value3,
    required String value4,
    String? authKey,
  }) async {
    final activeAuthKey = authKey ?? _defaultAuthKey;
    var recipient = customerPhone.replaceAll(RegExp(r'[\s\+\-]'), '');
    if (recipient.length == 10) {
      recipient = "91$recipient";
    }

    final url = Uri.parse("https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/");

    final headers = {
      "accept": "application/json",
      "content-type": "application/json",
      "authkey": activeAuthKey,
    };

    final body = {
      "integrated_number": "917618797108",
      "content_type": "template",
      "payload": {
        "messaging_product": "whatsapp",
        "type": "template",
        "template": {
          "name": "hitech_proforma_invoice",
          "language": {
            "code": "en",
            "policy": "deterministic"
          },
          "namespace": "8c14bdc2_df6c_4da7_9c53_488ab620f59e",
          "to_and_components": [
            {
              "to": [ recipient ],
              "components": {
                "header_1": {
                  "filename": filename,
                  "type": "document",
                  "value": pdfUrl
                },
                "body_1": {
                  "type": "text",
                  "value": value1
                },
                "body_2": {
                  "type": "text",
                  "value": value2
                },
                "body_3": {
                  "type": "text",
                  "value": value3
                },
                "body_4": {
                  "type": "text",
                  "value": value4
                }
              }
            }
          ]
        }
      }
    };

    try {
      print('MSG91 Bulk Template: Sending hitech_proforma_invoice to $recipient with PDF URL: $pdfUrl');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      print('MSG91 Response Code: ${response.statusCode}');
      print('MSG91 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['status'] == 'success' || resData['type'] == 'success';
      }
      return false;
    } catch (e) {
      print('MSG91 Error: $e');
      return false;
    }
  }

  static Future<bool> sendWhatsAppBrochureTemplate({
    required String customerPhone,
    required String pdfUrl,
    required String filename,
    required String vehicleModel,
    required String customerName,
    String? authKey,
  }) async {
    final activeAuthKey = authKey ?? _defaultAuthKey;
    var recipient = customerPhone.replaceAll(RegExp(r'[\s\+\-]'), '');
    if (recipient.length == 10) {
      recipient = "91$recipient";
    }

    final url = Uri.parse("https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/");

    final headers = {
      "accept": "application/json",
      "content-type": "application/json",
      "authkey": activeAuthKey,
    };

    final body = {
      "integrated_number": "917618797108",
      "content_type": "template",
      "payload": {
        "messaging_product": "whatsapp",
        "type": "template",
        "template": {
          "name": "brochure",
          "language": {
            "code": "en",
            "policy": "deterministic"
          },
          "namespace": "8c14bdc2_df6c_4da7_9c53_488ab620f59e",
          "to_and_components": [
            {
              "to": [ recipient ],
              "components": {
                "header_1": {
                  "filename": filename,
                  "type": "document",
                  "value": pdfUrl
                },
                "body_vehicle_model": {
                  "type": "text",
                  "value": vehicleModel,
                  "parameter_name": "vehicle_model"
                },
                "body_customer_name": {
                  "type": "text",
                  "value": customerName,
                  "parameter_name": "customer_name"
                }
              }
            }
          ]
        }
      }
    };

    try {
      print('MSG91 Bulk Template: Sending brochure to $recipient with PDF URL: $pdfUrl');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      print('MSG91 Response Code: ${response.statusCode}');
      print('MSG91 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['status'] == 'success' || resData['type'] == 'success';
      }
      return false;
    } catch (e) {
      print('MSG91 Error: $e');
      return false;
    }
  }
}
