import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/quote.dart';
import '../theme/app_colors.dart';

class QuoteCard extends StatelessWidget {
  final Quote quote;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDownload;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.isFavorited,
    required this.onFavoriteToggle,
    required this.onDownload,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFF6C3CE1), Color(0xFF3A1C71)],
    [Color(0xFFFF416C), Color(0xFF8B0000)],
    [Color(0xFF1565C0), Color(0xFF00B0FF)],
    [Color(0xFF11998E), Color(0xFF175C4E)],
    [Color(0xFFF7971E), Color(0xFFB85C00)],
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  ];

  List<Color> get _gradient =>
      _gradients[quote.id.hashCode.abs() % _gradients.length];

  void _share() {
    Share.share('"${quote.text}"\n\n— ${quote.author}\n\nvia Stauso');
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradient;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 14,
                  child: Text(
                    '“',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 96,
                      color: Colors.white.withValues(alpha: 0.12),
                      height: 1,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            quote.text,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 7,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '— ${quote.author}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      _ActionRow(
                        isFavorited: isFavorited,
                        onFavoriteToggle: onFavoriteToggle,
                        onDownload: onDownload,
                        onShare: _share,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
          icon: isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
