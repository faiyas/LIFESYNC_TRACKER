import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  static Future<void> shareFile(String filePath, {String? text}) async {
    final file = XFile(filePath);
    await Share.shareXFiles([file], text: text);
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  static Future<File> generatePdfReport({
    required String title,
    required List<List<String>> tableData,
    required List<String> headers,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated on: ${DateTime.now().toString().substring(0, 19)}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: tableData,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
            ],
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File('${outputDir.path}/$title.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> printPdf(File pdfFile) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfFile.readAsBytes(),
    );
  }

  static Future<File> generateCsvReport({
    required String title,
    required List<List<String>> tableData,
    required List<String> headers,
  }) async {
    final StringBuffer csvContent = StringBuffer();
    csvContent.writeln(headers.join(','));

    for (var row in tableData) {
      final sanitizedRow = row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',');
      csvContent.writeln(sanitizedRow);
    }

    final outputDir = await getTemporaryDirectory();
    final file = File('${outputDir.path}/$title.csv');
    await file.writeAsString(csvContent.toString());
    return file;
  }
}
