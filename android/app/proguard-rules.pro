# ============================================================
# Magma Blitz — ProGuard / R8 rules
# ============================================================
# Keeps Flutter, Firebase, AppsFlyer, and the WebView plugin
# intact; strips verbose logging from release binaries.

-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (deferred components)
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AppsFlyer
-keep class com.appsflyer.** { *; }
-dontwarn com.appsflyer.**

# WebView
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Strip Android logging — keep warnings & errors.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
