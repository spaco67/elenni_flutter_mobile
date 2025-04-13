import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/news_article.dart';
import '../models/news_source.dart';
import 'database_service.dart';

class RssService {
  final DatabaseService _databaseService = DatabaseService();

  // Generate a unique ID for an article based on its URL and title
  String _generateArticleId(String url, String title) {
    final content = '$url-$title';
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Parse an RSS item into a NewsArticle
  NewsArticle _parseRssItem(RssItem item, NewsSource source) {
    // Clean up the content (remove HTML tags and extra whitespace)
    String description = item.description ?? '';
    description = description.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    String content = item.content?.value ?? description;
    content = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    // Find the first image in the content if available
    String? imageUrl;
    final RegExp imgRegex = RegExp(r'<img[^>]+src="([^">]+)"');
    final match = imgRegex.firstMatch(item.description ?? '');
    if (match != null) {
      imageUrl = match.group(1);
    }

    // Parse the publish date
    DateTime publishDate;
    try {
      publishDate =
          item.pubDate != null ? DateTime.parse(item.pubDate!) : DateTime.now();
    } catch (e) {
      publishDate = DateTime.now();
    }

    return NewsArticle(
      id: _generateArticleId(item.link ?? '', item.title ?? ''),
      title: item.title ?? 'No Title',
      description: description,
      content: content,
      url: item.link ?? '',
      imageUrl: imageUrl,
      publishDate: publishDate,
      sourceId: source.id,
      sourceName: source.name,
    );
  }

  // Fetch articles from a single source
  Future<List<NewsArticle>> fetchArticlesFromSource(NewsSource source) async {
    try {
      final response = await http
          .get(Uri.parse(source.url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return [];
      }

      // Try to parse as RSS
      try {
        final channel = RssFeed.parse(response.body);
        return channel.items
            .map((item) => _parseRssItem(item, source))
            .toList();
      } catch (e) {
        // If RSS parsing fails, try to parse as Atom
        try {
          final feed = AtomFeed.parse(response.body);
          return feed.items.map((item) {
            // Make sure we have valid links before accessing them
            if (item.links.isEmpty) {
              return NewsArticle(
                id: _generateArticleId('no-link', item.title ?? ''),
                title: item.title ?? 'No Title',
                description: item.summary ?? '',
                content: item.content ?? item.summary ?? '',
                url: '',
                imageUrl: null,
                publishDate: DateTime.now(),
                sourceId: source.id,
                sourceName: source.name,
              );
            }

            // Get the first link if available
            final href = item.links.first.href ?? '';

            // Handle the DateTime object correctly
            DateTime publishDate;
            try {
              publishDate = item.updated is DateTime
                  ? (item.updated as DateTime)
                  : DateTime.now();
            } catch (e) {
              publishDate = DateTime.now();
            }

            return NewsArticle(
              id: _generateArticleId(href, item.title ?? ''),
              title: item.title ?? 'No Title',
              description: item.summary ?? '',
              content: item.content ?? item.summary ?? '',
              url: href,
              imageUrl:
                  null, // Atom feeds typically don't include images directly
              publishDate: publishDate,
              sourceId: source.id,
              sourceName: source.name,
            );
          }).toList();
        } catch (e) {
          // Both parsing attempts failed
          print('Failed to parse feed from ${source.name}: $e');
          return [];
        }
      }
    } catch (e) {
      // Network error or timeout
      print('Error fetching from ${source.name}: $e');
      return [];
    }
  }

  // Fetch articles from all sources or a specific region
  Future<List<NewsArticle>> fetchArticles({
    NewsRegion? region,
    NewsCategory? category,
    bool storeInDb = true,
  }) async {
    List<NewsSource> sources = [];

    if (region != null && category != null) {
      sources = NewsSources.getSourcesByRegionAndCategory(region, category);
    } else if (region != null) {
      sources = NewsSources.getSourcesByRegion(region);
    } else if (category != null) {
      sources = NewsSources.getSourcesByCategory(category);
    } else {
      sources = NewsSources.sources;
    }

    List<NewsArticle> allArticles = [];

    for (var source in sources) {
      try {
        final articles = await fetchArticlesFromSource(source);
        allArticles.addAll(articles);
      } catch (e) {
        print('Failed to fetch from ${source.name}: $e');
      }
    }

    // Sort by publish date, newest first
    allArticles.sort((a, b) => b.publishDate.compareTo(a.publishDate));

    // Store in database if requested
    if (storeInDb && allArticles.isNotEmpty) {
      await _databaseService.insertArticles(allArticles);
    }

    return allArticles;
  }

  // Refresh news on a schedule
  Timer? _refreshTimer;

  void startPeriodicRefresh(
      {Duration refreshInterval = const Duration(hours: 1)}) {
    _refreshTimer?.cancel();

    // Initial refresh
    fetchArticles();

    // Schedule periodic refresh
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      fetchArticles();
    });
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
