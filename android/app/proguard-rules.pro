-keepattributes Signature
-keepattributes *Annotation*

# Keep Gson types and generic info
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken

# Keep flutter_local_notifications models/receivers
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep timezone classes used by flutter_local_notifications
-keep class org.apache.commons.lang3.time.DateUtils { *; }

# Keep Flutter generated registrant
-keep class io.flutter.plugins.** { *; }

