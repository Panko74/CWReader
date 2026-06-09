import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final sourcePath = 'ICONA.png';
  if (!File(sourcePath).existsSync()) {
    print('ICONA.png not found at project root');
    exit(1);
  }

  final src = img.decodeImage(File(sourcePath).readAsBytesSync());
  if (src == null) {
    print('Failed to decode ICONA.png');
    exit(1);
  }

  final baseDir = 'android/app/src/main/res';

  final sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final resized = img.copyResize(src, width: entry.value, height: entry.value);
    final png = img.encodePng(resized);
    final dir = '$baseDir/mipmap-${entry.key}';
    File('$dir/ic_launcher.png').writeAsBytesSync(png);
    print('Wrote $dir/ic_launcher.png');
  }

  createAdaptiveXml(baseDir);
  print('Done!');
}

void createAdaptiveXml(String baseDir) {
  File('$baseDir/mipmap-anydpi-v26/ic_launcher.xml').parent.createSync(recursive: true);
  File('$baseDir/mipmap-anydpi-v26/ic_launcher.xml').writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher"/>
</adaptive-icon>
''');
  print('Wrote mipmap-anydpi-v26/ic_launcher.xml');
}
