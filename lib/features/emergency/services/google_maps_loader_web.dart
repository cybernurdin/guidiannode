// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<void>? _loadingFuture;
bool _authFailureHookInstalled = false;
String? _authFailureMessage;

// Google calls window.gm_authFailure when the Maps JavaScript API rejects a
// request (invalid key, wrong HTTP referrer allow-list, API not enabled on
// the project, billing disabled, etc). Without this hook, google.maps still
// ends up partially defined, so our readiness poll below sees `google.maps`
// exist and reports "loaded" -- then the actual map widget crashes deep
// inside Google's minified JS with a cryptic "window.<random> is not a
// function" error. Capturing this callback turns that into an actionable
// message instead.
void _onAuthFailure() {
  _authFailureMessage =
      'Google Maps rejected this website\'s API key (RefererNotAllowedMapError / '
      'ApiNotActivatedMapError / billing disabled). In Google Cloud Console, '
      'check that this key: (1) has "Maps JavaScript API" enabled, (2) has '
      '"HTTP referrers" application restrictions that include this domain '
      '(not an Android-app-only restriction), and (3) belongs to a project '
      'with billing enabled.';
}

void _installAuthFailureHook() {
  if (_authFailureHookInstalled) {
    return;
  }
  _authFailureHookInstalled = true;
  globalContext.setProperty('gm_authFailure'.toJS, _onAuthFailure.toJS);
}

String _resolveApiKey(String apiKey) {
  if (apiKey.trim().isNotEmpty) {
    return apiKey.trim();
  }

  final metaTag = html.document.querySelector(
    'meta[name="google-maps-api-key"]',
  );
  final metaKey = metaTag?.getAttribute('content')?.trim() ?? '';

  if (metaKey.isNotEmpty) {
    return metaKey;
  }

  throw StateError(
    'Google Maps API key is missing. Set GOOGLE_MAPS_API_KEY/VITE_GOOGLE_MAPS_API_KEY or add the web meta tag.',
  );
}

bool get _isGoogleMapsReady {
  final dynamic window = html.window;
  final dynamic google = window.google;
  return google != null && google.maps != null;
}

Future<void> ensureGoogleMapsLoaded(String apiKey) {
  final resolvedApiKey = _resolveApiKey(apiKey);

  if (_isGoogleMapsReady) {
    return Future<void>.value();
  }

  if (_loadingFuture != null) {
    return _loadingFuture!;
  }

  _installAuthFailureHook();

  final completer = Completer<void>();
  _loadingFuture = completer.future;

  final existingScript = html.document.querySelector(
    'script[data-guardian-node-google-maps="true"]',
  );

  if (existingScript == null) {
    final script = html.ScriptElement()
      ..async = true
      ..defer = true
      ..src =
          'https://maps.googleapis.com/maps/api/js?key=$resolvedApiKey&loading=async'
      ..setAttribute('data-guardian-node-google-maps', 'true');
    html.document.head?.children.add(script);
  }

  late Timer poller;
  poller = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    if (_authFailureMessage != null) {
      poller.cancel();
      completer.completeError(StateError(_authFailureMessage!));
      return;
    }

    if (_isGoogleMapsReady) {
      poller.cancel();
      completer.complete();
      return;
    }

    if (timer.tick >= 200) {
      poller.cancel();
      completer.completeError(
        StateError('Timed out while loading Google Maps JavaScript API.'),
      );
    }
  });

  return _loadingFuture!;
}
