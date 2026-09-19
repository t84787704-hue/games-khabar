import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../services/translation_service.dart';

class TranslatedNewsTitle extends StatefulWidget {
  final NewsModel news;
  final String langCode;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;

  const TranslatedNewsTitle({
    super.key,
    required this.news,
    required this.langCode,
    required this.style,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.textDirection,
  });

  @override
  State<TranslatedNewsTitle> createState() => _TranslatedNewsTitleState();
}

class _TranslatedNewsTitleState extends State<TranslatedNewsTitle> {
  String? _translated;

  @override
  void initState() {
    super.initState();
    _checkTranslation();
  }

  @override
  void didUpdateWidget(covariant TranslatedNewsTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.langCode != widget.langCode || oldWidget.news.id != widget.news.id) {
      _checkTranslation();
    }
  }

  void _checkTranslation() {
    final lang = widget.langCode;
    final currentTitle = TranslationService.cleanBbCodeAndHtml(widget.news.getTitle(lang));
    final isLatin = (lang == 'en' || lang == 'ro' || lang.toLowerCase().contains('roman'));

    if (isLatin || TranslationService.isTextInLanguage(currentTitle, lang)) {
      _translated = currentTitle;
      return;
    }

    _translated = currentTitle;
    final baseTitle = widget.news.titleMap['en'] ?? currentTitle;
    TranslationService.translateSingle(baseTitle, lang).then((t) {
      if (mounted && t.isNotEmpty && (isLatin || TranslationService.isTextInLanguage(t, lang))) {
        widget.news.titleMap[lang] = t;
        setState(() {
          _translated = t;
        });
      }
    });

    // Pre-cache article description so when user opens the news, it is already in Urdu
    if (!isLatin) {
      final currentDesc = widget.news.getDescription(lang);
      if (!TranslationService.isTextInLanguage(currentDesc, lang)) {
        final baseDesc = widget.news.descriptionMap['en']?.isNotEmpty == true
            ? widget.news.descriptionMap['en']!
            : currentDesc;
        TranslationService.translateArticle(baseDesc, lang).then((d) {
          if (d.isNotEmpty && TranslationService.isTextInLanguage(d, lang)) {
            widget.news.descriptionMap[lang] = d;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _translated ?? TranslationService.cleanBbCodeAndHtml(widget.news.getTitle(widget.langCode));
    return Text(
      title,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      style: widget.style,
    );
  }
}
