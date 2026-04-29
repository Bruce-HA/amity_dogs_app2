import 'package:flutter/material.dart';
import '../widgets/app_dog_image.dart';

class BreedingPlanA4Page extends StatelessWidget {
  final Map<String, dynamic> company;
  final Map<String, dynamic> femaleDog;
  final Map<String, dynamic> maleDog;
  final Map<String, dynamic> colourResults;
  final String puppyGrade;
  final double coi;
  final double avk;
  final List<String> warnings;
  final List<String> healthWarnings;
  final String breedingPlanCode;

  const BreedingPlanA4Page({
    super.key,
    required this.company,
    required this.femaleDog,
    required this.maleDog,
    required this.colourResults,
    required this.puppyGrade,
    required this.coi,
    required this.avk,
    required this.warnings,
    required this.healthWarnings,
    required this.breedingPlanCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text('Breeding Report • $breedingPlanCode'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 794,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildParentDogsSection(),
                const SizedBox(height: 20),
                _buildMetricCards(),
                const SizedBox(height: 20),
                _buildColourOutcomes(),
                const SizedBox(height: 20),
                _buildHealthSection(),
                const SizedBox(height: 20),
                _buildFooterNotes(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2B0B45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company['company_name'] ?? 'Amity Labradoodles',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                company['trading_name']?.toString().isNotEmpty == true
                    ? company['trading_name']
                    : 'BREEDING PLAN REPORT',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${company['email'] ?? ''}   ${company['phone'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${company['association_name'] ?? ''} ${company['association_number'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              const Text(
                'BREEDING PLAN REPORT',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildParentDogsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 22, child: _dogInfoCard('DAM', femaleDog, true)),
        Expanded(flex: 24, child: _dogPhoto(femaleDog)),
        Expanded(
          flex: 8,
          child: Column(
            children: const [
              SizedBox(height: 60),
              Text(
                '×',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Expected\nLitter\nOutcomes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(flex: 24, child: _dogPhoto(maleDog)),
        Expanded(flex: 22, child: _dogInfoCard('SIRE', maleDog, false)),
      ],
    );
  }

  Widget _dogInfoCard(String label, Map<String, dynamic> dog, bool female) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          dog['dog_name'] ?? '',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          dog['pet_name'] ?? '',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text('Colour: ${dog['colour'] ?? '-'}'),
        Text('Coat: ${dog['coat_type'] ?? '-'}'),
        Text('Size: ${dog['size'] ?? '-'}'),
        Text('Sex: ${female ? 'Female' : 'Male'}'),
      ],
    );
  }

  Widget _dogPhoto(Map<String, dynamic> dog) {
    return Center(
      child: AppDogImage(
        dogId: dog['id'],
        dogAla: dog['dog_ala'],
        size: 220,
        radius: 12,
      ),
    );
  }

  Widget _buildMetricCards() {
    return Row(
      children: [
        Expanded(child: _metricCard('Puppy Grade', puppyGrade)),
        const SizedBox(width: 16),
        Expanded(child: _metricCard('COI', '${coi.toStringAsFixed(2)}%')),
        const SizedBox(width: 16),
        Expanded(child: _metricCard('AVK / ALC', '${avk.toStringAsFixed(1)}%')),
      ],
    );
  }

  Widget _metricCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColourOutcomes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expected Colour Outcomes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...colourResults.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key.toString()),
                Text('${entry.value}%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthSection() {
    final allWarnings = [...warnings, ...healthWarnings];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health + Genetic Considerations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (allWarnings.isEmpty)
          const Text('No major breeding risks identified.')
        else
          ...allWarnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $w'),
            ),
          ),
      ],
    );
  }

  Widget _buildFooterNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          company['default_disclaimer'] ??
              'Breeding report generated for breeder planning purposes only.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${company['street_address'] ?? ''}, ${company['suburb'] ?? ''} ${company['state'] ?? ''} ${company['postcode'] ?? ''}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          company['website'] ?? '',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Breeder ID: ${company['breeder_id'] ?? '-'}   Prefix: ${company['breeder_prefix'] ?? '-'}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
