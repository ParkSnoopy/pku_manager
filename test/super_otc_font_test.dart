import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/ui/super_otc_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Static Super OTC exposes the required KR and SC faces', () async {
    final data = await rootBundle.load(notoSansCjkSuperOtcAsset);
    final collection = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final lengths = <int>[];
    for (final index in [...notoSansCjkKrFaces, ...notoSansCjkScFaces]) {
      final face = extractSuperOtcFace(collection, index);
      expect(ByteData.sublistView(face).getUint32(0), 0x4f54544f);
      lengths.add(face.length);
    }
    expect(lengths.toSet(), hasLength(greaterThan(1)));
  });

  test(
    'Serif Static Super OTC exposes every active KR and SC weight',
    () async {
      final data = await rootBundle.load(notoSerifCjkSuperOtcAsset);
      final collection = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      for (final index in [...notoSerifCjkKrFaces, ...notoSerifCjkScFaces]) {
        final face = extractSuperOtcFace(collection, index);
        expect(ByteData.sublistView(face).getUint32(0), 0x4f54544f);
      }
    },
  );

  test('face extraction rejects invalid collections and indices', () {
    expect(() => extractSuperOtcFace(Uint8List(12), 0), throwsFormatException);
  });
}
