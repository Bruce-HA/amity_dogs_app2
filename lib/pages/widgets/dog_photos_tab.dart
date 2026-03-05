import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DogPhotosTab extends StatefulWidget {
  final String dogId;

  const DogPhotosTab({super.key, required this.dogId});

  @override
  State<DogPhotosTab> createState() => _DogPhotosTabState();
}

class _DogPhotosTabState extends State<DogPhotosTab> {

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> photos = [];

  bool loading = true;

  final String baseUrl =
      "https://phkwizyrpfzoecugpshb.supabase.co/storage/v1/object/public/dog_files";

  @override
  void initState() {
    super.initState();
    loadPhotos();
  }

  Future<void> loadPhotos() async {

    loading = true;
    setState(() {});

    final response = await supabase
        .from('dog_photos')
        .select()
        .eq('dog_id', widget.dogId)
        .order('created_at', ascending: false);

    photos = List<Map<String, dynamic>>.from(response);

    loading = false;
    setState(() {});
  }

  String getFullUrl(String fileName) {

    fileName = fileName.split("/").last;

    final url =
        "$baseUrl/${widget.dogId}/photo/$fileName";

    print("PHOTO URL: $url");

    return url;
  }

  Widget buildPhotoCard(Map<String, dynamic> photo) {

    final fileName = photo['url'] ?? "";

    final fullUrl =
        "https://phkwizyrpfzoecugpshb.supabase.co/storage/v1/object/public/dog_files/${widget.dogId}/photo/$fileName";

    print("DISPLAYING IMAGE: $fullUrl");

    final description = photo['description'] ?? "";

    return GestureDetector(
      onTap: () async {

        final result =
            await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewerPage(
              imageUrl: fullUrl,
              photo: photo,
              dogId: widget.dogId,
              dogAla: widget.dogAla,
            ),
          ),
        );

        if (result == true) {
          loadPhotos();
        }
      },
    );
  }


  void openViewer(String url, String description) {

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => Scaffold(

          appBar: AppBar(),

          backgroundColor: Colors.black,

          body: Column(

            children: [

              Expanded(

                child: Center(

                  child: Image.network(url),
                ),
              ),

              if (description.isNotEmpty)

                Padding(

                  padding: const EdgeInsets.all(16),

                  child: Text(

                    description,

                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (photos.isEmpty) {
      return const Center(child: Text("No photos"));
    }

    return GridView.builder(

      padding: const EdgeInsets.all(8),

      itemCount: photos.length,

      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 3,

        crossAxisSpacing: 8,

        mainAxisSpacing: 8,
      ),

      itemBuilder: (context, index) {

        return buildPhotoCard(photos[index]);
      },
    );
  }
}
