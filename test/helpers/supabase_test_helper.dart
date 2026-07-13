import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a real [SupabaseClient] wired to a fake HTTP transport.
///
/// The Postgrest/GoTrue builder logic (URL/header construction, JSON
/// decoding, single/maybeSingle handling) runs for real; only the network
/// call is replaced, driven by [handler].
SupabaseClient buildTestSupabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseClient(
    'https://test.supabase.co',
    'test-anon-key',
    httpClient: MockClient(handler),
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
}

/// 200 OK JSON response. `postgrest` reads `response.request!.method`, so
/// [request] must be echoed back on every response built by a handler.
http.Response jsonOk(http.Request request, dynamic data) => http.Response(
      jsonEncode(data),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );

/// 200 OK empty body — decodes to `null` for maybeSingle()/void calls.
http.Response emptyOk(http.Request request) =>
    http.Response('', 200, request: request);

/// Non-2xx JSON error response, shaped like a Postgrest/GoTrue error body.
http.Response errorResponse(
  http.Request request,
  int status, {
  String message = 'error',
}) =>
    http.Response(
      jsonEncode({'message': message, 'msg': message, 'error': message}),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );