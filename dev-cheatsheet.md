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

Deploy locally for testing:

```
functions-framework --target second_API_calls --debug
```

Create Android installer file:

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
