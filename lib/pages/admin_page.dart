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
import 'admin/remove_dna_page.dart';
import 'admin/company_profile_page.dart';

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
            padding: const EdgeInsets.only(bottom: 16, right: 12),
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
        child: ListView(
          children: [

            // =========================
            // 🎨 APPEARANCE
            // =========================
            _sectionTitle(context, 'APPEARANCE'),

            const SizedBox(height: 12),

            _buildThemeSelector(context),

            const SizedBox(height: 24),

            // =========================
            // 👥 PEOPLE TOOLS
            // =========================
            _sectionTitle(context, 'PEOPLE'),

            const SizedBox(height: 12),

            _card(
              icon: Icons.people,
              title: 'Manage Users',
              subtitle: 'Add and manage system users',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageUsersPage(),
                  ),
                );
              },
              
            ),

            const SizedBox(height: 24),

            // =========================
            // Add profile button
            // =========================
            _card(
              icon: Icons.business,
              iconColor: Colors.deepPurple,
              title: 'Company Profile',
              subtitle: 'Business details, logo, registration and branding',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CompanyProfilePage(),
                  ),
                );
              },
            ),
            // =========================
            // 🧬 DNA TOOLS
            // =========================
            _sectionTitle(context, 'DNA'),

            const SizedBox(height: 12),

            _card(
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              title: 'Remove DNA',
              subtitle: 'Delete DNA records and files by dog ALA',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RemoveDNAPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // =========================
            // ⚙️ SYSTEM
            // =========================
            _sectionTitle(context, 'SYSTEM'),

            const SizedBox(height: 12),

            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.code),
                title: const Text('Developer Mode'),
                subtitle: const Text(
                  'Show internal page names',
                  softWrap: true,
                ),
                value: AppSettings.showPageHints,
                onChanged: (v) {
                  AppSettings.showPageHints = v;
                  (context as Element).markNeedsBuild();
                },
              ),
            ),

            const SizedBox(height: 12),

            _card(
              icon: Icons.verified_user,
              title: 'Test My Roles',
              subtitle: 'Check current user permissions',
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

            const SizedBox(height: 12),

            _card(
              icon: Icons.build,
              title: 'Data Tools',
              subtitle: 'Merge people, fix breeders, clean duplicates',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDataToolsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // 🔹 SECTION TITLE
  // =========================

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  // =========================
  // 🔹 STANDARD CARD
  // =========================

  Widget _card({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(
          subtitle,
          softWrap: true,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // =========================
  // 🎨 THEME SELECTOR
  // =========================

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