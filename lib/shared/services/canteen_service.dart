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
      },
    );

    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});

    final canteenJson = Map<String, dynamic>.from(
      data['canteen'] as Map? ?? {},
    );

    return Canteen.fromJson(canteenJson);
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
}
