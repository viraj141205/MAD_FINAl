import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';

export '../models/appointment.dart' show ConflictException;

class AppointmentProvider extends ChangeNotifier {
  // ── Dependencies ──────────────────────────────────────────────────────────

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ── State ─────────────────────────────────────────────────────────────────

  List<Appointment> _appointments = [];
  List<Appointment> get appointments => List.unmodifiable(_appointments);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _subscription;

  // ── Constructor ───────────────────────────────────────────────────────────

  AppointmentProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    loadAppointments();
  }

  // ── Firestore collection reference ────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('appointments');

  // ── Core Operations ───────────────────────────────────────────────────────

  /// Starts a real-time stream from Firestore ordered by [dateTime].
  /// Automatically rebuilds the local list on every remote change.
  void loadAppointments() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _collection
        .orderBy('dateTime')
        .snapshots()
        .listen(
          (snapshot) {
            _appointments = snapshot.docs
                .map((doc) => Appointment.fromMap(
                      doc.data(),
                      doc.id,
                    ))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object err) {
            _error = err.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Adds a new appointment to Firestore after performing a conflict check.
  ///
  /// Throws [ConflictException] if the requested [dateTime] slot already
  /// contains 3 or more appointments that are NOT "Cancelled".
  Future<void> addAppointment(Appointment a) async {
    _assertAuthenticated();

    // ── Conflict check ────────────────────────────────────────────────────
    final sameSlot = _appointments.where((apt) {
      return apt.dateTime.isAtSameMomentAs(a.dateTime) &&
          apt.status != 'Cancelled';
    }).toList();

    if (sameSlot.length >= 3) {
      throw const ConflictException(
        'This time slot already has 3 active appointments. '
        'Please choose a different time.',
      );
    }

    // ── Assign next queue position ─────────────────────────────────────────
    // Only consider active (Scheduled / In Progress) appointments so that
    // Completed or Cancelled slots don't inflate the counter.
    final activeApts = _appointments
        .where((e) => e.status != 'Completed' && e.status != 'Cancelled')
        .toList();

    final nextPosition = activeApts.isEmpty
        ? 1
        : activeApts.map((e) => e.queuePosition).reduce(
                  (a, b) => a > b ? a : b,
                ) +
            1;

    // ── Generate a document ID ─────────────────────────────────────────────
    final docId = const Uuid().v4();

    final toSave = a.copyWith(
      id: docId,
      queuePosition: nextPosition,
      userId: _auth.currentUser!.uid,
      isSynced: true,
    );

    await _collection.doc(docId).set(toSave.toMap());
  }

  /// Updates the [status] field of the appointment identified by [id].
  Future<void> updateStatus(String id, String status) async {
    _assertAuthenticated();
    await _collection.doc(id).update({'status': status});
  }

  /// Convenience wrapper — sets the appointment's status to "Cancelled".
  Future<void> cancelAppointment(String id) async {
    await updateStatus(id, 'Cancelled');
  }

  /// Permanently deletes the appointment document from Firestore.
  Future<void> deleteAppointment(String id) async {
    _assertAuthenticated();
    await _collection.doc(id).delete();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  /// Returns a filtered view of the local [_appointments] list.
  ///
  /// All parameters are optional. When [null], that filter is not applied.
  ///
  /// - [search]      — case-insensitive match on [name] or [serviceType]
  /// - [status]      — exact match on [status]
  /// - [serviceType] — exact match on [serviceType]
  /// - [date]        — matches appointments on the same calendar day
  List<Appointment> getFilteredAppointments({
    String? search,
    String? status,
    String? serviceType,
    DateTime? date,
  }) {
    return _appointments.where((apt) {
      // Search filter
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        final inName = apt.name.toLowerCase().contains(q);
        final inService = apt.serviceType.toLowerCase().contains(q);
        if (!inName && !inService) return false;
      }

      // Status filter
      if (status != null && status.isNotEmpty && apt.status != status) {
        return false;
      }

      // Service-type filter
      if (serviceType != null &&
          serviceType.isNotEmpty &&
          apt.serviceType != serviceType) {
        return false;
      }

      // Date filter (same calendar day)
      if (date != null) {
        final aptDate = apt.dateTime;
        final sameDay = aptDate.year == date.year &&
            aptDate.month == date.month &&
            aptDate.day == date.day;
        if (!sameDay) return false;
      }

      return true;
    }).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _assertAuthenticated() {
    if (_auth.currentUser == null) {
      throw StateError(
        'No authenticated user found. Please sign in before managing appointments.',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
