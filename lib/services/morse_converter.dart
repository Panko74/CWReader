import '../models/morse_map.dart';
import '../models/substitution.dart';

class MorseConverter {
  final List<Substitution> substitutions;

  MorseConverter({this.substitutions = const []});

  static final Map<String, String> _accentMap = {
    'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'ê': 'e', 'ë': 'e', 'ē': 'e',
    'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o',
    'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss',
    '\u00A0': ' ',
  };

  static final Map<int, Map<int, int>> _combineMap = {
    0x61: {0x0300: 0xE0, 0x0301: 0xE1},
    0x65: {0x0300: 0xE8, 0x0301: 0xE9},
    0x69: {0x0300: 0xEC, 0x0301: 0xED},
    0x6F: {0x0300: 0xF2, 0x0301: 0xF3},
    0x75: {0x0300: 0xF9, 0x0301: 0xFA},
    0x41: {0x0300: 0xC0, 0x0301: 0xC1},
    0x45: {0x0300: 0xC8, 0x0301: 0xC9},
    0x49: {0x0300: 0xCC, 0x0301: 0xCD},
    0x4F: {0x0300: 0xD2, 0x0301: 0xD3},
    0x55: {0x0300: 0xD9, 0x0301: 0xDA},
  };

  String _composeNfd(String text) {
    final out = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0300 && code <= 0x036F && i > 0) {
        final prev = text.codeUnitAt(i - 1);
        final composed = _combineMap[prev]?[code];
        if (composed != null) {
          final s = out.toString();
          out.clear();
          out.write(s.substring(0, s.length - 1));
          out.writeCharCode(composed);
        }
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }

  String _normalizeNonItalian(String text) {
    return text.split('').map((c) {
      final lower = c.toLowerCase();
      final replacement = _accentMap[lower];
      if (replacement != null) {
        return c == c.toUpperCase() ? replacement.toUpperCase() : replacement;
      }
      return c;
    }).join('');
  }

  String applySubstitutions(String text) {
    for (final sub in substitutions) {
      if (sub.enabled) {
        text = text.replaceAll(sub.from, sub.to);
      }
    }
    return text;
  }

  List<String> textToTokens(String text) {
    final tokens = <String>[];
    text = _composeNfd(text);
    text = _normalizeNonItalian(text);
    final words = text.split(RegExp(r'\s+'));

    for (int w = 0; w < words.length; w++) {
      if (w > 0) tokens.add(' ');

      final word = words[w];
      for (int i = 0; i < word.length; i++) {
        final char = word[i];
        final code = MorseMap.toMorse(char);
        if (code != null) {
          tokens.add(code);
        }
      }
    }
    return tokens;
  }

  String textToMorseString(String text) {
    return textToTokens(text).join(' ');
  }
}
