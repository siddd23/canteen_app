import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class EmployeeAddressService {
  EmployeeAddressService._();
  static final instance = EmployeeAddressService._();
  static const _path = '${ApiConstants.customers}/addresses';

  Future<List<Map<String, dynamic>>> list() async {
    final response = await ApiService.instance.get(_path);
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return (data['addresses'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> add(Map<String, dynamic> address) async {
    final response = await ApiService.instance.post(_path, body: address);
    return Map<String, dynamic>.from(response['data'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> address) async {
    final response = await ApiService.instance.patch('$_path/$id', body: address);
    return Map<String, dynamic>.from(response['data'] as Map? ?? {});
  }

  Future<void> remove(String id) async {
    await ApiService.instance.delete('$_path/$id');
  }

  Future<void> setDefault(String id) async {
    await ApiService.instance.patch('$_path/$id/default');
  }
}
