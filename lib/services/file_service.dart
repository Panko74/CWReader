import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    status = await Permission.storage.request();
    if (status.isGranted) return true;

    return false;
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    return false;
  }

  Future<PlatformFile?> pickFile() async {
    // file_picker uses SAF internally, no permissions needed on Android 10+
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<String> readFileContent(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
        return await _readTxt(filePath);
      case 'epub':
        try {
          return await _readEpub(filePath);
        } catch (e) {
          throw Exception('Errore lettura EPUB: $e');
        }
      default:
        throw UnsupportedError('Formato non supportato: $ext');
    }
  }

  Future<String> _readTxt(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return _decodeText(bytes);
  }

  String _decodeText(List<int> bytes) {
    if (bytes.length >= 2) {
      if ((bytes[0] == 0xFE && bytes[1] == 0xFF) ||
          (bytes[0] == 0xFF && bytes[1] == 0xFE)) {
        return String.fromCharCodes(bytes);
      }
      if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        bytes = bytes.sublist(3);
      }
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  Future<String> _readEpub(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? opfPath;
    try {
      final containerEntry =
          archive.files.firstWhere((f) => f.name == 'META-INF/container.xml');
      final containerXml =
          XmlDocument.parse(_decodeText(containerEntry.content));
      opfPath = containerXml
          .findAllElements('rootfile')
          .first
          .getAttribute('full-path');
    } catch (_) {
      for (final f in archive.files) {
        if (f.name.endsWith('.opf')) {
          opfPath = f.name;
          break;
        }
      }
    }

    if (opfPath == null) return '';

    final opfEntry = archive.files.firstWhere((f) => f.name == opfPath);
    final opfXml =
        XmlDocument.parse(_decodeText(opfEntry.content));

    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    final spineRefs = opfXml
        .findAllElements('itemref')
        .map((e) => e.getAttribute('idref'))
        .where((r) => r != null)
        .cast<String>()
        .toList();

    final idToHref = <String, String>{};
    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        idToHref[id] = href;
      }
    }

    final buffer = StringBuffer();
    for (final ref in spineRefs) {
      final href = idToHref[ref];
      if (href == null) continue;
      final fullPath = '$opfDir$href';
      try {
        final entry = archive.files.firstWhere((f) => f.name == fullPath);
        final html = _decodeText(entry.content);
        buffer.writeln(_stripHtml(html));
      } catch (_) {}
    }

    return buffer.toString();
  }

  String _stripHtml(String html) {
    html = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '\n');
    html = html.replaceAllMapped(
      RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false),
      (_) => '\n',
    );
    html = html.replaceAll(RegExp(r'</?(?:p|div|h[1-6]|li|tr|br|section|blockquote|article|nav|header|footer|figure|figcaption)[^>]*>', caseSensitive: false), '\n');
    html = html.replaceAll(RegExp(r'<[^>]*>'), '');
    html = html
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&#8211;', '-')
      .replaceAll('&#8212;', '-')
      .replaceAll('&#8216;', "'")
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8220;', '"')
      .replaceAll('&#8221;', '"')
      .replaceAll('&#8230;', '...');
    html = html.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)));
    html = html.replaceAll(RegExp(r'[ \t]+'), ' ');
    html = html.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    html = html.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    html = html.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    return html.trim();
  }

  Future<String> getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }
}
