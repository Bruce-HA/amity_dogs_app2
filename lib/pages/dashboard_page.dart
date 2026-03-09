import 'package:flutter/material.dart';

import 'dogs_page.dart';
import 'people_page.dart';
import 'litters_page.dart';
import 'calendar_page.dart';
import 'vehicle_log_page.dart';
import 'reports_page.dart';

// Create these pages if not already existing
import 'admin_page.dart';
import 'tools_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amity Dogs'),
        centerTitle: true,
      ),
     
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          dashboardTile(context, Icons.pets, 'Dogs', const DogsPage()),
          dashboardTile(context, Icons.people, 'People', const PeoplePage()),
          dashboardTile(context, Icons.child_care, 'Litters', const LittersPage()),
          dashboardTile(context, Icons.calendar_month, 'Calendar', const CalendarPage()),
          dashboardTile(context, Icons.directions_car, 'Vehicle Log', const VehicleLogPage()),
          dashboardTile(context, Icons.bar_chart, 'Reports', const ReportsPage()),
          dashboardTile(context, Icons.admin_panel_settings, 'Admin', const AdminPage()),
          dashboardTile(context, Icons.build, 'Tools', const ToolsPage()),
        ],
      ),
    );
  }

  Widget dashboardTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}