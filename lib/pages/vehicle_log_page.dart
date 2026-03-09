import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vehicle_reports_page.dart';

class VehicleLogPage extends StatefulWidget {
  const VehicleLogPage({super.key});

  @override
  State<VehicleLogPage> createState() => _VehicleLogPageState();
}

class _VehicleLogPageState extends State<VehicleLogPage> {
  final supabase = Supabase.instance.client;

  final List<String> vehicles = ['I30', 'Staria'];

  final Map<String, int> lastKm = {};

  String selectedVehicle = 'I30';

  final startKmController = TextEditingController();
  final endKmController = TextEditingController();
  final notesController = TextEditingController();

  bool isBusiness = false;

  bool loading = true;
  bool saving = false;

  final String driverName = 'Bruce McLean';

  @override
  void initState() {
    super.initState();

    if (selectedVehicle == 'I30') {
      isBusiness = false;
    } else {
      isBusiness = true;
    }

    loadAllVehicleKms();
  }

  Future<void> loadAllVehicleKms() async {
    try {
      final response = await supabase
          .from('vehicle_logs')
          .select('vehicle_name, end_km, created_at')
          .order('created_at', ascending: false);

      for (var row in response) {
        final vehicle = row['vehicle_name'];
        final km = row['end_km'];

        if (!lastKm.containsKey(vehicle)) {
          lastKm[vehicle] = km;
        }
      }

      startKmController.text =
          (lastKm[selectedVehicle] ?? 0).toString();
    } catch (e) {
      debugPrint("Error loading vehicle KMs: $e");
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> saveLog() async {
    final startKm = int.tryParse(startKmController.text);
    final endKm = int.tryParse(endKmController.text);

    if (startKm == null || endKm == null) return;

    final distance = endKm - startKm;

    saving = true;
    setState(() {});

    try {
      await supabase.from('vehicle_logs').insert({
        'vehicle_name': selectedVehicle,
        'start_km': startKm,
        'end_km': endKm,
        'distance_km': distance,
        'is_business': isBusiness,
        'notes': notesController.text,
        'driver_name': driverName,
      });

      lastKm[selectedVehicle] = endKm;

      startKmController.text = endKm.toString();
      endKmController.clear();
      notesController.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vehicle log saved')));
    } catch (e) {
      debugPrint("Save error: $e");

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error saving log')));
    }

    saving = false;
    setState(() {});
  }

  Widget vehicleTile(String vehicle) {
    final isSelected = vehicle == selectedVehicle;
    final km = lastKm[vehicle] ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedVehicle = vehicle;

          startKmController.text = km.toString();

          if (vehicle == 'I30') {
            isBusiness = false;
          } else {
            isBusiness = true;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade200 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/$vehicle.png', height: 55),
            const SizedBox(height: 8),
            Text(
              vehicle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('$km km', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VehicleReportsPage(vehicleName: vehicle),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text(
                "Report",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
    Widget build(BuildContext context) {
      if (loading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Log')),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: vehicles
                            .map((v) => Expanded(child: vehicleTile(v)))
                            .toList(),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Private'),
                          Switch(
                            value: isBusiness,
                            onChanged: (value) {
                              setState(() {
                                isBusiness = value;
                              });
                            },
                          ),
                          const Text('Business'),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Driver\n$driverName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: startKmController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Start KM'),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: endKmController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'End KM'),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: notesController,
                        decoration:
                            const InputDecoration(labelText: 'Notes'),
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving ? null : saveLog,
                          child: saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
}