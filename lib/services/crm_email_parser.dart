import 'package:intl/intl.dart';

class ParsedCrmEnquiry {
  String formSource;
  String rawText;

  String name;
  String firstName;
  String lastName;
  String email;
  String phone;
  String address;

  String sizePreference;
  String sexPreference;
  String colourPreference;
  String timeframePreference;

  String message;
  String agreementNotes;

  DateTime? enquirySubmittedAt;

  ParsedCrmEnquiry({
    required this.formSource,
    required this.rawText,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    required this.sizePreference,
    required this.sexPreference,
    required this.colourPreference,
    required this.timeframePreference,
    required this.message,
    required this.agreementNotes,
    required this.enquirySubmittedAt,
  });
}

class CrmEmailParser {
  static ParsedCrmEnquiry parse(String raw) {
    final cleaned = _clean(raw);
    final lines = cleaned
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final labels = [
      'Name',
      'Email',
      'Contact Phone',
      'Phone',
      'Address',
      'Size',
      'Sex',
      'Coat Colour',
      'Time frame',
      'Comment or Message',
    ];

    final name = _valueAfter(lines, 'Name', labels);
    final email = _valueAfter(lines, 'Email', labels);
    final phone = _valueAfter(lines, 'Contact Phone', labels).isNotEmpty
        ? _valueAfter(lines, 'Contact Phone', labels)
        : _valueAfter(lines, 'Phone', labels);

    final address = _valueAfter(lines, 'Address', labels);
    final size = _valueAfter(lines, 'Size', labels);
    final sex = _valueAfter(lines, 'Sex', labels);
    final colour = _valueAfter(lines, 'Coat Colour', labels);
    final timeframe = _valueAfter(lines, 'Time frame', labels);
    final message = _valueAfter(lines, 'Comment or Message', labels);

    final submittedAt = _parseSubmittedDate(cleaned);

    final nameParts = name.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final isLongForm =
        size.isNotEmpty || sex.isNotEmpty || colour.isNotEmpty || timeframe.isNotEmpty;

    return ParsedCrmEnquiry(
      formSource: isLongForm ? 'website_long_form' : 'website_short_form',
      rawText: raw,
      name: name,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      address: address,
      sizePreference: size,
      sexPreference: sex,
      colourPreference: colour,
      timeframePreference: timeframe,
      message: message,
      agreementNotes: _extractAgreements(cleaned),
      enquirySubmittedAt: submittedAt,
    );
  }

  static String _clean(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('￾', '')
        .trim();
  }

  static String _valueAfter(
    List<String> lines,
    String label,
    List<String> allLabels,
  ) {
    final index = lines.indexWhere(
      (line) => line.toLowerCase() == label.toLowerCase(),
    );

    if (index == -1 || index + 1 >= lines.length) return '';

    final buffer = <String>[];

    for (int i = index + 1; i < lines.length; i++) {
      final line = lines[i];

      final isNextLabel = allLabels.any(
        (l) => line.toLowerCase() == l.toLowerCase(),
      );

      if (isNextLabel) break;
      if (line.toLowerCase().startsWith('sent from amity')) break;

      buffer.add(line);
    }

    return buffer.join('\n').trim();
  }

  static DateTime? _parseSubmittedDate(String text) {
  // Best source: email header
  final headerMatch = RegExp(
    r'Date:\s*(.+)',
    caseSensitive: false,
  ).firstMatch(text);

  if (headerMatch != null) {
    var raw = headerMatch.group(1)!.trim();

    raw = raw
        .replaceAll('\u202f', ' ')
        .replaceAll('\u00a0', ' ')
        .replaceAll(' at ', ' ')
        .replaceAll('AEST', '')
        .replaceAll('AEDT', '')
        .trim();

    final formats = [
      DateFormat('d MMMM yyyy h:mm:ss a'),
      DateFormat('d MMMM yyyy h:mm a'),
      DateFormat('d MMM yyyy h:mm:ss a'),
      DateFormat('d MMM yyyy h:mm a'),
    ];

    for (final format in formats) {
      try {
        return format.parse(raw);
      } catch (_) {}
    }
  }

  // Fallback: form date only
  final simpleDate = RegExp(r'\b(\d{1,2}/\d{1,2}/\d{4})\b').firstMatch(text);

  if (simpleDate != null) {
    try {
      return DateFormat('dd/MM/yyyy').parse(simpleDate.group(1)!);
    } catch (_) {}
  }

  return null;
}

  static String _extractAgreements(String text) {
    final agreementLines = text
        .split('\n')
        .map((e) => e.trim())
        .where((line) =>
            line.toLowerCase().contains('i understand') ||
            line.toLowerCase().contains('i agree') ||
            line.toLowerCase().contains('deposit') ||
            line.toLowerCase().contains('de-sexed') ||
            line.toLowerCase().contains('allocated'))
        .toList();

    return agreementLines.join('\n');
  }
}