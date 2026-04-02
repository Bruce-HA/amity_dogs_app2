class LitterStats {
  final int litters;
  final int pups;
  final int males;
  final int females;

  LitterStats({
    required this.litters,
    required this.pups,
    required this.males,
    required this.females,
  });
}

LitterStats calculateLitterStatsFromDogs(List dogs, String dogAla) {
  int m = 0;
  int f = 0;
  final Set<String> litterSet = {};

  for (var pup in dogs) {
    final ala = pup['dog_ala']?.toString();
    final sexRaw = pup['sex']?.toString().toLowerCase();

    if (sexRaw != null) {
      if (sexRaw.startsWith('m')) m++;
      if (sexRaw.startsWith('f')) f++;
    }

    if (ala != null) {
      final parts = ala.split('-');
      if (parts.length >= 2) {
        litterSet.add('${parts[0]}-${parts[1]}');
      }
    }
  }

  return LitterStats(
    litters: litterSet.length,
    pups: m + f,
    males: m,
    females: f,
  );
}