import 'package:flutter/material.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIRESTORE SECURITY RULES                                               ║
// ║  Copy the block below into Firebase Console →                           ║
// ║  Firestore Database → Rules                                             ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║                                                                          ║
// ║  rules_version = '2';                                                   ║
// ║  service cloud.firestore {                                              ║
// ║    match /databases/{database}/documents {                              ║
// ║      match /appointments/{docId} {                                      ║
// ║        // Admins (custom claim) can do anything                         ║
// ║        allow read, write: if request.auth != null                       ║
// ║                           && request.auth.token.admin == true;          ║
// ║        // Owner can read/update/delete their own docs                   ║
// ║        allow read, update, delete: if request.auth != null              ║
// ║                           && request.auth.uid == resource.data.userId;  ║
// ║        // Any authenticated user can create a new appointment           ║
// ║        allow create: if request.auth != null                            ║
// ║                      && request.auth.uid == request.resource.data.userId;║
// ║      }                                                                  ║
// ║    }                                                                    ║
// ║  }                                                                      ║
// ║                                                                          ║
// ╚══════════════════════════════════════════════════════════════════════════╝

/// Slide-from-right page transition replacing the default fade/push.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(SlidePageRoute(builder: (_) => MyScreen()));
/// ```
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Primary: slide in from right
            final slide = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Secondary: outgoing screen slides slightly left and fades
            final fadeOut = Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(
                  parent: secondaryAnimation, curve: Curves.easeIn),
            );

            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fadeOut, child: child),
            );
          },
        );
}
