import 'package:BeatNow/Screens/ProfileScreen/profileother_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<String> _searchHistory = [];
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  bool _searchingUsers = false;
  List<Map<String, dynamic>> _userSearchResults = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('searchHistory') ?? [];
    });
  }

  Future<void> _saveSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('searchHistory', _searchHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _authController.changeTab(AuthTabs.home);
          },
        ),
        actions: _searchingUsers
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.filter_alt),
                  onPressed: () {
                    _showFilterPopup(context);
                  },
                ),
              ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onSubmitted: (value) {
                _addToSearchHistory(value);
              },
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text('Searching in: '),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchingUsers = false;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Beats',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: _searchingUsers
                            ? Colors.grey
                            : const Color(0xFF4E0566),
                        fontWeight: _searchingUsers
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchingUsers = true;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Users',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: _searchingUsers
                            ? const Color(0xFF4E0566)
                            : Colors.grey,
                        fontWeight: _searchingUsers
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            if (_searchingUsers) ...[
              const Text(
                'User Search Results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: _buildUserSearchReadults(),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Search History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: _buildSearchHistory(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistory() {
    return ListView.builder(
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        return _buildHistoryItem(_searchHistory[index]);
      },
    );
  }

  Widget _buildHistoryItem(String term) {
    return ListTile(
      title: Text(term),
      trailing: IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          _removeFromSearchHistory(term);
        },
      ),
    );
  }

  void _removeFromSearchHistory(String term) {
    setState(() {
      _searchHistory.remove(term);
      _saveSearchHistory();
    });
  }

  void _addToSearchHistory(String term) {
    setState(() {
      if (!_searchHistory.contains(term)) {
        _searchHistory.insert(0, term);
        _saveSearchHistory();
      }
    });

    if (_searchingUsers) {
      _searchUsers(term).then((results) {
        setState(() {
          _userSearchResults = results
              .map((user) => {
                    '_id': (user['_id'] ?? user['id']).toString(),
                    'username': user['username'].toString(),
                    'full_name': user['full_name']?.toString(),
                    'profile_image_url': user['profile_image_url']?.toString(),
                  })
              .toList();
        });
      }).catchError((error) {
        setState(() {
          _userSearchResults = [];
        });
      });
    }
  }

  Widget _buildUserSearchReadults() {
    if (_userSearchResults.isEmpty) {
      return const Text('No se han encontrado resultados.');
    }
    return ListView.builder(
      itemCount: _userSearchResults.length,
      itemBuilder: (context, index) {
        final user = _userSearchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              user['profile_image_url']?.toString() ??
                  "https://res.beatnow.app/beatnow/${user['_id']}/photo_profile/photo_profile.png",
            ),
            radius: 20,
          ),
          title: Text('@' + user['username']!),
          onTap: () {
            if (user['_id'] != null && user['username'] != null) {
              _beatNowService.setOtherUserFromSearchResult(user);
              Get.to(() => ProfileOtherScreen());
            } else {
              // Manejar caso donde user['_id'] o user['username'] es nulo
              debugPrint('Usuario no válido: $_userSearchResults');
            }
          },
        );
      },
    );
  }

  void _showFilterPopup(BuildContext context) {
    String selectedGenre = 'Rock';
    double selectedPrice = 0.00;
    int selectedBpm = 120;
    String selectedInstrument = 'Guitar';

    List<String> instruments = [
      'Guitar',
      'Bass',
      'Flute',
      'Drums',
      'Piano',
      'Synth',
      'Vocals',
      'Strings',
      'Brass',
      'Harp'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Advanced Beat Filters'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Genre:'),
                    DropdownButton<String>(
                      value: selectedGenre,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedGenre = newValue;
                          });
                        }
                      },
                      items: <String>[
                        'Trap',
                        'Hip-Hop',
                        'Pop',
                        'Rock',
                        'Jazz',
                        'Reggae',
                        'R&B',
                        'Country',
                        'Blues',
                        'Metal'
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),
                    Text('Price: \$${selectedPrice.toStringAsFixed(2)}'),
                    Slider(
                      value: selectedPrice,
                      min: 0,
                      max: 150,
                      divisions: 30,
                      onChanged: (double value) {
                        setState(() {
                          selectedPrice = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        const Text('BPM: '),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (selectedBpm > 0) {
                                selectedBpm--;
                              }
                            });
                          },
                        ),
                        Text('$selectedBpm'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              if (selectedBpm < 300) {
                                selectedBpm++;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    const Text('Instruments:'),
                    DropdownButton<String>(
                      value: selectedInstrument,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedInstrument = newValue;
                          });
                        }
                      },
                      items: instruments
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all<Color>(Colors.red),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                          const Color(0xFF4E0566))),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _searchUsers(String query) async {
    final results = await _beatNowService.searchUsers(query);
    return results
        .where((user) =>
            (user['_id'] ?? user['id']) != null && user['username'] != null)
        .toList();
  }

  Future<List<dynamic>> _searchFilter(String query) {
    return _beatNowService.searchPosts(query);
  }
}
