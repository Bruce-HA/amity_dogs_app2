import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_log.dart';

class VehicleLogService {
  final _client = Supabase.instance.client;

  Future<List<VehicleLog>> fetchLogs() async {
    final data = await _client
        .from('vehicle_logs')
        .select()
        .order('log_date', ascending: false);

    return (data as List).map((e) => VehicleLog.fromMap(e)).toList();
  }

  Future<void> addLog(VehicleLog log) async {
    await _client.from('vehicle_logs').insert(log.toMap());
  }
}
