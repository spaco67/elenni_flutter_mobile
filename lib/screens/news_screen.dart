import 'package:flutter/material.dart';
import '../models/news_source.dart';
import '../models/news_article.dart';
import '../services/rss_service.dart';
import '../services/database_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  final RssService _rssService = RssService();
  final DatabaseService _databaseService = DatabaseService();
  final FlutterTts _flutterTts = FlutterTts();

  late TabController _tabController;
  bool _isLoading = true;
  List<NewsArticle> _articles = [];
  NewsRegion _selectedRegion = NewsRegion.nigeria;
  NewsCategory? _selectedCategory;
  String? _readingArticleId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _initTts();
    _loadArticles();

    // Start refreshing news in the background
    Future.delayed(Duration.zero, () {
      _rssService.startPeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flutterTts.stop();
    _rssService.stopPeriodicRefresh();
    super.dispose();
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
            _selectedRegion = NewsRegion.nigeria;
            break;
          case 1:
            _selectedRegion = NewsRegion.africa;
            break;
          case 2:
            _selectedRegion = NewsRegion.global;
            break;
        }
      });
      _loadArticles();
    }
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to get cached articles from the database
      List<NewsArticle> cachedArticles = [];
      try {
        cachedArticles = await _databaseService.getArticles(limit: 50);

        if (cachedArticles.isNotEmpty) {
          setState(() {
            _articles = cachedArticles.where((article) {
              final source = NewsSources.getSourceById(article.sourceId);
              return source != null &&
                  source.region == _selectedRegion &&
                  (_selectedCategory == null ||
                      source.category == _selectedCategory);
            }).toList();
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error getting cached articles: $e');
        // Continue with fetching new articles even if DB fails
      }

      // Fetch fresh articles
      try {
        final freshArticles = await _rssService.fetchArticles(
          region: _selectedRegion,
          category: _selectedCategory,
        );

        setState(() {
          _articles = freshArticles;
          _isLoading = false;
        });
      } catch (e) {
        print('Error fetching fresh articles: $e');

        // If we failed to get fresh articles but have cached ones, keep showing those
        if (_articles.isEmpty) {
          // If we have no articles to show at all, check if we need fallback mode
          if (_isLoading) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error in _loadArticles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _stopSpeaking() {
    _flutterTts.stop();
    setState(() {
      _readingArticleId = null;
    });
  }

  void _toggleReadArticle(NewsArticle article) async {
    if (_readingArticleId == article.id) {
      _stopSpeaking();
    } else {
      setState(() {
        _readingArticleId = article.id;
      });

      final textToRead = "${article.title}. ${article.content}";
      await _speak(textToRead);

      // Mark as read in the database
      try {
        await _databaseService.markArticleAsRead(article.id);

        // Update local data
        setState(() {
          int index = _articles.indexWhere((a) => a.id == article.id);
          if (index != -1) {
            _articles[index] = _articles[index].copyWith(isRead: true);
          }
        });
      } catch (e) {
        print('Error marking article as read: $e');
      }
    }
  }

  void _toggleFavorite(NewsArticle article) async {
    try {
      await _databaseService.toggleFavorite(article.id);

      // Update local data
      setState(() {
        int index = _articles.indexWhere((a) => a.id == article.id);
        if (index != -1) {
          _articles[index] =
              _articles[index].copyWith(isFavorite: !article.isFavorite);
        }
      });
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  void _openArticleUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open article link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elenni News'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Nigeria'),
            Tab(text: 'Africa'),
            Tab(text: 'Global'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArticles,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<NewsCategory?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by category',
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
              _loadArticles();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...NewsCategory.values.map((category) => PopupMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No news articles found',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArticles,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadArticles,
                  child: ListView.builder(
                    itemCount: _articles.length,
                    itemBuilder: (context, index) {
                      final article = _articles[index];
                      return _buildArticleCard(article);
                    },
                  ),
                ),
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _openArticleUrl(article.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article image if available
            if (article.imageUrl != null)
              SizedBox(
                width: double.infinity,
                height: 180,
                child: CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              ),

            // Article content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article.sourceName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        article.formattedPublishDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: article.isRead ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    article.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: article.isRead ? Colors.grey : null,
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _toggleReadArticle(article),
                          icon: Icon(_readingArticleId == article.id
                              ? Icons.stop
                              : Icons.play_arrow),
                          label: Text(_readingArticleId == article.id
                              ? 'Stop'
                              : 'Read'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _readingArticleId == article.id
                                ? Colors.red
                                : null,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            article.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: article.isFavorite ? Colors.red : null,
                          ),
                          onPressed: () => _toggleFavorite(article),
                          tooltip: 'Favorite',
                        ),
                      ],
                    ),
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
