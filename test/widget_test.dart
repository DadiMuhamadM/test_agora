import 'package:flutter_test/flutter_test.dart';
import 'package:test_agora/main.dart';

void main() {
  test('AgoraConfig constants are properly configured', () {
    expect(AgoraConfig.appKey, isNotEmpty);
    expect(AgoraConfig.penumpangId, isNotEmpty);
    expect(AgoraConfig.driverId, isNotEmpty);
    expect(AgoraConfig.penumpangId, isNot(equals(AgoraConfig.driverId)));
  });
}
