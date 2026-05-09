# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress missing Play Core classes (Flutter engine references them
# but the library is not needed for apps without deferred components)
-dontwarn com.google.android.play.core.**
