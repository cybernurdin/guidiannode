import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

class SupabaseRealtimeService {
  SupabaseRealtimeService._();

  static final SupabaseRealtimeService instance = SupabaseRealtimeService._();

  bool _initialized = false;

  bool get isConfigured => AppConfig.hasSupabaseRealtimeConfig;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialize() async {
    if (_initialized || !isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      throw StateError(
        'Supabase realtime is not configured. Supply SUPABASE_URL and SUPABASE_ANON_KEY to enable live subscriptions.',
      );
    }
  }

  RealtimeChannel subscribeToUserNotifications({
    required String userId,
    required void Function(Map<String, dynamic>) onInsert,
  }) {
    final channel = _client.channel(
      'guardian-node-notifications-$userId-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();

    return channel;
  }

  RealtimeChannel subscribeToAlertLocation({
    required String alertId,
    required void Function(Map<String, dynamic>) onChange,
  }) {
    final channel = _client.channel(
      'guardian-node-live-location-$alertId-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'alert_id',
            value: alertId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onChange(payload.newRecord);
            }
          },
        )
        .subscribe();

    return channel;
  }

  RealtimeChannel subscribeToAlertStatus({
    required String alertId,
    required void Function(Map<String, dynamic>) onChange,
  }) {
    final channel = _client.channel(
      'guardian-node-alert-status-$alertId-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: alertId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onChange(payload.newRecord);
            }
          },
        )
        .subscribe();

    return channel;
  }

  RealtimeChannel subscribeToEmergencyFeed({
    required void Function() onMutation,
  }) {
    final channel = _client.channel(
      'guardian-node-feed-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) => onMutation(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_locations',
          callback: (_) => onMutation(),
        )
        .subscribe();

    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (!_initialized || channel == null) {
      return;
    }

    await _client.removeChannel(channel);
  }
}
