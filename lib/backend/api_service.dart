import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final Dio _dio = Dio();
  final String _bridgeUrl = "https://asia-south1-carservices-4774a.cloudfunctions.net/uploadInventoryImage";

  // Helper to recursively cast Map<Object?, Object?> to Map<String, dynamic>
  Map<String, dynamic> _deepCast(Map map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _deepCast(value));
      } else if (value is List) {
        return MapEntry(key.toString(), value.map((e) => e is Map ? _deepCast(e) : e).toList());
      }
      return MapEntry(key.toString(), value);
    });
  }

  Future<Map<String, dynamic>> getInitialState({String? garageId}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getInitialState');
      final result = await callable.call({'garageId': garageId}).timeout(const Duration(seconds: 15));
      if (result.data == null) return {};
      final data = _deepCast(result.data as Map);
      
      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('initial_state_cache', jsonEncode(data));
      
      return data;
    } catch (e) {
      // Return cache if network fails or timeouts
      final cached = await getCachedInitialState();
      if (cached != null) return cached;
      return {'view': 'error', 'message': "Connection Timeout. Please check your internet."};
    }
  }

  Future<Map<String, dynamic>?> getCachedInitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('initial_state_cache');
      if (cachedStr != null) {
        return jsonDecode(cachedStr) as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>> submitJob(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('submitJob');
      final result = await callable.call(data);
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('addVehicle');
      final result = await callable.call(data);
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('addInventoryItem');
      final result = await callable.call(data);
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getInventory() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getInventoryLive');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateStock(int id, int adjustment) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('updateStock');
      final result = await callable.call({'id': id, 'adjustment': adjustment});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveGarageServices(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('saveGarageServices');
      final result = await callable.call(data);
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getGaragePricing(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getGaragePricing');
      final result = await callable.call(data);
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteInventoryItem(int id, String? imageUrl) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('deleteInventoryItem');
      final result = await callable.call({'id': id, 'imageUrl': imageUrl});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUploadUrl(String fileName, String contentType) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getUploadUrl');
      final result = await callable.call({'fileName': fileName, 'contentType': contentType});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<bool> uploadFile(String url, Uint8List bytes, String contentType) async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 15);
      final response = await dio.put(url, data: Stream.fromIterable([bytes]), options: Options(headers: {'Content-Type': contentType, 'Content-Length': bytes.length}));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> uploadInventoryImageProxy(String fileName, String contentType, String base64Data) async {
    try {
      final response = await _dio.post(_bridgeUrl, data: {'data': {'fileName': fileName, 'contentType': contentType, 'base64Data': base64Data}});
      if (response.data != null && response.data['data'] != null) {
        return _deepCast(response.data['data'] as Map);
      }
      return {'status': 'error', 'message': 'Invalid response from bridge'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitGarageRequest(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('submitGarageRequest');
      final result = await callable.call(data);
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getGarageRequestStatus() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getGarageRequestStatus');
      final result = await callable.call();
      if (result.data == null) return {};
      final data = _deepCast(result.data as Map);
      
      // If we got multiple requests, the frontend might need to handle them
      return data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAllGarageRequests() async {
    final res = await getGarageRequestStatus();
    if (res['status'] == 'success' && res['requests'] != null) {
      return List<Map<String, dynamic>>.from(res['requests'] as List);
    }
    // Backward compatibility if backend only returns one 'request'
    if (res['status'] == 'success' && res['request'] != null) {
      return [Map<String, dynamic>.from(res['request'] as Map)];
    }
    return [];
  }

  Future<Map<String, dynamic>> getGarageRequestsAdmin() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getGarageRequestsAdmin');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateGarageRequestStatus(int id, String status) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('updateGarageRequestStatus');
      final result = await callable.call({'id': id, 'status': status});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getGarageJobs({String? garageId}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getGarageJobsV2');
      final result = await callable.call({'garageId': garageId});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUserJobs() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getUserJobs');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getNotifications({String module = 'user'}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getNotifications');
      final result = await callable.call({'module': module});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateInvoiceNo() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('generateInvoiceNo');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<void> markNotificationsAsRead({String module = 'user'}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('markNotificationsAsRead');
      await callable.call({'module': module});
    } catch (e) {
      print("Error marking notifications as read: $e");
    }
  }

  Future<Map<String, dynamic>> getApprovedGarages() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getApprovedGarages');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateJobStatus(int jobId, String status, {Map<String, dynamic>? pricing}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('updateJobStatus');
      final result = await callable.call({'jobId': jobId, 'status': status, 'pricing': pricing});
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
