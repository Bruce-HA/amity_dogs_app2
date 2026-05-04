import 'package:flutter/material.dart';

import 'inbox_page.dart';
import 'crm_import_queue_page.dart';
import '../../pages/people_page.dart';

class CrmDashboardPage extends StatelessWidget {
  const CrmDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      appBar: AppBar(
        title: const Text('CRM Hub'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(18),
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 0.75,
        children: [
          _CrmTile(
            title: 'CRM Inbox',
            subtitle: 'Buyer enquiries',
            icon: Icons.inbox,
            color: const Color(0xFF009688),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InboxPage(),
                ),
              );
            },
          ),
          _CrmTile(
            title: 'Email Import',
            subtitle: 'Approve new emails',
            icon: Icons.mark_email_unread,
            color: const Color(0xFF6F3FA7),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CrmImportQueuePage(),
                ),
              );
            },
          ),
          _CrmTile(
            title: 'People',
            subtitle: 'Buyers and contacts',
            icon: Icons.people,
            color: const Color(0xFF3F51B5),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PeoplePage(),
                ),
              );
            },
          ),
          _CrmTile(
            title: 'Templates',
            subtitle: 'Save auto\nreply messages',
            icon: Icons.article,
            color: const Color(0xFF795548),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Response Templates page not wired yet'),
                ),
              );
            },
          ),

          _CrmTile(
            title: 'Add Enquiry',
            subtitle: 'Manual entry',
            icon: Icons.person_add_alt_1,
            color: const Color(0xFFFF9800),
            onTap: () {
              // TODO: Wire to your manual enquiry/import page.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add Enquiry page not wired yet'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CrmTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CrmTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      elevation: 8,
      shadowColor: color.withOpacity(0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}