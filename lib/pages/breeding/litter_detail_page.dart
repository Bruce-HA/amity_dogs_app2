import 'package:flutter/material.dart';
import '../breeding/litter_whelping_page.dart';
import '../litters/litter_puppies_page.dart';
import '../litters/litter_weights_page.dart';
import '../../widgets/app_title.dart';

class LitterDetailPage extends StatelessWidget {
  final Map litter;

  const LitterDetailPage({
    super.key,
    required this.litter,
  });

  @override
  Widget build(BuildContext context) {
  
    //
    return Scaffold(
      appBar: AppBar(
        title: buildTitle('Litter', 'LitterDetailPage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _navTile(
            context,
            title: 'Overview',
            onTap: () {},
          ),

          _navTile(
            context,
            title: 'Whelping',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LitterWhelpingPage(litter: litter),
                ),
              );
            },
          ),

          _navTile(
            context,
            title: 'Puppies',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LitterPuppiesPage(litter: litter),
                ),
              );
            },
          ),

          _navTile(
            context,
            title: 'Weights',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LitterWeightsPage(litter: litter),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context,
      {required String title, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}