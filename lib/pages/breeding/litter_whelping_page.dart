import 'package:flutter/material.dart';
import '../../widgets/app_title.dart';

class LitterWhelpingPage extends StatelessWidget {
  final Map litter;

  const LitterWhelpingPage({
    super.key,
    required this.litter,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: buildTitle('Whelping', 'LitterWhelpingPage'),
      ),
      body: const Center(
        child: Text('Whelping page (move CreatePuppies here next)'),
      ),
    );
  }
}