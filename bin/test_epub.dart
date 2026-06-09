import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

void main() {
  final dir = Directory.current.path;
  final epubPath = '$dir\\Let My People Go Surfing The Education of a Reluctant Businessman\u2014Including 10 More Years of Business Unusual.epub';
  final f = File(epubPath);
  if (!f.existsSync()) {
    print('File not found at: $epubPath');
    // Try to find it
    for (var e in Directory(dir).listSync()) {
      if (e.path.endsWith('.epub')) {
        print('Found: ${e.path}');
      }
    }
    return;
  }
  var b = f.readAsBytesSync();
  print('File size: ${b.length}');
  var z = ZipDecoder().decodeBytes(b);
  print('Files in archive: ${z.files.length}');
  
  // List first 20 files
  for (int i = 0; i < (z.files.length > 20 ? 20 : z.files.length); i++) {
    print('  ${z.files[i].name} (${z.files[i].size} bytes)');
  }
  
  // Find container
  var container = z.files.firstWhere((e) => e.name == 'META-INF/container.xml');
  var containerXml = String.fromCharCodes(container.content);
  print('\nCONTAINER:\n$containerXml');
  
  // Parse OPF
  var doc = XmlDocument.parse(containerXml);
  var opfPath = doc.findAllElements('rootfile').first.getAttribute('full-path');
  print('\nOPF path: $opfPath');
  
  var opfEntry = z.files.firstWhere((e) => e.name == opfPath);
  var opfXml = String.fromCharCodes(opfEntry.content);
  print('\nOPF content (first 2000 chars):\n${opfXml.substring(0, opfXml.length > 2000 ? 2000 : opfXml.length)}');
  
  // Get spine
  var opfDoc = XmlDocument.parse(opfXml);
  var spineRefs = opfDoc.findAllElements('itemref')
    .map((e) => e.getAttribute('idref'))
    .where((r) => r != null)
    .cast<String>()
    .toList();
  print('\nSpine refs (first 10): ${spineRefs.take(10).toList()}');
  
  var idToHref = <String, String>{};
  for (var item in opfDoc.findAllElements('item')) {
    var id = item.getAttribute('id');
    var href = item.getAttribute('href');
    if (id != null && href != null) idToHref[id] = href;
  }
  print('\nItem map: $idToHref');
  
  var opfDir = (opfPath ?? '').contains('/')
    ? (opfPath ?? '').substring(0, (opfPath ?? '').lastIndexOf('/') + 1)
    : '';
  print('\nOPF dir: "$opfDir"');
  
  void extractText(XmlNode node, StringBuffer buffer) {
    if (node is XmlText) {
      buffer.write(node.value);
    } else if (node is XmlElement) {
      if (node.localName == 'br' || node.localName == 'p' || node.localName == 'div') {
        buffer.write(' ');
      }
      for (final child in node.children) {
        extractText(child, buffer);
      }
    }
  }

  // Process all text content files in the spine
  var totalChars = 0;
  var contentFiles = 0;
  var xmlOk = 0;
  var xmlFail = 0;
  for (var ref in spineRefs) {
    var href = idToHref[ref];
    if (href == null) continue;
    var fullPath = '$opfDir$href';
    var ext = href.split('.').last;
    if (ext != 'xhtml' && ext != 'html' && ext != 'htm') continue;
    try {
      var entry = z.files.firstWhere((e) => e.name == fullPath);
      var html = String.fromCharCodes(entry.content);
      // Try XML parse first
      try {
        var doc = XmlDocument.parse(html);
        var root = doc.rootElement;
        if (root != null) {
          var buf = StringBuffer();
          extractText(root, buf);
          var text = buf.toString().trim();
          if (text.length > 0) {
            xmlOk++;
            totalChars += text.length;
            if (ref == spineRefs[0] || ref == spineRefs[1] || ref == spineRefs[3] || ref == spineRefs[7]) {
              print('\n--- XML OK: $ref ($fullPath) ---');
              print(text.substring(0, text.length > 300 ? 300 : text.length));
            }
          }
        }
      } catch (e) {
        xmlFail++;
        // Try regex fallback
        var text = html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
        if (text.length > 0) {
          totalChars += text.length;
          if (ref == spineRefs[7]) {
            print('\n--- REGEX FALLBACK: $ref ($fullPath) ---');
            print(text.substring(0, text.length > 300 ? 300 : text.length));
          }
        }
      }
      contentFiles++;
    } catch (e) {
      print('\nError processing $fullPath: $e');
    }
  }
  print('\n\nTotal text files: $contentFiles');
  print('XML parse OK: $xmlOk, XML parse FAIL: $xmlFail');
  print('Total extracted chars: $totalChars');
  
  // Check what MorseConverter would do
  var morseChars = 0;
  var nonMorseChars = <String>{};
  var textToConvert = 'Test text with accents like résumé and façade.';
  for (var c in textToConvert.split('')) {
    if ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,?\'!/():;&=+-_"@ '.contains(c.toUpperCase())) {
      morseChars++;
    } else {
      nonMorseChars.add(c);
    }
  }
  print('Non-morse chars in test: $nonMorseChars');
}
