// ignore_for_file: avoid_print
//
// Generates quotes via Gemini API and seeds them to Firestore.
// Uses only dart:io and dart:convert — no extra packages.
//
// Usage: dart scripts/seed_with_gemini.dart

import 'dart:convert';
import 'dart:io';

// ─── Config ───────────────────────────────────────────────────────────────────

const _geminiKey = 'AIzaSyBDn2m-zxh3X5Ae2NI4Y8O1Yu6JfP7ON9o';
const _geminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

const _firestoreProject = 'statuso-d523e';
const _firestoreKey = 'AIzaSyCR-nx07QHxQ4jfh5lWXms-Qn338y49YuE';

const _categories = [
  'morning',
  'love',
  'motivation',
  'friendship',
  'festivals',
  'shayari',
  'spiritual',
  'success',
];

// ─── Gemini ───────────────────────────────────────────────────────────────────

/// Calls Gemini to generate 20 quotes for [category].
/// Returns a list of {text, author} maps.
Future<List<Map<String, dynamic>>> _generateQuotes(
  HttpClient client,
  String category,
) async {
  final uri = Uri.parse('$_geminiEndpoint?key=$_geminiKey');
  final prompt =
      "Generate 20 unique, beautiful, shareable quotes for the '$category' "
      "category for an Indian social media app. Mix English and Hindi quotes. "
      "Return ONLY a JSON array of objects with fields: text, author. "
      "No markdown, no explanation.";

  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': prompt}
        ]
      }
    ],
    'generationConfig': {
      'temperature': 0.9,
      'maxOutputTokens': 4096,
    },
  });

  // Retry up to 3 times on transient errors
  for (var attempt = 1; attempt <= 3; attempt++) {
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.write(body);
    final res = await req.close();
    final raw = await res.transform(utf8.decoder).join();

    if (res.statusCode != 200) {
      if (attempt < 3) {
        print('  ⚠ Gemini returned ${res.statusCode}, retrying ($attempt/3)…');
        sleep(const Duration(seconds: 3));
        continue;
      }
      throw Exception('Gemini error ${res.statusCode}: $raw');
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final text = (decoded['candidates'] as List)[0]['content']['parts'][0]
        ['text'] as String;

    return _parseQuoteArray(text);
  }
  throw Exception('Gemini failed after 3 attempts');
}

/// Strips optional markdown fences and parses the JSON array from Gemini output.
List<Map<String, dynamic>> _parseQuoteArray(String raw) {
  var text = raw.trim();

  // Strip ```json ... ``` or ``` ... ```
  if (text.startsWith('```')) {
    final firstNewline = text.indexOf('\n');
    final lastFence = text.lastIndexOf('```');
    if (firstNewline != -1 && lastFence > firstNewline) {
      text = text.substring(firstNewline + 1, lastFence).trim();
    }
  }

  // Find the JSON array bounds in case there's surrounding text
  final start = text.indexOf('[');
  final end = text.lastIndexOf(']');
  if (start == -1 || end == -1) {
    throw FormatException('No JSON array found in Gemini response:\n$text');
  }
  text = text.substring(start, end + 1);

  final list = jsonDecode(text) as List;
  return list.cast<Map<String, dynamic>>();
}

// ─── Firestore REST helpers ───────────────────────────────────────────────────

String _firestoreBase() =>
    'https://firestore.googleapis.com/v1/projects/$_firestoreProject/databases/(default)/documents';

Map<String, dynamic> _val(dynamic v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double) return {'doubleValue': v};
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  if (v is String) return {'stringValue': v};
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(_val).toList()}
    };
  }
  if (v is Map) {
    return {
      'mapValue': {
        'fields': v.map((k, val) => MapEntry(k as String, _val(val)))
      }
    };
  }
  return {'stringValue': v.toString()};
}

Future<void> _writeDoc(
  HttpClient client,
  String collection,
  String docId,
  Map<String, dynamic> data,
) async {
  final uri = Uri.parse(
      '${_firestoreBase()}/$collection/$docId?key=$_firestoreKey');
  final req = await client.patchUrl(uri);
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode({
    'fields': data.map((k, v) => MapEntry(k, _val(v))),
  }));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 300) {
    throw Exception('Firestore [$collection/$docId] ${res.statusCode}: $body');
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

void main() async {
  final client = HttpClient();
  var totalWritten = 0;

  try {
    for (final category in _categories) {
      print('\n🤖 Generating quotes for "$category"…');

      List<Map<String, dynamic>> quotes;
      try {
        quotes = await _generateQuotes(client, category);
      } catch (e) {
        stderr.writeln('  ❌ Skipping "$category": $e');
        continue;
      }

      print('  📝 Received ${quotes.length} quotes — writing to Firestore…');

      for (var i = 0; i < quotes.length; i++) {
        final q = quotes[i];
        final text = (q['text'] ?? '').toString().trim();
        final author = (q['author'] ?? 'Unknown').toString().trim();
        if (text.isEmpty) continue;

        final docId = '${category}_${(i + 1).toString().padLeft(2, '0')}';
        await _writeDoc(client, 'quotes', docId, {
          'text': text,
          'author': author.isEmpty ? 'Unknown' : author,
          'categoryId': category,
          'language': 'en',
          'tags': <String>[],
          'isPremium': false,
          'createdAt': DateTime.now(),
        });
        print('  ✓ quotes/$docId');
        totalWritten++;
      }

      // Brief pause between categories to stay within Gemini rate limits
      if (category != _categories.last) {
        sleep(const Duration(seconds: 2));
      }
    }

    print('\n✅ Done! $totalWritten quotes seeded across ${_categories.length} categories.');
  } catch (e) {
    stderr.writeln('\n❌ Fatal error: $e');
    exit(1);
  } finally {
    client.close();
  }
}
