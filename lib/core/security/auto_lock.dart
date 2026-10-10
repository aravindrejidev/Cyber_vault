import 'dart:async';

import 'package:cyber_vault/core/security/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Used to close every open page when the vault locks.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bumped on every touch / keystroke; resets the inactivity timer.
final ValueNotifier<int> userActivity = ValueNotifier<int>(0);

/// Bumped when the app goes to the background. Sensitive screens react by
/// hiding secrets or closing themselves immediately.
final ValueNotifier<int> backgroundSignal = ValueNotifier<int>(0);

void reportUserActivity() {
  userActivity.value++;
}

/// Lets the app open system screens without the background timeout locking
/// the vault in the meantime.
class LockGuard {
  LockGuard._();

  static int _depth = 0;
  static DateTime? _suspendedUntil;

  static bool get isSuspended {
    if (_depth > 0) return true;
    final DateTime? until = _suspendedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// For screens that give no Future back (the installer, system settings):
  /// the background timeout is paused for [duration] or until the app returns.
  static void suspendFor(Duration duration) {
    _suspendedUntil = DateTime.now().add(duration);
  }

  static bool get hasTimedSuspension => _suspendedUntil != null;

  static void clearTimedSuspension() {
    _suspendedUntil = null;
  }

  /// For screens that give a Future back (the file picker).
  static Future<T> suspendWhile<T>(Future<T> Function() action) async {
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
      reportUserActivity();
    }
  }
}

/// Wrap the whole app with this. It locks the vault when:
///  * the app stays in the background for more than 30 seconds,
///  * there is no touch/keyboard activity for 3 minutes,
///  * the app is being destroyed.
class AutoLockScope extends ConsumerStatefulWidget {
  const AutoLockScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoLockScope> createState() => _AutoLockScopeState();
}

class _AutoLockScopeState extends ConsumerState<AutoLockScope>
    with WidgetsBindingObserver {
  static const Duration _backgroundTimeout = Duration(seconds: 30);
  static const Duration _inactivityTimeout = Duration(minutes: 3);

  Timer? _inactivityTimer;
  Timer? _backgroundTimer;
  DateTime? _backgroundedAt;
  DateTime? _lastTouch;

  bool get _unlocked =>
      ref.read(sessionProvider).status == VaultStatus.unlocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    userActivity.addListener(_restartInactivityTimer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    userActivity.removeListener(_restartInactivityTimer);
    _inactivityTimer?.cancel();
    _backgroundTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _lockNow();
      return;
    }
    if (state == AppLifecycleState.resumed && LockGuard.hasTimedSuspension) {
      // Back from the installer / system settings: normal rules apply again.
      final bool withinWindow = LockGuard.isSuspended;
      LockGuard.clearTimedSuspension();
      if (withinWindow) {
        _restartInactivityTimer();
      } else {
        _lockNow();
      }
      return;
    }
    if (LockGuard.isSuspended) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _onBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  void _onBackgrounded() {
    if (!_unlocked) return;
    _backgroundedAt ??= DateTime.now();
    backgroundSignal.value++;
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(_backgroundTimeout, _lockNow);
  }

  void _onResumed() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    final DateTime? at = _backgroundedAt;
    _backgroundedAt = null;
    if (at != null && DateTime.now().difference(at) >= _backgroundTimeout) {
      _lockNow();
      return;
    }
    _restartInactivityTimer();
  }

  void _lockNow() {
    _inactivityTimer?.cancel();
    _backgroundTimer?.cancel();
    if (_unlocked) {
      ref.read(sessionProvider.notifier).lock();
    }
  }

  void _restartInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_unlocked) return;
    _inactivityTimer = Timer(_inactivityTimeout, _lockNow);
  }

  void _touch() {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastTouch;
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _lastTouch = now;
    _restartInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VaultStatus>(
      sessionProvider.select((SessionState s) => s.status),
      (VaultStatus? previous, VaultStatus next) {
        if (next == VaultStatus.unlocked) {
          _restartInactivityTimer();
        } else {
          _inactivityTimer?.cancel();
          _backgroundTimer?.cancel();
          _backgroundedAt = null;
        }
      },
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      onPointerMove: (_) => _touch(),
      onPointerUp: (_) => _touch(),
      child: widget.child,
    );
  }
}
