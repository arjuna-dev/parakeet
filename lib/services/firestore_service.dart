import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get a collection reference
  CollectionReference getCollectionReference(String collectionPath) {
    return _db.collection(collectionPath);
  }

  // Get a document reference
  DocumentReference getDocumentReference(
      String collectionPath, String documentId) {
    return _db.collection(collectionPath).doc(documentId);
  }

  // Get a collection
  Future<QuerySnapshot> getCollection(String collectionPath) async {
    return await _db.collection(collectionPath).get();
  }

  // Get a document
  Future<DocumentSnapshot> getDocument(
      String collectionPath, String documentId) async {
    return await _db.collection(collectionPath).doc(documentId).get();
  }

  // Add a document
  Future<DocumentReference> addDocument(
      String collectionPath, Map<String, dynamic> data) async {
    return await _db.collection(collectionPath).add(data);
  }

  // Update a document
  Future<void> updateDocument(String collectionPath, String documentId,
      Map<String, dynamic> data) async {
    await _db.collection(collectionPath).doc(documentId).update(data);
  }

  // Delete a document
  Future<void> deleteDocument(String collectionPath, String documentId) async {
    await _db.collection(collectionPath).doc(documentId).delete();
  }
}
