import 'package:BeatNow/Models/SavedPost.dart';
import 'package:flutter/material.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  _SavedScreen createState() => _SavedScreen();
}

class _SavedScreen extends State<SavedScreen> {
  late Future<List<SavedPost>> _savedPosts;

  @override
  void initState() {
    super.initState();
    _savedPosts = getSavedPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Beats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121212), // sombra más oscura
              Color(0xFF0D0D0D), // incluso más oscura
            ],
            stops: [0.5, 1.0], // dónde comenzar y terminar cada color
          ),
        ),
        child: FutureBuilder<List<SavedPost>>(
          future: _savedPosts,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GridView.builder(
                padding: const EdgeInsets.all(10.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                  childAspectRatio: 0.5, // Proporción 2:1 (alto:ancho)
                ),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          snapshot.data![index].coverImageUrl ??
                              'https://res.beatnow.app/beatnow/'
                                  '${snapshot.data![index].creatorId ?? snapshot.data![index].userId}'
                                  '/posts/${snapshot.data![index].postId}/caratula.'
                                  '${snapshot.data![index].coverFormat ?? 'jpg'}',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            // Por defecto, muestra un loading spinner.
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Future<List<SavedPost>> getSavedPosts() async {
    const apiUrl = 'https://api.beatnow.app/v1/api/users/saved-posts';
    final token = UserSingleton().token;
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = convert.jsonDecode(response.body);
      if (jsonResponse['saved_posts'] is List) {
        return jsonResponse['saved_posts']
            .map<SavedPost>((item) => SavedPost.fromJson(item))
            .toList();
      } else {
        throw Exception('Saved posts is not a list');
      }
    } else {
      throw Exception('Failed to fetch post information');
    }
  }
}
