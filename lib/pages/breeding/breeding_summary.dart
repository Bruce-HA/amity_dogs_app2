import 'package:flutter/material.dart';

class BreedingSummarySection extends StatelessWidget {
  final Map<String, String> femaleDNA;
  final Map<String, String> maleDNA;
  final List<String> sharedAncestors;
  final String femaleName;
  final String maleName;

  const BreedingSummarySection({
    super.key,
    required this.femaleDNA,
    required this.maleDNA,
    required this.sharedAncestors,
    required this.femaleName,
    required this.maleName,
  });

  List<String> _buildAdvice() {
    final advice = <String>[];

    // Colour prediction
    if (femaleDNA['B'] == 'b/b' && maleDNA['B'] == 'b/b') {
      advice.add('100% liver pigment puppies expected');
    }

    if (femaleDNA['E'] == 'e/e' && maleDNA['E'] == 'e/e') {
      advice.add('100% caramel / gold based coats expected');
    }

    // Merle safety
    if (femaleDNA['M'] == 'm/m' && maleDNA['M'] == 'm/m') {
      advice.add('No merle puppies possible • safe non-merle pairing');
    }

    // Parti
    if (femaleDNA['S'] == 'S/S' && maleDNA['S'] == 'S/S') {
      advice.add('No parti puppies expected • low white marking risk');
    }

    // Hidden tan points
    if ((femaleDNA['A']?.contains('at') ?? false) ||
        (maleDNA['A']?.contains('at') ?? false)) {
      advice.add('Tan point genetics present • useful for future phantom programs');
    }

    // COI awareness
    if (sharedAncestors.isNotEmpty) {
      advice.add('Shared ancestry present • monitor COI for future pairings');
    }

    if (advice.isEmpty) {
      advice.add('Strong balanced pairing with no major genetic concerns detected');
    }

    return advice;
  }

  String _recommendationScore() {
    if (femaleDNA['M'] == 'm/m' &&
        maleDNA['M'] == 'm/m' &&
        femaleDNA['B'] == 'b/b' &&
        maleDNA['B'] == 'b/b') {
      return 'Highly Recommended';
    }

    return 'Recommended';
  }

  @override
  Widget build(BuildContext context) {
    final advice = _buildAdvice();
    final recommendation = _recommendationScore();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.green,
                  size: 22,
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Breeding Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Recommendations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text(
              '$femaleName × $maleName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),

            ...advice.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Breeder Recommendation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Strong pairing for consistent companion puppies, reliable coat quality, and structured future breeding decisions.',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
