import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonPicker extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? selectedPerson;
  final Function(Map<String, dynamic>) onSelected;
  final bool useBusinessName;

  const PersonPicker({
    super.key,
    required this.label,
    required this.selectedPerson,
    required this.onSelected,
    this.useBusinessName = false,
  });

  /// 🔍 Highlight search matches
  Widget _highlightText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final matches =
        RegExp(query, caseSensitive: false).allMatches(text);

    if (matches.isEmpty) return Text(text);

    List<TextSpan> spans = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentQuery = '';

    final controller = TextEditingController(
      text: selectedPerson != null
          ? (useBusinessName
              ? (selectedPerson!['business_name'] ?? '')
              : "${selectedPerson!['first_name_1st'] ?? ''} ${selectedPerson!['last_name_1st'] ?? ''}")
          : '',
    );

    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      debounceDuration: const Duration(milliseconds: 300),

      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            useBusinessName ? Icons.home_work : Icons.person,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      suggestionsCallback: (pattern) async {
        currentQuery = pattern;

        if (pattern.isEmpty) return [];

        final response = await Supabase.instance.client
            .from('people')
            .select()
            .or(
              'first_name_1st.ilike.%$pattern%,'
              'last_name_1st.ilike.%$pattern%,'
              'business_name.ilike.%$pattern%',
            )
            .limit(10);

        return List<Map<String, dynamic>>.from(response);
      },

      itemBuilder: (context, person) {
        final business = person['business_name'] ?? '';
        final name =
            "${person['first_name_1st'] ?? ''} ${person['last_name_1st'] ?? ''}";

        return ListTile(
          title: Text(
            useBusinessName
                ? (business.isNotEmpty ? business : name)
                : name,
          ),
          subtitle: useBusinessName ? Text(name) : null,
        );
      },

      onSuggestionSelected: (person) {
        print("SELECTED PERSON: ${person['people_id']}"); // 👈 DEBUG
        FocusScope.of(context).unfocus();
        onSelected(person);
      },
    );
  }
}