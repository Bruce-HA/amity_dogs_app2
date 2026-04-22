class ColourService {

  static String determineColour(Map<String, String> g) {
    final E = g['E'] ?? '';
    final K = g['K'] ?? '';
    final B = g['B'] ?? '';
    final A = g['A'] ?? '';

    // 🧬 E overrides everything
    if (!E.contains('E')) {
      return 'Caramel';
    }

    // 🧬 Dominant black
    if (K.contains('KB')) {
      return 'Black';
    }

    // 🧬 Chocolate
    if (!B.contains('B')) {
      return 'Chocolate';
    }

    // 🧬 Phantom
    if (A.contains('AT')) {
      return 'Phantom';
    }

    // 🧬 Sable
    if (A.contains('AY')) {
      return 'Sable';
    }

    return 'Black';
  }
}