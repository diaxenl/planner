# device_calendar serializes its models with Gson by field name, so their
# names must survive R8 shrinking and obfuscation.
-keep class com.builttoroam.devicecalendar.** { *; }
