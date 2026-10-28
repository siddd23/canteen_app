import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class EmployeeCanteenService {
  EmployeeCanteenService._();
  static final instance = EmployeeCanteenService._();
  static const _path = '${ApiConstants.customers}/canteens';

  Future<List<Map<String, dynamic>>> saved() async {
    final result = await ApiService.instance.get(_path);
    final data = Map<String, dynamic>.from(result['data'] as Map? ?? {});
    return (data['canteens'] as List? ?? [])
        .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> add(String code) async {
    await ApiService.instance.post(_path, body: {'code': code.trim().toUpperCase()});
  }

  Future<void> remove(String id) async {
    await ApiService.instance.delete('$_path/$id');
  }

  Future<Map<String, dynamic>> menu(String code) async {
    final response = await ApiService.instance.get('/public/canteens/$code/menu', authenticated: false);
    return Map<String, dynamic>.from(response['data'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> placeOrder(String code, Map<String, dynamic> body) async {
    final response = await ApiService.instance.post('/public/canteens/$code/orders', body: body);
    return Map<String, dynamic>.from(response['data'] as Map? ?? {});
  }
}
