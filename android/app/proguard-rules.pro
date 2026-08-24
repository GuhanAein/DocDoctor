# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# Google ML Kit (on-device OCR)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.android.gms.vision.**
-keep class com.google.mlkit.vision.text.** { *; }

# CameraX (camera plugin)
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# PDFium (pdfx)
-keep class com.shockwave.pdfium.** { *; }
-keep class com.radu.pdf_renderer.** { *; }
-dontwarn com.shockwave.pdfium.**

# Syncfusion PDF (pure Dart, no rules needed) / Excel (pure Dart)
# Share_plus / file_picker providers
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.core.app.CoreComponentFactory { *; }
