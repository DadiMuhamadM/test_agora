# ==============================================================================
# PROGUARD / R8 RULES UNTUK AGORA (CHAT & RTC) FLUTTER
# ==============================================================================

# 1. Agora RTC Engine (Voice & Video Call)
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# 2. Agora Chat SDK (Hyphenate Core)
-keep class com.hyphenate.** { *; }
-dontwarn com.hyphenate.**

# 3. Native JNI Methods
-keepclassmembers class * {
    native <methods>;
}

# 4. Pertahankan Anotasi & Refleksi yang Dibutuhkan SDK
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 5. Mencegah R8 Gagal Akibat Warning Dependency Opsional
-dontwarn **

