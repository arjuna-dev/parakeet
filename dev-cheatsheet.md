# Cheatsheet

---


##### Deploy all functions in codebase:

```bash
firebase deploy --only functions
```


##### Deploy specific functions in codebase:

```bash
firebase deploy --only functions:fist_API_calls,functions:second_API_calls
```


##### Delete a specified function:

```bash
firebase functions:delete myFunction
```

```bash
firebase functions:delete myFunction --region us-east-1
```

##### Deploy locally for testing
```
functions-framework --target second_API_calls --debug
```

##### Create Android installer file
```
flutter build apk --release
```

##### Run on selected device (build the .apk file first for Android):
```
flutter run --release
```

##### Try cleaning if something go wrong:
```
flutter clean
```

##### How to get a DEBUG SHA-1 key to add to GCP or firestore:
(or replace ~/.android/debug.keystore with your path)
```
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

##### How to get a RELEASE SHA-1 key to add to GCP or firestore:
(or replace ~/.android/release.keystore with your path)
```
keytool -list -v -keystore ~/.android/release.keystore -alias parakeetreleasekeystore -storepass Ilove@alllanguages
```

##### To run on device as emulator and print to a file to not loose the lines in the console: select the device, plug it in, tun command:
```
flutter run > flutter_output.txt
```

##### To print both to the terminal and save to file:
```
flutter run | tee flutter_output.txt
```

##### Add new icons using flutter_launcher_icons package:

1. Replace the icon ima under assets (1024x1024, .png)
2. Run this command after installing the package:
```
dart run flutter_launcher_icons:main
```

### How to bundle an Android bundle and apks file

Run:
```bash
flutter build appbundle
```

#### How te test an apk from the bundle on a device

##### Installation:

1. Download the .jar file from https://github.com/google/bundletool/releases 
2. Add this to .zshrc:
```bash
alias bundletool='java -jar /path/to/bundletool-all-1.16.0.jar'
```
Alternatively you'll have to point to the .jar file every time with 

```bash
java -jar /path/to/bundletool-all-1.16.0.jar
```
##### Generate .apks
Generate a set of APKs under an .apks file with:
```bash
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=build/app/outputs/bundle/release/app-release.apks
```
##### Install from .apks
To test the recently created .apks file on a connected Android device:
```
bundletool install-apks --apks=build/app/outputs/bundle/release/app-release.apks
```

#### Note: this last command will install the app but not open it immediately, you must search and open the app manually

### Build for iOS Deployment

```
flutter build ipa --obfuscate --split-debug-info=build/app/outputs/symbols
```

### Build for web

```
flutter build web
```