import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class QuotationService {
  final ApiService _apiService = ApiService();

  Future<List<dynamic>> getQuotations(String leadId) async {
    final response = await _apiService.get('quotations.php?lead_id=$leadId');
    return response['data'] ?? [];
  }

  Future<void> uploadQuotation(String leadId, File file) async {
    final uri = Uri.parse('${ApiService.baseUrl}/quotations.php');
    
    // Manual multipart request since ApiService handles JSON
    var request = http.MultipartRequest('POST', uri);
    
    // Add custom headers from ApiService (like cookies)
    Map<String, String> headers = await _apiService.getHeaders();
    request.headers.addAll(headers);

    request.fields['lead_id'] = leadId;
    request.files.add(await http.MultipartFile.fromPath('quotation', file.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var result = jsonDecode(responseData);

    if (result['status'] != 'success') {
      throw Exception(result['message'] ?? 'Upload failed');
    }
  }
}
