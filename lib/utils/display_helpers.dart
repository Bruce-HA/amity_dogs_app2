String displayNose(String? value) {
  if (value == null) return '';

  switch (value.toLowerCase()) {
    case 'liver':
      return 'Rose';
    case 'black':
      return 'Black';
    default:
      return value;
  }
}