# Flutter default ProGuard rules.
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.plugin.common.PluginRegistry { *; }
-keep class io.flutter.embedding.android.* { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-dontwarn com.google.android.play.core.**
