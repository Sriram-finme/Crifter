import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/quote.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quote_card.dart';

// ─── Text-color presets ───────────────────────────────────────────────────────

const List<Color> kTextColors = [
  Colors.white,
  Colors.black,
  AppColors.accent,
  AppColors.primary,
  Color(0xFFE91E63),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class EditorScreen extends ConsumerStatefulWidget {
  final String quoteId;
  const EditorScreen({super.key, required this.quoteId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  // ── Quote state ──
  AsyncValue<Quote?> _quoteAsync = const AsyncValue.loading();

  // ── Editor state ──
  int _gradientIndex = 0;
  Uint8List? _backgroundImage;
  String _fontFamily = 'Playfair Display';
  double _fontSize = 22;
  Color _textColor = Colors.white;
  QuoteTextPosition _textPosition = QuoteTextPosition.center;
  int _activeTab = 0;

  final _nameController = TextEditingController();
  final _screenshotController = ScreenshotController();
  final _picker = ImagePicker();

  static const _tabs = ['Background', 'Text Style', 'Layout'];

  // ── Lifecycle ──

  @override
  void initState() {
    super.initState();
    _fetchQuote();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Data ──

  Future<void> _fetchQuote() async {
    try {
      final doc = await FirebaseService.firestore
          .collection('quotes')
          .doc(widget.quoteId)
          .get();
      if (!doc.exists) {
        setState(() => _quoteAsync = const AsyncValue.data(null));
        return;
      }
      final quote = Quote.fromJson({...doc.data()!, 'id': doc.id});
      setState(() {
        _quoteAsync = AsyncValue.data(quote);
        _gradientIndex = quote.id.hashCode.abs() % kGradientPresets.length;
      });
    } catch (e, st) {
      setState(() => _quoteAsync = AsyncValue.error(e, st));
    }
  }

  // ── Card builder ──

  Widget _buildCardView(Quote quote) {
    return QuoteCardView(
      quote: quote,
      gradientIndex: _backgroundImage == null ? _gradientIndex : null,
      backgroundImage: _backgroundImage,
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      textColor: _textColor,
      textPosition: _textPosition,
      watermarkName: _nameController.text.trim().isEmpty
          ? 'Stauso'
          : _nameController.text.trim(),
    );
  }

  // ── Capture ──

  Future<Uint8List?> _captureCard(Quote quote) async {
    return _screenshotController.captureFromWidget(
      SizedBox(width: 1080, height: 1080, child: _buildCardView(quote)),
      context: context,
      delay: const Duration(milliseconds: 80),
    );
  }

  // ── Actions ──

  Future<void> _download(Quote quote) async {
    try {
      final bytes = await _captureCard(quote);
      if (bytes == null) return;
      await SaverGallery.saveImage(
        bytes,
        quality: 100,
        name: 'stauso_${DateTime.now().millisecondsSinceEpoch}',
        androidRelativePath: 'Pictures/Stauso',
        androidExistNotSave: false,
      );
      if (mounted) _showSnack('Saved to gallery!', isError: false);
    } catch (e) {
      if (mounted) _showSnack('Could not save: $e');
    }
  }

  Future<void> _share(Quote quote) async {
    try {
      final bytes = await _captureCard(quote);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/stauso_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '"${quote.text}"\n\n— ${quote.author}\n\nvia Stauso',
      );
    } catch (e) {
      if (mounted) _showSnack('Could not share: $e');
    }
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _backgroundImage = bytes);
  }

  void _clearImage() => setState(() => _backgroundImage = null);

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final quote = _quoteAsync.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          if (quote != null) ...[
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Save to gallery',
              onPressed: () => _download(quote),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () => _share(quote),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: _quoteAsync.when(
        data: (q) {
          if (q == null) {
            return const Center(child: Text('Quote not found'));
          }
          return Column(
            children: [
              _PreviewArea(cardView: _buildCardView(q)),
              _BottomPanel(
                activeTab: _activeTab,
                tabs: _tabs,
                onTabChange: (i) => setState(() => _activeTab = i),
                tabContent: [
                  _BackgroundTab(
                    selectedGradient: _gradientIndex,
                    hasCustomImage: _backgroundImage != null,
                    onGradientSelect: (i) => setState(() {
                      _gradientIndex = i;
                      _backgroundImage = null;
                    }),
                    onGalleryPick: _pickImage,
                    onClearImage: _clearImage,
                  ),
                  _TextStyleTab(
                    fontFamily: _fontFamily,
                    fontSize: _fontSize,
                    textColor: _textColor,
                    onFontSelect: (f) => setState(() => _fontFamily = f),
                    onFontSizeChange: (s) => setState(() => _fontSize = s),
                    onColorSelect: (c) => setState(() => _textColor = c),
                  ),
                  _LayoutTab(
                    textPosition: _textPosition,
                    nameController: _nameController,
                    onPositionSelect: (p) =>
                        setState(() => _textPosition = p),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

// ─── Preview area ─────────────────────────────────────────────────────────────

class _PreviewArea extends StatelessWidget {
  final Widget cardView;
  const _PreviewArea({required this.cardView});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: const Color(0xFF080808),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(aspectRatio: 1, child: cardView),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom panel shell ───────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final int activeTab;
  final List<String> tabs;
  final void Function(int) onTabChange;
  final List<Widget> tabContent;

  const _BottomPanel({
    required this.activeTab,
    required this.tabs,
    required this.onTabChange,
    required this.tabContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tab bar
          Row(
            children: tabs.asMap().entries.map((e) {
              final isSelected = activeTab == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChange(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Tab content
          SizedBox(
            height: 190,
            child: IndexedStack(index: activeTab, children: tabContent),
          ),
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─── Tab 1: Background ────────────────────────────────────────────────────────

class _BackgroundTab extends StatelessWidget {
  final int selectedGradient;
  final bool hasCustomImage;
  final void Function(int) onGradientSelect;
  final VoidCallback onGalleryPick;
  final VoidCallback onClearImage;

  const _BackgroundTab({
    required this.selectedGradient,
    required this.hasCustomImage,
    required this.onGradientSelect,
    required this.onGalleryPick,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Background',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Gallery button
                GestureDetector(
                  onTap: hasCustomImage ? onClearImage : onGalleryPick,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: hasCustomImage
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.background,
                      border: Border.all(
                        color: hasCustomImage
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasCustomImage
                          ? Icons.close_rounded
                          : Icons.photo_outlined,
                      color: hasCustomImage
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Gradient swatches
                ...kGradientPresets.asMap().entries.map((e) {
                  final isSelected = !hasCustomImage && selectedGradient == e.key;
                  return GestureDetector(
                    onTap: () => onGradientSelect(e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: e.value,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: e.value.first.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (hasCustomImage) ...[
            const SizedBox(height: 12),
            Text(
              'Tap the × to remove your photo and use a gradient.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tab 2: Text Style ────────────────────────────────────────────────────────

class _TextStyleTab extends StatelessWidget {
  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final void Function(String) onFontSelect;
  final void Function(double) onFontSizeChange;
  final void Function(Color) onColorSelect;

  const _TextStyleTab({
    required this.fontFamily,
    required this.fontSize,
    required this.textColor,
    required this.onFontSelect,
    required this.onFontSizeChange,
    required this.onColorSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font picker
          Text(
            'Font',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kFontFamilies.map((f) {
                final isSelected = fontFamily == f;
                return GestureDetector(
                  onTap: () => onFontSelect(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      f.split(' ').first,
                      style: buildQuoteTextStyle(
                        f,
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Font size slider
          Row(
            children: [
              Text(
                'Size',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    inactiveTrackColor:
                        AppColors.textSecondary.withValues(alpha: 0.3),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: fontSize,
                    min: 16,
                    max: 40,
                    onChanged: onFontSizeChange,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${fontSize.round()}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Color picker
          Text(
            'Text Color',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: kTextColors.map((c) {
              final isSelected = textColor == c;
              return GestureDetector(
                onTap: () => onColorSelect(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: c == Colors.white || c == Colors.black
                              ? (c == Colors.white ? Colors.black : Colors.white)
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3: Layout ────────────────────────────────────────────────────────────

class _LayoutTab extends StatelessWidget {
  final QuoteTextPosition textPosition;
  final TextEditingController nameController;
  final void Function(QuoteTextPosition) onPositionSelect;

  const _LayoutTab({
    required this.textPosition,
    required this.nameController,
    required this.onPositionSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text position
          Text(
            'Text Position',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PositionButton(
                label: 'Top',
                icon: Icons.vertical_align_top_rounded,
                isSelected: textPosition == QuoteTextPosition.top,
                onTap: () => onPositionSelect(QuoteTextPosition.top),
              ),
              const SizedBox(width: 10),
              _PositionButton(
                label: 'Center',
                icon: Icons.vertical_align_center_rounded,
                isSelected: textPosition == QuoteTextPosition.center,
                onTap: () => onPositionSelect(QuoteTextPosition.center),
              ),
              const SizedBox(width: 10),
              _PositionButton(
                label: 'Bottom',
                icon: Icons.vertical_align_bottom_rounded,
                isSelected: textPosition == QuoteTextPosition.bottom,
                onTap: () => onPositionSelect(QuoteTextPosition.bottom),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Name / watermark
          Text(
            'Your Name (shown as watermark)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Ravi Kumar',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PositionButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
