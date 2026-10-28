import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseLicenseDataSource {
  final SupabaseClient _client;
  SupabaseLicenseDataSource(this._client);

  Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    final response = await _client.from('subscriptions')
      .select().eq('user_id', userId).maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createSubscription(String userId, String type) async {
    final response = await _client.from('subscriptions').insert({
      'user_id': userId, 'type': type, 'is_active': true,
      'start_date': DateTime.now().toIso8601String(),
    }).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateSubscription(String id, Map<String, dynamic> data) async {
    final response = await _client.from('subscriptions')
      .update(data).eq('id', id).select().single();
    return response;
  }

  Future<Map<String, dynamic>?> getLicenseByKey(String licenseKey) async {
    final response = await _client.from('licenses')
      .select().eq('license_key', licenseKey).maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createLicense(Map<String, dynamic> data) async {
    final response = await _client.from('licenses').insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>?> getLicenseBySubscription(String subscriptionId) async {
    final response = await _client.from('licenses')
      .select().eq('subscription_id', subscriptionId).maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> findProductKey(String key) async {
    final response = await _client.from('product_keys')
      .select('id, is_used, expires_at')
      .eq('key', key)
      .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> claimProductKey(String id, String userId) async {
    final response = await _client.from('product_keys')
      .update({'is_used': true, 'used_by': userId, 'used_at': DateTime.now().toIso8601String()})
      .eq('id', id)
      .eq('is_used', false)
      .select('id')
      .maybeSingle();
    return response;
  }
}

