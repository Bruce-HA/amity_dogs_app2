import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'people_edit_page.dart';
import 'package:url_launcher/url_launcher.dart';

class PeopleDetailPage extends StatefulWidget {
  final String personId;
  final String? dogName;
  final String? dogAla;

  const PeopleDetailPage({
    super.key,
    required this.personId,
    this.dogName,
    this.dogAla,
  });

  @override
  State<PeopleDetailPage> createState() => _PeopleDetailPageState();
}

class _PeopleDetailPageState extends State<PeopleDetailPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? person;
  String? replyToEmail;
  bool loading = true;

  int selectedTab = 0;
  final tabs = ['Overview', 'Notes', 'Files'];

  @override
  void initState() {
    super.initState();
    loadPerson();
  }

  Future<void> loadPerson() async {
    final personRes = await supabase
        .from('people')
        .select()
        .eq('people_id', widget.personId)
        .maybeSingle();

    final settingsRes = await supabase
        .from('app_settings') // ✅ YOUR TABLE
        .select()
        .limit(1)
        .maybeSingle();

    setState(() {
      person = personRes;
      replyToEmail = settingsRes?['reply_to_email'];
      loading = false;
    });
  }

  // 🔥 ACTIONS

  Future<void> _call(String phone) async {
    final uri = Uri.parse("tel:$phone");
    await launchUrl(uri);
  }

  Future<void> _email(String email) async {
    final uri = Uri.parse(
      "mailto:$email"
      "?subject="
      "&body="
      "${replyToEmail != null ? 'From: $replyToEmail%0D%0A%0D%0A' : ''}",
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _maps(String address) async {
    final uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    await launchUrl(uri);
  }
    //// add whatapps and sms
  Future<void> _sms(String phone) async {
    final uri = Uri.parse("sms:$phone");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsapp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse("https://wa.me/$cleaned");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
    
    
  // 🔥 HEADER CARD

  Widget buildHeaderCard() {
    final name =
        "${person?['first_name_1st'] ?? ''} ${person?['last_name_1st'] ?? ''}";
    final business = person?['business_name'];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (business != null && business.toString().isNotEmpty)
            Text(
              business,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

          Text(
            name,
            style: TextStyle(color: Colors.grey.shade700),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (person?['phone_1st'] != null)
                _ActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: () => _call(person!['phone_1st']),
                ),

              if (person?['phone_1st'] != null)
                _ActionButton(
                  icon: Icons.sms,
                  label: 'SMS',
                  onTap: () => _sms(person!['phone_1st']),
                ),

              if (person?['phone_1st'] != null)
                _ActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () => _whatsapp(person!['phone_1st']),
                ),

              if (person?['email_1st'] != null)
                _ActionButton(
                  icon: Icons.email,
                  label: 'Email',
                  onTap: () => _email(person!['email_1st']),
                ),
            ],
          )
        ],
      ),
    );
  }

  // 🔥 ADDRESS CARD

  Widget buildAddressCard() {
    final address =
        "${person?['street_address'] ?? ''} ${person?['suburb_address'] ?? ''} ${person?['postcode_address'] ?? ''}";

    if (address.trim().isEmpty) return const SizedBox();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Address',
              style: TextStyle(fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          Text(address),

          const SizedBox(height: 12),

          Row(
            children: [
              _MapButton(
                label: 'Google',
                icon: Icons.map,
                onTap: () => _openGoogleMaps(address),
              ),

              const SizedBox(width: 8),

              _MapButton(
                label: 'Apple',
                icon: Icons.apple,
                onTap: () => _openAppleMaps(address),
              ),

              const SizedBox(width: 8),

              _MapButton(
                label: 'Waze',
                icon: Icons.navigation,
                onTap: () => _openWaze(address),
              ),
            ],
          )
        ],
      ),
    );
  }
///
  Widget buildSecondContactCard() {
    final hasData =
        (person?['first_name_2nd'] != null &&
            person!['first_name_2nd'].toString().isNotEmpty) ||
        (person?['email_2nd'] != null &&
            person!['email_2nd'].toString().isNotEmpty) ||
        (person?['phone_2nd'] != null &&
            person!['phone_2nd'].toString().isNotEmpty);

    if (!hasData) return const SizedBox();

    final name =
        "${person?['first_name_2nd'] ?? ''} ${person?['last_name_2nd'] ?? ''}";
    final relationship = person?['relationship_2nd'] ?? '';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Second Contact',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          Text(name),

          if (relationship.toString().isNotEmpty)
            Text(
              relationship,
              style: TextStyle(color: Colors.grey.shade600),
            ),

          const SizedBox(height: 12),

          Row(
            children: [
              if (person?['phone_2nd'] != null)
                _ActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: () => _call(person!['phone_2nd']),
                ),

              if (person?['email_2nd'] != null)
                _ActionButton(
                  icon: Icons.email,
                  label: 'Email',
                  onTap: () => _email(person!['email_2nd']),
                ),
            ],
          ),
        ],
      ),
    );
  }
/// Add Map links
/// 
   Future<void> _openGoogleMaps(String address) async {
      final url =
          "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}";
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    Future<void> _openAppleMaps(String address) async {
      final url =
          "https://maps.apple.com/?q=${Uri.encodeComponent(address)}";
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    Future<void> _openWaze(String address) async {
      final url =
          "https://waze.com/ul?q=${Uri.encodeComponent(address)}";
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  // 🔥 TAG GRID

  Widget buildTags() {
    final tags = [
      ['Breeder', person?['is_breeder']],
      ['Owner', person?['is_owner']],
      ['Guardian', person?['is_guardian']],
      ['Prospect', person?['is_prospect']],
      ['Buyer', person?['is_buyer']],
      ['Supplier', person?['is_supplier']],
    ];

    return _Card(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .where((t) => t[1] == true)
            .map((t) => Chip(label: Text(t[0] as String)))
            .toList(),
      ),
    );
  }

  Widget buildNotesCard() {
    final notes = person?['notes'];

    if (notes == null || notes.toString().trim().isEmpty) {
      return const SizedBox();
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(notes),
        ],
      ),
    );
  }

  // 🔥 OVERVIEW

  Widget buildOverview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        buildHeaderCard(),
        const SizedBox(height: 12),

        buildSecondContactCard(), // ✅ CORRECT

        const SizedBox(height: 12),
        buildAddressCard(),
        const SizedBox(height: 12),
        buildTags(),
        const SizedBox(height: 12),
        buildNotesCard(),
      ],
    );
  }

  // 🔥 TABS

  Widget buildTabs() {
    return Row(
      children: List.generate(tabs.length, (index) {
        final selected = selectedTab == index;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedTab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: selected
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Text(
                tabs[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget buildTabContent() {
    switch (tabs[selectedTab]) {
      case 'Overview':
        return buildOverview();
      default:
        return const Center(child: Text('Coming soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Person'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PeopleEditPage(person: person!),
                ),
              );

              await loadPerson(); // 🔥 refresh
            },
          )
        ],
      ),
      body: Column(
        children: [
          buildTabs(),
          Expanded(child: buildTabContent()),
        ],
      ),
    );
  }
}

// 🔥 REUSABLE COMPONENTS

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
class _MapButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}