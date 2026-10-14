import '../../core/constants/api_constants.dart';
import '../models/canteen.dart';
import 'api_service.dart';

class CanteenService {
  CanteenService._();

  static final CanteenService instance = CanteenService._();

  Future<Canteen> createCanteen({
    required String name,
    required String address,
    required String city,
    required String contactNumber,
    required String openingTime,
    required String closingTime,
    List<CanteenServiceSlot>? serviceSlots,
  }) async {
    final response = await ApiService.instance.post(
      ApiConstants.canteens,
      body: {
        'name': name.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'contactNumber': contactNumber.trim(),
        'openingTime': openingTime.trim(),
        'closingTime': closingTime.trim(),
        if (serviceSlots != null) 'serviceSlots': serviceSlots.map((slot) => slot.toJson()).toList(),
      },
    );

    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});

    final canteenJson = Map<String, dynamic>.from(
      data['canteen'] as Map? ?? {},
    );

    return Canteen.fromJson(canteenJson);
  }

  Future<Canteen> updateCanteen({
    required String canteenId,
    required String name,
    required String address,
    required String city,
    required String contactNumber,
    required List<CanteenServiceSlot> serviceSlots,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.canteens}/$canteenId',
      body: {
        'name': name.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'contactNumber': contactNumber.trim(),
        'serviceSlots': serviceSlots.map((slot) => slot.toJson()).toList(),
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return Canteen.fromJson(Map<String, dynamic>.from(data['canteen'] as Map? ?? {}));
  }

  Future<List<Canteen>> getMyCanteens() async {
    final response = await ApiService.instance.get(ApiConstants.canteens);

    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});

    final canteensJson = data['canteens'] as List? ?? [];

    return canteensJson
        .map(
          (canteen) =>
              Canteen.fromJson(Map<String, dynamic>.from(canteen as Map)),
        )
        .toList();
  }

  Future<Canteen> updateMasterQrStatus({
    required String canteenId,
    required bool enabled,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.canteens}/$canteenId/master-qr/status',
      body: {'enabled': enabled},
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return Canteen.fromJson(
      Map<String, dynamic>.from(data['canteen'] as Map? ?? {}),
    );
  }
}
