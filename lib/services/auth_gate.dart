import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();

  bool _unlocked = false;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attemptUnlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _unlocked = false;
    }

    if (state == AppLifecycleState.resumed && !_unlocked) {
      _attemptUnlock();
    }
  }

  Future<void> _attemptUnlock() async {
    if (_authInProgress || _unlocked) return;

    _authInProgress = true;

    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return;

      final ok = await _auth.authenticate(
        localizedReason: 'Authenticate device to continue',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (ok && mounted) {
        setState(() {
          _unlocked = true;
        });
      }
    } catch (e, st) {
      debugPrint("AUTH ERROR: $e\n$st");
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Locked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Authenticate with your device to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _authInProgress ? null : _attemptUnlock,
                child: Text(_authInProgress ? 'Checking…' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

