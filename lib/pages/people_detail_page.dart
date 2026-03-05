import 'package:flutter/material.dart';

class PeopleDetailPage extends StatelessWidget {
  final String peopleId;

  const PeopleDetailPage({super.key, required this.peopleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Owner Details")),

      body: Center(child: Text("People Detail Page\nID: $peopleId")),
    );
  }
}
