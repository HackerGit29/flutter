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
    final response = await _client.from('licences')
      .select().eq('license_key', licenseKey).maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createLicense(Map<String, dynamic> data) async {
    final response = await _client.from('licences').insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>?> getLicenseBySubscription(String subscriptionId) async {
    final response = await _client.from('licences')
      .select().eq('subscription_id', subscriptionId).maybeSingle();
    return response;
  }
}

