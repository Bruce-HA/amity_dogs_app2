import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/app_card.dart';
import '../../ui/spacing.dart';

class DogListCard extends StatelessWidget {
  final Map dog;
  final VoidCallback onTap;

  const DogListCard({
    super.key,
    required this.dog,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = dog['dog_name'] ?? 'Unnamed';
    final status = dog['status'] ?? '';
    final sex = dog['sex'] ?? '';

    final litters = dog['litter_count'] ?? 0;
    final pups = dog['puppy_count'] ?? 0;

    // 🔥 IMAGE RESOLUTION
    final rawUrl = dog['hero_image_url'];

    String? finalUrl;

    if (rawUrl != null && rawUrl.toString().isNotEmpty) {
      if (rawUrl.toString().startsWith('http')) {
        finalUrl = rawUrl;
      } else {
        final dogAla = dog['dog_ala'];
        finalUrl = Supabase.instance.client.storage
            .from('dog_files')
            .getPublicUrl('$dogAla/photos/$rawUrl');
      }
    }

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: finalUrl != null
                ? AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      finalUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.pets, size: 40),
                  ),
          ),

          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NAME + SEX
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(sex == 'Male' ? '🔵' : '🩷'),
                  ],
                ),

                AppSpacing.hXs,

                // STATUS CHIP
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

                AppSpacing.hMd,

                // STATS
                Row(
                  children: [
                    _Stat("Litters", litters),
                    AppSpacing.wLg,
                    _Stat("Pups", pups),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 REQUIRED helper widget (this was missing)
class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}