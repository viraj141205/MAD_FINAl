import 'package:cloud_firestore/cloud_firestore.dart';

/// Thrown when a requested time slot already has 3 or more active appointments.
class ConflictException implements Exception {
  final String message;
  const ConflictException(this.message);

  @override
  String toString() => 'ConflictException: $message';
}

class Appointment {
  String id;
  String name;
  String serviceType;
  DateTime dateTime;
  int queuePosition;
  String status; // "Scheduled", "In Progress", "Completed", "Cancelled"
  String userId; // Firebase Auth UID
  bool isSynced;

  Appointment({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.dateTime,
    required this.queuePosition,
    required this.status,
    required this.userId,
    this.isSynced = false,
  });

  /// Serialise to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'serviceType': serviceType,
      'dateTime': Timestamp.fromDate(dateTime),
      'queuePosition': queuePosition,
      'status': status,
      'userId': userId,
      'isSynced': isSynced,
    };
  }

  /// Deserialise from a Firestore document snapshot.
  factory Appointment.fromMap(Map<String, dynamic> map, String docId) {
    return Appointment(
      id: docId,
      name: map['name'] as String? ?? '',
      serviceType: map['serviceType'] as String? ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      queuePosition: (map['queuePosition'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'Scheduled',
      userId: map['userId'] as String? ?? '',
      isSynced: map['isSynced'] as bool? ?? true,
    );
  }

  Appointment copyWith({
    String? id,
    String? name,
    String? serviceType,
    DateTime? dateTime,
    int? queuePosition,
    String? status,
    String? userId,
    bool? isSynced,
  }) {
    return Appointment(
      id: id ?? this.id,
      name: name ?? this.name,
      serviceType: serviceType ?? this.serviceType,
      dateTime: dateTime ?? this.dateTime,
      queuePosition: queuePosition ?? this.queuePosition,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
