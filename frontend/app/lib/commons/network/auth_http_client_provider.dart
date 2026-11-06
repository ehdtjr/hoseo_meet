import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_http_client.dart';


final authHttpClientProvider = Provider<AuthHttpClient>((ref) {
  final client = AuthHttpClient(ref);
  ref.onDispose(client.close);
  return client;
});
