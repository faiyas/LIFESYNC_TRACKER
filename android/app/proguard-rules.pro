# Disable R8 optimizations to prevent native Flutter plugin crashes on startup
-dontoptimize

# Flutter Engine & Native Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit Text Recognition Rules
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# SQLite & Sqflite Rules
-keep class com.tekartik.sqflite.** { *; }
-keep class org.sqlite.** { *; }

# Local Notifications Rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Sharing & Image Intent Rules
-keep class com.intentutils.** { *; }
-keep class com.example.receive_sharing_intent.** { *; }

# Gson & JSON Models
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
