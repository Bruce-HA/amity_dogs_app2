import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonPicker extends StatefulWidget {
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

  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    _setInitialText();
  }

  @override
  void didUpdateWidget(covariant PersonPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setInitialText();
  }

  void _setInitialText() {
    if (widget.selectedPerson == null) {
      controller.text = '';
      return;
    }

    final p = widget.selectedPerson!;

    controller.text = widget.useBusinessName
        ? (p['business_name'] ?? '')
        : "${p['first_name_1st'] ?? ''} ${p['last_name_1st'] ?? ''}";
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      debounceDuration: const Duration(milliseconds: 300),

      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(
            widget.useBusinessName ? Icons.home_work : Icons.person,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) return [];

        final client = Supabase.instance.client;

        /// 🔥 If looks like UUID → search directly
        if (pattern.length > 20 && pattern.contains('-')) {
          final response = await client
              .from('people')
              .select()
              .eq('people_id', pattern)
              .limit(1);

          return List<Map<String, dynamic>>.from(response);
        }

        /// 🔍 Otherwise normal search
        final response = await client
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
            widget.useBusinessName
                ? (business.isNotEmpty ? business : name)
                : name,
          ),
          subtitle: Text(person['people_id']), // 👈 ADD THIS
        );
      },

      onSuggestionSelected: (person) {
        controller.text = widget.useBusinessName
            ? (person['business_name'] ?? '')
            : "${person['first_name_1st'] ?? ''} ${person['last_name_1st'] ?? ''}";

        widget.onSelected(person);
      },
    );
  }
}