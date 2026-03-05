import 'package:flutter/material.dart';

import 'dogs_page.dart';
import 'people_page.dart';
import 'litters_page.dart';
import 'calendar_page.dart';
import 'vehicle_log_page.dart';
import 'reports_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  Widget buildTabButton({
    required IconData icon,
    required String label,
    required int tabIndex,
  }) {
    final isSelected = _tabController.index == tabIndex;

    return InkWell(
      onTap: () {
        setState(() {
          _tabController.index = tabIndex;
        });
      },

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),

        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.teal : Colors.transparent,
              width: 3,
            ),
          ),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(icon, size: 26, color: isSelected ? Colors.teal : Colors.grey),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.teal : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDashboardTabs() {
    return Container(
      color: Colors.white,

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: buildTabButton(
                  icon: Icons.pets,
                  label: "Dogs",
                  tabIndex: 0,
                ),
              ),

              Expanded(
                child: buildTabButton(
                  icon: Icons.people,
                  label: "People",
                  tabIndex: 1,
                ),
              ),

              Expanded(
                child: buildTabButton(
                  icon: Icons.child_care,
                  label: "Litters",
                  tabIndex: 2,
                ),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: buildTabButton(
                  icon: Icons.calendar_month,
                  label: "Calendar",
                  tabIndex: 3,
                ),
              ),

              Expanded(
                child: buildTabButton(
                  icon: Icons.directions_car,
                  label: "Vehicles",
                  tabIndex: 4,
                ),
              ),

              Expanded(
                child: buildTabButton(
                  icon: Icons.bar_chart,
                  label: "Reports",
                  tabIndex: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            buildDashboardTabs(),

            Expanded(
              child: TabBarView(
                controller: _tabController,

                children: const [
                  DogsPage(),
                  PeoplePage(),
                  LittersPage(),
                  CalendarPage(),
                  VehicleLogPage(),
                  ReportsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
