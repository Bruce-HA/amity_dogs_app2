import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crm/inbox_page.dart';
import 'dogs_page.dart';
import 'people_page.dart';
import 'calendar_page.dart';
import 'vehicle_log_page.dart';
import 'reports_page.dart';
import 'dailies/dailies_page.dart';
import 'flow/flow_dashboard_page.dart';
import 'admin_page.dart';
import 'tools_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? company;
  String? userName;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCompanyProfile();
  }

  Future<void> loadCompanyProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }
      try {
      final appUser = await supabase
          .from('app_users')
          .select('first_name, last_name, company_profile_id')
          .eq('id', user.id)
          .maybeSingle();

      debugPrint('APP USER DATA: $appUser');

      userName = appUser?['first_name'];
    } catch (e) {
      debugPrint('Dashboard app user name error: $e');
    }

      final res = await supabase
          .from('company_profile')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        company = res;
        loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard company profile error: $e');

      if (!mounted) return;

      setState(() => loading = false);
    }
  }

  Color colourFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;

    final cleaned = hex.replaceAll('#', '');

    if (cleaned.length != 6) return fallback;

    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final primary = colourFromHex(
      company?['primary_colour'],
      const Color(0xFF5B2C83),
    );

    final secondary = colourFromHex(
      company?['secondary_colour'],
      const Color(0xFFD4AF37),
    );

    final accent = colourFromHex(
      company?['accent_colour'],
      const Color(0xFF8E44AD),
    );

    final companyName =
        company?['trading_name'] ?? company?['company_name'] ?? 'Amity Dogs';

    final footerText =
        company?['footer_text'] ?? 'Ethical Breeding • Exceptional Dogs';

    final logoUrl = company?['company_logo_url'];
    final associationLogoUrl = company?['association_logo_url'];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(companyName),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(
                      primary: primary,
                      secondary: secondary,
                      accent: accent,
                      companyName: companyName,
                      footerText: footerText,
                      logoUrl: logoUrl,
                      associationLogoUrl: associationLogoUrl,
                      userName: userName, // 👈 ADD THIS
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.05,
                      children: [
                        dashboardTile(
                          context,
                          icon: Icons.pets,
                          title: 'Dogs',
                          subtitle: 'Profiles & breeding dogs',
                          page: const DogsPage(),
                          colour: primary,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.route,
                          title: 'The Flow',
                          subtitle: 'Breeding workflow',
                          page: const FlowDashboardPage(),
                          colour: accent,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.mark_email_unread,
                          title: 'CRM Inbox',
                          subtitle: 'Sales enquiries',
                          page: const InboxPage(),
                          colour: Colors.teal,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.people,
                          title: 'People',
                          subtitle: 'Owners & breeders',
                          page: const PeoplePage(),
                          colour: Colors.indigo,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.event_note,
                          title: 'Daily',
                          subtitle: 'Notes & records',
                          page: DailiesPage(),
                          colour: Colors.orange,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.calendar_month,
                          title: 'Calendar',
                          subtitle: 'Dates & reminders',
                          page: const CalendarPage(),
                          colour: Colors.blue,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.directions_car,
                          title: 'Vehicle Log',
                          subtitle: 'Trips & expenses',
                          page: const VehicleLogPage(),
                          colour: Colors.green,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.bar_chart,
                          title: 'Reports',
                          subtitle: 'Breeding reports',
                          page: const ReportsPage(),
                          colour: secondary,
                          darkText: true,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.admin_panel_settings,
                          title: 'Admin',
                          subtitle: 'Settings & profile',
                          page: const AdminPage(),
                          colour: Colors.deepPurple,
                        ),
                        dashboardTile(
                          context,
                          icon: Icons.build,
                          title: 'Tools',
                          subtitle: 'Utilities',
                          page: const ToolsPage(),
                          colour: Colors.blueGrey,
                        ),
                      ],
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Text(
                        footerText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader({
    required Color primary,
    required Color secondary,
    required Color accent,
    required String companyName,
    required String footerText,
    required String? logoUrl,
    required String? associationLogoUrl,
    required String? userName, // 👈 ADD THIS
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            accent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _logoBubble(logoUrl, Icons.pets, secondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName != null
                          ? 'Welcome back $userName'
                          : 'Welcome',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),

                    if (company?['association_number'] != null)
                      Text(
                        company!['association_number'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (associationLogoUrl != null &&
                  associationLogoUrl.toString().isNotEmpty)
                _logoBubble(associationLogoUrl, Icons.verified, secondary),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: secondary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    footerText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoBubble(String? url, IconData fallbackIcon, Color accentColour) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColour,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  color: accentColour,
                  size: 30,
                ),
              )
            : Icon(
                fallbackIcon,
                color: accentColour,
                size: 30,
              ),
      ),
    );
  }

  Widget dashboardTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
    required Color colour,
    bool darkText = false,
  }) {
    final textColour = darkText ? Colors.black87 : Colors.white;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colour.withOpacity(0.28),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 34,
                color: textColour,
              ),
            ),

            const Spacer(),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColour,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColour.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}