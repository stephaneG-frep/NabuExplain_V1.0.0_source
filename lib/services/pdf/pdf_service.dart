import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart'
    show BuildContext, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';

class PdfExportService {
  static pw.ThemeData? _theme;
  static pw.Font? _mono;

  /// Polices embarquées : Helvetica (par défaut) n'a ni émojis ni la plupart
  /// des caractères Unicode. Noto Emoji sert de police de repli.
  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    Future<pw.Font> load(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));
    final regular = await load('NotoSans-Regular.ttf');
    final bold = await load('NotoSans-Bold.ttf');
    final emoji = await load('NotoEmoji-Regular.ttf');
    _mono = await load('NotoSansMono-Regular.ttf');
    _theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
      fontFallback: [emoji],
    );
    return _theme!;
  }

  Future<File?> exportExplanation(Explanation exp) async {
    try {
      return await _write(
        await buildExplanationPdf(exp),
        exp.title ?? exp.query,
      );
    } catch (_) {
      return null;
    }
  }

  Future<File?> exportMemo(MemoCard memo) async {
    try {
      return await _write(await buildMemoPdf(memo), 'fiche_${memo.title}');
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> buildExplanationPdf(Explanation exp) async {
    final theme = await _loadTheme();
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '🦉 NabuExplain',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.purple,
                  ),
                ),
                pw.Text(
                  'Généré le ${_formatDate(exp.createdAt)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Niveau : ${_levelLabel(exp.level)}  •  Complexité : ${exp.complexity}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
              wordSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.purple50,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              _inline(exp.title ?? exp.query),
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple900,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          ..._markdown(exp.response),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildMemoPdf(MemoCard memo) async {
    final theme = await _loadTheme();
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            '🦉 NabuExplain — Fiche mémo',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.purple),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            memo.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple900,
            ),
          ),
          pw.SizedBox(height: 16),
          ..._markdown(memo.content),
        ],
      ),
    );
    return doc.save();
  }

  /// Génère le PDF puis ouvre le menu de partage Android (enregistrer,
  /// envoyer par mail, Drive…) : le fichier est dans le dossier privé de l'app.
  Future<void> exportAndShare(
    BuildContext context,
    Future<File?> Function() export,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await export();
    if (file == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('😕 Impossible de générer le PDF.')),
      );
      return;
    }
    await shareFile(file);
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/pdf'),
    ], text: 'Exporté depuis NabuExplain');
  }

  Future<File> _write(Uint8List bytes, String title) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(dir.path, 'nabu_pdf', '${safeFileName(title)}.pdf'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Nom de fichier sans caractères interdits (/, :, retours à la ligne…).
  static String safeFileName(String title) {
    var name = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (name.length > 40) name = name.substring(0, 40);
    return name.isEmpty ? 'nabuexplain' : name;
  }

  String _formatDate(DateTime dt) {
    final months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _levelLabel(String key) {
    const labels = {
      'very_simple': 'Très simple',
      'beginner': 'Débutant',
      'intermediate': 'Intermédiaire',
      'advanced': 'Avancé',
      'expert': 'Expert',
    };
    return labels[key] ?? key;
  }

  /// Convertit le Markdown courant des réponses IA en widgets PDF : titres,
  /// listes, gras et blocs de code (conservés en police à chasse fixe).
  List<pw.Widget> _markdown(String text) {
    final widgets = <pw.Widget>[];
    final fence = RegExp(r'```[^\n]*\n([\s\S]*?)```');
    var last = 0;
    for (final m in fence.allMatches(text)) {
      widgets.addAll(_paragraphs(text.substring(last, m.start)));
      widgets.add(_codeBlock(m.group(1) ?? ''));
      last = m.end;
    }
    widgets.addAll(_paragraphs(text.substring(last)));
    return widgets;
  }

  pw.Widget _codeBlock(String code) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        code.trimRight(),
        style: pw.TextStyle(font: _mono, fontSize: 9, lineSpacing: 2),
      ),
    );
  }

  List<pw.Widget> _paragraphs(String text) {
    final widgets = <pw.Widget>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }
      final heading = RegExp(r'^\s*(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              _inline(heading.group(2)!),
              style: pw.TextStyle(
                fontSize: level <= 2 ? 15 : 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple900,
              ),
            ),
          ),
        );
        continue;
      }
      final bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        final indent = bullet.group(1)!.length * 4.0;
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 8 + indent, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('•  ', style: const pw.TextStyle(fontSize: 11)),
                pw.Expanded(
                  child: pw.Text(
                    _inline(bullet.group(2)!),
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      final isBoldLine = RegExp(r'^\s*\*\*[^*]+\*\*:?\s*$').hasMatch(line);
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            _inline(line),
            style: pw.TextStyle(
              fontSize: 11,
              lineSpacing: 3,
              fontWeight: isBoldLine
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Retire la syntaxe Markdown en ligne sans toucher au contenu : les `_` et
  /// `*` isolés (snake_case, a*b) sont conservés.
  String _inline(String text) {
    return text
        .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
          (m) => '${m.group(1)} (${m.group(2)})',
        )
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])'),
          (m) => m.group(1)!,
        )
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
  }
}
