import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  setAccountType({uid, type}) {
    FirebaseFirestore.instance.collection("users").doc(uid).update({
      '$type': true,
    });
  }
}
