String calculateDogAge(String? dobString) {
  if (dobString == null || dobString.isEmpty) return '';

  final dob = DateTime.parse(dobString);
  final now = DateTime.now();

  int years = now.year - dob.year;
  int months = now.month - dob.month;

  if (months < 0) {
    years--;
    months += 12;
  }

  return "$years years $months months";
}