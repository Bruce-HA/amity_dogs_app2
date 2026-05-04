import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
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
import 'crm/crm_dashboard_page.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late final AnimationController _pulseController;
  late final Animation<Color?> _crmColourAnimation;

  Timer? _crmQueueTimer;
  int pendingImportCount = 0;

 // late AnimationController _pulseController;
 // late Animation<Color?> _colorAnimation;

//  int pendingImportCount = 0;

  @override
  void dispose() {
    _crmQueueTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
  Map<String, dynamic>? company;
  String? userName;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _crmColourAnimation = ColorTween(
      begin: Colors.teal,
      end: Colors.redAccent,
    ).animate(_pulseController);

    loadCompanyProfile();
    loadPendingImportCount();

    _crmQueueTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => loadPendingImportCount(),
    );
  }

  Future<void> loadPendingImportCount() async {
    try {
      final data = await supabase
          .from('crm_email_import_log')
          .select('id')
          .eq('import_status', 'pending');

      if (!mounted) return;

      final count = data.length;
      final wasZero = pendingImportCount == 0;

      setState(() {
        pendingImportCount = count;
      });

      if (count > 0) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }

        if (wasZero) {
          HapticFeedback.lightImpact();
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    } catch (e) {
      debugPrint('CRM pending queue count error: $e');
    }
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
                      userName: userName,
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.95,
                      ),
                      delegate: SliverChildListDelegate(
                        [
                          dashboardTile(
                            icon: Icons.pets,
                            title: 'Dogs',
                            page: const DogsPage(),
                            colour: primary,
                          ),
                          dashboardTile(
                            icon: Icons.route,
                            title: 'The Flow',
                            page: const FlowDashboardPage(),
                            colour: accent,
                          ),

                     /*     
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final color = pendingImportCount > 0
                                  ? _colorAnimation.value
                                  : Colors.teal;

                              return dashboardTile(
                                icon: Icons.hub,
                                title: pendingImportCount > 0
                                    ? 'CRM Hub\n$pendingImportCount waiting'
                                    : 'CRM Hub',
                                page: const CrmDashboardPage(),
                                colour: color ?? Colors.teal,
                              );
                            },
                           
                          ),
                          dashboardTile(
                            icon: Icons.people,
                            title: 'People',
                            page: const PeoplePage(),
                            colour: Colors.indigo,
                          ),
                     */     
/// add old tile back in 
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final colour = pendingImportCount > 0
                                  ? (_crmColourAnimation.value ?? Colors.teal)
                                  : Colors.teal;

                              return dashboardTile(
                                icon: Icons.hub,
                                title: pendingImportCount > 0
                                    ? 'CRM Hub\n$pendingImportCount waiting'
                                    : 'CRM Hub',
                                page: const CrmDashboardPage(),
                                colour: colour,
                              );
                            },
                          ),


                          dashboardTile(
                            icon: Icons.event_note,
                            title: 'Daily',
                            page: const DailiesPage(),
                            colour: Colors.orange,
                          ),
                          dashboardTile(
                            icon: Icons.calendar_month,
                            title: 'Calendar',
                            page: const CalendarPage(),
                            colour: Colors.blue,
                          ),
                          dashboardTile(
                            icon: Icons.directions_car,
                            title: 'Vehicle Log',
                            page: const VehicleLogPage(),
                            colour: Colors.green,
                          ),
                          dashboardTile(
                            icon: Icons.bar_chart,
                            title: 'Reports',
                            page: const ReportsPage(),
                            colour: secondary,
                            darkText: true,
                          ),
                          dashboardTile(
                            icon: Icons.admin_panel_settings,
                            title: 'Admin',
                            page: const AdminPage(),
                            colour: Colors.deepPurple,
                          ),
                          dashboardTile(
                            icon: Icons.build,
                            title: 'Tools',
                            page: const ToolsPage(),
                            colour: Colors.blueGrey,
                          ),
                        ],
                      ),
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
    required String? userName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, accent],
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
                      userName != null ? 'Welcome back $userName' : 'Welcome',
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

    Widget dashboardTile({
      required IconData icon,
      required String title,
      required Widget page,
      required Color colour,
      bool darkText = false,
    }) {
      return _DashboardTile(
        icon: icon,
        title: title,
        page: page,
        colour: colour,
        darkText: darkText,
      );
    }
  }

  class _DashboardTile extends StatefulWidget {
    final IconData icon;
    final String title;
    final Widget page;
    final Color colour;
    final bool darkText;

    const _DashboardTile({
      required this.icon,
      required this.title,
      required this.page,
      required this.colour,
      required this.darkText,
    });

    @override
    State<_DashboardTile> createState() => _DashboardTileState();
  }

  class _DashboardTileState extends State<_DashboardTile> {
    bool pressed = false;

    @override
    Widget build(BuildContext context) {
      final textColour = widget.darkText ? Colors.black87 : Colors.white;

      return GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) {
          setState(() => pressed = false);

          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => widget.page),
          );
        },
        child: AnimatedScale(
          scale: pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.colour.withOpacity(0.95),
                  widget.colour,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.colour.withOpacity(pressed ? 0.38 : 0.24),
                  blurRadius: pressed ? 18 : 12,
                  offset: Offset(0, pressed ? 4 : 7),
                ),
              ],
            ),
            child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          widget.icon,
          size: 44, // 👈 slightly larger
          color: Colors.white,
        ),
      ),

      const SizedBox(height: 16),

      Text(
        widget.title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textColour,
        ),
      ),
    ],
  ),
        ),
      ),
    );
  }
}