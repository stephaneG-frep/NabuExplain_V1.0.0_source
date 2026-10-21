import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:nabu_explain/models/explanation.dart';
import 'package:nabu_explain/models/models.dart';

class PdfExportService {
  Future<File?> exportExplanation(Explanation exp) async {
    try {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('🦉 NabuExplain', style: const pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple,
                )),
                pw.Text('Généré le ${_formatDate(exp.createdAt)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Niveau : ${exp.level}  •  Complexité : ${exp.complexity}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey,
              wordSpacing: 2)),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.purple50,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              _stripMarkdown(exp.query),
              style: const pw.TextStyle(fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple900),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            _stripMarkdown(exp.response),
            style: const pw.TextStyle(fontSize: 11, height: 1.7),
          ),
        ],
      ));

      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'nabu_pdf',
          '${exp.title ?? exp.query.substring(0, exp.query.length > 30 ? 30 : exp.query.length)}.pdf'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(await doc.save());
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<File?> exportMemo(MemoCard memo) async {
    try {
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('🦉 NabuExplain — Fiche mémo',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.purple)),
            pw.SizedBox(height: 16),
            pw.Text(memo.title,
              style: const pw.TextStyle(fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple900)),
            pw.SizedBox(height: 16),
            pw.Text(_stripMarkdown(memo.content),
              style: const pw.TextStyle(fontSize: 11, height: 1.7)),
          ],
        ),
      ));

      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'nabu_pdf',
          'fiche_${memo.title.replaceAll(' ', '_')}.pdf'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(await doc.save());
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exporté depuis NabuExplain',
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _stripMarkdown(String text) {
    var result = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '[code]')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), r'$1');
    return result;
  }
}