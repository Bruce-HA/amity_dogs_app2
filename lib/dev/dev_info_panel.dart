import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class DevInfoPanel extends StatelessWidget {
  final String page;
  final String filePath;
  final String purpose;
  final List<String> dataSources;
  final String notes;

  const DevInfoPanel({
    super.key,
    required this.page,
    required this.filePath,
    required this.purpose,
    required this.dataSources,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    // 👇 USE YOUR EXISTING DEV FLAG
    if (!AppSettings.showPageHints) return const SizedBox.shrink();

    return Card(
      color: Colors.black.withOpacity(0.85),
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        collapsedIconColor: Colors.white,
        iconColor: Colors.white,
        title: Text(
          '🛠 DEV: $page',
          style: const TextStyle(color: Colors.white),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FILE:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(filePath, style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 8),

                  const Text('PURPOSE:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(purpose),
                  const SizedBox(height: 8),

                  const Text('DATA SOURCES:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...dataSources.map((d) => Text('- $d')),
                  const SizedBox(height: 8),

                  const Text('NOTES:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(notes),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}