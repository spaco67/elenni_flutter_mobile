import 'dart:async';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';
import 'database_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class RadioService {
  final Dio _dio = Dio();
  final DatabaseService _databaseService = DatabaseService();
  static const String _baseUrl = 'https://www.radio.net';
  static const String _attributionText = 'Station data provided by Radio.net';

  // Predefined list of Nigerian radio stations for direct access
  final List<Map<String, dynamic>> _nigerianStations = [
    {
      'id': 'smooth_fm_lagos',
      'name': 'Smooth FM Lagos',
      'streamUrl': 'https://smoothfm-atunwadigital.streamguys1.com/smoothfm',
      'logoUrl':
          'https://www.smoothfm.com.ng/wp-content/themes/smooth-new/assets/img/sticky-logo.png',
      'country': 'Nigeria',
      'genre': 'jazz',
      'description': 'Smooth 98.1 FM Lagos - Lagos\' Number One Radio Station'
    },
    {
      'id': 'cool_fm_lagos',
      'name': 'Cool FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://www.coolfm.ng/wp-content/uploads/2018/10/cool-fm-lagos-logo-1.jpg',
      'country': 'Nigeria',
      'genre': 'pop',
      'description': 'Coming Soon - Cool FM 96.9 Lagos'
    },
    {
      'id': 'beat_fm_lagos',
      'name': 'Beat FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://beatfm.ondemandigital.com/wp-content/uploads/2022/03/beat-lagos-1-1.jpg',
      'country': 'Nigeria',
      'genre': 'pop',
      'description': 'Coming Soon - The Beat 99.9 FM Lagos'
    },
    {
      'id': 'wazobia_fm_lagos',
      'name': 'Wazobia FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://www.wazobiafm.com/wp-content/uploads/2018/10/wazobia-lagos-logo.jpg',
      'country': 'Nigeria',
      'genre': 'talk',
      'description': 'Coming Soon - Wazobia FM 95.1 Lagos'
    },
    {
      'id': 'naija_fm_lagos',
      'name': 'Naija FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://www.naijafm.com/wp-content/uploads/2019/09/naija-lagos-logo.jpg',
      'country': 'Nigeria',
      'genre': 'afrobeats',
      'description': 'Coming Soon - Naija FM 102.7 Lagos'
    },
    {
      'id': 'lagos_talks',
      'name': 'Lagos Talks',
      'streamUrl': null,
      'logoUrl':
          'https://lagostalks.com/wp-content/uploads/2018/11/lagos-talks-logo.png',
      'country': 'Nigeria',
      'genre': 'talk',
      'description': 'Coming Soon - Lagos Talks 91.3 FM'
    },
    {
      'id': 'classic_fm_lagos',
      'name': 'Classic FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://classicfmlag.com/wp-content/uploads/2022/11/header-logo.png',
      'country': 'Nigeria',
      'genre': 'jazz',
      'description': 'Coming Soon - Classic FM 97.3 Lagos'
    },
    {
      'id': 'city_fm_lagos',
      'name': 'City FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://cityfm.ng/wp-content/uploads/2020/05/city-fm-logo.png',
      'country': 'Nigeria',
      'genre': 'afrobeats',
      'description': 'Coming Soon - City FM 105.1 Lagos'
    },
    {
      'id': 'rhythm_fm_lagos',
      'name': 'Rhythm FM Lagos',
      'streamUrl': null,
      'logoUrl':
          'https://rhythmfm.ng/wp-content/uploads/2021/01/rhythm-93-7-logo-300x300-1.jpg',
      'country': 'Nigeria',
      'genre': 'afrobeats',
      'description': 'Coming Soon - Rhythm 93.7 FM Lagos'
    },
    {
      'id': 'nigeria_info_fm',
      'name': 'Nigeria Info FM',
      'streamUrl': null,
      'logoUrl':
          'https://www.nigeriainfo.fm/wp-content/uploads/2018/10/nigeria-info-lagos-logo.jpg',
      'country': 'Nigeria',
      'genre': 'news',
      'description': 'Coming Soon - Nigeria Info 99.3 FM'
    }
  ];

  // Predefined list of African radio stations for direct access
  final List<Map<String, dynamic>> _africanStations = [
    {
      'id': 'yfm_ghana',
      'name': 'YFM Ghana',
      'streamUrl': null,
      'logoUrl':
          'https://yfmghana.com/wp-content/uploads/2021/07/thumbnail_Y-logo-300x300-1.jpg',
      'country': 'Ghana',
      'genre': 'afrobeats',
      'description': 'Coming Soon - YFM Ghana'
    },
    {
      'id': 'capital_fm_kenya',
      'name': 'Capital FM Kenya',
      'streamUrl': null,
      'logoUrl': 'https://www.capitalfm.co.ke/assets/img/capital-logo.png',
      'country': 'Kenya',
      'genre': 'pop',
      'description': 'Coming Soon - Capital FM 98.4'
    },
    {
      'id': 'metro_fm_south_africa',
      'name': 'Metro FM',
      'streamUrl': null,
      'logoUrl':
          'https://www.metrofm.co.za/static/assets/2020/images/MetroFM980x280.png',
      'country': 'South Africa',
      'genre': 'hiphop',
      'description': 'Coming Soon - Metro FM'
    },
    {
      'id': 'bbc_africa',
      'name': 'BBC Africa',
      'streamUrl': null,
      'logoUrl': 'https://ichef.bbci.co.uk/images/ic/640x360/p07whsrp.jpg',
      'country': 'International',
      'genre': 'news',
      'description': 'Coming Soon - BBC World Service Africa'
    },
    {
      'id': 'citi_fm_ghana',
      'name': 'Citi FM',
      'streamUrl': null,
      'logoUrl':
          'https://citinewsroom.com/wp-content/uploads/2018/05/Citi-FM-Logo.png',
      'country': 'Ghana',
      'genre': 'news',
      'description': 'Coming Soon - Citi 97.3 FM'
    }
  ];

  // Generate a unique ID for a station based on its name and URL
  String _generateStationId(String name, String url) {
    final content = '$name-$url';
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  // Get stations by region
  Future<List<RadioStation>> getStationsByRegion(RadioRegion region) async {
    try {
      List<RadioStation> stations = [];

      // First try to get cached stations
      try {
        final cachedStations = await _getStationsFromDatabase(region);
        if (cachedStations.isNotEmpty) {
          return cachedStations;
        }
      } catch (e) {
        print('Error getting stations from database: $e');
      }

      // If no cached stations, use the predefined lists
      if (region == RadioRegion.nigeria) {
        stations = _nigerianStations.map((stationData) {
          if (stationData['id'] == null || stationData['id'].isEmpty) {
            stationData['id'] = _generateStationId(
                stationData['name'], stationData['streamUrl']);
          }
          return RadioStation.fromMap(stationData);
        }).toList();
      } else if (region == RadioRegion.africa) {
        stations = _africanStations.map((stationData) {
          if (stationData['id'] == null || stationData['id'].isEmpty) {
            stationData['id'] = _generateStationId(
                stationData['name'], stationData['streamUrl']);
          }
          return RadioStation.fromMap(stationData);
        }).toList();
      } else {
        // For global stations, use the ones we've defined above for now
        // In a real implementation, we would fetch from Radio.net or similar
        final combinedStations = [..._nigerianStations, ..._africanStations];
        stations = combinedStations.map((stationData) {
          if (stationData['id'] == null || stationData['id'].isEmpty) {
            stationData['id'] = _generateStationId(
                stationData['name'], stationData['streamUrl']);
          }
          return RadioStation.fromMap(stationData);
        }).toList();
      }

      // Cache stations in database
      try {
        await _saveStationsToDatabase(stations);
      } catch (e) {
        print('Error saving stations to database: $e');
      }

      return stations;
    } catch (e) {
      print('Error getting stations by region: $e');
      return [];
    }
  }

  // Get stations by genre
  Future<List<RadioStation>> getStationsByGenre(RadioGenre genre) async {
    // Get all stations
    final nigerianStations = await getStationsByRegion(RadioRegion.nigeria);
    final africanStations = await getStationsByRegion(RadioRegion.africa);
    final allStations = [...nigerianStations, ...africanStations];

    // Filter by genre
    return allStations.where((station) => station.genre == genre).toList();
  }

  // Get favorite stations
  Future<List<RadioStation>> getFavoriteStations() async {
    try {
      return _getStationsFromDatabase(null, favoritesOnly: true);
    } catch (e) {
      print('Error getting favorite stations: $e');
      return [];
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String stationId) async {
    try {
      await _toggleFavoriteInDatabase(stationId);
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  // Save stations to database
  Future<void> _saveStationsToDatabase(List<RadioStation> stations) async {
    for (final station in stations) {
      final stationMap = station.toMap();
      stationMap['streamUrl'] = station.streamUrl; // Ensure streamUrl is set

      await _databaseService.insertRadioStation(stationMap);
    }
  }

  // Get stations from database
  Future<List<RadioStation>> _getStationsFromDatabase(RadioRegion? region,
      {bool favoritesOnly = false}) async {
    String? regionStr;
    if (region != null) {
      regionStr = region.toString().split('.').last;
    }

    final stationMaps = await _databaseService.getRadioStations(
      region: regionStr,
      favoritesOnly: favoritesOnly,
    );

    return stationMaps.map((map) => RadioStation.fromMap(map)).toList();
  }

  // Toggle favorite in database
  Future<void> _toggleFavoriteInDatabase(String stationId) async {
    await _databaseService.toggleRadioStationFavorite(stationId);
  }

  // Get attribution text
  String getAttributionText() {
    return _attributionText;
  }

  Future<List<Map<String, dynamic>>> getNigerianStations() async {
    try {
      // Get Smooth FM (the only working station)
      final smoothFm = _nigerianStations.firstWhere(
        (station) => station['id'] == 'smooth_fm_lagos',
        orElse: () => throw Exception('Smooth FM not found'),
      );

      // Get all other stations except Smooth FM
      final otherStations = _nigerianStations
          .where((station) => station['id'] != 'smooth_fm_lagos')
          .toList();

      // Return Smooth FM first, followed by other stations
      return [smoothFm, ...otherStations];
    } catch (e) {
      print('Error getting Nigerian stations: $e');
      return [];
    }
  }
}
