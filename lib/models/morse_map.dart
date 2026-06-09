class MorseMap {
  static const Map<String, String> _charToMorse = {
    'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.',
    'F': '..-.', 'G': '--.', 'H': '....', 'I': '..', 'J': '.---',
    'K': '-.-', 'L': '.-..', 'M': '--', 'N': '-.', 'O': '---',
    'P': '.--.', 'Q': '--.-', 'R': '.-.', 'S': '...', 'T': '-',
    'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-', 'Y': '-.--',
    'Z': '--..',
    '0': '-----', '1': '.----', '2': '..---', '3': '...--', '4': '....-',
    '5': '.....', '6': '-....', '7': '--...', '8': '---..', '9': '----.',
    '.': '.-.-.-', ',': '--..--', '?': '..--..', "'": '.----.',
    '!': '-.-.--', '/': '-..-.', '(': '-.--.', ')': '-.--.-',
    '&': '.-...', ':': '---...', ';': '-.-.-.', '=': '-...-',
    '+': '.-.-.', '-': '-....-', '_': '..--.-', '"': '.-..-.',
    '@': '.--.-.', ' ': '/',
    'À': '.--.-', 'à': '.--.-',
    'È': '..-..', 'è': '..-..',
    'É': '..-..', 'é': '..-..',
    'Ì': '..-..', 'ì': '..-..',
    'Ò': '---.', 'ò': '---.',
    'Ù': '..--', 'ù': '..--',
  };

  static final Map<String, String> _morseToChar =
      _charToMorse.map((k, v) => MapEntry(v, k));

  static String? toMorse(String char) =>
      _charToMorse[char] ?? _charToMorse[char.toUpperCase()];

  static String? fromMorse(String morse) => _morseToChar[morse];

  static bool isKnown(String char) =>
      _charToMorse.containsKey(char.toUpperCase());

  static Set<String> get knownChars =>
      _charToMorse.keys.map((k) => k.toUpperCase()).toSet();
}
