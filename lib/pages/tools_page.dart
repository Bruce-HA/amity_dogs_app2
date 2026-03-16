import 'package:flutter/material.dart';
import '../pages/tools/simple_pedigree_page.dart'; 
import '../pages/tools/pregnancy_calculator_page.dart';// ✅ correct place

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        centerTitle: true,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          toolTile(
            context,
            Icons.account_tree,
            'Simple Pedigree',
            const SimplePedigreePage(),
          ),
          toolTile(
            context,
            Icons.pregnant_woman,
            'Pregnancy Date Calculator',
            const PregnancyCalculatorPage(),
          ),
          toolTile(
            context,
            Icons.science,
            'DNA Colour Lookup',
            PlaceholderPage(title: 'DNA Colour Lookup'),
          ),
          toolTile(
            context,
            Icons.build,
            'Spare',
            PlaceholderPage(title: 'Spare'),
          ),
          toolTile(
            context,
            Icons.extension,
            '1',
            PlaceholderPage(title: 'Tool 1'),
          ),
          toolTile(
            context,
            Icons.extension,
            '2',
            PlaceholderPage(title: 'Tool 2'),
          ),
        ],
      ),
    );
  }

  Widget toolTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
// 👇 This must be OUTSIDE ToolsPage

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text(
          '$title\nComing Soon',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}