#!/usr/bin/env python3
"""Adds the permissions Resonant needs to the Android and iOS projects that `flutter create` generated.
Safe to run more than once: anything already present is left alone."""
import os
import sys

ANDROID_PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.VIBRATE",
    "android.permission.RECORD_AUDIO",
    "android.permission.BLUETOOTH",
    "android.permission.BLUETOOTH_CONNECT",
]
# Android 11+ hides other apps unless you ask: needed to find the speech engine and the voice recognizer.
ANDROID_QUERIES = """    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
    </queries>
"""
IOS_KEYS = {
    "NSMicrophoneUsageDescription": "Resonant listens when you hold a finger down to ask a question about a picture.",
    "NSSpeechRecognitionUsageDescription": "Resonant turns your spoken question into text so it can answer it.",
    "NSCameraUsageDescription": "Resonant can photograph a diagram or page so you can explore it by touch.",
    "NSPhotoLibraryUsageDescription": "Resonant opens pictures you choose so you can explore them by touch.",
}


def patch_android(root):
    path = os.path.join(root, "android/app/src/main/AndroidManifest.xml")
    if not os.path.exists(path):
        print("skip android: no manifest at", path)
        return
    text = open(path, encoding="utf-8").read()
    marker = "<application"
    if marker not in text:
        sys.exit("AndroidManifest.xml has no <application> element; add the permissions by hand")
    add = ""
    for perm in ANDROID_PERMISSIONS:
        if perm not in text:
            add += f'    <uses-permission android:name="{perm}"/>\n'
    if "<queries>" not in text:
        add += ANDROID_QUERIES
    if add:
        i = text.index(marker)
        line_start = text.rfind("\n", 0, i) + 1
        text = text[:line_start] + add + text[line_start:]
        open(path, "w", encoding="utf-8").write(text)
        print("patched", path)
    else:
        print("android already patched")


def patch_ios(root):
    path = os.path.join(root, "ios/Runner/Info.plist")
    if not os.path.exists(path):
        print("skip ios: no Info.plist at", path)
        return
    text = open(path, encoding="utf-8").read()
    add = ""
    for key, msg in IOS_KEYS.items():
        if f"<key>{key}</key>" not in text:
            add += f"\t<key>{key}</key>\n\t<string>{msg}</string>\n"
    if add:
        i = text.rindex("</dict>")
        text = text[:i] + add + text[i:]
        open(path, "w", encoding="utf-8").write(text)
        print("patched", path)
    else:
        print("ios already patched")


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    patch_android(root)
    patch_ios(root)
