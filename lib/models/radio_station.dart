import 'package:flutter/material.dart';

enum RadioRegion { nigeria, africa, global }

enum RadioGenre {
  afrobeats,
  highlife,
  gospel,
  news,
  sports,
  talk,
  hiphop,
  reggae,
  jazz,
  pop,
  other
}

extension RadioGenreExtension on RadioGenre {
  String get displayName {
    switch (this) {
      case RadioGenre.afrobeats:
        return 'Afrobeats';
      case RadioGenre.highlife:
        return 'Highlife';
      case RadioGenre.gospel:
        return 'Gospel';
      case RadioGenre.news:
        return 'News';
      case RadioGenre.sports:
        return 'Sports';
      case RadioGenre.talk:
        return 'Talk';
      case RadioGenre.hiphop:
        return 'Hip Hop';
      case RadioGenre.reggae:
        return 'Reggae';
      case RadioGenre.jazz:
        return 'Jazz';
      case RadioGenre.pop:
        return 'Pop';
      case RadioGenre.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case RadioGenre.afrobeats:
        return Icons.music_note;
      case RadioGenre.highlife:
        return Icons.music_note;
      case RadioGenre.gospel:
        return Icons.church;
      case RadioGenre.news:
        return Icons.newspaper;
      case RadioGenre.sports:
        return Icons.sports_soccer;
      case RadioGenre.talk:
        return Icons.record_voice_over;
      case RadioGenre.hiphop:
        return Icons.headphones;
      case RadioGenre.reggae:
        return Icons.music_note;
      case RadioGenre.jazz:
        return Icons.piano;
      case RadioGenre.pop:
        return Icons.music_note;
      case RadioGenre.other:
        return Icons.radio;
    }
  }
}

extension RadioRegionExtension on RadioRegion {
  String get displayName {
    switch (this) {
      case RadioRegion.nigeria:
        return 'Nigeria';
      case RadioRegion.africa:
        return 'Africa';
      case RadioRegion.global:
        return 'Global';
    }
  }
}

class RadioStation {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final RadioRegion region;
  final RadioGenre genre;
  final String? description;
  final String? country;
  final String? language;
  final String? website;
  bool isFavorite;

  RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    required this.region,
    required this.genre,
    this.description,
    this.country,
    this.language,
    this.website,
    this.isFavorite = false,
  });

  factory RadioStation.fromMap(Map<String, dynamic> map) {
    // Map RadioRegion and RadioGenre from strings
    RadioRegion regionFromString(String? regionStr) {
      if (regionStr == null) return RadioRegion.global;

      if (regionStr.toLowerCase() == 'nigeria') {
        return RadioRegion.nigeria;
      } else if ([
        "ghana",
        "kenya",
        "south africa",
        "tanzania",
        "uganda",
        "zimbabwe",
        "ethiopia",
        "cameroon",
        "angola",
        "mozambique",
        "senegal"
      ].contains(regionStr.toLowerCase())) {
        return RadioRegion.africa;
      } else {
        return RadioRegion.global;
      }
    }

    RadioGenre genreFromString(String? genreStr) {
      if (genreStr == null) return RadioGenre.other;

      final String genre = genreStr.toLowerCase();

      if (genre.contains('afrobeat')) {
        return RadioGenre.afrobeats;
      } else if (genre.contains('highlife')) {
        return RadioGenre.highlife;
      } else if (genre.contains('gospel') || genre.contains('christian')) {
        return RadioGenre.gospel;
      } else if (genre.contains('news')) {
        return RadioGenre.news;
      } else if (genre.contains('sport')) {
        return RadioGenre.sports;
      } else if (genre.contains('talk') || genre.contains('discussion')) {
        return RadioGenre.talk;
      } else if (genre.contains('hip hop') ||
          genre.contains('hiphop') ||
          genre.contains('rap')) {
        return RadioGenre.hiphop;
      } else if (genre.contains('reggae')) {
        return RadioGenre.reggae;
      } else if (genre.contains('jazz')) {
        return RadioGenre.jazz;
      } else if (genre.contains('pop')) {
        return RadioGenre.pop;
      } else {
        return RadioGenre.other;
      }
    }

    return RadioStation(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Station',
      streamUrl: map['streamUrl'] ?? '',
      logoUrl: map['logoUrl'],
      region: regionFromString(map['country']),
      genre: genreFromString(map['genre']),
      description: map['description'],
      country: map['country'],
      language: map['language'],
      website: map['website'],
      isFavorite: map['isFavorite'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'streamUrl': streamUrl,
      'logoUrl': logoUrl,
      'region': region.toString().split('.').last,
      'genre': genre.toString().split('.').last,
      'description': description,
      'country': country,
      'language': language,
      'website': website,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }
}
