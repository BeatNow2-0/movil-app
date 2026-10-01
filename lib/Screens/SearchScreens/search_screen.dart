import 'dart:async';

import 'package:BeatNow/Models/Posts.dart';
import 'package:BeatNow/Models/UserSingleton.dart';
import 'package:BeatNow/Models/media_defaults.dart';
import 'package:BeatNow/Screens/ProfileScreen/profileother_screen.dart';
import 'package:BeatNow/Controllers/auth_controller.dart';
import 'package:BeatNow/services/api_client.dart';
import 'package:BeatNow/services/beatnow_service.dart';
import 'package:BeatNow/theme/beatnow_theme.dart';
import 'package:BeatNow/widgets/cached_media_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<String> _searchHistory = [];
  final AuthController _authController = Get.find<AuthController>();
  final BeatNowService _beatNowService = BeatNowService();
  final TextEditingController _searchController = TextEditingController();
  bool _searchingUsers = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _userSearchResults = [];
  List<Posts> _beatSearchResults = [];
  Map<String, String> _activeFilters = {};
  final ScrollController _beatResultsController = ScrollController();
  Timer? _beatSearchDebounce;
  Timer? _userSearchDebounce;
  int _beatRequestId = 0;
  int _userRequestId = 0;
  int _beatSkip = 0;
  static const int _beatPageSize = 20;
  bool _isLoadingMoreBeats = false;
  bool _hasMoreBeats = true;
  String _beatQuery = '';
  String? _beatSearchError;
  String? _userSearchError;
  Future<List<Posts>>? _ownPostsFuture;
  String _ownPostsUsername = '';

  @override
  void dispose() {
    _beatSearchDebounce?.cancel();
    _userSearchDebounce?.cancel();
    _beatResultsController
      ..removeListener(_onBeatResultsScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _beatResultsController.addListener(_onBeatResultsScroll);
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
        title: const Text('Explore'),
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
              controller: _searchController,
              onChanged: (value) {
                if (_searchingUsers) {
                  _scheduleUserSearch(value);
                } else {
                  _scheduleBeatSearch(value);
                }
              },
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: _searchingUsers
                    ? 'Search producers by username...'
                    : 'Search beats...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16.0),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.music_note_rounded),
                  label: Text('Beats'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.person_search_rounded),
                  label: Text('Producers'),
                ),
              ],
              selected: {_searchingUsers},
              onSelectionChanged: (selection) =>
                  _switchSearchMode(selection.first),
            ),
            const SizedBox(height: BeatNowTokens.space3),
            if (!_searchingUsers && _activeFilters.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activeFilters.entries
                    .where((entry) => entry.value.isNotEmpty)
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        onDeleted: () {
                          setState(() {
                            _activeFilters.remove(entry.key);
                          });
                          _startBeatSearch(_searchController.text.trim());
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8.0),
            Expanded(child: _buildSearchContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_searchingUsers) {
      return _buildUserSearchReadults();
    }

    return _hasBeatCriteria ? _buildBeatSearchResults() : _buildExploreStart();
  }

  Widget _buildExploreStart({bool producers = false}) {
    return ListView(
      children: [
        const SizedBox(height: BeatNowTokens.space4),
        Text(
          producers ? 'Find producers' : 'Explore beats',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: BeatNowTokens.space2),
        Text(
          producers
              ? 'Search producers by username or name.'
              : 'Search by title, genre, mood or instruments.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!producers)
          Padding(
            padding: const EdgeInsets.only(top: BeatNowTokens.space3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showFilterPopup(context),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Browse with filters'),
              ),
            ),
          ),
        if (_searchHistory.isNotEmpty) ...[
          const SizedBox(height: BeatNowTokens.space6),
          Row(
            children: [
              Expanded(
                child: Text('Recent searches',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _searchHistory.clear());
                  _saveSearchHistory();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: BeatNowTokens.space2,
            runSpacing: BeatNowTokens.space2,
            children: _searchHistory.take(8).map((term) {
              return InputChip(
                label: Text(term),
                onPressed: () {
                  _searchController.text = term;
                  _runSearch(term);
                },
                onDeleted: () => _removeFromSearchHistory(term),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _removeFromSearchHistory(String term) {
    setState(() {
      _searchHistory.remove(term);
      _saveSearchHistory();
    });
  }

  void _switchSearchMode(bool searchingUsers) {
    if (_searchingUsers == searchingUsers) return;
    _beatSearchDebounce?.cancel();
    _userSearchDebounce?.cancel();
    _beatRequestId++;
    _userRequestId++;
    setState(() {
      _searchingUsers = searchingUsers;
      _isLoading = false;
      _isLoadingMoreBeats = false;
    });
    if (searchingUsers) {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) _runSearch(query);
    } else {
      _scheduleBeatSearch(_searchController.text);
    }
  }

  bool get _hasBeatCriteria =>
      _beatQuery.isNotEmpty ||
      _activeFilters.values.any((value) => value.isNotEmpty);

  void _scheduleUserSearch(String rawTerm) {
    _userSearchDebounce?.cancel();
    final term = rawTerm.trim();
    final requestId = ++_userRequestId;
    setState(() {
      _userSearchResults = [];
      _userSearchError = null;
      _isLoading = term.isNotEmpty;
    });
    if (term.isEmpty) return;
    _userSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || requestId != _userRequestId || !_searchingUsers) return;
      _runSearch(term, recordHistory: false);
    });
  }

  void _scheduleBeatSearch(String rawTerm) {
    _beatSearchDebounce?.cancel();
    final query = rawTerm.trim();
    final requestId = ++_beatRequestId;
    _beatQuery = query;
    _beatSkip = 0;
    _hasMoreBeats = true;
    _beatSearchError = null;
    final hasCriteria = query.isNotEmpty ||
        _activeFilters.values.any((value) => value.isNotEmpty);
    setState(() {
      _beatSearchResults = [];
      _isLoading = hasCriteria;
      _isLoadingMoreBeats = false;
    });
    if (!hasCriteria) return;
    _beatSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchBeatPage(query: query, requestId: requestId, reset: true);
    });
  }

  Future<void> _startBeatSearch(String rawTerm,
      {bool recordHistory = false}) async {
    _beatSearchDebounce?.cancel();
    final query = rawTerm.trim();
    _beatQuery = query;
    final requestId = ++_beatRequestId;
    _beatSkip = 0;
    _hasMoreBeats = true;
    _beatSearchError = null;
    final hasCriteria = query.isNotEmpty ||
        _activeFilters.values.any((value) => value.isNotEmpty);
    setState(() {
      _beatSearchResults = [];
      _isLoading = hasCriteria;
      _isLoadingMoreBeats = false;
    });
    if (recordHistory && query.isNotEmpty) {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      await _saveSearchHistory();
      if (!mounted || requestId != _beatRequestId) return;
    }
    if (hasCriteria) {
      await _fetchBeatPage(query: query, requestId: requestId, reset: true);
    }
  }

  void _onBeatResultsScroll() {
    if (_searchingUsers ||
        _isLoading ||
        _isLoadingMoreBeats ||
        !_hasMoreBeats ||
        !_beatResultsController.hasClients ||
        _beatResultsController.position.extentAfter > 360) {
      return;
    }
    _fetchBeatPage(query: _beatQuery, requestId: _beatRequestId, reset: false);
  }

  Future<void> _fetchBeatPage({
    required String query,
    required int requestId,
    required bool reset,
  }) async {
    if (requestId != _beatRequestId || _searchingUsers || !_hasBeatCriteria)
      return;
    if (!reset && (_isLoadingMoreBeats || !_hasMoreBeats)) return;

    final skip = reset ? 0 : _beatSkip;
    setState(() {
      if (reset) {
        _isLoading = true;
      } else {
        _isLoadingMoreBeats = true;
      }
      _beatSearchError = null;
    });

    try {
      final results = await _searchFilter(query, skip: skip);
      if (!mounted || requestId != _beatRequestId || _searchingUsers) return;
      final parsed = results.map(Posts.fromApi).toList();
      if (reset && query.isNotEmpty && _activeFilters.isEmpty) {
        try {
          final ownPosts = await _loadOwnPostsForSearch();
          final normalizedQuery = query.toLowerCase();
          parsed.addAll(ownPosts.where((post) {
            final searchable = <String>[
              post.title,
              post.description,
              post.genre,
              ...post.tags,
              ...post.moods,
              ...post.instruments,
            ].join(' ').toLowerCase();
            return searchable.contains(normalizedQuery);
          }));
        } catch (_) {
          // Keep general search results when the personal-post request fails.
        }
      }
      if (!mounted || requestId != _beatRequestId || _searchingUsers) return;
      final knownIds = reset
          ? <String>{}
          : _beatSearchResults.map((post) => post.id).toSet();
      final uniquePosts = parsed
          .where((post) => post.id.isEmpty || knownIds.add(post.id))
          .toList();
      setState(() {
        if (reset) {
          _beatSearchResults = uniquePosts;
        } else {
          _beatSearchResults.addAll(uniquePosts);
        }
        _beatSkip = skip + results.length;
        _hasMoreBeats = results.length == _beatPageSize;
      });
    } catch (error) {
      if (!mounted || requestId != _beatRequestId || _searchingUsers) return;
      setState(() => _beatSearchError = error is ApiException
          ? error.userMessage
          : 'Could not search beats. Try again.');
    } finally {
      if (mounted && requestId == _beatRequestId) {
        setState(() {
          _isLoading = false;
          _isLoadingMoreBeats = false;
        });
      }
    }
  }

  Future<void> _runSearch(String rawTerm, {bool recordHistory = true}) async {
    final term = rawTerm.trim();
    if (_searchingUsers) {
      if (term.isEmpty) return;
      final requestId = ++_userRequestId;
      setState(() {
        _isLoading = true;
        _userSearchError = null;
        if (recordHistory) {
          _searchHistory.remove(term);
          _searchHistory.insert(0, term);
        }
      });
      if (recordHistory) await _saveSearchHistory();
      try {
        final results = _includeCurrentUser(
          await _searchUsers(term),
          term,
        );
        if (!mounted || requestId != _userRequestId || !_searchingUsers) return;
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
      } catch (error) {
        if (!mounted || requestId != _userRequestId || !_searchingUsers) return;
        setState(() {
          final currentUser = _matchingCurrentUser(term);
          _userSearchResults = currentUser == null ? [] : [currentUser];
          _userSearchError = currentUser != null
              ? null
              : error is ApiException
                  ? error.userMessage
                  : 'Could not search producers. Try again.';
        });
      } finally {
        if (mounted && requestId == _userRequestId) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    await _startBeatSearch(term, recordHistory: true);
  }

  Widget _buildUserSearchReadults() {
    if (_userSearchResults.isEmpty) {
      if (_userSearchError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_userSearchError!),
              TextButton.icon(
                onPressed: () => _runSearch(_searchController.text),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (_searchController.text.trim().isEmpty) {
        return _buildExploreStart(producers: true);
      }
      return Text(
        _searchController.text.trim().isEmpty
            ? 'Search producers by username.'
            : 'No producers found.',
      );
    }
    return ListView.builder(
      itemCount: _userSearchResults.length,
      itemBuilder: (context, index) {
        final user = _userSearchResults[index];
        final username = user['username']?.toString() ?? '';
        final fullName = user['full_name']?.toString().trim() ?? '';
        return ListTile(
          leading: ClipOval(
            child: _producerAvatar(user['profile_image_url']?.toString()),
          ),
          title: Text(fullName.isNotEmpty ? fullName : '@$username'),
          subtitle: fullName.isNotEmpty ? Text('@$username') : null,
          onTap: () {
            if (user['_id'] != null && user['username'] != null) {
              _beatNowService.setOtherUserFromSearchResult(user);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileOtherScreen()),
              );
            } else {
              // Manejar caso donde user['_id'] o user['username'] es nulo
              debugPrint('Usuario no válido: $_userSearchResults');
            }
          },
        );
      },
    );
  }

  Widget _producerAvatar(String? imageUrl) {
    final source = imageUrl?.trim() ?? '';
    final uri = Uri.tryParse(source);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return _producerAvatarFallback();
    }
    return CachedNetworkImage(
      imageUrl: source,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => _producerAvatarFallback(),
      errorWidget: (_, __, ___) => _producerAvatarFallback(),
    );
  }

  Widget _producerAvatarFallback() => Container(
        width: 40,
        height: 40,
        color: BeatNowTokens.surface2,
        alignment: Alignment.center,
        child: const Icon(Icons.person_rounded, color: Colors.white54),
      );

  Map<String, dynamic>? _matchingCurrentUser(String term) {
    final user = UserSingleton();
    final username = user.username.trim();
    if (username.isEmpty ||
        !username.toLowerCase().contains(term.toLowerCase())) {
      return null;
    }
    return {
      '_id': user.id,
      'username': username,
      'full_name': user.name,
      'profile_image_url': user.profileImageUrl,
    };
  }

  List<Map<String, dynamic>> _includeCurrentUser(
    List<Map<String, dynamic>> results,
    String term,
  ) {
    final currentUser = _matchingCurrentUser(term);
    if (currentUser == null) return results;
    final currentId = currentUser['_id'];
    final currentUsername = currentUser['username'].toString().toLowerCase();
    final alreadyIncluded = results.any((user) =>
        (user['_id'] ?? user['id'])?.toString() == currentId ||
        user['username']?.toString().toLowerCase() == currentUsername);
    return alreadyIncluded ? results : [...results, currentUser];
  }

  Future<List<Posts>> _loadOwnPostsForSearch() async {
    final username = UserSingleton().username.trim();
    if (username.isEmpty) return const <Posts>[];
    if (_ownPostsFuture == null || username != _ownPostsUsername) {
      _ownPostsUsername = username;
      _ownPostsFuture = _beatNowService.getUserPosts(username);
    }
    try {
      return await _ownPostsFuture!;
    } catch (_) {
      _ownPostsFuture = null;
      rethrow;
    }
  }

  Widget _buildBeatSearchResults() {
    if (_beatSearchResults.isEmpty) {
      if (_beatSearchError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Beat search failed. Try again.'),
              TextButton.icon(
                onPressed: () => _fetchBeatPage(
                  query: _beatQuery,
                  requestId: _beatRequestId,
                  reset: true,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return Text(
        _hasBeatCriteria
            ? 'No beats found. Try another search or adjust the filters.'
            : 'Search beats by title or choose filters.',
      );
    }

    return ListView.separated(
      controller: _beatResultsController,
      itemCount: _beatSearchResults.length +
          (_isLoadingMoreBeats || _beatSearchError != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _beatSearchResults.length) {
          if (_isLoadingMoreBeats) {
            return const Padding(
              padding: EdgeInsets.all(BeatNowTokens.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Center(
            child: TextButton.icon(
              onPressed: () => _fetchBeatPage(
                query: _beatQuery,
                requestId: _beatRequestId,
                reset: false,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry loading more'),
            ),
          );
        }
        final post = _beatSearchResults[index];
        final producerName = post.username.isNotEmpty
            ? post.username
            : post.userId == UserSingleton().id
                ? UserSingleton().username
                : 'Producer';
        return Container(
          decoration: BoxDecoration(
            color: BeatNowTokens.surface1,
            borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
              child: CachedMediaImage(
                url: post.coverImageUrl,
                fallbackAsset: MediaDefaults.coverImage,
                width: 56,
                height: 56,
              ),
            ),
            title:
                Text(post.title, style: const TextStyle(color: Colors.white)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '@$producerName',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (post.genre.isNotEmpty) post.genre,
                    if (post.bpm != null) '${post.bpm} BPM',
                    if (post.tags.isNotEmpty)
                      '#${post.tags.take(2).join(' #')}',
                  ].join('  •  '),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${post.likes}',
                    style: const TextStyle(color: Colors.white)),
                const Text('likes',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFilterPopup(BuildContext context) async {
    final genreController =
        TextEditingController(text: _activeFilters['genre'] ?? '');
    final bpmController =
        TextEditingController(text: _activeFilters['bpm'] ?? '');
    final moodController =
        TextEditingController(text: _activeFilters['moods'] ?? '');
    final instrumentsController =
        TextEditingController(text: _activeFilters['instruments'] ?? '');
    final filters = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            BeatNowTokens.space4,
            BeatNowTokens.space3,
            BeatNowTokens.space4,
            MediaQuery.viewInsetsOf(sheetContext).bottom + BeatNowTokens.space4,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filter beats',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: BeatNowTokens.space2),
                Text('Use the filters supported by beat search.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: BeatNowTokens.space4),
                TextFormField(
                  controller: genreController,
                  decoration: const InputDecoration(
                    labelText: 'Genre',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: BeatNowTokens.space3),
                TextFormField(
                  controller: moodController,
                  decoration: const InputDecoration(
                    labelText: 'Mood',
                    prefixIcon: Icon(Icons.mood_outlined),
                  ),
                ),
                const SizedBox(height: BeatNowTokens.space3),
                TextFormField(
                  controller: bpmController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'BPM',
                    prefixIcon: Icon(Icons.speed_rounded),
                  ),
                ),
                const SizedBox(height: BeatNowTokens.space3),
                TextFormField(
                  controller: instrumentsController,
                  decoration: const InputDecoration(
                    labelText: 'Instruments',
                    prefixIcon: Icon(Icons.piano_rounded),
                  ),
                ),
                const SizedBox(height: BeatNowTokens.space4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: BeatNowTokens.space2),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, <String, String>{
                            if (genreController.text.trim().isNotEmpty)
                              'genre': genreController.text.trim(),
                            if (int.tryParse(bpmController.text) != null)
                              'bpm': bpmController.text,
                            if (moodController.text.trim().isNotEmpty)
                              'moods': moodController.text.trim(),
                            if (instrumentsController.text.trim().isNotEmpty)
                              'instruments': instrumentsController.text.trim(),
                          });
                        },
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    genreController.dispose();
    bpmController.dispose();
    moodController.dispose();
    instrumentsController.dispose();
    if (!mounted || filters == null) return;
    setState(() => _activeFilters = filters);
    await _startBeatSearch(_searchController.text.trim());
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    final results = await _beatNowService.searchUsers(query);
    return results
        .where((user) =>
            (user['_id'] ?? user['id']) != null && user['username'] != null)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _searchFilter(String query,
      {required int skip}) {
    return _beatNowService.searchPosts(
      query,
      filters: _activeFilters,
      limit: _beatPageSize,
      skip: skip,
    );
  }
}
