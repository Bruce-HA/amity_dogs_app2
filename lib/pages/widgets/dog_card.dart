import 'package:flutter/material.dart';
import '../../utils/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DogCard extends StatelessWidget {
  final Map<String, dynamic> dog;
  final VoidCallback? onTap;

  const DogCard({
    super.key,
    required this.dog,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 GET HERO IMAGE FROM dog_photos
    final fileName = dog['hero'];
      final dogAla = dog['dog_ala'];

      String? imageUrl;

      if (fileName != null && dogAla != null) {
        imageUrl = Supabase.instance.client.storage
            .from('dog_files')
            .getPublicUrl('$dogAla/photos/$fileName');
      }

    String age = '';
    final dobRaw = dog['dob'];
    if (dobRaw != null) {
      age = calculateDogAge(dobRaw.toString());
    }

    final isUnderFive = age.contains('y')
        ? int.tryParse(age.split('y').first.trim()) != null &&
            int.parse(age.split('y').first.trim()) < 5
        : false;

    return InkWell(
      onTap: onTap, // 👈 THIS FIXES NAVIGATION
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ IMAGE (ONLY ONE)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: imageUrl != null
                ? AspectRatio(
                    aspectRatio: 1.2,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  )
                : Container(
                    height: 110,
                    color: Colors.grey.shade300,
                  ),
          ),

          // ✅ TEXT
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dog['dog_name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dog['dog_ala'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
 
  }
}