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
    final heroList = dog['hero'] as List?;

    String? imageUrl;

    if (heroList != null && heroList.isNotEmpty) {
      final hero = heroList.first;

      final fileName = hero['url'];
      final dogAla = dog['dog_ala'];

      if (fileName != null && dogAla != null) {
        imageUrl = Supabase.instance.client.storage
            .from('dog_files')
            .getPublicUrl('$dogAla/photos/$fileName');
      }
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
        height: 180,
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
            // IMAGE
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
             child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 110,
                    color: Colors.grey.shade300,
                  )
                 ),
  

            // CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dog['dog_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      dog['dog_ala'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (age.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isUnderFive
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          age,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}