import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import 'queue_status_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const List<String> _serviceTypes = [
    'General Consultation',
    'Dental',
    'Hair Cut',
    'Document Submission',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String _selectedService = _serviceTypes.first;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;
  String? _dateTimeError; // inline error shown below picker row

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateTimeError = _validateDateTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();

    // When today is selected, seed the picker to now+30 min so the user
    // doesn't accidentally pick a time that is already in the past.
    TimeOfDay smartInitial = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    if (_selectedDate != null) {
      final isToday = _selectedDate!.year == now.year &&
          _selectedDate!.month == now.month &&
          _selectedDate!.day == now.day;
      if (isToday && _selectedTime == null) {
        final future = now.add(const Duration(minutes: 30));
        smartInitial = TimeOfDay(hour: future.hour, minute: future.minute);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: smartInitial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _dateTimeError = _validateDateTime();
      });
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  static final _nameRegex = RegExp(r'^[a-zA-Z ]+$');

  String? _validateDateTime() {
    if (_selectedDate == null) return 'Please select a date';
    if (_selectedTime == null) return 'Please select a time';

    // Time window: 9 AM – 6 PM only
    final h = _selectedTime!.hour;
    if (h < 9 || h >= 18) {
      return 'Only 9 AM to 6 PM slots allowed';
    }

    final now = DateTime.now();
    final combined = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    // Not in the past
    if (combined.isBefore(now)) {
      return 'Cannot book an appointment in the past';
    }

    // No more than 30 days ahead
    if (combined.isAfter(now.add(const Duration(days: 30)))) {
      return 'Maximum 30 days in advance';
    }

    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final dtError = _validateDateTime();
    if (dtError != null) { _showSnack(dtError, isError: true); return; }

    setState(() => _submitting = true);

    final combined = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    final apt = Appointment(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      serviceType: _selectedService,
      dateTime: combined,
      queuePosition: 0,
      status: 'Scheduled',
      userId: FirebaseAuth.instance.currentUser!.uid,
      isSynced: false,
    );

    try {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.addAppointment(apt);
      if (!mounted) return;

      // Fetch saved copy (provider stream will have updated by now)
      final saved = provider.appointments.firstWhere(
        (a) => a.serviceType == apt.serviceType && a.dateTime == combined,
        orElse: () => apt,
      );
      _showConfirmDialog(saved);
    } on ConflictException {
      if (!mounted) return;
      _showConflictDialog();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text('Slot Full'),
        ]),
        content: const Text(
          'This time slot already has 3 active appointments.\nPlease choose another time.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(Appointment apt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text('Confirmed!'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('ID', apt.id.substring(0, 8).toUpperCase()),
            const SizedBox(height: 6),
            _infoRow('Queue', '#${apt.queuePosition}'),
            const SizedBox(height: 6),
            _infoRow('When', DateFormat('dd MMM yyyy, hh:mm a').format(apt.dateTime)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // close dialog
              // Push (not replace) so the tab stack stays intact
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => QueueStatusScreen(appointment: apt)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View Queue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // close dialog
              // BookingScreen may be a tab (IndexedStack) — never blindly pop.
              // Instead reset the form so the user can book again.
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(); // pushed as a route → go back
              } else {
                _resetForm(); // embedded in tab → clear fields
              }
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Clears all booking fields back to their initial state.
  void _resetForm() {
    _formKey.currentState?.reset();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _nameCtrl.text = user?.displayName ?? '';
      _selectedService = _serviceTypes.first;
      _selectedDate = null;
      _selectedTime = null;
      _dateTimeError = null;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF1976D2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _infoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1976D2)))),
    ],
  );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
    filled: true,
    fillColor: const Color(0xFFF5F9FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.blue.shade100, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);
    final dateLabel = _selectedDate == null
        ? 'Select Date'
        : DateFormat('EEE, dd MMM yyyy').format(_selectedDate!);
    final timeLabel = _selectedTime == null ? 'Select Time' : _selectedTime!.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(title: const Text('Book Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 6,
            shadowColor: primary.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded, color: primary),
                    ),
                    const SizedBox(width: 12),
                    const Text('Appointment Details',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primary)),
                  ]),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dec('Full Name', Icons.person_outline),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (!_nameRegex.hasMatch(v.trim())) {
                        return 'Name must contain letters only';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Service
                  DropdownButtonFormField<String>(
                    value: _selectedService,
                    decoration: _dec('Service Type', Icons.medical_services_outlined),
                    items: _serviceTypes
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedService = v); },
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 20),

                  // Date & Time
                  Text('Date & Time',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: dateLabel,
                      isPlaceholder: _selectedDate == null,
                      onTap: _pickDate,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: timeLabel,
                      isPlaceholder: _selectedTime == null,
                      onTap: _pickTime,
                    )),
                  ]),
                  const SizedBox(height: 6),
                  // ── Inline date/time validation feedback ───────────────
                  if (_dateTimeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _dateTimeError!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Allowed: 9:00 AM – 6:00 PM · Up to 30 days ahead',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  const SizedBox(height: 16),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(_submitting ? 'Booking...' : 'Book Appointment',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Picker tile widget ────────────────────────────────────────────────────────

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.isPlaceholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100, width: 1.2),
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1976D2), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
            style: TextStyle(
              fontSize: 13,
              color: isPlaceholder ? Colors.grey.shade500 : const Color(0xFF1A237E),
              fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );
  }
}
