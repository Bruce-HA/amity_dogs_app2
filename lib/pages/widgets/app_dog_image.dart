import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppDogImage extends StatelessWidget {
  final String? dogId;
  final String? dogAla;
  final double size;
  final double radius;

  const AppDogImage({
    super.key,
    required this.dogId,
    required this.dogAla,
    this.size = 56,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final id = dogId;
    final ala = dogAla;
    if (id == null || ala == null) {
      return _fallback();
    }

    return FutureBuilder(
      future: Supabase.instance.client
          .from('dog_photos')
          .select('url, is_hero')
          .eq('dog_id', id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _shimmer();
        }

        final photos =
            (snapshot.data as List?)?.cast<Map<String, dynamic>>();

        if (photos == null || photos.isEmpty) {
          return _fallback();
        }

        final hero = photos.firstWhere(
          (p) => p['is_hero'] == true,
          orElse: () => photos.first,
        );

        final rawUrl = hero['url'];

        if (rawUrl == null || rawUrl.isEmpty) {
          return _fallback();
        }

        final path = '$dogAla/photos/$rawUrl';

        final publicUrl = Supabase.instance.client.storage
            .from('dog_files')
            .getPublicUrl(path);

        return _image(publicUrl);
      },
    );
  }

  Widget _image(String url) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }

  // 🧊 SHIMMER LOADING
  Widget _shimmer() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.grey.shade200,
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // 🖼 FALLBACK IMAGE
  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/no_photo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}