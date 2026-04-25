import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';

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

  Future<Map<String, dynamic>> getInitialState() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getInitialState');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'view': 'error', 'message': e.toString()};
    }
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
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
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

  Future<Map<String, dynamic>> getGarageJobs() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getGarageJobs');
      final result = await callable.call();
      if (result.data == null) return {};
      return _deepCast(result.data as Map);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getNotifications');
      final result = await callable.call();
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
}
