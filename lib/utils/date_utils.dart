String calculateDogAge(String? dobString) {
  if (dobString == null || dobString.isEmpty) return '';

  final dob = DateTime.tryParse(dobString);
  if (dob == null) return '';

  final now = DateTime.now();
  final difference = now.difference(dob);

  final totalDays = difference.inDays;

  // =====================
  // 🐶 PUPPIES (< 2 months)
  // =====================
  if (totalDays < 60) {
    if (totalDays < 7) {
      return "$totalDays day${totalDays == 1 ? '' : 's'}";
    }

    final weeks = totalDays ~/ 7;
    final days = totalDays % 7;

    if (days == 0) {
      return "$weeks week${weeks == 1 ? '' : 's'}";
    }

    return "$weeks week${weeks == 1 ? '' : 's'} "
           "$days day${days == 1 ? '' : 's'}";
  }

  // =====================
  // 🧠 STANDARD (months / years)
  // =====================
  int years = now.year - dob.year;
  int months = now.month - dob.month;

  if (now.day < dob.day) {
    months -= 1;
  }

  if (months < 0) {
    years -= 1;
    months += 12;
  }

  if (years <= 0) {
    return "$months month${months == 1 ? '' : 's'}";
  }

  if (months == 0) {
    return "$years year${years == 1 ? '' : 's'}";
  }

  return "$years year${years == 1 ? '' : 's'} "
         "$months month${months == 1 ? '' : 's'}";
}