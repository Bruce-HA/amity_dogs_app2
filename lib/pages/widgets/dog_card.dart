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
    final dogAla = dog['dog_ala'];

    // from SQL view
    final fileName =
        dog['hero_file_name'] ??
        dog['file_name'] ??
        dog['url'];

    String? imageUrl;

    if (dogAla != null && fileName != null) {
      imageUrl = Supabase.instance.client.storage
          .from('dog_files')
          .getPublicUrl(
            '$dogAla/photos/$fileName',
          );
    }

    return InkWell(
      onTap: onTap,
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: imageUrl != null
                  ? AspectRatio(
                      aspectRatio: 1.2,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) =>
                            Container(
                          height: 110,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    )
                  : Container(
                      height: 110,
                      color: Colors.grey.shade300,
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    dog['dog_name'] ?? '',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                  Text(
                    dog['dog_ala'] ?? '',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
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