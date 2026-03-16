import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tabs/dog_notes_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_correspondence_tab.dart';

class PeopleDetailPage extends StatefulWidget {
  final String personId;

  const PeopleDetailPage({
    super.key,
    required this.personId,
  });

  @override
  State<PeopleDetailPage> createState() => _PeopleDetailPageState();
}

class _PeopleDetailPageState extends State<PeopleDetailPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? person;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final response = await supabase
        .from('people')
        .select()
        .eq('people_id', widget.personId)
        .single();

    setState(() {
      person = response;
      loading = false;
    });
  }

  // =========================================================
  // ACTIONS
  // =========================================================

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void call(String? phone) {
    if (phone == null || phone.isEmpty) return;
    _launch("tel:$phone");
  }

  void email(String? email) {
    if (email == null || email.isEmpty) return;
    _launch("mailto:$email");
  }

  void whatsapp(String? phone) {
    if (phone == null || phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    _launch("https://wa.me/$cleaned");
  }
  void openWaze(String address) {
    _launch(
      "https://waze.com/ul?q=${Uri.encodeComponent(address)}&navigate=yes",
    );
  }

  void openAppleMaps(String address) {
    _launch(
      "https://maps.apple.com/?daddr=${Uri.encodeComponent(address)}",
    );
  }
  void openGoogleMaps(String address) {
    _launch(
        "https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}");
  }

  // =========================================================
  // ROLE CHIP
  // =========================================================

  Widget roleChip(String label, bool enabled, Color color) {
    if (!enabled) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Chip(
        label: Text(label),
        backgroundColor: color.withOpacity(.15),
        labelStyle: TextStyle(color: color),
      ),
    );
  }

  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (loading || person == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final business = person!['business_name'] ?? '';
    final first1 = person!['first_name_1st'] ?? '';
    final last1 = person!['last_name_1st'] ?? '';
    final phone1 = person!['phone_1st'] ?? '';
    final email1 = person!['email_1st'] ?? '';

    final street = person!['street_address'] ?? '';
    final suburb = person!['suburb_address'] ?? '';
    final postcode = person!['postcode_address'] ?? '';
    final state = person!['state_address'] ?? '';

    final fullAddress = "$street, $suburb, $postcode $state";

    final hasAddress = fullAddress.trim().replaceAll(',', '').isNotEmpty;

    final displayName = business.toString().isNotEmpty
        ? business
        : "$first1 $last1";

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(displayName),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: push edit screen
              },
            ),
          ],
        ),

        // ===============================
        // BODY
        // ===============================

        body: Column(
          children: [

            // ===============================
            // PREMIUM HEADER CARD
            // ===============================

            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      business,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "$first1 $last1",
                      style: const TextStyle(fontSize: 18),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [

                        Tooltip(
                          message: phone1.isEmpty ? "No phone number" : "Call $phone1",
                          child: IconButton(
                            icon: const Icon(Icons.phone),
                            onPressed: phone1.isEmpty ? null : () => call(phone1),
                          ),
                        ),

                        Tooltip(
                          message: email1.isEmpty ? "No email address" : "Email $email1",
                          child: IconButton(
                            icon: const Icon(Icons.email),
                            onPressed: email1.isEmpty ? null : () => email(email1),
                          ),
                        ),

                        Tooltip(
                          message: phone1.isEmpty ? "No phone for WhatsApp" : "WhatsApp $phone1",
                          child: IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: phone1.isEmpty ? null : () => whatsapp(phone1),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 30),

                    Text(
                      fullAddress,
                      style: const TextStyle(fontSize: 14),
                    ),

                    Row(
                      children: [

                        Tooltip(
                          message: hasAddress ? "Open in Google Maps" : "No address available",
                          child: IconButton(
                            icon: const Icon(Icons.map),
                            onPressed: hasAddress ? () => openGoogleMaps(fullAddress) : null,
                          ),
                        ),


                        Tooltip(
                          message: hasAddress ? "Open in Waze" : "No address available",
                          child: IconButton(
                            icon: const Icon(Icons.navigation),
                            onPressed: hasAddress ? () => openWaze(fullAddress) : null,
                          ),
                        ),

                        Tooltip(
                          message: hasAddress ? "Open in Apple Maps" : "No address available",
                          child: IconButton(
                            icon: const Icon(Icons.location_on),
                            onPressed: hasAddress ? () => openAppleMaps(fullAddress) : null,
                          ),
                        ),
                        

                      ],
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      children: [
                        roleChip("Breeder",
                            person!['is_breeder'] ?? false, Colors.purple),
                        roleChip("Owner",
                            person!['is_owner'] ?? false, Colors.blue),
                        roleChip("Guardian",
                            person!['is_guardian'] ?? false, Colors.teal),
                        roleChip("Supplier",
                            person!['is_supplier'] ?? false, Colors.orange),
                        roleChip("Buyer",
                            person!['is_buyer'] ?? false, Colors.green),
                        roleChip("Prospect",
                            person!['is_prospect'] ?? false, Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ===============================
            // TABS (Like DogDetailsPage)
            // ===============================

            const TabBar(
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.teal,
              tabs: [
                Tab(text: "Notes"),
                Tab(text: "Files"),
                Tab(text: "Correspondence"),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  DogNotesTab(dogId: widget.personId), // reuse logic pattern
                  DogFilesTab(
                    dogId: widget.personId,
                    dogAla: displayName,
                  ),
                  DogCorrespondenceTab(dogId: widget.personId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}