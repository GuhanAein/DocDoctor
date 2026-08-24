import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';


/// Pure-Dart document converters. All methods are isolate-safe.
class DocumentConverters {
  // ════ Text → PDF ════════════════════════════════════════════════
  Uint8List txtToPdf(String text, {double fontSize = 11, double lineHeight = 16}) {
    final doc = PdfDocument();
    final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
    const margin = 48.0;
    final pageWidth = 595.0;
    final usable = pageWidth - margin * 2;
    final charsPerLine = (usable / (fontSize * 0.5)).floor().clamp(10, 200);

    var page = doc.pages.add();
    var y = margin;
    const pageHeight = 842.0;

    for (final rawLine in text.split('\n')) {
      if (rawLine.isEmpty) {
        y += lineHeight;
        continue;
      }
      final wrapped = _wrapLine(rawLine, charsPerLine);
      for (final line in wrapped) {
        if (y + lineHeight > pageHeight - margin) {
          page = doc.pages.add();
          y = margin;
        }
        page.graphics.drawString(
          line,
          font,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(margin, y, usable, lineHeight + 2),
        );
        y += lineHeight;
      }
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  List<String> _wrapLine(String line, int charsPerLine) {
    final words = line.split(RegExp(r'\s+'));
    final result = <String>[];
    var current = '';
    for (final w in words) {
      if (w.length > charsPerLine) {
        if (current.isNotEmpty) {
          result.add(current);
          current = '';
        }
        for (var i = 0; i < w.length; i += charsPerLine) {
          result.add(w.substring(i, (i + charsPerLine).clamp(0, w.length)));
        }
        continue;
      }
      if ((current + (current.isEmpty ? '' : ' ') + w).length <= charsPerLine) {
        current = (current.isEmpty ? '' : '$current ') + w;
      } else {
        if (current.isNotEmpty) result.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result.isEmpty ? [''] : result;
  }

  // ════ HTML → PDF ════════════════════════════════════════════════
  Uint8List htmlToPdf(String html) {
    final doc = PdfDocument();
    const margin = 48.0;
    const pageWidth = 595.0;
    const pageHeight = 842.0;
    const usable = pageWidth - margin * 2;
    var y = margin;

    var page = doc.pages.add();

    void ensureSpace(double needed) {
      if (y + needed > pageHeight - margin) {
        page = doc.pages.add();
        y = margin;
      }
    }

    void drawText(String text, double size, {bool bold = false, bool italic = false, int color = 0x000000}) {
      if (text.isEmpty) return;
      final font = PdfStandardFont(PdfFontFamily.helvetica, size);
      final charsPerLine = (usable / (size * 0.5)).floor().clamp(10, 200);
      final lineHeight = size * 1.45;
      for (final rawLine in text.split('\n')) {
        if (rawLine.isEmpty) {
          y += lineHeight;
          continue;
        }
        for (final line in _wrapLine(rawLine, charsPerLine)) {
          ensureSpace(lineHeight);
          page.graphics.drawString(
            line,
            font,
            brush: PdfSolidBrush(PdfColor(255, (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF)),
            bounds: Rect.fromLTWH(margin, y, usable, lineHeight + 2),
          );
          y += lineHeight;
        }
      }
    }

    String extractText(XmlElement el) => el.descendants
        .whereType<XmlText>()
        .map((t) => t.value)
        .join();

    void walk(XmlElement el) {
      for (final child in el.childElements) {
        switch (child.name.local.toLowerCase()) {
          case 'h1': ensureSpace(60); drawText(extractText(child), 22, bold: true); y += 12; break;
          case 'h2': ensureSpace(50); drawText(extractText(child), 18, bold: true); y += 10; break;
          case 'h3': ensureSpace(40); drawText(extractText(child), 15, bold: true); y += 8; break;
          case 'h4': case 'h5': case 'h6':
            drawText(extractText(child), 13, bold: true); break;
          case 'p': drawText(extractText(child), 11); y += 6; break;
          case 'br': y += 14; break;
          case 'b': case 'strong':
            final t = extractText(child);
            if (t.isNotEmpty) {
              ensureSpace(16);
              final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
              page.graphics.drawString(t, font, brush: PdfBrushes.black, bounds: Rect.fromLTWH(margin, y, usable, 18));
              y += 16;
            }
            break;
          case 'i': case 'em': drawText(extractText(child), 11); break;
          case 'li': ensureSpace(16); drawText('• ${extractText(child)}', 11); break;
          case 'ul': case 'ol': walk(child); y += 4; break;
          case 'table':
            final rows = child.childElements.where((e) => e.name.local.toLowerCase() == 'tr');
            for (final row in rows) {
              final cells = row.childElements
                  .where((e) => e.name.local.toLowerCase() == 'td' || e.name.local.toLowerCase() == 'th')
                  .map((c) => extractText(c))
                  .toList();
              if (cells.isEmpty) continue;
              ensureSpace(18);
              final cellW = usable / cells.length;
              for (var i = 0; i < cells.length; i++) {
                page.graphics.drawRectangle(
                  pen: PdfPens.black,
                  bounds: Rect.fromLTWH(margin + cellW * i, y, cellW, 18),
                );
                page.graphics.drawString(
                  cells[i].length > 30 ? cells[i].substring(0, 30) : cells[i],
                  PdfStandardFont(PdfFontFamily.helvetica, 9),
                  brush: PdfBrushes.black,
                  bounds: Rect.fromLTWH(margin + cellW * i + 2, y + 2, cellW - 4, 14),
                );
              }
              y += 18;
            }
            y += 6;
            break;
          case 'div': case 'body': case 'html': case 'head': case 'title':
          case 'style': case 'script':
            walk(child);
            break;
          default:
            final t = extractText(child);
            if (t.isNotEmpty) drawText(t, 11);
        }
      }
    }

    try {
      final root = XmlDocument.parse(html);
      final body = root.findAllElements('body');
      if (body.isNotEmpty) {
        walk(body.first);
      } else {
        walk(root.rootElement);
      }
    } catch (_) {
      // Not valid XML (plain HTML): strip tags crudely.
      final text = html
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</(p|div|h[1-6]|li|tr)>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
      drawText(text, 11);
    }

    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  // ════ CSV → PDF ═════════════════════════════════════════════════
  Uint8List csvToPdf(String csv, {String? title}) {
    final rows = _parseCsv(csv);
    final doc = PdfDocument();
    var page = doc.pages.add();
    const margin = 36.0;

    void drawGrid(List<List<String>> grid, {double fontPt = 8}) {
      final font = PdfStandardFont(PdfFontFamily.helvetica, fontPt);
      final nCols = grid.map((r) => r.length).fold(0, (a, b) => a > b ? a : b);
      if (nCols == 0) return;
      const pageWidth = 595.0;
      const pageHeight = 842.0;
      final colW = (pageWidth - margin * 2) / nCols;
      final rowH = fontPt * 2.1;
      var y = margin;
      if (title != null) {
        page.graphics.drawString(
          title,
          PdfStandardFont(PdfFontFamily.helvetica, 14),
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(margin, y, pageWidth - margin * 2, 20),
        );
        y += 28;
      }
      for (var r = 0; r < grid.length; r++) {
        if (y + rowH > pageHeight - margin) {
          page = doc.pages.add();
          y = margin;
        }
        final row = grid[r];
        for (var c = 0; c < nCols; c++) {
          final text = c < row.length ? row[c] : '';
          page.graphics.drawRectangle(
            pen: PdfPens.darkGray,
            bounds: Rect.fromLTWH(margin + colW * c, y, colW, rowH),
          );
          var t = text;
          final maxChars = (colW / (fontPt * 0.5)).floor();
          if (t.length > maxChars) t = t.substring(0, maxChars);
          page.graphics.drawString(
            t,
            font,
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(margin + colW * c + 3, y + 2, colW - 6, rowH - 4),
          );
        }
        y += rowH;
      }
    }

    if (rows.length > 90) {
      // Chunk long tables across pages for speed.
      for (var i = 0; i < rows.length; i += 90) {
        final chunk = rows.sublist(i, (i + 90).clamp(0, rows.length));
        drawGrid(chunk, fontPt: 7);
      }
    } else {
      drawGrid(rows);
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  List<List<String>> _parseCsv(String csv) {
    final rows = <List<String>>[];
    final row = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < csv.length; i++) {
      final ch = csv[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          row.add(buf.toString());
          buf.clear();
        } else if (ch == '\n' || ch == '\r') {
          if (ch == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
          row.add(buf.toString());
          buf.clear();
          rows.add(List.of(row));
          row.clear();
        } else {
          buf.write(ch);
        }
      }
    }
    if (buf.isNotEmpty || row.isNotEmpty) {
      row.add(buf.toString());
      rows.add(List.of(row));
    }
    return rows;
  }

  // ════ XLSX → PDF ════════════════════════════════════════════════
  Uint8List xlsxToPdf(Uint8List xlsxBytes) {
    final excel = Excel.decodeBytes(xlsxBytes);
    final doc = PdfDocument();
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      final maxRow = sheet.maxRows;
      final maxCols = sheet.maxColumns;
      if (maxRow <= 0 || maxCols <= 0) continue;

      const margin = 36.0;
      const pageWidth = 595.0;
      const pageHeight = 842.0;
      final colW = (pageWidth - margin * 2) / maxCols;
      final rowH = 18.0;

      var page = doc.pages.add();
      var y = margin + 30;

      for (var r = 0; r < maxRow; r++) {
        if (y + rowH > pageHeight - margin) {
          page = doc.pages.add();
          y = margin;
        }
        for (var c = 0; c < maxCols; c++) {
          final cell = sheet.rows[r][c];
          final text = cell == null ? '' : cellValueText(cell.value);
          page.graphics.drawRectangle(
            pen: PdfPens.darkGray,
            bounds: Rect.fromLTWH(margin + colW * c, y, colW, rowH),
          );
          final font = PdfStandardFont(PdfFontFamily.helvetica, 7);
          page.graphics.drawString(
            text.length > 26 ? text.substring(0, 26) : text,
            font,
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(margin + colW * c + 2, y + 2, colW - 4, rowH - 4),
          );
        }
        y += rowH;
      }
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  String cellValueText(CellValue? value) {
    if (value == null) return '';
    return switch (value) {
      TextCellValue v => v.value.text ?? '',
      IntCellValue v => v.value.toString(),
      DoubleCellValue v => v.value.toString(),
      DateCellValue v => '${v.year}-${v.month}-${v.day}',
      FormulaCellValue v => v.formula,
      _ => value.toString(),
    };
  }

  // ════ DOCX → PDF (text-based layout) ════════════════════════════
  Uint8List docxToPdf(Uint8List docxBytes) {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final entry = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => archive.files.firstWhere(
        (f) => f.name.endsWith('document.xml'),
        orElse: () => ArchiveFile('', 0, const []),
      ),
    );
    if (entry.content.isEmpty) return txtToPdf('[No text content found]');
    final xml = XmlDocument.parse(utf8.decode(entry.content));
    final doc = PdfDocument();
    const margin = 48.0;
    const usable = 595.0 - margin * 2;
    const pageHeight = 842.0;
    var page = doc.pages.add();
    var y = margin;

    void ensureSpace(double h) {
      if (y + h > pageHeight - margin) {
        page = doc.pages.add();
        y = margin;
      }
    }

    for (final p in xml.findAllElements('w:p')) {
      final style = p.getElement('w:pPr')?.getElement('w:pStyle')?.getAttribute('w:val') ?? '';
      var size = 11.0;
      var lineHeight = 15.0;
      if (style.toLowerCase().contains('title')) size = 24;
      else if (style.toLowerCase().contains('heading1') || style.toLowerCase().contains('heading 1')) size = 18;
      else if (style.toLowerCase().contains('heading2') || style.toLowerCase().contains('heading 2')) size = 15;
      else if (style.toLowerCase().contains('heading3') || style.toLowerCase().contains('heading 3')) size = 13;
      lineHeight = size * 1.4;

      final runs = p.findAllElements('w:r');
      if (runs.isEmpty) {
        y += lineHeight * 0.6;
        continue;
      }
      ensureSpace(lineHeight);
      final font = PdfStandardFont(PdfFontFamily.helvetica, size);
      final charsPerLine = (usable / (size * 0.5)).floor().clamp(10, 200);
      var lineText = '';
      for (final run in runs) {
        final textEl = run.getElement('w:t');
        if (textEl != null) lineText += textEl.innerText;
        final tab = run.getElement('w:tab');
        if (tab != null) lineText += '    ';
        final br = run.getElement('w:br');
        if (br != null) {
          page.graphics.drawString(lineText, font, brush: PdfBrushes.black,
              bounds: Rect.fromLTWH(margin, y, usable, lineHeight + 2));
          y += lineHeight;
          lineText = '';
        }
      }
      for (final line in _wrapLine(lineText, charsPerLine)) {
        ensureSpace(lineHeight);
        page.graphics.drawString(line, font, brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(margin, y, usable, lineHeight + 2));
        y += lineHeight;
      }
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  // ════ PPTX → PDF ════════════════════════════════════════════════
  Uint8List pptxToPdf(Uint8List pptxBytes) {
    final archive = ZipDecoder().decodeBytes(pptxBytes);
    final slideEntries = archive.files
        .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) => _slideNum(a.name).compareTo(_slideNum(b.name)));
    final doc = PdfDocument();
    const slideW = 960.0;   // points (10in)
    const slideH = 540.0;
    const emuPerPoint = 12700.0;

    for (final entry in slideEntries) {
      final xml = XmlDocument.parse(utf8.decode(entry.content));
      final page = doc.pages.add();
      doc.pageSettings.size = const Size(slideW, slideH);
      doc.pageSettings.margins.all = 0;
      for (final sp in xml.findAllElements('a:p')) {
        final texts = sp.findAllElements('a:t').map((t) => t.innerText).join();
        if (texts.trim().isEmpty) continue;
        // Walk up to the shape container for position/size.
        var parent = sp.parent;
        double x = 60, y = 60, w = slideW - 120, h = 40;
        while (parent != null) {
          final off = parent.getElement('a:off');
          final ext = parent.getElement('a:ext');
          if (off != null && ext != null) {
            x = (int.tryParse(off.getAttribute('x') ?? '') ?? 0) / emuPerPoint;
            y = (int.tryParse(off.getAttribute('y') ?? '') ?? 0) / emuPerPoint;
            w = (int.tryParse(ext.getAttribute('cx') ?? '') ?? 0) / emuPerPoint;
            h = (int.tryParse(ext.getAttribute('cy') ?? '') ?? 0) / emuPerPoint;
            break;
          }
          parent = parent.parent;
        }
        var fontSize = 16.0;
        final sz = sp.parent?.getElement('a:rPr')?.getAttribute('sz');
        if (sz != null) fontSize = (int.tryParse(sz) ?? 1600) / 100;
        final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize.clamp(6, 72));
        page.graphics.drawString(
          texts,
          font,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(x, y, w.clamp(10, slideW - x), h.clamp(10, slideH - y)),
        );
      }
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  int _slideNum(String name) {
    final m = RegExp(r'slide(\d+)\.xml').firstMatch(name);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  // ════ PDF → TXT (uses syncfusion text extraction) ═══════════════
  String pdfToText(Uint8List pdfBytes, {String? password}) {
    final doc = PdfDocument(inputBytes: pdfBytes, password: password);
    try {
      return PdfTextExtractor(doc).extractText();
    } finally {
      doc.dispose();
    }
  }

  // ════ PDF → DOCX ════════════════════════════════════════════════
  Uint8List pdfToDocx(Uint8List pdfBytes, {String? password}) {
    final text = pdfToText(pdfBytes, password: password);
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.replaceAll('\n', ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final body = StringBuffer();
    for (final p in paragraphs) {
      body.write('<w:p><w:r><w:t xml:space="preserve">${_xmlEscape(p)}</w:t></w:r></w:p>');
    }
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>${body.toString()}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:body>
</w:document>''';
    return _zipDocx(documentXml);
  }

  Uint8List _zipDocx(String documentXml) {
    final encoder = ZipEncoder();
    final archive = Archive();
    archive.addFile(ArchiveFile('word/document.xml', utf8.encode(documentXml).length, utf8.encode(documentXml)));
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>'''),
    ));
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''),
    ));
    final data = encoder.encode(archive);
    return Uint8List.fromList(data ?? const []);
  }

  // ════ PDF → XLSX ════════════════════════════════════════════════
  Uint8List pdfToXlsx(Uint8List pdfBytes, {String? password}) {
    final text = pdfToText(pdfBytes, password: password);
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final cells = line.split(RegExp(r'\s{2,}')).where((c) => c.isNotEmpty).map((c) => c.trim()).toList();
      sheet.appendRow([for (final c in cells) TextCellValue(c)]);
    }
    return Uint8List.fromList(excel.encode() ?? const []);
  }

  // ════ XLSX → CSV ════════════════════════════════════════════════
  String xlsxToCsv(Uint8List xlsxBytes, {String? sheetName}) {
    final excel = Excel.decodeBytes(xlsxBytes);
    final name = sheetName ?? excel.tables.keys.first;
    final sheet = excel.tables[name];
    if (sheet == null) return '';
    final buf = StringBuffer();
    for (var r = 0; r < sheet.maxRows; r++) {
      final cells = <String>[];
      for (var c = 0; c < sheet.maxColumns; c++) {
        final cell = sheet.rows[r][c];
        cells.add(_csvEscape(cell == null ? '' : cellValueText(cell.value)));
      }
      buf.writeln(cells.join(','));
    }
    return buf.toString();
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // ════ CSV → XLSX ════════════════════════════════════════════════
  Uint8List csvToXlsx(String csv) {
    final rows = _parseCsv(csv);
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (final row in rows) {
      sheet.appendRow([for (final c in row) TextCellValue(c)]);
    }
    return Uint8List.fromList(excel.encode() ?? const []);
  }

  // ════ PPTX build (for PDF → PPTX) ═══════════════════════════════
  Uint8List buildPptxFromImages(List<Uint8List> slidePngs) {
    final encoder = ZipEncoder();
    final archive = Archive();
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
${[for (var i = 1; i <= slidePngs.length; i++) '<Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'].join('\n')}
</Types>'''),
    ));
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>'''),
    ));
    final slideIdList = [for (var i = 1; i <= slidePngs.length; i++) '<p:sldId id="256$i" r:id="rId$i"/>'].join('');
    archive.addFile(ArchiveFile(
      'ppt/presentation.xml',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId100"/></p:sldMasterIdLst>
<p:sldIdLst>$slideIdList</p:sldIdLst>
<p:sldSz cx="12192000" cy="6858000"/>
</p:presentation>'''),
    ));
    archive.addFile(ArchiveFile(
      'ppt/_rels/presentation.xml.rels',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId100" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
${[for (var i = 1; i <= slidePngs.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>'].join('\n')}
</Relationships>'''),
    ));
    archive.addFile(ArchiveFile(
      'ppt/slideMasters/slideMaster1.xml',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree><p:nvGrpSpPr/><p:grpSpPr/></p:spTree></p:cSld>
<p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/>
<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
</p:sldMaster>'''),
    ));
    archive.addFile(ArchiveFile(
      'ppt/slideMasters/_rels/slideMaster1.xml.rels',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>'''),
    ));
    archive.addFile(ArchiveFile(
      'ppt/slideLayouts/slideLayout1.xml',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank">
<p:cSld name="Blank"><p:spTree><p:nvGrpSpPr/><p:grpSpPr/></p:spTree></p:cSld>
<p:clrMapOvr><a:overrideClrMapping accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/></p:clrMapOvr>
</p:sldLayout>'''),
    ));
    archive.addFile(ArchiveFile(
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>'''),
    ));
    for (var i = 0; i < slidePngs.length; i++) {
      final n = i + 1;
      archive.addFile(ArchiveFile('ppt/media/slideImage$n.png', slidePngs[i].length, slidePngs[i]));
      archive.addFile(ArchiveFile(
        'ppt/slides/slide$n.xml',
        0,
        utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree>
<p:nvGrpSpPr/><p:grpSpPr/>
<p:pic><p:nvPicPr><p:cNvPr id="4$n" name="Slide $n"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
<p:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
<p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="6858000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
</p:pic>
</p:spTree></p:cSld>
</p:sld>'''),
      ));
      archive.addFile(ArchiveFile(
        'ppt/slides/_rels/slide$n.xml.rels',
        0,
        utf8.encode('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/slideImage$n.png"/>
</Relationships>'''),
      ));
    }
    final data = encoder.encode(archive);
    return Uint8List.fromList(data ?? const []);
  }

  String _xmlEscape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
