String calculateDogAge(String? dobString) {
  if (dobString == null || dobString.isEmpty) return '';

  final dob = DateTime.parse(dobString);
  final now = DateTime.now();

  int years = now.year - dob.year;
  int months = now.month - dob.month;

  if (years == 0) {
  return "${months}m";
}
if (months == 0) {
  return "${years}y";
}
return "${years}y ${months}m";

}