import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_http_client.dart';


final authHttpClientProvider = Provider<AuthHttpClient>((ref) {
  return AuthHttpClient(ref);
});
