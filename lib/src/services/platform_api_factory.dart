import 'http_platform_api.dart';
import 'platform_api.dart';

PlatformApi buildPlatformApi() {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
  const initialToken = String.fromEnvironment('API_TOKEN', defaultValue: '');

  return HttpPlatformApi(
    baseUrl: baseUrl,
    initialAccessToken: initialToken.isEmpty ? null : initialToken,
  );
}
