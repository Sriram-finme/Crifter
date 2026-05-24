'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();
const db = admin.firestore();

// ─── Config ───────────────────────────────────────────────────────────────────

const GEMINI_KEY = 'AIzaSyBDn2m-zxh3X5Ae2NI4Y8O1Yu6JfP7ON9o';
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_KEY}`;

const CATEGORIES = [
  'morning', 'love', 'motivation', 'friendship',
  'festivals', 'shayari', 'spiritual', 'success',
];

// ─── Gemini helpers ───────────────────────────────────────────────────────────

async function generateQuotes(category) {
  const prompt =
    `Generate 20 beautiful shareable social media quotes for '${category}' ` +
    `for an Indian app. Include 8 English, 6 Hindi (Devanagari), 3 Tamil (Tamil script), ` +
    `3 Telugu (Telugu script). Return ONLY a valid JSON array, each object: ` +
    `text, author, language (en/hi/ta/te). No markdown, no explanation.`;

  let lastError;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await axios.post(GEMINI_URL, {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.9, maxOutputTokens: 4096 },
      }, { timeout: 30000 });

      const raw = response.data.candidates[0].content.parts[0].text;
      return parseQuoteArray(raw);
    } catch (err) {
      lastError = err;
      console.warn(`Gemini attempt ${attempt}/3 failed for "${category}":`, err.message);
      if (attempt < 3) await sleep(4000);
    }
  }
  throw lastError;
}

function parseQuoteArray(raw) {
  let text = raw.trim();

  // Strip markdown fences if Gemini ignored the instruction
  if (text.startsWith('```')) {
    const firstNewline = text.indexOf('\n');
    const lastFence = text.lastIndexOf('```');
    if (firstNewline !== -1 && lastFence > firstNewline) {
      text = text.substring(firstNewline + 1, lastFence).trim();
    }
  }

  // Locate the JSON array in case there is surrounding text
  const start = text.indexOf('[');
  const end = text.lastIndexOf(']');
  if (start === -1 || end === -1) {
    throw new Error(`No JSON array found in Gemini response: ${text.slice(0, 200)}`);
  }
  return JSON.parse(text.substring(start, end + 1));
}

// ─── Core refresh logic ───────────────────────────────────────────────────────

async function refreshCategory(category) {
  console.log(`[${category}] Generating quotes via Gemini…`);
  const quotes = await generateQuotes(category);
  console.log(`[${category}] ${quotes.length} quotes received.`);

  // Delete quotes older than 48 hours for this category
  const cutoff = new Date(Date.now() - 48 * 60 * 60 * 1000);
  const oldSnap = await db.collection('quotes')
    .where('categoryId', '==', category)
    .where('createdAt', '<', cutoff)
    .get();

  if (!oldSnap.empty) {
    const delBatch = db.batch();
    oldSnap.docs.forEach((doc) => delBatch.delete(doc.ref));
    await delBatch.commit();
    console.log(`[${category}] Deleted ${oldSnap.size} stale quotes.`);
  }

  // Write new quotes in a batch
  const writeBatch = db.batch();
  const ts = Date.now();
  quotes.forEach((q, i) => {
    const text = (q.text || '').trim();
    if (!text) return;
    const docId = `${category}_${ts}_${String(i + 1).padStart(2, '0')}`;
    writeBatch.set(db.collection('quotes').doc(docId), {
      text,
      author: (q.author || 'Unknown').trim() || 'Unknown',
      categoryId: category,
      language: q.language || 'en',
      tags: [],
      isPremium: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  await writeBatch.commit();
  console.log(`[${category}] Wrote ${quotes.length} new quotes.`);
}

// ─── Utility ──────────────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─── Function 1: refreshQuotes — scheduled every 24 hours ────────────────────

exports.refreshQuotes = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub.schedule('every 24 hours')
  .onRun(async () => {
    console.log('=== refreshQuotes started ===');
    for (const category of CATEGORIES) {
      try {
        await refreshCategory(category);
      } catch (err) {
        console.error(`[${category}] Failed:`, err.message);
      }
      // Pause between categories to respect Gemini rate limits
      await sleep(2000);
    }
    console.log('=== refreshQuotes complete ===');
    return null;
  });

// ─── Function 2: seedInitialQuotes — HTTP POST, call once after deploy ────────

exports.seedInitialQuotes = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed — use POST');
      return;
    }

    const results = [];
    for (const category of CATEGORIES) {
      try {
        await refreshCategory(category);
        results.push({ category, status: 'ok' });
      } catch (err) {
        console.error(`[${category}] Seed failed:`, err.message);
        results.push({ category, status: 'error', error: err.message });
      }
      await sleep(2000);
    }

    const ok = results.filter((r) => r.status === 'ok').length;
    res.json({
      message: `Seeded ${ok}/${CATEGORIES.length} categories.`,
      results,
      seededAt: new Date().toISOString(),
    });
  });
