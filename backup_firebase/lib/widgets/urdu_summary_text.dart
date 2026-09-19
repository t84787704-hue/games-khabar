import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../services/translation_service.dart';

class UrduSummaryText extends StatefulWidget {
  final NewsModel news;
  final int maxLines;
  final TextStyle? style;

  const UrduSummaryText({
    super.key,
    required this.news,
    this.maxLines = 2,
    this.style,
  });

  @override
  State<UrduSummaryText> createState() => _UrduSummaryTextState();
}

class _UrduSummaryTextState extends State<UrduSummaryText> {
  String? _urduText;

  @override
  void initState() {
    super.initState();
    _resolveUrduText();
  }

  @override
  void didUpdateWidget(covariant UrduSummaryText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.news.id != widget.news.id) {
      _resolveUrduText();
    }
  }

  void _resolveUrduText() {
    // 1. Check titleMap for 'ur'
    final candidateTitle = widget.news.titleMap['ur'] ?? '';
    if (candidateTitle.isNotEmpty && TranslationService.isTextInLanguage(candidateTitle, 'ur')) {
      _urduText = candidateTitle;
      return;
    }

    // 2. Check descriptionMap for 'ur'
    final candidateDesc = widget.news.descriptionMap['ur'] ?? '';
    if (candidateDesc.isNotEmpty && TranslationService.isTextInLanguage(candidateDesc, 'ur')) {
      // Pick first 1-2 clean sentences from description
      final clean = TranslationService.cleanBbCodeAndHtml(candidateDesc);
      final sentences = clean.split(RegExp(r'[۔\n]')).where((s) => s.trim().isNotEmpty).toList();
      if (sentences.isNotEmpty) {
        _urduText = sentences.take(2).join('۔ ').trim();
        if (!_urduText!.endsWith('۔')) _urduText = '$_urduText۔';
        return;
      }
    }

    // 3. If no Urdu yet, translate the English title into Urdu
    final englishBase = widget.news.titleMap['en'] ?? widget.news.title;
    if (englishBase.trim().isNotEmpty) {
      TranslationService.translateSingle(englishBase, 'ur').then((translated) {
        if (mounted && translated.isNotEmpty && TranslationService.isTextInLanguage(translated, 'ur')) {
          widget.news.titleMap['ur'] = translated;
          setState(() {
            _urduText = translated;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_urduText == null || _urduText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = TextStyle(
      color: const Color(0xFF69F0AE),
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 3.0),
      child: Text(
        _urduText!,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        textDirection: ui.TextDirection.rtl,
        textAlign: TextAlign.right,
        style: widget.style ?? defaultStyle,
      ),
    );
  }
}
