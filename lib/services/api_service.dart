import 'dart:convert';
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
        return data.map((json) => Record.fromJson(json)).toList();
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
        return data.map((json) => Record.fromJson(json)).toList();
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
        body: json.encode(record.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Record.fromJson(data);
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
        body: json.encode(record.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Record.fromJson(data);
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
}