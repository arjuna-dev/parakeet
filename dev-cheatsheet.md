Cheatsheet

---

---

Deploy all funcitons in codebase:

```bash
firebase deploy --only functions
```

---

Deploy specific funcitons in codebase:

```bash
firebase deploy --only functions:addMessage,functions:makeUppercase
```

---

Delete a specified function:

```bash
firebase functions:delete myFunction
```

```bash
firebase functions:delete myFunction --region us-east-1
```

Deploy locally for testing
```
functions-framework --target second_API_calls --debug
```

Create Android installer file
```
flutter build apk --release
```

Run on selected device (build the .apk file first for Android):
```
flutter run --release
```

Try cleaning if something go wrong:
```
flutter clean
```

How to get a DEBUG SHA-1 key to add to GCP or firestore:
(or replace ~/.android/debug.keystore with your path)
```
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

How to get a RELEASE SHA-1 key to add to GCP or firestore:
(or replace ~/.android/release.keystore with your path)
```
keytool -list -v -keystore ~/.android/release.keystore -alias parakeetreleasekeystore -storepass Ilove@alllanguages
```

To run on device as emulator and print to a file to not loose the lines in the console: select the device, plug it in, tun command:
```
flutter run > flutter_output.txt
```

To print both to the terminal and save to file:
```
flutter run | tee flutter_output.txt
```

Add new icons using flutter_launcher_icons package:

1. Replace the icon ima under assets (1024x1024, .png)
2. Run this command after installing the package:
```
dart run flutter_launcher_icons:main
```