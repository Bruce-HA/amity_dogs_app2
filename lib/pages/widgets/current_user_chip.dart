import 'package:flutter/material.dart';
import '../../services/app_user.dart';

class CurrentUserChip extends StatelessWidget {
  const CurrentUserChip({super.key});

  @override
  Widget build(BuildContext context) {
    final name = AppUser.name;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}