import 'package:flutter/material.dart';

class NewsSource {
  final String id;
  final String name;
  final String url;
  final String? iconPath;
  final NewsCategory category;
  final NewsRegion region;

  const NewsSource({
    required this.id,
    required this.name,
    required this.url,
    this.iconPath,
    required this.category,
    required this.region,
  });
}

enum NewsCategory {
  general,
  business,
  technology,
  entertainment,
  sports,
  health,
  science,
  politics
}

enum NewsRegion { nigeria, africa, global }

extension NewsCategoryExtension on NewsCategory {
  String get displayName {
    switch (this) {
      case NewsCategory.general:
        return 'General';
      case NewsCategory.business:
        return 'Business';
      case NewsCategory.technology:
        return 'Technology';
      case NewsCategory.entertainment:
        return 'Entertainment';
      case NewsCategory.sports:
        return 'Sports';
      case NewsCategory.health:
        return 'Health';
      case NewsCategory.science:
        return 'Science';
      case NewsCategory.politics:
        return 'Politics';
    }
  }

  IconData get icon {
    switch (this) {
      case NewsCategory.general:
        return Icons.public;
      case NewsCategory.business:
        return Icons.business;
      case NewsCategory.technology:
        return Icons.computer;
      case NewsCategory.entertainment:
        return Icons.movie;
      case NewsCategory.sports:
        return Icons.sports_soccer;
      case NewsCategory.health:
        return Icons.health_and_safety;
      case NewsCategory.science:
        return Icons.science;
      case NewsCategory.politics:
        return Icons.gavel;
    }
  }
}

extension NewsRegionExtension on NewsRegion {
  String get displayName {
    switch (this) {
      case NewsRegion.nigeria:
        return 'Nigeria';
      case NewsRegion.africa:
        return 'Africa';
      case NewsRegion.global:
        return 'Global';
    }
  }
}

// List of predefined news sources
class NewsSources {
  static const List<NewsSource> sources = [
    // Nigerian News Sources
    NewsSource(
      id: 'legit_ng',
      name: 'Legit.ng',
      url: 'https://www.legit.ng/rss/all.rss',
      category: NewsCategory.general,
      region: NewsRegion.nigeria,
    ),
    NewsSource(
      id: 'punch_ng',
      name: 'Punch Nigeria',
      url: 'https://punchng.com/feed/',
      category: NewsCategory.general,
      region: NewsRegion.nigeria,
    ),
    NewsSource(
      id: 'vanguard_ng',
      name: 'Vanguard Nigeria',
      url: 'https://www.vanguardngr.com/feed/',
      category: NewsCategory.general,
      region: NewsRegion.nigeria,
    ),
    NewsSource(
      id: 'guardian_ng',
      name: 'The Guardian Nigeria',
      url: 'https://guardian.ng/feed/',
      category: NewsCategory.general,
      region: NewsRegion.nigeria,
    ),
    NewsSource(
      id: 'techcabal',
      name: 'TechCabal',
      url: 'https://techcabal.com/feed/',
      category: NewsCategory.technology,
      region: NewsRegion.nigeria,
    ),
    NewsSource(
      id: 'complete_sports',
      name: 'Complete Sports',
      url: 'https://www.completesports.com/feed/',
      category: NewsCategory.sports,
      region: NewsRegion.nigeria,
    ),

    // African News Sources
    NewsSource(
      id: 'all_africa',
      name: 'AllAfrica',
      url: 'https://allafrica.com/tools/headlines/rdf/latest/headlines.rdf',
      category: NewsCategory.general,
      region: NewsRegion.africa,
    ),
    NewsSource(
      id: 'the_africa_report',
      name: 'The Africa Report',
      url: 'https://www.theafricareport.com/feed/',
      category: NewsCategory.general,
      region: NewsRegion.africa,
    ),
    NewsSource(
      id: 'africa_news',
      name: 'Africa News',
      url: 'https://www.africanews.com/feed/',
      category: NewsCategory.general,
      region: NewsRegion.africa,
    ),

    // Global News Sources
    NewsSource(
      id: 'bbc_world',
      name: 'BBC World',
      url: 'http://feeds.bbci.co.uk/news/world/rss.xml',
      category: NewsCategory.general,
      region: NewsRegion.global,
    ),
    NewsSource(
      id: 'cnn',
      name: 'CNN',
      url: 'http://rss.cnn.com/rss/edition.rss',
      category: NewsCategory.general,
      region: NewsRegion.global,
    ),
    NewsSource(
      id: 'reuters',
      name: 'Reuters',
      url: 'https://www.reutersagency.com/feed/',
      category: NewsCategory.general,
      region: NewsRegion.global,
    ),
    NewsSource(
      id: 'aljazeera',
      name: 'Al Jazeera',
      url: 'https://www.aljazeera.com/xml/rss/all.xml',
      category: NewsCategory.general,
      region: NewsRegion.global,
    ),
    NewsSource(
      id: 'techcrunch',
      name: 'TechCrunch',
      url: 'https://techcrunch.com/feed/',
      category: NewsCategory.technology,
      region: NewsRegion.global,
    ),
    NewsSource(
      id: 'espn',
      name: 'ESPN',
      url: 'https://www.espn.com/espn/rss/news',
      category: NewsCategory.sports,
      region: NewsRegion.global,
    ),
  ];

  static List<NewsSource> getSourcesByRegion(NewsRegion region) {
    return sources.where((source) => source.region == region).toList();
  }

  static List<NewsSource> getSourcesByCategory(NewsCategory category) {
    return sources.where((source) => source.category == category).toList();
  }

  static List<NewsSource> getSourcesByRegionAndCategory(
      NewsRegion region, NewsCategory category) {
    return sources
        .where(
            (source) => source.region == region && source.category == category)
        .toList();
  }

  static NewsSource? getSourceById(String id) {
    try {
      return sources.firstWhere((source) => source.id == id);
    } catch (e) {
      return null;
    }
  }
}
