import 'package:flutter/material.dart';

enum ToolCategory {
  pdf('PDF', Icons.picture_as_pdf_outlined, Color(0xFFD32F2F)),
  image('Image', Icons.image_outlined, Color(0xFF388E3C)),
  office('Office', Icons.table_chart_outlined, Color(0xFF6A1B9A)),
  files('Files', Icons.folder_outlined, Color(0xFFF57C00));

  const ToolCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

enum ToolInputType { pdf, image, any, txt, csv, html, docx, xlsx, pptx, zip, none }

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.phase,
    this.inputType = ToolInputType.pdf,
    this.allowsMultiple = false,
    this.allowsBatch = false,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ToolCategory category;
  final int phase;
  final ToolInputType inputType;
  final bool allowsMultiple;
  final bool allowsBatch;
}

const List<ToolDefinition> allTools = [
  // ── PDF: organize ────────────────────────────────────────────────
  ToolDefinition(
    id: 'pdf_merge', name: 'Merge PDF', description: 'Combine multiple PDFs into one file',
    icon: Icons.merge_type, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.pdf, allowsMultiple: true, allowsBatch: false,
  ),
  ToolDefinition(
    id: 'pdf_split', name: 'Split PDF', description: 'Split into single pages or custom ranges',
    icon: Icons.call_split, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_remove', name: 'Remove Pages', description: 'Delete selected pages from a PDF',
    icon: Icons.delete_sweep_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_extract', name: 'Extract Pages', description: 'Save selected pages as a new PDF',
    icon: Icons.content_cut, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_reorder', name: 'Organize Pages', description: 'Reorder pages by drag & drop',
    icon: Icons.swap_vert, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_insert', name: 'Insert Pages', description: 'Insert a PDF into another at any position',
    icon: Icons.playlist_add, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.pdf, allowsMultiple: true,
  ),
  ToolDefinition(
    id: 'pdf_scan', name: 'Scan to PDF', description: 'Capture documents with the camera',
    icon: Icons.document_scanner_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.none, allowsMultiple: true,
  ),

  // ── PDF: optimize / convert ──────────────────────────────────────
  ToolDefinition(
    id: 'pdf_compress', name: 'Compress PDF', description: 'Reduce PDF file size',
    icon: Icons.compress, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_repair', name: 'Repair PDF', description: 'Fix corrupted or damaged PDFs',
    icon: Icons.build_circle_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_ocr', name: 'PDF OCR', description: 'Make scanned PDFs searchable (on-device)',
    icon: Icons.text_snippet_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_from_image', name: 'Image → PDF', description: 'Convert images into a PDF',
    icon: Icons.image_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_from_word', name: 'Word → PDF', description: 'Convert DOCX to PDF',
    icon: Icons.description_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.docx, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_from_excel', name: 'Excel → PDF', description: 'Convert XLSX to PDF',
    icon: Icons.table_view_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.xlsx, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_from_ppt', name: 'PowerPoint → PDF', description: 'Convert PPTX to PDF',
    icon: Icons.slideshow_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.pptx, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_from_txt', name: 'TXT → PDF', description: 'Convert plain text to PDF',
    icon: Icons.notes_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.txt, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_from_html', name: 'HTML → PDF', description: 'Convert HTML files to PDF',
    icon: Icons.code_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.html, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_from_csv', name: 'CSV → PDF', description: 'Convert CSV tables to PDF',
    icon: Icons.grid_on_outlined, category: ToolCategory.pdf, phase: 2,
    inputType: ToolInputType.csv, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'pdf_to_image', name: 'PDF → Image', description: 'Render pages to JPG/PNG',
    icon: Icons.burst_mode_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_to_word', name: 'PDF → Word', description: 'Extract content into a DOCX',
    icon: Icons.description_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_to_excel', name: 'PDF → Excel', description: 'Extract tabular data into XLSX',
    icon: Icons.table_view_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_to_ppt', name: 'PDF → PowerPoint', description: 'Pages into a PPTX',
    icon: Icons.slideshow_outlined, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_to_text', name: 'PDF → Text', description: 'Extract all text as TXT',
    icon: Icons.text_fields, category: ToolCategory.pdf, phase: 2,
  ),
  ToolDefinition(
    id: 'pdf_to_pdfa', name: 'PDF → PDF/A', description: 'Convert to archival PDF/A-1b',
    icon: Icons.archive_outlined, category: ToolCategory.pdf, phase: 2,
  ),

  // ── PDF: edit ────────────────────────────────────────────────────
  ToolDefinition(
    id: 'pdf_annotate', name: 'Annotate', description: 'Add text, shapes & freehand marks',
    icon: Icons.draw_outlined, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_watermark', name: 'Watermark', description: 'Stamp text/image across pages',
    icon: Icons.branding_watermark_outlined, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_page_numbers', name: 'Page Numbers', description: 'Add page numbering',
    icon: Icons.format_list_numbered, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_crop', name: 'Crop PDF', description: 'Crop margins or page regions',
    icon: Icons.crop, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_flatten', name: 'Flatten PDF', description: 'Bake annotations & forms into pages',
    icon: Icons.layers_outlined, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_metadata', name: 'Edit Metadata', description: 'Title, author, keywords…',
    icon: Icons.info_outline, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_resize', name: 'Resize Pages', description: 'Change page size (A4, Letter…)',
    icon: Icons.aspect_ratio, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_grayscale', name: 'Grayscale', description: 'Convert PDF to black & white',
    icon: Icons.tonality, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_stamp', name: 'Stamp', description: 'Add approved/confidential stamps',
    icon: Icons.approval_outlined, category: ToolCategory.pdf, phase: 3,
  ),

  // ── PDF: security ────────────────────────────────────────────────
  ToolDefinition(
    id: 'pdf_forms', name: 'PDF Forms', description: 'Detect, fill & create form fields',
    icon: Icons.check_box_outlined, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_password', name: 'Password Protect', description: 'Encrypt PDF with a password',
    icon: Icons.lock_outline, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_unlock', name: 'Unlock PDF', description: 'Remove password protection',
    icon: Icons.lock_open_outlined, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_sign', name: 'Sign PDF', description: 'Draw or place your signature',
    icon: Icons.gesture, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_redact', name: 'Redact PDF', description: 'Black out sensitive content',
    icon: Icons.hide_image_outlined, category: ToolCategory.pdf, phase: 3,
  ),
  ToolDefinition(
    id: 'pdf_compare', name: 'Compare PDFs', description: 'Diff two PDFs visually',
    icon: Icons.compare_outlined, category: ToolCategory.pdf, phase: 3,
    allowsMultiple: true,
  ),

  // ── Image tools ──────────────────────────────────────────────────
  ToolDefinition(
    id: 'img_compress', name: 'Compress', description: 'Shrink image file size',
    icon: Icons.compress, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'img_resize', name: 'Resize', description: 'Change pixel dimensions',
    icon: Icons.photo_size_select_large_outlined, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'img_crop', name: 'Crop', description: 'Cut out a region',
    icon: Icons.crop, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image,
  ),
  ToolDefinition(
    id: 'img_rotate', name: 'Rotate / Flip', description: 'Rotate, mirror & transpose',
    icon: Icons.rotate_90_degrees_ccw, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'img_convert', name: 'Convert Format', description: 'JPG, PNG, WEBP, BMP…',
    icon: Icons.swap_horiz, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'img_collage', name: 'Merge / Collage', description: 'Combine images side by side or grid',
    icon: Icons.dashboard_outlined, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true,
  ),
  ToolDefinition(
    id: 'img_adjust', name: 'Adjust', description: 'Brightness, contrast, saturation, sharpen',
    icon: Icons.tune, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image,
  ),
  ToolDefinition(
    id: 'img_watermark', name: 'Watermark', description: 'Stamp text or logo',
    icon: Icons.branding_watermark_outlined, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'img_border', name: 'Border / Frame', description: 'Add colored borders & rounded corners',
    icon: Icons.crop_free, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'img_photo_layout', name: 'Photo Layout', description: 'Passport & ID photo sheets',
    icon: Icons.perm_contact_cal_outlined, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image,
  ),
  ToolDefinition(
    id: 'img_ocr', name: 'Image OCR', description: 'Extract text from images',
    icon: Icons.text_snippet_outlined, category: ToolCategory.image, phase: 4,
    inputType: ToolInputType.image, allowsMultiple: true,
  ),

  // ── Office / Files tools ─────────────────────────────────────────
  ToolDefinition(
    id: 'ofc_excel_to_csv', name: 'Excel → CSV', description: 'Export XLSX sheets as CSV',
    icon: Icons.table_view_outlined, category: ToolCategory.office, phase: 5,
    inputType: ToolInputType.xlsx, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'ofc_csv_to_excel', name: 'CSV → Excel', description: 'Import CSV into XLSX',
    icon: Icons.grid_on_outlined, category: ToolCategory.office, phase: 5,
    inputType: ToolInputType.csv, allowsMultiple: true, allowsBatch: true,
  ),
  ToolDefinition(
    id: 'ofc_excel_to_image', name: 'Excel → Image', description: 'Render sheets to PNG',
    icon: Icons.image_outlined, category: ToolCategory.office, phase: 5,
    inputType: ToolInputType.xlsx,
  ),
  ToolDefinition(
    id: 'ofc_zip', name: 'Zip Files', description: 'Compress any files into a ZIP',
    icon: Icons.inventory_2_outlined, category: ToolCategory.office, phase: 5,
    inputType: ToolInputType.any, allowsMultiple: true,
  ),
  ToolDefinition(
    id: 'ofc_unzip', name: 'Unzip', description: 'Extract ZIP archives',
    icon: Icons.folder_zip_outlined, category: ToolCategory.office, phase: 5,
    inputType: ToolInputType.zip,
  ),
];

ToolDefinition? findTool(String id) {
  for (final t in allTools) {
    if (t.id == id) return t;
  }
  return null;
}

List<ToolDefinition> toolsForCategory(ToolCategory category) =>
    allTools.where((t) => t.category == category).toList();

List<ToolDefinition> searchTools(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return allTools;
  return allTools.where((t) =>
      t.name.toLowerCase().contains(q) ||
      t.description.toLowerCase().contains(q) ||
      t.category.label.toLowerCase().contains(q)).toList();
}

ToolDefinition? suggestToolForFile(String fileName) {
  final ext = fileName.toLowerCase();
  if (ext.endsWith('.pdf')) return findTool('pdf_merge');
  if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') ||
      ext.endsWith('.webp') || ext.endsWith('.bmp') || ext.endsWith('.gif') ||
      ext.endsWith('.heic')) {
    return findTool('img_compress');
  }
  if (ext.endsWith('.xlsx')) return findTool('ofc_excel_to_csv');
  if (ext.endsWith('.csv')) return findTool('ofc_csv_to_excel');
  if (ext.endsWith('.zip')) return findTool('ofc_unzip');
  return null;
}
