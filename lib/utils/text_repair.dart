import 'dart:convert';

String repairTurkishText(String input) {
  if (input.isEmpty) return input;

  var text = input;
  for (var i = 0; i < 4; i++) {
    final replaced = _applyManualRepairs(text);
    final decoded = _decodeLatin1AsUtf8(replaced);
    final best =
        _repairScore(decoded) >= _repairScore(replaced) ? decoded : replaced;
    if (best == text) {
      break;
    }
    text = best;
  }

  return text
      .replaceAll('\uFFFD', '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

String _applyManualRepairs(String input) {
  const replacements = <String, String>{
    '\u00C2 ': ' ',
    '\u00C2': '',
    '\u00E2\u20AC\u00A2': '\u2022',
    '\u00E2\u20AC\u0153': '"',
    '\u00E2\u20AC\u009D': '"',
    '\u00E2\u20AC\u201C': '-',
    '\u00E2\u20AC\u201D': '-',
    '\u00E2\u20AC\u2019': '\'',
    '\u00E2\u20AC\u02DC': '\'',
    '\u00E2\u20AC\u00A6': '...',
    '\u00C3\u2014': 'x',
  };

  var text = input;
  replacements.forEach((broken, fixed) {
    text = text.replaceAll(broken, fixed);
  });
  return text;
}

String _decodeLatin1AsUtf8(String text) {
  if (!_looksBroken(text)) return text;
  try {
    return utf8.decode(latin1.encode(text), allowMalformed: true);
  } catch (_) {
    return text;
  }
}

bool _looksBroken(String text) {
  return text.contains('\u00C3') ||
      text.contains('\u00C4') ||
      text.contains('\u00C5') ||
      text.contains('\u00C2') ||
      text.contains('\u00E2') ||
      text.contains('\uFFFD');
}

int _repairScore(String text) {
  const preferred =
      '\u00E7\u011F\u0131\u00F6\u015F\u00FC\u00C7\u011E\u0130\u00D6\u015E\u00DC';
  const brokenHints = '\u00C3\u00C4\u00C5\u00C2\u00E2\uFFFD';

  var score = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (preferred.contains(char)) score += 2;
    if (brokenHints.contains(char)) score -= 3;
  }
  return score;
}
