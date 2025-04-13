import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../services/audio_player_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({Key? key}) : super(key: key);

  @override
  _RadioScreenState createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen>
    with SingleTickerProviderStateMixin {
  final RadioService _radioService = RadioService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final FlutterTts _flutterTts = FlutterTts();

  late TabController _tabController;
  bool _isLoading = true;
  List<RadioStation> _stations = [];
  RadioRegion _selectedRegion = RadioRegion.nigeria;
  RadioGenre? _selectedGenre;
  bool _showingFavorites = false;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _initAudioPlayer();
    _initTts();
    _loadStations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initAudioPlayer() async {
    await _audioPlayerService.init();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedRegion = RadioRegion.nigeria;
            break;
          case 1:
            _selectedRegion = RadioRegion.africa;
            break;
          case 2:
            _selectedRegion = RadioRegion.global;
            break;
        }
        _showingFavorites = false;
      });
      _loadStations();
    }
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<RadioStation> stations;

      if (_showingFavorites) {
        stations = await _radioService.getFavoriteStations();
      } else if (_selectedGenre != null) {
        stations = await _radioService.getStationsByGenre(_selectedGenre!);
        // Filter by region
        stations = stations
            .where((station) => station.region == _selectedRegion)
            .toList();
      } else {
        stations = await _radioService.getStationsByRegion(_selectedRegion);
      }

      // Apply search filter if needed
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        stations = stations
            .where((station) =>
                station.name.toLowerCase().contains(query) ||
                (station.description?.toLowerCase().contains(query) ?? false))
            .toList();
      }

      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    await _radioService.toggleFavorite(station.id);

    setState(() {
      station.isFavorite = !station.isFavorite;
    });

    // If showing favorites, reload the list
    if (_showingFavorites) {
      _loadStations();
    }
  }

  Future<void> _playStation(RadioStation station) async {
    try {
      // Announce station name
      await _flutterTts.speak('Playing ${station.name}');

      // Slight delay to allow announcement to be heard
      await Future.delayed(const Duration(milliseconds: 1500));

      // Play the station
      await _audioPlayerService.playStation(station);

      // Force UI update
      setState(() {});
    } catch (e) {
      print('Error playing station: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing station: ${e.toString()}')),
      );
    }
  }

  void _showGenreFilter() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          children: [
            ListTile(
              title: const Text('All Genres',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() {
                  _selectedGenre = null;
                });
                Navigator.pop(context);
                _loadStations();
              },
            ),
            const Divider(),
            ...RadioGenre.values
                .map((genre) => ListTile(
                      leading: Icon(genre.icon),
                      title: Text(genre.displayName),
                      onTap: () {
                        setState(() {
                          _selectedGenre = genre;
                        });
                        Navigator.pop(context);
                        _loadStations();
                      },
                    ))
                .toList(),
          ],
        );
      },
    );
  }

  void _toggleShowFavorites() {
    setState(() {
      _showingFavorites = !_showingFavorites;
    });
    _loadStations();
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.isEmpty ? null : query;
    });
    _loadStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elenni Radio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Nigeria'),
            Tab(text: 'Africa'),
            Tab(text: 'Global'),
          ],
        ),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: StationSearchDelegate(
                  onSearch: _performSearch,
                  onClear: () {
                    setState(() {
                      _searchQuery = null;
                    });
                    _loadStations();
                  },
                ),
              );
            },
            tooltip: 'Search',
          ),
          // Genre filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showGenreFilter,
            tooltip: 'Filter by genre',
          ),
          // Favorites button
          IconButton(
            icon: Icon(
                _showingFavorites ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleShowFavorites,
            tooltip: _showingFavorites ? 'Show all' : 'Show favorites',
          ),
        ],
      ),
      body: Column(
        children: [
          // Attribution text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text(
              _radioService.getAttributionText(),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),

          // Mini player when a station is playing
          if (_audioPlayerService.currentStation != null) _buildMiniPlayer(),

          // Stations list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stations.isEmpty
                    ? _buildEmptyState()
                    : _buildStationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.radio, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _showingFavorites
                ? 'No favorite stations yet'
                : _searchQuery != null
                    ? 'No stations matching "$_searchQuery"'
                    : 'No stations available',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showingFavorites = false;
                _searchQuery = null;
                _selectedGenre = null;
              });
              _loadStations();
            },
            child: const Text('Show all stations'),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsList() {
    return RefreshIndicator(
      onRefresh: _loadStations,
      child: ListView.builder(
        itemCount: _stations.length,
        itemBuilder: (context, index) {
          final station = _stations[index];
          final isPlaying =
              _audioPlayerService.currentStation?.id == station.id &&
                  _audioPlayerService.playing;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: isPlaying ? 4 : 1,
            color: isPlaying ? Colors.purple.shade50 : null,
            child: InkWell(
              onTap: () => _playStation(station),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Station logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: station.logoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: station.logoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.radio,
                                  size: 30,
                                ),
                              )
                            : const Icon(
                                Icons.radio,
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Station info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPlaying)
                                const Icon(Icons.graphic_eq,
                                    size: 16, color: Colors.purple),
                              if (isPlaying) const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  station.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isPlaying ? Colors.purple : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            station.description ?? station.genre.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(station.genre.icon,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                station.genre.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Play/favorite button
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.stop : Icons.play_arrow,
                            color: isPlaying ? Colors.purple : null,
                          ),
                          onPressed: () => isPlaying
                              ? _audioPlayerService
                                  .stop()
                                  .then((_) => setState(() {}))
                              : _playStation(station),
                          tooltip: isPlaying ? 'Stop' : 'Play',
                        ),
                        IconButton(
                          icon: Icon(
                            station.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: station.isFavorite ? Colors.red : null,
                          ),
                          onPressed: () => _toggleFavorite(station),
                          tooltip: station.isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final station = _audioPlayerService.currentStation!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Station logo
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 40,
              height: 40,
              color: Colors.grey[300],
              child: station.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: station.logoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.radio,
                        size: 20,
                      ),
                    )
                  : const Icon(
                      Icons.radio,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Station info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Now Playing',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  station.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Controls
          StreamBuilder<bool>(
            stream: _audioPlayerService.playingStream,
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;

              return Row(
                children: [
                  IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: _audioPlayerService.togglePlayPause,
                    color: Colors.purple,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () {
                      _audioPlayerService.stop().then((_) => setState(() {}));
                    },
                    color: Colors.purple,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Search delegate for station search
class StationSearchDelegate extends SearchDelegate<String> {
  final Function(String) onSearch;
  final VoidCallback onClear;

  StationSearchDelegate({required this.onSearch, required this.onClear});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onClear();
          close(context, '');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        onClear();
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    return Container(); // The main screen will show the results
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.radio),
          title: const Text('Search stations'),
          subtitle: Text('Type to search for "$query"'),
          onTap: () {
            onSearch(query);
            close(context, query);
          },
        ),
      ],
    );
  }
}
