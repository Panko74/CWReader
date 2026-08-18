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

  String applySubstitutions(String text) {
    for (final sub in substitutions) {
      if (sub.enabled) {
        text = text.replaceAll(sub.from, sub.to);
      }
    }
    return text;
  }

  List<String> textToTokens(String text) {
    return textToTokensWithSource(text).tokens;
  }

  /// Tokenizza [text] come [textToTokens], restituendo anche, per ogni token,
  /// l'indice del carattere di origine in [text] (‑1 per i separatori di parola,
  /// sostituiti poi con l'indice del carattere precedente + 1).
  TokenizedResult textToTokensWithSource(String text) {
    final composedCodes = <int>[];
    final composedSrc = <int>[];
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0300 && code <= 0x036F && composedCodes.isNotEmpty) {
        final prev = composedCodes.last;
        final combined = _combineMap[prev]?[code];
        if (combined != null) {
          composedCodes[composedCodes.length - 1] = combined;
          continue;
        }
      }
      composedCodes.add(code);
      composedSrc.add(i);
    }

    final foldedCodes = <int>[];
    final foldedSrc = <int>[];
    for (int i = 0; i < composedCodes.length; i++) {
      final code = composedCodes[i];
      final c = String.fromCharCode(code);
      final lower = c.toLowerCase();
      final replacement = _accentMap[lower];
      if (replacement != null) {
        final out =
            c == c.toUpperCase() ? replacement.toUpperCase() : replacement;
        for (int k = 0; k < out.length; k++) {
          foldedCodes.add(out.codeUnitAt(k));
          foldedSrc.add(composedSrc[i]);
        }
      } else {
        foldedCodes.add(code);
        foldedSrc.add(composedSrc[i]);
      }
    }

    final tokens = <String>[];
    final indices = <int>[];
    final whitespace = RegExp(r'\s');
    var i = 0;
    var inWord = false;
    var lastSrc = -1;
    while (i < foldedCodes.length) {
      final code = foldedCodes[i];
      if (whitespace.hasMatch(String.fromCharCode(code))) {
        if (inWord) {
          tokens.add(' ');
          indices.add(lastSrc + 1);
          inWord = false;
        }
      } else {
        final morse = MorseMap.toMorse(String.fromCharCode(code));
        if (morse != null) {
          tokens.add(morse);
          lastSrc = foldedSrc[i];
          indices.add(lastSrc);
          inWord = true;
        }
      }
      i++;
    }
    return TokenizedResult(tokens, indices);
  }

  String textToMorseString(String text) {
    return textToTokens(text).join(' ');
  }
}

class TokenizedResult {
  final List<String> tokens;
  final List<int> sourceIndices;

  const TokenizedResult(this.tokens, this.sourceIndices);
}
