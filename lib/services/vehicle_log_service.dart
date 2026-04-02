import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleLogService {
  static final _client = Supabase.instance.client;

  /*
  ============================================================
  GET LAST KM PER VEHICLE
  ============================================================
  */
  static Future<Map<String, int>> getLastKms() async {
    final Map<String, int> lastKm = {};

    final response = await _client
        .from('vehicle_logs')
        .select('vehicle_name, end_km, created_at')
        .order('created_at', ascending: false);

    for (final row in response) {
      final vehicle = row['vehicle_name'];
      final km = row['end_km'];

      if (!lastKm.containsKey(vehicle)) {
        lastKm[vehicle] = km;
      }
    }

    return lastKm;
  }

  /*
  ============================================================
  SAVE LOG
  ============================================================
  */
  static Future<void> saveLog({
    required String vehicleName,
    required int startKm,
    required int endKm,
    required bool isBusiness,
    required String notes,
    required String driverName,
  }) async {
    await _client.from('vehicle_logs').insert({
      'vehicle_name': vehicleName,
      'start_km': startKm,
      'end_km': endKm,
      'distance_km': endKm - startKm,
      'is_business': isBusiness,
      'notes': notes,
      'driver_name': driverName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /*
  ============================================================
  GET LOGS (FOR REPORTS)
  ============================================================
  */
  static Future<List<Map<String, dynamic>>> getLogs({
    String? vehicleName,
    required DateTime startDate,
    required DateTime endDate,
    String tripFilter = "Both",
  }) async {
    dynamic query = _client.from('vehicle_logs').select();

    if (vehicleName != null) {
      query = query.eq('vehicle_name', vehicleName);
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));

    query = query
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());

    if (tripFilter == "Business") {
      query = query.eq('is_business', true);
    } else if (tripFilter == "Private") {
      query = query.eq('is_business', false);
    }

    query = query.order('created_at');

    final result = await query;

    return List<Map<String, dynamic>>.from(result);
  }
}