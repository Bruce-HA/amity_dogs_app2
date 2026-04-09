import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/spay_due_label.dart';
import '../../ui/app_card.dart';
import '../../ui/spacing.dart';
import '../../utils/date_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DogListCard extends StatelessWidget {
  final Map dog;
  final VoidCallback onTap;

  const DogListCard({
    super.key,
    required this.dog,
    required this.onTap,
  });

  Widget _sexIcon(String? sex) {
    final value = (sex ?? '').toLowerCase().trim();

    if (value == 'male') {
      return const Icon(Icons.male, color: Colors.blue, size: 18);
    } else if (value == 'female') {
      return const Icon(Icons.female, color: Colors.pink, size: 18);
    } else {
      return const SizedBox();
    }
  }

  /// 🔥 SAFE HERO IMAGE RESOLVER
  String? _resolveHeroUrl(Map dog) {
  try {
      final heroList = dog['hero'] as List?;

      if (heroList == null || heroList.isEmpty) return null;

      final hero = heroList.firstWhere(
        (p) => p['is_hero'] == true,
        orElse: () => heroList.first,
      );

      final fileName = hero['url'];
      final dogAla = dog['dog_ala'];

      if (fileName == null || dogAla == null) return null;

      return Supabase.instance.client.storage
          .from('dog_files')
          .getPublicUrl(
            '$dogAla/photos/$fileName',
            transform: const TransformOptions(
              width: 600,
              height: 450,
              resize: ResizeMode.cover,
              quality: 75,
            ),
        );
  } catch (e) {
    debugPrint('Hero image error: $e');
    return null;
  }
}

  @override
  Widget build(BuildContext context) {
    final name = dog['dog_name'] ?? 'Unnamed';
    final status = dog['status'] ?? '';
    final sex = dog['sex'] ?? '';

    /// 🔥 NEW: stats from DB view

    final litters = dog['litter_count'] ?? 0;
    final pups = dog['puppy_count'] ?? 0;

    final finalUrl = _resolveHeroUrl(dog);

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
                    child: CachedNetworkImage(
                      imageUrl: finalUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      fadeInDuration: const Duration(milliseconds: 150),
                      filterQuality: FilterQuality.low,
                      placeholder: (context, url) => Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => _placeholder(),
                    ),
                  )
                : _placeholder(),
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
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dog['dog_ala'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    ),
                    _sexIcon(sex),
                  ],
                ),

                AppSpacing.hXs,

                Text(
                  calculateDogAge(dog['dob']),
                  style: Theme.of(context).textTheme.bodySmall,
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

                // SPAY LABEL
                SpayDueLabel(spayDue: dog['spay_due']),

                AppSpacing.hMd,

                // STATS
                Row(
                  children: [
                    Expanded(child: _Stat("Litters", litters)),
                    Expanded(child: _Stat("Pups", pups)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(18),
        ),
        child: Image.asset(
          'assets/images/no_photo.png',
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }
}

// 🔥 STAT WIDGET
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