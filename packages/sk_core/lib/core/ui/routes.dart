import 'package:flutter/material.dart';

/// Gentle fade transition (no sudden slides) used across all games.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (_, a, _, child) =>
      FadeTransition(opacity: a, child: child),
);

/// Lets the hub re-arm its start cue when the child comes back to it.
final routeObserver = RouteObserver<ModalRoute<void>>();
