import 'dart:convert';
import 'dart:io';

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
      if (age < _cacheTtl.inMilliseconds) return cachedUrl;
    }

    // Fetch a fresh random image from Unsplash
    final query = _queries[category] ?? category;
    final uri = Uri.parse(
      'https://api.unsplash.com/photos/random'
      '?query=${Uri.encodeComponent(query)}'
      '&orientation=squarish'
      '&client_id=$_accessKey',
    );

    // ignore: avoid_print
    print('[Unsplash] Fetching image for "$category": $uri');

    final client = HttpClient()..autoUncompress = true;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      final response = await request.close();

      // ignore: avoid_print
      print('[Unsplash] Response status: ${response.statusCode} for "$category"');

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('[Unsplash] Non-200; serving stale cache for "$category"');
        return cachedUrl;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final urls = data['urls'] as Map<String, dynamic>?;
      final imageUrl = urls?['regular'] as String?;

      // ignore: avoid_print
      print('[Unsplash] Image URL for "$category": $imageUrl');

      if (imageUrl != null) {
        await prefs.setString(urlKey, imageUrl);
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      }
      return imageUrl;
    } catch (e) {
      // ignore: avoid_print
      print('[Unsplash] Error for "$category": $e');
      return cachedUrl;
    } finally {
      client.close();
    }
  }
}
