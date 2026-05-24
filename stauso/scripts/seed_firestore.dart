// Firestore seeding script — pure Dart, no extra dependencies.
//
// ignore_for_file: avoid_print
//
// Usage:
//   dart scripts/seed_firestore.dart <project_id> <web_api_key>
//
// Get your Web API Key from:
//   Firebase Console → Project Settings → General → Web API Key
//
// Before running, temporarily set Firestore rules to allow unauthenticated
// writes (dev only), then restore your production rules afterwards:
//
//   rules_version = '2';
//   service cloud.firestore {
//     match /databases/{database}/documents {
//       match /{document=**} { allow read, write: if true; }
//     }
//   }

import 'dart:convert';
import 'dart:io';

// ─── Firestore REST helpers ───────────────────────────────────────────────────

String _base(String project) =>
    'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents';

/// Converts a Dart value into the Firestore REST "typed value" format.
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

Map<String, dynamic> _doc(Map<String, dynamic> data) =>
    {'fields': data.map((k, v) => MapEntry(k, _val(v)))};

/// PATCH creates-or-replaces a document at collection/docId.
Future<void> _write(
  HttpClient client,
  String project,
  String apiKey,
  String collection,
  String docId,
  Map<String, dynamic> data,
) async {
  final uri = Uri.parse('${_base(project)}/$collection/$docId?key=$apiKey');
  final req = await client.patchUrl(uri);
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode(_doc(data)));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 300) {
    throw Exception('[$collection/$docId] ${res.statusCode}: $body');
  }
  print('  ✓ $collection/$docId');
}

// ─── Seed data ────────────────────────────────────────────────────────────────

final _categories = [
  {'id': 'morning', 'name': 'Good Morning', 'slug': 'morning', 'iconUrl': '🌅', 'sortOrder': 1, 'isActive': true},
  {'id': 'love', 'name': 'Love', 'slug': 'love', 'iconUrl': '❤️', 'sortOrder': 2, 'isActive': true},
  {'id': 'motivation', 'name': 'Motivation', 'slug': 'motivation', 'iconUrl': '💪', 'sortOrder': 3, 'isActive': true},
  {'id': 'friendship', 'name': 'Friendship', 'slug': 'friendship', 'iconUrl': '🤝', 'sortOrder': 4, 'isActive': true},
  {'id': 'festivals', 'name': 'Festivals', 'slug': 'festivals', 'iconUrl': '🎉', 'sortOrder': 5, 'isActive': true},
  {'id': 'shayari', 'name': 'Shayari', 'slug': 'shayari', 'iconUrl': '✍️', 'sortOrder': 6, 'isActive': true},
  {'id': 'spiritual', 'name': 'Spiritual', 'slug': 'spiritual', 'iconUrl': '🙏', 'sortOrder': 7, 'isActive': true},
  {'id': 'success', 'name': 'Success', 'slug': 'success', 'iconUrl': '🏆', 'sortOrder': 8, 'isActive': true},
];

Map<String, dynamic> _quote(String text, String author, String categoryId) => {
      'text': text,
      'author': author,
      'categoryId': categoryId,
      'language': 'en',
      'tags': <String>[],
      'isPremium': false,
      'createdAt': DateTime.now(),
    };

final _quotes = <Map<String, dynamic>>[
  // ── Good Morning ─────────────────────────────────────────────────────────
  _quote('Every morning is a new beginning. Take a deep breath, smile, and start again.', 'Unknown', 'morning'),
  _quote('Rise up, start fresh. See the bright opportunity in each new day.', 'Unknown', 'morning'),
  _quote('Morning is an important time of day, because how you spend your morning can often tell you what kind of day you are going to have.', 'Lemony Snicket', 'morning'),
  _quote('Each morning we are born again. What we do today matters most.', 'Buddha', 'morning'),
  _quote('The sun is new each day. Greet it with a grateful heart and a willing spirit.', 'Heraclitus', 'morning'),

  // ── Love ─────────────────────────────────────────────────────────────────
  _quote('The best thing to hold onto in life is each other.', 'Audrey Hepburn', 'love'),
  _quote('Love is not about how many days, months, or years you have been together. It\'s all about how much you love each other every single day.', 'Unknown', 'love'),
  _quote('In all the world, there is no heart for me like yours. In all the world, there is no love for you like mine.', 'Maya Angelou', 'love'),
  _quote('To love and be loved is to feel the sun from both sides.', 'David Viscott', 'love'),
  _quote('Where there is love there is life.', 'Mahatma Gandhi', 'love'),

  // ── Motivation ───────────────────────────────────────────────────────────
  _quote('Push yourself, because no one else is going to do it for you.', 'Unknown', 'motivation'),
  _quote('Great things never come from comfort zones.', 'Unknown', 'motivation'),
  _quote('Dream it. Wish it. Do it.', 'Unknown', 'motivation'),
  _quote('Success doesn\'t just find you. You have to go out and get it.', 'Unknown', 'motivation'),
  _quote('The harder you work for something, the greater you\'ll feel when you achieve it.', 'Unknown', 'motivation'),

  // ── Friendship ───────────────────────────────────────────────────────────
  _quote('A real friend is one who walks in when the rest of the world walks out.', 'Walter Winchell', 'friendship'),
  _quote('Friendship is born at that moment when one person says to another: "What! You too? I thought I was the only one."', 'C.S. Lewis', 'friendship'),
  _quote('Good friends are like stars. You don\'t always see them, but you know they\'re always there.', 'Unknown', 'friendship'),
  _quote('A friend is someone who knows all about you and still loves you.', 'Elbert Hubbard', 'friendship'),
  _quote('True friendship comes when the silence between two people is comfortable.', 'David Tyson', 'friendship'),

  // ── Festivals ────────────────────────────────────────────────────────────
  _quote('May the festival of lights brighten the darkest corners of your life and fill it with happiness and cheer.', 'Unknown', 'festivals'),
  _quote('Festivals are the mirrors of culture, reflecting the spirit and joy of a people.', 'Unknown', 'festivals'),
  _quote('Celebration is when the heart overflows and joy spills into the world around us.', 'Unknown', 'festivals'),
  _quote('May every festival bring new hopes and wash away sorrows. Wishing you a joyful celebration!', 'Unknown', 'festivals'),
  _quote('Festivals remind us that life is meant to be lived with laughter, color, and togetherness.', 'Unknown', 'festivals'),

  // ── Shayari ──────────────────────────────────────────────────────────────
  _quote('Zindagi ke safar mein, guzar jaate hain jo makaam, woh phir nahi aate, woh phir nahi aate.', 'Sahir Ludhianvi', 'shayari'),
  _quote('Kabhi kabhi mere dil mein khayal aata hai, ki jaise tujhko banaya gaya hai mere liye.', 'Sahir Ludhianvi', 'shayari'),
  _quote('Dil dhoondta hai phir wohi, fursat ke raat din — baithe rahen tasawwur-e-jaana kiye hue.', 'Gulzar', 'shayari'),
  _quote('Teri aankhon ki namkeen mastiyon ne loot liya, humein barbad kiya, phir bhi hum muskura diye.', 'Mirza Ghalib', 'shayari'),
  _quote('Ishq ne Ghalib nikamma kar diya, warna hum bhi aadmi the kaam ke.', 'Mirza Ghalib', 'shayari'),

  // ── Spiritual ────────────────────────────────────────────────────────────
  _quote('The soul that sees beauty may sometimes walk alone.', 'Goethe', 'spiritual'),
  _quote('Be still and know that I am God.', 'Psalms 46:10', 'spiritual'),
  _quote('The present moment is the only moment available to us, and it is the door to all moments.', 'Thich Nhat Hanh', 'spiritual'),
  _quote('Your task is not to seek for love, but merely to seek and find all the barriers within yourself that you have built against it.', 'Rumi', 'spiritual'),
  _quote('What you seek is seeking you.', 'Rumi', 'spiritual'),

  // ── Success ──────────────────────────────────────────────────────────────
  _quote('Success is not final, failure is not fatal: It is the courage to continue that counts.', 'Winston Churchill', 'success'),
  _quote('Don\'t watch the clock; do what it does. Keep going.', 'Sam Levenson', 'success'),
  _quote('The secret of success is to do the common things uncommonly well.', 'John D. Rockefeller', 'success'),
  _quote('Success usually comes to those who are too busy to be looking for it.', 'Henry David Thoreau', 'success'),
  _quote('Opportunities don\'t happen. You create them.', 'Chris Grosser', 'success'),
];

// ─── Main ─────────────────────────────────────────────────────────────────────

void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart scripts/seed_firestore.dart <project_id> <web_api_key>');
    stderr.writeln('');
    stderr.writeln('  project_id  : your Firebase project ID (e.g. stauso-abc12)');
    stderr.writeln('  web_api_key : Firebase Console → Project Settings → General → Web API Key');
    exit(1);
  }

  final project = args[0];
  final apiKey = args[1];
  final client = HttpClient();

  try {
    // ── Categories ──────────────────────────────────────────────────────────
    print('\n📂 Seeding categories…');
    for (final cat in _categories) {
      final id = cat['id'] as String;
      await _write(client, project, apiKey, 'categories', id, {
        'name': cat['name'],
        'slug': cat['slug'],
        'iconUrl': cat['iconUrl'],
        'sortOrder': cat['sortOrder'],
        'isActive': cat['isActive'],
      });
    }

    // ── Quotes ──────────────────────────────────────────────────────────────
    print('\n💬 Seeding quotes…');
    for (var i = 0; i < _quotes.length; i++) {
      final q = _quotes[i];
      final catId = q['categoryId'] as String;
      final docId = '${catId}_${(i + 1).toString().padLeft(2, '0')}';
      await _write(client, project, apiKey, 'quotes', docId, q);
    }

    print('\n✅ Done! ${_categories.length} categories + ${_quotes.length} quotes seeded.');
  } catch (e) {
    stderr.writeln('\n❌ Error: $e');
    stderr.writeln('\nMake sure your Firestore rules allow unauthenticated writes during seeding.');
    exit(1);
  } finally {
    client.close();
  }
}
