import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';

class FirestorePropertyDataSource implements PropertyRemoteDataSource {
  final Firestore firestore;

  FirestorePropertyDataSource(this.firestore);

  CollectionReference get _properties => firestore.collection('properties');

  @override
  Future<PropertyModel> createProperty(PropertyModel property) async {
    final docRef = _properties.doc(property.id.isEmpty ? null : property.id);
    await docRef.set(property.toMap());
    return property.copyWith(id: docRef.id);
  }

  @override
  Future<PropertyModel> getPropertyById(String id) async {
    final doc = await _properties.doc(id).get();
    if (!doc.exists) throw NotFoundException('Property', id);
    return PropertyModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId) async {
    final snap = await _properties.where('landownerId', WhereFilter.equal, landownerId).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<PropertyModel>> getPropertiesByManager(String managerId) async {
    final snap = await _properties.where('managerId', WhereFilter.equal, managerId).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<PropertyModel>> getAllProperties() async {
    final snap = await _properties.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updateProperty(PropertyModel property) async {
    await _properties.doc(property.id).update(property.toMap());
  }

  @override
  Future<void> deleteProperty(String id) async {
    await _properties.doc(id).delete();
  }
}
