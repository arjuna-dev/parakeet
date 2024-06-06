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