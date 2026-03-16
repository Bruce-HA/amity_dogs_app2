import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';
import '../theme/amity_theme.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'APPEARANCE',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            _buildThemeSelector(context),

            const SizedBox(height: 24),

            Text(
              'SYSTEM',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            const Text('Admin Tools'),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Column(
      children: AmityThemeType.values.map((themeType) {
        return RadioListTile<AmityThemeType>(
          title: Text(themeType.name.toUpperCase()),
          value: themeType,
          groupValue: context.watch<ThemeProvider>().currentTheme,
          onChanged: (value) {
            if (value != null) {
              context.read<ThemeProvider>().setTheme(value);
            }
          },
        );
      }).toList(),
    );
  }
}