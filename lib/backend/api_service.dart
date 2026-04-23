import 'package:cloud_functions/cloud_functions.dart';

class ApiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // Request the initial state from the server (BlackBox approach)
  Future<Map<String, dynamic>> getInitialState() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('getInitialState');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Api Error: $e');
      return {'view': 'error', 'message': e.toString()};
    }
  }

  // Submit a job - logic is fully on server
  Future<Map<String, dynamic>> submitJob(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('submitJob');
      final result = await callable.call(data);
      return result.data as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('addVehicle');
      final result = await callable.call(data);
      return result.data as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
