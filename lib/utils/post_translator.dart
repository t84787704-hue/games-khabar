import 'package:translator/translator.dart';

class PostTranslator {
  static final GoogleTranslator _translator = GoogleTranslator();

  static Future<String> translatePost(String text, String targetLang) async {
    if (text.isEmpty) return '';
    try {
      Translation translation = await _translator.translate(text, to: targetLang);
      return translation.text;
    } catch (e) {
      return text; // اگر انٹرنیٹ نہ ہو تو اورجنل ٹیکسٹ ہی شو ہو گا
    }
  }
}
