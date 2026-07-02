import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(ApiClient.resetClientForTesting);

  test('hides technical backend details from users', () async {
    ApiClient.setClientForTesting(
      MockClient(
        (_) async => http.Response(
          '{"message":"Could not reach http://10.0.2.2:3000/api"}',
          500,
        ),
      ),
    );

    final response = await ApiClient.safeRequest('GET', '/health');

    expect(response['success'], isFalse);
    expect(response['message'], contains('Could not reach'));
    expect(response['message'], isNot(contains('10.0.2.2')));
    expect(response['message'], isNot(contains('http')));
  });

  test('maps missing network to a friendly message', () async {
    ApiClient.setClientForTesting(
      MockClient((_) async => throw const SocketException('network down')),
    );

    final response = await ApiClient.safeRequest('GET', '/health');

    expect(response['success'], isFalse);
    expect(
      response['message'],
      'No internet connection. Please check your network and try again.',
    );
  });

  test('maps invalid JSON to a friendly response error', () async {
    ApiClient.setClientForTesting(
      MockClient((_) async => http.Response('<html>bad gateway</html>', 200)),
    );

    final response = await ApiClient.safeRequest('GET', '/health');

    expect(response['success'], isFalse);
    expect(response['message'], contains('Something went wrong'));
  });
}
