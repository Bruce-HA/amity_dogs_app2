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

        final b = genotypeMap['B'] ?? {};
        final e = genotypeMap['E'] ?? {};

        double black = 0;
        double chocolate = 0;
        double caramel = 0;
        double cream = 0;

        double gold = 0;
        // =========================
        // PRIMARY VISIBLE COLOUR ONLY
        // Must total 100%
        // =========================

                // =========================
        // PRIMARY VISIBLE COLOUR ONLY
        // Must total 100%
        // =========================

        double chocolateChance = 0;
        double caramelChance = 0;

        b.forEach((geno, pct) {
          if (geno.contains('b/b')) {
            chocolateChance += pct;
          }
        });

        e.forEach((geno, pct) {
          if (geno == 'e/e') {
            caramelChance += pct;
          }
        });

        // e/e overrides visually
        if (chocolateChance > 0 && caramelChance > 0) {
          chocolate = chocolateChance * 0.5;
          caramel = caramelChance * 0.3;
          cream = caramelChance * 0.1;
          gold = caramelChance * 0.1;
        }
        else if (chocolateChance > 0) {
          chocolate = chocolateChance;
          black = 100 - chocolate;
        }
        else if (caramelChance > 0) {
          caramel = caramelChance * 0.7;
          cream = caramelChance * 0.15;
          gold = caramelChance * 0.15;
          black = 100 - caramelChance;
        }
        else {
          black = 100;
        }

        // =========================
        // FINAL MAP
        // =========================

        void add(String name, double value) {
          if (value > 0) {
            results[name] = value;
          }
        }

        add('Black', black);
        add('Chocolate', chocolate);
        add('Caramel', caramel);
        add('Cream', cream);
        add('Gold', gold);

        return results;
      }
    }
