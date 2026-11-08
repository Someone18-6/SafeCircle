import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/helpers.dart';

/// Thrown when the device location cannot be obtained. The [message] is
/// written for end users and can be shown directly in the UI.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

/// Thin service layer that keeps Firebase / device logic out of the widgets.
///
/// Data model (all documents belong to the signed-in user):
///   users/{uid}                    -> name, email, emergencyNumber
///   users/{uid}/contacts/{id}      -> name, relation, phone
///   users/{uid}/alerts/{id}        -> SOS alerts (status Active / Resolved)
///   users/{uid}/checkins/{id}      -> "I am safe" check-ins
class AppServices {
  AppServices._();

  static const String defaultEmergencyNumber = '112';

  // ---------------------------------------------------------------- user --

  static User? get user => FirebaseAuth.instance.currentUser;

  static String get displayName {
    final name = user?.displayName?.trim();
    return (name == null || name.isEmpty) ? 'SafeCircle User' : name;
  }

  static DocumentReference<Map<String, dynamic>> get userDoc {
    final current = user;
    if (current == null) {
      throw StateError('No user is signed in.');
    }
    return FirebaseFirestore.instance.collection('users').doc(current.uid);
  }

  static CollectionReference<Map<String, dynamic>> get contacts =>
      userDoc.collection('contacts');

  static CollectionReference<Map<String, dynamic>> get alerts =>
      userDoc.collection('alerts');

  static CollectionReference<Map<String, dynamic>> get checkins =>
      userDoc.collection('checkins');

  /// Creates or updates the profile document for [account].
  static Future<void> saveProfile(User account, String name) {
    return FirebaseFirestore.instance.collection('users').doc(account.uid).set({
      'name': name,
      'email': account.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// The number dialled by the "Call emergency services" actions.
  static Future<String> emergencyNumber() async {
    try {
      final snapshot = await userDoc.get();
      final value = snapshot.data()?['emergencyNumber'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {
      // Fall back to the default if the profile cannot be read.
    }
    return defaultEmergencyNumber;
  }

  static Future<void> setEmergencyNumber(String number) {
    return userDoc.set({'emergencyNumber': number}, SetOptions(merge: true));
  }

  // ------------------------------------------------------------ location --

  /// Asks for permission (if needed) and returns the current position.
  static Future<Position> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException(
        'Location services are turned off. Please enable them and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is blocked. Allow it in your browser or '
        'device settings and try again.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      throw const LocationException(
        'Could not determine your location. Please check your signal / GPS '
        'and try again.',
      );
    }
  }

  // --------------------------------------------------------------- SOS ----

  /// Saves an SOS alert. [position] may be null when location is unavailable,
  /// because an alert without coordinates is still better than no alert.
  static Future<void> createSosAlert({
  Position? position,
  String? locationProblem,
}) async {
  final current = user;

  await alerts.add({
    'type': 'SOS',
    'status': 'Active',
    'latitude': position?.latitude,
    'longitude': position?.longitude,
    'accuracy': position?.accuracy,
    'mapsUrl': position == null
        ? null
        : mapsLink(position.latitude, position.longitude),
    'locationProblem': locationProblem,
    'userName': displayName,
    'userEmail': current?.email,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

static Future<void> resolveAlert(String id) async {
  await alerts.doc(id).update({
    'status': 'Resolved',
    'resolvedAt': FieldValue.serverTimestamp(),
  });
}

static Future<void> deleteAlert(String id) async {
  await alerts.doc(id).delete();
}

  // ----------------------------------------------------------- check-in ---

  static Future<void> createCheckIn({String? note}) {
    final trimmed = note?.trim() ?? '';
    return checkins.add({
      'status': 'Safe',
      'note': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteCheckIn(String id) => checkins.doc(id).delete();

  // ----------------------------------------------------------- contacts ---

  static Future<void> saveContact({
    String? id,
    required String name,
    required String relation,
    required String phone,
  }) {
    final data = {
      'name': name.trim(),
      'relation': relation.trim().isEmpty ? 'Contact' : relation.trim(),
      'phone': cleanPhone(phone),
    };

    if (id == null) {
      return contacts.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    }
    return contacts.doc(id).update(data);
  }

  static Future<void> deleteContact(String id) => contacts.doc(id).delete();

  // ------------------------------------------------------------ device ----

  /// Opens a link (call, SMS, WhatsApp, maps). Returns false on failure.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
