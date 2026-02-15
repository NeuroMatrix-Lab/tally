import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/record.dart';

class ApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp') ?? '47.107.242.24';
    return 'http://$serverIp:7378/api';
  }

  static Future<List<Record>> getRecentRecords({int months = 3}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/records/recent?months=$months'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Record.fromMap(json)).toList();
      } else {
        throw Exception('Failed to load records: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching records: $e');
    }
  }

  static Future<List<Record>> searchRecords({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
    String? ledger,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final queryParams = <String, String>{
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

      if (category != null) {
        queryParams['category'] = category;
      }

      if (ledger != null) {
        queryParams['ledger'] = ledger;
      }

      final uri = Uri.parse('$baseUrl/records/search')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Record.fromMap(json)).toList();
      } else {
        throw Exception('Failed to search records: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching records: $e');
    }
  }

  static Future<List<String>> getRecentCategories({int months = 3}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/records/categories?months=$months'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  static Future<List<String>> getRecentWorkContents({int months = 3}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/records/work-contents?months=$months'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      } else {
        throw Exception('Failed to load work contents: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching work contents: $e');
    }
  }

  static Future<List<String>> getAllLedgers() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/records/ledgers'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      } else {
        throw Exception('Failed to load ledgers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ledgers: $e');
    }
  }

  static Future<Record> createRecord(Record record) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/records'),
        headers: {'Content-Type': 'application/json'},
        body: record.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Record.fromMap(data);
      } else {
        throw Exception('Failed to create record: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating record: $e');
    }
  }

  static Future<Record> updateRecord(Record record) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/records/${record.id}'),
        headers: {'Content-Type': 'application/json'},
        body: record.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Record.fromMap(data);
      } else {
        throw Exception('Failed to update record: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating record: $e');
    }
  }

  static Future<void> deleteRecord(String recordId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.delete(
        Uri.parse('$baseUrl/records/$recordId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete record: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting record: $e');
    }
  }

  static Future<List<Record>> getDeletedRecords() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/deleted-records'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Record.fromMap(json)).toList();
      } else {
        throw Exception('Failed to load deleted records: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching deleted records: $e');
    }
  }

  static Future<Record> restoreDeletedRecord(String recordId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/deleted-records/$recordId/restore'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Record.fromMap(data);
      } else {
        throw Exception('Failed to restore record: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error restoring record: $e');
    }
  }

  static Future<void> permanentlyDeleteRecord(String recordId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.delete(
        Uri.parse('$baseUrl/deleted-records/$recordId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to permanently delete record: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error permanently deleting record: $e');
    }
  }

  static Future<String> uploadImage(File imageFile) async {
    try {
      final baseUrl = await _getBaseUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        final baseUrlWithoutApi = baseUrl.replaceAll('/api', '');
        return '$baseUrlWithoutApi${data['imageUrl']}';
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  static Future<List<String>> syncLedgers() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/records/ledgers'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      } else {
        throw Exception('Failed to sync ledgers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error syncing ledgers: $e');
    }
  }

  static Future<String> createLedger(String name) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/records/ledgers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'] ?? data['name'];
      } else {
        throw Exception('Failed to create ledger: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating ledger: $e');
    }
  }

  static Future<void> updateLedger(String oldName, String newName) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/records/ledgers/$oldName'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': newName}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update ledger: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating ledger: $e');
    }
  }

  static Future<void> deleteLedger(String name) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.delete(
        Uri.parse('$baseUrl/records/ledgers/$name'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete ledger: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting ledger: $e');
    }
  }
}