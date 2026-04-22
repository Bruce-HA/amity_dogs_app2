class GeneticsService {

  /// Split "ay/a" → ["ay", "a"]
  static List<String> splitAlleles(String genotype) {
    if (!genotype.contains('/')) return [];
    return genotype.split('/').map((e) => e.trim()).toList();
  }

  /// Generate Punnett square for ONE locus
  static Map<String, double> punnett(String f, String m) {
    final fAlleles = splitAlleles(f);
    final mAlleles = splitAlleles(m);

    final results = <String, double>{};

    for (var fa in fAlleles) {
      for (var ma in mAlleles) {
        final combo = [fa, ma]..sort();
        final key = "${combo[0]}/${combo[1]}";

        results[key] = (results[key] ?? 0) + 25;
      }
    }

    return results;
  }
  static List<String> breedingWarnings(
    Map<String, String> f,
    Map<String, String> m,
  ) {
    final warnings = <String>[];

    // ❗ Double merle
    if (f['M']?.contains('M') == true &&
        m['M']?.contains('M') == true) {
      warnings.add("⚠️ Double Merle risk");
    }

    // ❗ Chocolate carrier pairing
    if (f['B'] == 'B/b' && m['B'] == 'B/b') {
      warnings.add("⚠️ 25% Chocolate risk");
    }

    return warnings;
  }


  /// Combine multiple loci
  static Map<String, Map<String, double>> buildGenotypeMap(
    Map<String, String> female,
    Map<String, String> male,
  ) {
    final loci = ['E', 'K', 'A', 'B', 'D', 'S', 'M'];

    final result = <String, Map<String, double>>{};

    for (final locus in loci) {
      final f = female[locus];
      final m = male[locus];

      if (f != null && m != null) {
        result[locus] = punnett(f, m);
      }
    }

    return result;
  }
  static Map<String, double> buildPhenotypes(
    Map<String, Map<String, double>> genotypeMap,
  ) {
    final results = <String, double>{};

    // Simplified for now: iterate combinations later upgrade

    genotypeMap.forEach((locus, values) {
      values.forEach((geno, pct) {
        // placeholder logic
        results[geno] = (results[geno] ?? 0) + pct;
      });
    });

    return results;
  }
}