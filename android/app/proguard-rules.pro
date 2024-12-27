# Example proguard-rules.pro content
-keep class * { *; }
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }