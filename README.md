# DocDoctor

A privacy-first, fully offline document toolkit for Android. Scan, convert,
edit, sign, redact, and organise PDFs, images, and office files — every
operation runs locally on your device. No accounts, no cloud, no network
access (the `INTERNET` permission is explicitly stripped from the manifest).

> Built with Flutter. Designed with an Apple-inspired, grouped-card UI.

---

## All features

### PDF — Organise
| # | Tool | What it does |
|---|------|---------------|
| 1 | **Merge PDF** | Combine multiple PDFs into one file |
| 2 | **Split PDF** | Split into single pages or custom ranges (e.g. `1-3,5,7-9`) |
| 3 | **Remove Pages** | Delete selected pages from a PDF |
| 4 | **Extract Pages** | Save selected pages as a new PDF |
| 5 | **Organize Pages** | Reorder pages by drag & drop |
| 6 | **Insert Pages** | Insert a PDF into another at any position |
| 7 | **Scan to PDF** | Capture documents with the camera (edge/perspective correction) |

### PDF — Optimize & Convert
| # | Tool | What it does |
|---|------|---------------|
| 8 | **Compress PDF** | Reduce file size (lossless or lossy, DPI/quality controls) |
| 9 | **Repair PDF** | Fix corrupted or damaged PDFs |
| 10 | **PDF OCR** | Make scanned PDFs searchable (on-device, ML Kit) |
| 11 | **Image → PDF** | Convert images into a PDF |
| 12 | **Word → PDF** | Convert DOCX to PDF |
| 13 | **Excel → PDF** | Convert XLSX to PDF |
| 14 | **PowerPoint → PDF** | Convert PPTX to PDF |
| 15 | **TXT → PDF** | Convert plain text to PDF |
| 16 | **HTML → PDF** | Convert HTML files to PDF |
| 17 | **CSV → PDF** | Convert CSV tables to PDF |
| 18 | **PDF → Image** | Render pages to JPG / PNG / WebP |
| 19 | **PDF → Word** | Extract content into a DOCX |
| 20 | **PDF → Excel** | Extract tabular data into XLSX |
| 21 | **PDF → PowerPoint** | Pages into a PPTX |
| 22 | **PDF → Text** | Extract all text as TXT |
| 23 | **PDF → PDF/A** | Convert to archival PDF/A-1b |

### PDF — Edit
| # | Tool | What it does |
|---|------|---------------|
| 24 | **Annotate** | Add text, shapes & freehand marks |
| 25 | **Watermark** | Stamp text/image across pages (tiled, angled, opacity) |
| 26 | **Page Numbers** | Add page numbering (format, alignment, skip-first) |
| 27 | **Crop PDF** | Crop margins or page regions |
| 28 | **Flatten PDF** | Bake annotations & forms into pages |
| 29 | **Edit Metadata** | Title, author, subject, keywords, creator |
| 30 | **Resize Pages** | Change page size (A4 / A5 / A3 / Letter / Legal / B5) |
| 31 | **Grayscale** | Convert PDF to black & white |
| 32 | **Stamp** | Add approved / confidential stamps |

### PDF — Security & Forms
| # | Tool | What it does |
|---|------|---------------|
| 33 | **PDF Forms** | Detect, fill & create form fields |
| 34 | **Password Protect** | Encrypt PDF with a password (AES-256) |
| 35 | **Unlock PDF** | Remove password protection |
| 36 | **Sign PDF** | Draw or place your signature |
| 37 | **Redact PDF** | Black out sensitive content |
| 38 | **Compare PDFs** | Diff two PDFs visually |

### Image
| # | Tool | What it does |
|---|------|---------------|
| 39 | **Compress** | Shrink image file size (quality / max width) |
| 40 | **Resize** | Change pixel dimensions |
| 41 | **Crop** | Cut out a region |
| 42 | **Rotate / Flip** | Rotate, mirror & transpose |
| 43 | **Convert Format** | JPG / PNG / WebP / BMP |
| 44 | **Merge / Collage** | Combine images side by side or in a grid |
| 45 | **Adjust** | Brightness, contrast, saturation, sharpen |
| 46 | **Watermark** | Stamp text or logo (position, scale, opacity, tiled) |
| 47 | **Border / Frame** | Add colored borders & rounded corners |
| 48 | **Photo Layout** | Passport & ID photo sheets |
| 49 | **Image OCR** | Extract text from images |

### Office & Files
| # | Tool | What it does |
|---|------|---------------|
| 50 | **Excel → CSV** | Export XLSX sheets as CSV |
| 51 | **CSV → Excel** | Import CSV into XLSX |
| 52 | **Excel → Image** | Render sheets to PNG |
| 53 | **Zip Files** | Compress any files into a ZIP |
| 54 | **Unzip** | Extract ZIP archives |

---

## App features

### Workflow
- **Batch mode** — run a single tool across many files in one pass
  (supported tools are marked batch-capable).
- **Tool search** — find any tool by name from the Home screen.
- **Before/After preview** — every result shows a comparison and an output-file
  list with sizes and saved status.
- **Open with system apps** — converted/saved files launch the Android
  "Open with" chooser.
- **Open in Files app** — jump to the native Android file manager.
- **Share / Open with** — share-to or open-with from any app (PDF, image,
  text, office, archive intent filters).



## Features

### Document tools
- **PDF**: scan (camera + edge/perspective correction), merge, split, compress,
  annotate, redact, compare, fill forms, and sign.
- **Images**: convert, compress, crop, and enhance (on-device OCR via ML Kit).
- **Office**: convert between PDF ⇄ DOC/XLS/PPT and related formats.
- **Batch mode**: run a single tool across many files in one pass.

### Files & organisation
- Built-in file manager with tabs for PDF, image, office, archive, text,
  processed, and favourites.
- **Recents** and **Favourites** tracked locally for quick access.
- All output is written to a dedicated `docdoctor` folder (see *Storage* below).

### Experience
- Animated launch splash with the DocDoctor logo.
- First-run onboarding emphasising on-device privacy: *"Everything local — all
  processes are done in your phone."*
- Light / dark / system themes with an iOS-style segmented control.
- Share-to / "Open with" DocDoctor from any app (PDF, image, text, office,
  archive supported).

---

## Privacy

DocDoctor is offline by design.

| Concern        | Status                                                     |
|----------------|------------------------------------------------------------|
| Network access | Removed — `INTERNET` permission is `tools:node="remove"`d  |
| Accounts       | None — no sign-in of any kind                              |
| Analytics      | None — no telemetry or crash reporting                     |
| File storage   | On-device only, inside a folder you choose                  |

---

## Getting started

### Prerequisites
- Flutter (Dart SDK `^3.10.1`)
- Android SDK / Android Studio (for the Android build)
- A physical device is recommended for the camera/scan features

### Install & run
```bash
flutter pub get
flutter run
```

### Build a release APK
```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

For smaller, architecture-specific builds:
```bash
flutter build apk --release --split-per-abi
# or target a single ABI:
flutter build apk --release --target-platform android-arm64
```

### Install on a connected device
```bash
flutter install
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Storage

All generated files are saved to a single, predictable location:

```
<your-chosen-folder>/docdoctor/
```

- On first launch the default is the app's external storage directory
  (`/storage/emulated/0/Android/data/<package>/files/docdoctor`).
- In **Settings → Storage** you can pick any folder; DocDoctor always creates
  and uses a `docdoctor` subfolder inside your choice, so outputs never get
  mixed up with your other files.
- A "Reset to default folder" action restores the original location.
- The chosen path is persisted in `settings.json`.

---

## App icon

The launcher icon is generated from `assets/logo.png` with
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons).
The config lives in `pubspec.yaml` under `flutter_launcher_icons:`.

To regenerate after changing the logo:
```bash
dart run flutter_launcher_icons
```

---

## Project structure

```
lib/
├── main.dart                     # Entry point
├── app.dart                      # MaterialApp + launch gate (splash → onboarding → shell)
├── app_shell.dart                # Bottom-nav shell: Home / Files / Batch / Settings
├── core/
│   ├── models/tool.dart          # Tool definitions & categories
│   ├── services/
│   │   ├── settings_service.dart # Output dir, theme mode, onboarding flag
│   │   ├── picker_service.dart   # File & directory pickers
│   │   ├── recent_service.dart   # Recents & favourites (JSON-backed)
│   │   ├── permission_service.dart
│   │   └── share_intent_service.dart
│   ├── theme/app_theme.dart      # Apple-style light/dark themes
│   ├── utils/file_utils.dart     # Filenames, sizes, formatting
│   └── widgets/app_logo.dart     # Reusable logo (with graceful fallback)
└── features/
    ├── onboarding/
    │   ├── splash_screen.dart     # Animated launch splash
    │   └── onboarding_screen.dart # First-run privacy screen
    ├── home/home_screen.dart     # Tool grid, recents, favourites, share sheet
    ├── files/                    # File manager + previews
    ├── batch/batch_screen.dart   # Multi-file workflow
    ├── settings/settings_screen.dart
    ├── tools/                     # Generic tool workflow (pick → options → run → done)
    ├── pdf/                       # PDF tools, options, and interactive editors
    ├── image/                     # Image tools & options
    └── office/                    # Office tools & options
```

### The tool workflow
Every tool follows the same flow (`lib/features/tools/tool_workflow_page.dart`):

1. **Pick** input file(s) (or start the camera for scans).
2. **Options** — tool-specific settings panel.
3. **Process** — runs on-device with live progress.
4. **Done** — a clean result screen with a Before/After preview, an output-file
   list, and **Save to docdoctor** / **Share** actions.

---

## Configuration

DocDoctor stores its configuration in a single JSON file inside the app's
documents directory (`settings.json`):

| Key         | Purpose                                                |
|-------------|--------------------------------------------------------|
| `outputDir` | Chosen output folder (the `docdoctor` parent)          |
| `themeMode` | `system` \| `light` \| `dark`                          |
| `onboarded` | Whether the first-run onboarding has been dismissed    |

---

## Tech stack

- **Flutter** + **Riverpod 3** (state management)
- `pdf`, `syncfusion_flutter_pdf`, `pdfx`, `printing` — PDF rendering & authoring
- `camera` + `google_mlkit_text_recognition` — scanning & on-device OCR
- `image`, `flutter_image_compress`, `image_cropper` — image processing
- `excel`, `xml` — office format handling
- `file_picker`, `path_provider`, `permission_handler`, `share_plus`
- `signature` — on-screen signing
- `archive` — ZIP handling

---

## License

Private project. Not published to pub.dev (`publish_to: 'none'`).
