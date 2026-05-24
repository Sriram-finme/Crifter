// ignore_for_file: avoid_print
//
// Generates multilingual quotes via Gemini and seeds them to Firestore.
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

Future<List<Map<String, dynamic>>> _generateQuotes(
  HttpClient client,
  String category,
) async {
  final uri = Uri.parse('$_geminiEndpoint?key=$_geminiKey');

  final prompt =
      "Generate 20 beautiful, shareable social media quotes for the '$category' "
      "category for an Indian app. Include: 8 in English, 6 in Hindi (Devanagari), "
      "3 in Tamil (Tamil script), 3 in Telugu (Telugu script). "
      "Return ONLY a valid JSON array with no markdown, each object having: "
      "text (the quote), author (real or 'Unknown'), language (en/hi/ta/te). "
      "No explanation, no backticks, just the JSON array.";

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

  for (var attempt = 1; attempt <= 3; attempt++) {
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.write(body);
    final res = await req.close();
    final raw = await res.transform(utf8.decoder).join();

    if (res.statusCode != 200) {
      if (attempt < 3) {
        print('  ⚠ Gemini ${res.statusCode}, retrying ($attempt/3)…');
        sleep(const Duration(seconds: 4));
        continue;
      }
      throw Exception('Gemini error ${res.statusCode}: $raw');
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final text = (decoded['candidates'] as List)[0]['content']['parts'][0]
        ['text'] as String;

    return _parseArray(text);
  }
  throw Exception('Gemini failed after 3 attempts');
}

List<Map<String, dynamic>> _parseArray(String raw) {
  var text = raw.trim();

  // Strip markdown fences if Gemini ignored the instruction
  if (text.startsWith('```')) {
    final firstNewline = text.indexOf('\n');
    final lastFence = text.lastIndexOf('```');
    if (firstNewline != -1 && lastFence > firstNewline) {
      text = text.substring(firstNewline + 1, lastFence).trim();
    }
  }

  // Locate the JSON array bounds in case there is surrounding text
  final start = text.indexOf('[');
  final end = text.lastIndexOf(']');
  if (start == -1 || end == -1) {
    throw FormatException('No JSON array in Gemini response:\n$text');
  }

  final list = jsonDecode(text.substring(start, end + 1)) as List;
  return list.cast<Map<String, dynamic>>();
}

// ─── Firestore REST helpers ───────────────────────────────────────────────────

String get _base =>
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

Future<void> _write(
  HttpClient client,
  String collection,
  String docId,
  Map<String, dynamic> data,
) async {
  final uri =
      Uri.parse('$_base/$collection/$docId?key=$_firestoreKey');
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
      print('\n🤖 [$category] Calling Gemini…');

      List<Map<String, dynamic>> quotes;
      try {
        quotes = await _generateQuotes(client, category);
      } catch (e) {
        stderr.writeln('  ❌ Skipping "$category": $e');
        continue;
      }

      print('  📝 ${quotes.length} quotes received — writing to Firestore…');

      for (var i = 0; i < quotes.length; i++) {
        final q = quotes[i];
        final text = (q['text'] ?? '').toString().trim();
        final author = (q['author'] ?? 'Unknown').toString().trim();
        final language = (q['language'] ?? 'en').toString().trim();
        if (text.isEmpty) continue;

        final docId = '${category}_${(i + 1).toString().padLeft(2, '0')}';
        await _write(client, 'quotes', docId, {
          'text': text,
          'author': author.isEmpty ? 'Unknown' : author,
          'categoryId': category,
          'language': language,
          'tags': <String>[],
          'isPremium': false,
          'createdAt': DateTime.now(),
        });
        print('  ✓ quotes/$docId [$language]');
        totalWritten++;
      }

      // Pause between categories to stay within Gemini rate limits
      if (category != _categories.last) {
        sleep(const Duration(seconds: 2));
      }
    }

    print(
        '\n✅ Done! $totalWritten quotes seeded across ${_categories.length} categories.');
  } catch (e) {
    stderr.writeln('\n❌ Fatal: $e');
    exit(1);
  } finally {
    client.close();
  }
}
