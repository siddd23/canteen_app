import '../../core/constants/api_constants.dart';
import '../models/office.dart';
import 'api_service.dart';

class OfficeService {
  OfficeService._();

  static final OfficeService instance = OfficeService._();

  Future<List<Office>> getMyOffices() async {
    final response = await ApiService.instance.get(ApiConstants.offices);
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final offices = data['offices'] as List? ?? const [];

    return offices
        .whereType<Map>()
        .map((item) => Office.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Office> createOffice({
    required String companyName,
    required String building,
    required String floor,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String contactPerson,
    required String contactNumber,
    required List<String> canteenIds,
  }) async {
    final response = await ApiService.instance.post(
      ApiConstants.offices,
      body: {
        'companyName': companyName.trim(),
        'building': building.trim(),
        'floor': floor.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'pincode': pincode.trim(),
        'contactPerson': contactPerson.trim(),
        'contactNumber': contactNumber.trim(),
        'canteenIds': canteenIds,
      },
    );

    return _officeFromResponse(response);
  }

  Future<Office> updateOfficeCanteens({
    required String officeId,
    required List<String> canteenIds,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.offices}/$officeId/canteens',
      body: {'canteenIds': canteenIds},
    );
    return _officeFromResponse(response);
  }

  Future<Office> updateOfficeStatus({
    required String officeId,
    required String status,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.offices}/$officeId/status',
      body: {'status': status},
    );
    return _officeFromResponse(response);
  }

  Office _officeFromResponse(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final office = Map<String, dynamic>.from(data['office'] as Map? ?? {});
    return Office.fromJson(office);
  }
}
