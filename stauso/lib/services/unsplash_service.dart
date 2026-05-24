// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UnsplashService {
  static const _accessKey = 'nVaSvCrFki3i-ppbDkj-ccPmOfXUR2K1zZc0oE67FxI';
  static const _cacheTtl = Duration(hours: 24);

  static const _queries = <String, String>{
    'morning': 'sunrise morning',
    'love': 'love romance',
    'motivation': 'success achievement',
    'friendship': 'friends happy',
    'festivals': 'celebration festival india',
    'shayari': 'poetry moonlight',
    'spiritual': 'temple meditation india',
    'success': 'success winner',
  };

  Future<String?> getImageForCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final urlKey = 'unsplash_url_$category';
    final tsKey = 'unsplash_ts_$category';

    // Return cached URL if still fresh
    final cachedUrl = prefs.getString(urlKey);
    final cachedTs = prefs.getInt(tsKey);
    if (cachedUrl != null && cachedTs != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cachedTs;
      if (age < _cacheTtl.inMilliseconds) {
        print('[Unsplash] Returning cached URL for "$category": $cachedUrl');
        return cachedUrl;
      }
    }

    final uri = Uri.https('api.unsplash.com', '/photos/random', {
      'query': _queries[category] ?? category,
      'orientation': 'squarish',
      'client_id': _accessKey,
    });

    print('[Unsplash] Fetching "$category" → $uri');

    try {
      final response = await http.get(uri);

      print('[Unsplash] Status ${response.statusCode} for "$category"');

      if (response.statusCode != 200) {
        print('[Unsplash] Body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return cachedUrl;
      }

      print('[Unsplash] Body (first 300): ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final urls = data['urls'] as Map<String, dynamic>?;
      final imageUrl = urls?['regular'] as String?;

      print('[Unsplash] Extracted URL for "$category": $imageUrl');

      if (imageUrl != null) {
        await prefs.setString(urlKey, imageUrl);
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      }
      return imageUrl;
    } catch (e, st) {
      print('[Unsplash] Error for "$category": $e\n$st');
      return cachedUrl;
    }
  }
}
