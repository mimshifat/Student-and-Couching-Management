import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../sync/session_manager.dart';

class SessionLockWrapper extends StatelessWidget {
  final Widget child;
  
  const SessionLockWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return child;
    }

    final sessionManager = SessionManager();

    return StreamBuilder<String>(
      stream: sessionManager.watchUserStatus(user.uid),
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data ?? 'active';

        // If the user has been manually suspended or deactivated from Firestore
        if (status == 'suspended' || status == 'inactive') {
          final isSuspended = status == 'suspended';
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isSuspended ? Icons.block : Icons.person_off, color: Colors.red, size: 80),
                      const SizedBox(height: 24),
                      Text(
                        isSuspended ? 'Account Suspended' : 'Account Inactive',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSuspended 
                          ? 'This account has been suspended by the administrator. You cannot use the application with this account.'
                          : 'This account is currently inactive. Please contact the administrator to reactivate it.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          authProvider.signOut();
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Otherwise, proceed to the device-session lock check
        return StreamBuilder<bool>(
          stream: sessionManager.watchSessionLock(user.uid),
          builder: (context, snapshot) {
            final isLocked = snapshot.data ?? false;

            if (!isLocked) {
              return child;
            }

            return Stack(
              children: [
                // Disable interactions
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 0.6,
                    child: child,
                  ),
                ),
                
                // Lock banner
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Material(
                      elevation: 4,
                      color: Colors.red.shade800,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock, color: Colors.white, size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              'Read-Only Mode',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Another device is actively editing data for this account. To prevent conflicts, this device is temporarily locked.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                // Reclaim session
                                sessionManager.claimSession(user.uid);
                              },
                              child: const Text('Reclaim Session Here'),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
