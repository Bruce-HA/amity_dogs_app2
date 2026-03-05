import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DogCorrespondenceTab extends StatefulWidget {
  final String dogId;

  const DogCorrespondenceTab({super.key, required this.dogId});

  @override
  State<DogCorrespondenceTab> createState() => _DogCorrespondenceTabState();
}

class _DogCorrespondenceTabState extends State<DogCorrespondenceTab> {
  final supabase = Supabase.instance.client;

  List items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    final result = await supabase
        .from('communications')
        .select()
        .eq('dog_id', widget.dogId)
        .order('created_at', ascending: false);

    setState(() {
      items = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,

      itemBuilder: (_, i) {
        final item = items[i];

        return ListTile(
          title: Text(item['subject'] ?? ''),

          subtitle: Text(item['message_body'] ?? ''),
        );
      },
    );
  }
}
