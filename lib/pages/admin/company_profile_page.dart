import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({super.key});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? profileId;

  // =========================
  // Controllers
  // =========================

  final companyName = TextEditingController();
  final tradingName = TextEditingController();
  final contactName = TextEditingController();

  final email = TextEditingController();
  final phone = TextEditingController();
  final mobile = TextEditingController();
  final website = TextEditingController();

  final abnBinNumber = TextEditingController();
  final associationName = TextEditingController();
  final associationNumber = TextEditingController();

  final breederPrefix = TextEditingController();

  final streetAddress = TextEditingController();
  final suburb = TextEditingController();
  final state = TextEditingController();
  final postcode = TextEditingController();
  final country = TextEditingController(text: 'Australia');

  final defaultCoiThreshold = TextEditingController(text: '5');
  final defaultAvkThreshold = TextEditingController(text: '85');

  final defaultBreedingNotes = TextEditingController();
  final defaultHealthWarningText = TextEditingController();
  final defaultDisclaimer = TextEditingController();
  final footerText = TextEditingController();

  final breederId = TextEditingController();
  final prefixApprovalDate = TextEditingController();

  final primaryColour = TextEditingController();
  final secondaryColour = TextEditingController();
  final accentColour = TextEditingController();
  final backgroundColour = TextEditingController();
  final textColour = TextEditingController();

  String preferredColourSet = 'Purple + Gold';
  String? companyLogoUrl;
  String? associationLogoUrl;

  final colourOptions = [
    'Purple + Gold',
    'Forest + Cream',
    'Navy + Silver',
    'Burgundy + Gold',
    'Emerald + Bronze',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // =========================
  // LOAD PROFILE
  // =========================

  Future<void> _loadProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final appUser = await supabase
          .from('app_users')
          .select('company_profile_id')
          .eq('id', userId)
          .maybeSingle();

      if (appUser == null ||
          appUser['company_profile_id'] == null) {
        setState(() => _loading = false);
        return;
      }

      final companyProfileId =
          appUser['company_profile_id'];

      final data = await supabase
          .from('company_profile')
          .select()
          .eq('id', companyProfileId)
          .maybeSingle();

      if (data != null) {
        profileId = data['id'];

        companyName.text = data['company_name'] ?? '';
        tradingName.text = data['trading_name'] ?? '';
        contactName.text = data['contact_name'] ?? '';

        email.text = data['email'] ?? '';
        phone.text = data['phone'] ?? '';
        mobile.text = data['mobile'] ?? '';
        website.text = data['website'] ?? '';

        abnBinNumber.text =
            data['abn_bin_number'] ?? '';

        associationName.text =
            data['association_name'] ?? '';

        associationNumber.text =
            data['association_number'] ?? '';

        breederPrefix.text =
            data['breeder_prefix'] ?? '';

        breederId.text =
            data['breeder_id'] ?? '';

        prefixApprovalDate.text =
            data['prefix_approval_date']
                    ?.toString() ??
                '';

        streetAddress.text =
            data['street_address'] ?? '';

        suburb.text = data['suburb'] ?? '';
        state.text = data['state'] ?? '';
        postcode.text = data['postcode'] ?? '';
        country.text =
            data['country'] ?? 'Australia';

        preferredColourSet =
            data['preferred_colour_set'] ??
                'Purple + Gold';

        primaryColour.text =
            data['primary_colour'] ?? '';

        secondaryColour.text =
            data['secondary_colour'] ?? '';

        accentColour.text =
            data['accent_colour'] ?? '';

        backgroundColour.text =
            data['background_colour'] ?? '';

        textColour.text =
            data['text_colour'] ?? '';

        defaultCoiThreshold.text =
            (data['default_coi_threshold'] ?? 5)
                .toString();

        defaultAvkThreshold.text =
            (data['default_avk_threshold'] ?? 85)
                .toString();

        defaultBreedingNotes.text =
            data['default_breeding_notes'] ?? '';

        defaultHealthWarningText.text =
            data['default_health_warning_text'] ?? '';

        defaultDisclaimer.text =
            data['default_disclaimer'] ?? '';

        footerText.text =
            data['footer_text'] ?? '';

        companyLogoUrl =
            data['company_logo_url'];

        associationLogoUrl =
            data['association_logo_url'];
      }
    } catch (e) {
      print('LOAD PROFILE ERROR: $e');
    }

    setState(() {
      _loading = false;
    });
  }
  // =========================
  // UPLOAD LOGO
  // =========================
  Future<void> _uploadLogo({
    required bool isCompanyLogo,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final appUser = await supabase
        .from('app_users')
        .select('company_profile_id')
        .eq('id', userId)
        .maybeSingle();

    if (appUser == null ||
        appUser['company_profile_id'] == null) {
      return;
    }

    final companyProfileId =
        appUser['company_profile_id'];

    final picker = ImagePicker();
     
  

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null) return;

      final file = File(picked.path);

      final fileName = isCompanyLogo
          ? 'company_logo.jpg'
          : 'association_logo.jpg';

      final path =
    '$companyProfileId/branding/$fileName';

      await supabase.storage
          .from('company_files')
          .upload(
            path,
            file,
            fileOptions: const FileOptions(
              upsert: true,
            ),
          );

      final publicUrl = supabase.storage
      .from('company_files')
      .getPublicUrl(path);

final refreshedUrl =
    '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      setState(() {
        if (isCompanyLogo) {
          companyLogoUrl = refreshedUrl;
        } else {
          associationLogoUrl = refreshedUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCompanyLogo
                ? 'Company logo uploaded'
                : 'Association logo uploaded',
          ),
        ),
      );
    } catch (e) {
      debugPrint('LOGO UPLOAD ERROR: $e');
    }
  }

  // =========================
  // SAVE PROFILE
  // =========================

  Future<void> _saveProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      final payload = {
        'id': profileId,
        'user_id': userId,
        'company_name': companyName.text,
        'trading_name': tradingName.text,
        'contact_name': contactName.text,

        'email': email.text,
        'phone': phone.text,
        'mobile': mobile.text,
        'website': website.text,

        'abn_bin_number': abnBinNumber.text,
        'association_name': associationName.text,
        'association_number': associationNumber.text,

        'breeder_prefix': breederPrefix.text,

        'breeder_id': breederId.text,
        'prefix_approval_date': prefixApprovalDate.text.isEmpty
            ? null
            : prefixApprovalDate.text,

        'primary_colour': primaryColour.text,
        'secondary_colour': secondaryColour.text,
        'accent_colour': accentColour.text,
        'background_colour': backgroundColour.text,
        'text_colour': textColour.text,

        'street_address': streetAddress.text,
        'suburb': suburb.text,
        'state': state.text,
        'postcode': postcode.text,
        'country': country.text,

        'preferred_colour_set': preferredColourSet,

        'company_logo_url': companyLogoUrl,
        'association_logo_url': associationLogoUrl,

        'default_coi_threshold':
            double.tryParse(defaultCoiThreshold.text) ?? 5,

        'default_avk_threshold':
            double.tryParse(defaultAvkThreshold.text) ?? 85,

        'default_breeding_notes':
            defaultBreedingNotes.text,

        'default_health_warning_text':
            defaultHealthWarningText.text,

        'default_disclaimer':
            defaultDisclaimer.text,

        'footer_text': 
            footerText.text,
      };

      await supabase
          .from('company_profile')
          .upsert(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Company Profile Saved"),
        ),
      );
    } catch (e) {
      debugPrint("SAVE PROFILE ERROR: $e");
    }
  }

  // =========================
  // UI HELPERS
  // =========================

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

//.    6
  Widget _buildLogoCard({
    required String title,
    required String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.image,
                    size: 32,
                  ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: onTap,
            child: const Text("Upload"),
          ),
        ],
      ),
    );
  }
//.    6
  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Company Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            sectionTitle("Business Identity"),

            field("Company Name", companyName),
            field("Trading Name", tradingName),
            field("Contact Name", contactName),

            field("Email", email),
            field("Phone", phone),
            field("Mobile", mobile),
            field("Website", website),

            field("ABN / BIN Number", abnBinNumber),
            field("Association Name", associationName),
            field("Association Number", associationNumber),
            field("Breeder ID", breederId),
            field("Prefix Approval Date", prefixApprovalDate),

            field("Breeder Prefix", breederPrefix),

            sectionTitle("Address"),

            field("Street Address", streetAddress),
            field("Suburb", suburb),
            field("State", state),
            field("Postcode", postcode),
            field("Country", country),

            sectionTitle("Report Styling"),
            field("Primary Colour", primaryColour),
            field("Secondary Colour", secondaryColour),
            field("Accent Colour", accentColour),
            field("Background Colour", backgroundColour),
            field("Text Colour", textColour),

            DropdownButtonFormField<String>(
              value: preferredColourSet,
              decoration: InputDecoration(
                labelText: "Preferred Colour Set",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: colourOptions.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  preferredColourSet = value!;
                });
              },
            ),

            sectionTitle("Branding Assets"),

              _buildLogoCard(
                title: "Company Logo",
                imageUrl: companyLogoUrl,
                onTap: () => _uploadLogo(
                  isCompanyLogo: true,
                ),
              ),

              const SizedBox(height: 12),

              _buildLogoCard(
                title: "Association Logo",
                imageUrl: associationLogoUrl,
                onTap: () => _uploadLogo(
                  isCompanyLogo: false,
                ),
              ),

              const SizedBox(height: 12),

            sectionTitle("Breeding Defaults"),

            field(
              "Footer Text",
              footerText,
            ),
            
            field(
              "Default COI Threshold",
              defaultCoiThreshold,
            ),

            field(
              "Default AVK Threshold",
              defaultAvkThreshold,
            ),

            field(
              "Standard Breeding Notes",
              defaultBreedingNotes,
              maxLines: 4,
            ),

            field(
              "Health Warning Text",
              defaultHealthWarningText,
              maxLines: 4,
            ),

            field(
              "Default Disclaimer",
              defaultDisclaimer,
              maxLines: 5,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                ),
                child: const Text(
                  "Save Company Profile",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}