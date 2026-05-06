import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import 'booking_screen.dart';
import 'queue_status_screen.dart';

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key});

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFFF59E0B);
      case 'Completed':   return const Color(0xFF10B981);
      case 'Cancelled':   return const Color(0xFFEF4444);
      default:            return const Color(0xFF1976D2);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'In Progress': return Icons.hourglass_top_rounded;
      case 'Completed':   return Icons.check_circle_rounded;
      case 'Cancelled':   return Icons.cancel_rounded;
      default:            return Icons.schedule_rounded;
    }
  }

  // ── Bottom sheet actions ──────────────────────────────────────────────────

  void _showActionSheet(BuildContext context, Appointment apt) {
    final provider = Provider.of<AppointmentProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Text(apt.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  _StatusBadge(
                      status: apt.status, color: _statusColor(apt.status)),
                ]),
              ),
              const Divider(height: 20),

              if (apt.status != 'Completed' && apt.status != 'Cancelled')
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFD1FAE5),
                    child: Icon(Icons.check_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Mark Completed'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await provider.updateStatus(apt.id, 'Completed');
                  },
                ),

              if (apt.status != 'Cancelled' && apt.status != 'Completed')
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.block_rounded, color: Color(0xFFF59E0B)),
                  ),
                  title: const Text('Cancel Appointment'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await provider.cancelAppointment(apt.id);
                  },
                ),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEE2E2),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444)),
                ),
                title: const Text('Delete',
                    style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await provider.deleteAppointment(apt.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    const primary = Color(0xFF1976D2);

    return Stack(
      children: [
        // ── Main stream list ──────────────────────────────────────────────
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1976D2)),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];
            final appointments = docs
                .map((d) => Appointment.fromMap(
                    d.data() as Map<String, dynamic>, d.id))
                .toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            // Empty state
            if (appointments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 80, color: primary.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('No appointments yet.',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text('Tap the + button to book one!',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: primary,
              onRefresh: () async =>
                  Provider.of<AppointmentProvider>(context, listen: false)
                      .loadAppointments(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: appointments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final apt = appointments[i];
                  final statusColor = _statusColor(apt.status);
                  final formattedDt =
                      DateFormat('dd MMM yyyy, hh:mm a').format(apt.dateTime);

                  return Card(
                    elevation: 3,
                    shadowColor: primary.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                QueueStatusScreen(appointment: apt)),
                      ),
                      onLongPress: () => _showActionSheet(context, apt),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          // Queue badge with Hero on the ID text
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Hero(
                                  tag: 'appt-${apt.id}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text('#${apt.queuePosition}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primary,
                                            fontSize: 14)),
                                  ),
                                ),
                                Text('Q',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: primary.withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(apt.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1A237E))),
                                const SizedBox(height: 3),
                                Text(apt.serviceType,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(formattedDt,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ),
                                ]),
                              ],
                            ),
                          ),

                          // Status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusBadge(
                                  status: apt.status, color: statusColor),
                              const SizedBox(height: 6),
                              Icon(_statusIcon(apt.status),
                                  color: statusColor, size: 18),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),

        // ── FAB ───────────────────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'list_fab',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookingScreen()),
            ),
            backgroundColor: primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Book'),
          ),
        ),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
