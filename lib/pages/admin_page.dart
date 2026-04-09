import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'manage_users_page.dart';
import '../theme/theme_provider.dart';
import '../theme/amity_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_page.dart';
import '../services/app_user.dart';
import 'admin/admin_data_tools_page.dart';
import '../services/app_settings.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
        title: const Text('Admin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 8),
                Text(
                  AppUser.name.isNotEmpty ? AppUser.name : 'Unknown user',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
        
      ),

      
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'APPEARANCE',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            _buildThemeSelector(context),

            const SizedBox(height: 24),

            Text(
              'SYSTEM',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Manage Users'),
                subtitle: const Text('Add and manage system users'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageUsersPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
      // toggle the test mode
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                secondary: const Icon(Icons.code),
                title: const Text('Developer Mode'),
                subtitle: const Text('Show internal page names'),
                value: AppSettings.showPageHints,
                onChanged: (v) {
                  AppSettings.showPageHints = v;
                  (context as Element).markNeedsBuild();
                },
              ),
),
      ///
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.visibility),
                title: const Text('Show Page Hints'),
                subtitle: const Text('Display internal page names'),
                value: AppSettings.showPageHints,
                onChanged: (v) {
                  AppSettings.showPageHints = v;
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
      ///
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Test My Roles'),
                subtitle: const Text('Check current user permissions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await AppUser.load();

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('My Roles'),
                      content: Text(
                        '''
                  Admin: ${AppUser.isAdmin}
                  Breeder: ${AppUser.isBreeder}
                  Helper: ${AppUser.isHelper}
                  Driver: ${AppUser.isDriver}
                  ''',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
              // test toggle
              
              Card(
                child: ListTile(
                  leading: const Icon(Icons.build), // 🔥 nice tools icon
                  title: const Text('Data Tools'),
                  subtitle: const Text('Merge people, fix breeders, clean duplicates'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDataToolsPage(),
                      ),
                    );
                  },
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Column(
      children: AmityThemeType.values.map((themeType) {
        return RadioListTile<AmityThemeType>(
          title: Text(themeType.name.toUpperCase()),
          value: themeType,
          groupValue: context.watch<ThemeProvider>().currentTheme,
          onChanged: (value) {
            if (value != null) {
              context.read<ThemeProvider>().setTheme(value);
            }
          },
        );
      }).toList(),
    );
  }
}