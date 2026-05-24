import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/quote.dart';
import '../theme/app_colors.dart';

// ─── Shared constants (used by editor) ───────────────────────────────────────

enum QuoteTextPosition { top, center, bottom }

const List<List<Color>> kGradientPresets = [
  [Color(0xFF6C3CE1), Color(0xFF3A1C71)],
  [Color(0xFFFF416C), Color(0xFF8B0000)],
  [Color(0xFF1565C0), Color(0xFF00B0FF)],
  [Color(0xFF11998E), Color(0xFF175C4E)],
  [Color(0xFFF7971E), Color(0xFFB85C00)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
];

const List<String> kFontFamilies = [
  'Playfair Display',
  'Poppins',
  'Dancing Script',
  'Merriweather',
  'Lato',
];

TextStyle buildQuoteTextStyle(
  String fontFamily, {
  double? fontSize,
  Color? color,
  FontWeight? fontWeight,
  double? height,
}) {
  final base = TextStyle(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    height: height,
  );
  return switch (fontFamily) {
    'Poppins' => GoogleFonts.poppins(textStyle: base),
    'Dancing Script' => GoogleFonts.dancingScript(textStyle: base),
    'Merriweather' => GoogleFonts.merriweather(textStyle: base),
    'Lato' => GoogleFonts.lato(textStyle: base),
    _ => GoogleFonts.playfairDisplay(textStyle: base),
  };
}

// ─── QuoteCardView — pure visual card, no action buttons ─────────────────────

class QuoteCardView extends StatelessWidget {
  final Quote quote;
  final int? gradientIndex;
  final Uint8List? backgroundImage;
  final String? imageUrl;
  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final QuoteTextPosition textPosition;
  final String watermarkName;

  const QuoteCardView({
    super.key,
    required this.quote,
    this.gradientIndex,
    this.backgroundImage,
    this.imageUrl,
    this.fontFamily = 'Playfair Display',
    this.fontSize = 22,
    this.textColor = Colors.white,
    this.textPosition = QuoteTextPosition.center,
    this.watermarkName = 'Stauso',
  });

  int get _gradientIdx =>
      gradientIndex ?? quote.id.hashCode.abs() % kGradientPresets.length;

  MainAxisAlignment get _columnAlignment => switch (textPosition) {
        QuoteTextPosition.top => MainAxisAlignment.start,
        QuoteTextPosition.bottom => MainAxisAlignment.end,
        QuoteTextPosition.center => MainAxisAlignment.center,
      };

  bool get _hasPhoto => backgroundImage != null || imageUrl != null;

  @override
  Widget build(BuildContext context) {
    final gradient = kGradientPresets[_gradientIdx];
    final useNetworkImage = backgroundImage == null && imageUrl != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background layer
          if (useNetworkImage)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: backgroundImage == null
                    ? LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: backgroundImage != null
                    ? DecorationImage(
                        image: MemoryImage(backgroundImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
          // Dark overlay for photos
          if (_hasPhoto)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          // Decorative opening quote mark
          Positioned(
            top: 8,
            left: 14,
            child: Text(
              '”',
              style: GoogleFonts.playfairDisplay(
                fontSize: 96,
                color: Colors.white.withValues(alpha: 0.12),
                height: 1,
              ),
            ),
          ),
          // Quote text + author
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 44),
            child: Column(
              mainAxisAlignment: _columnAlignment,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  quote.text,
                  style: buildQuoteTextStyle(
                    fontFamily,
                    fontSize: fontSize,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 9,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  '— ${quote.author}',
                  style: GoogleFonts.poppins(
                    fontSize: (fontSize * 0.58).clamp(11, 16),
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.75),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Watermark
          Positioned(
            bottom: 12,
            right: 16,
            child: Text(
              watermarkName,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QuoteCard — home-screen card: QuoteCardView + overlaid action row ────────

class QuoteCard extends StatelessWidget {
  final Quote quote;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDownload;
  final String? imageUrl;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.isFavorited,
    required this.onFavoriteToggle,
    required this.onDownload,
    this.imageUrl,
  });

  void _share() {
    Share.share('"“${quote.text}”"\n\n— ${quote.author}\n\nvia Stauso');
  }

  @override
  Widget build(BuildContext context) {
    final gradientIdx = quote.id.hashCode.abs() % kGradientPresets.length;
    final shadowColor = kGradientPresets[gradientIdx].first;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: QuoteCardView(
              quote: quote,
              gradientIndex: gradientIdx,
              imageUrl: imageUrl,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _ActionRow(
                isFavorited: isFavorited,
                onFavoriteToggle: onFavoriteToggle,
                onDownload: onDownload,
                onShare: _share,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _ActionRow({
    required this.isFavorited,
    required this.onFavoriteToggle,
    required this.onDownload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: isFavorited
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: isFavorited ? AppColors.accent : Colors.white,
          onTap: onFavoriteToggle,
        ),
        _ActionButton(
          icon: Icons.download_outlined,
          color: Colors.white,
          onTap: onDownload,
        ),
        _ActionButton(
          icon: Icons.share_outlined,
          color: Colors.white,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
