class VehicleLog {
  final String id;
  final String vehicleName;
  final int odometer;
  final String description;
  final DateTime logDate;

  VehicleLog({
    required this.id,
    required this.vehicleName,
    required this.odometer,
    required this.description,
    required this.logDate,
  });

  factory VehicleLog.fromMap(Map<String, dynamic> map) {
    return VehicleLog(
      id: map['id'],
      vehicleName: map['vehicle_name'],
      odometer: map['odometer'],
      description: map['description'] ?? '',
      logDate: DateTime.parse(map['log_date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_name': vehicleName,
      'odometer': odometer,
      'description': description,
      'log_date': logDate.toIso8601String(),
    };
  }
}
