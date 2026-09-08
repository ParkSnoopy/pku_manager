import 'dart:ui' show loadFontFromList;

import 'package:flutter/services.dart';

const notoSansCjkSuperOtcAsset = 'assets/fonts/NotoSansCJK.ttc';
const pkuNotoSansKrFamily = 'PKU Noto Sans CJK KR';
const pkuNotoSansScFamily = 'PKU Noto Sans CJK SC';

const notoSansCjkKrRegularFace = 26;
const notoSansCjkScRegularFace = 27;
const notoSansCjkKrBoldFace = 36;
const notoSansCjkScBoldFace = 37;

final class SuperOtcFontLoader {
  SuperOtcFontLoader._();

  static Future<void>? _loading;

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    final data = await rootBundle.load(notoSansCjkSuperOtcAsset);
    final collection = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    for (final face in const [
      (index: notoSansCjkKrRegularFace, family: pkuNotoSansKrFamily),
      (index: notoSansCjkKrBoldFace, family: pkuNotoSansKrFamily),
      (index: notoSansCjkScRegularFace, family: pkuNotoSansScFamily),
      (index: notoSansCjkScBoldFace, family: pkuNotoSansScFamily),
    ]) {
      await loadFontFromList(
        extractSuperOtcFace(collection, face.index),
        fontFamily: face.family,
      );
    }
  }
}

Uint8List extractSuperOtcFace(Uint8List collection, int faceIndex) {
  final source = ByteData.sublistView(collection);
  if (collection.length < 12 || source.getUint32(0) != 0x74746366) {
    throw const FormatException('Invalid OpenType collection');
  }
  final faceCount = source.getUint32(8);
  _requireRange(collection, 12, faceCount * 4);
  if (faceIndex < 0 || faceIndex >= faceCount) {
    throw RangeError.range(faceIndex, 0, faceCount - 1, 'faceIndex');
  }
  final faceOffset = source.getUint32(12 + faceIndex * 4);
  _requireRange(collection, faceOffset, 12);
  final signature = source.getUint32(faceOffset);
  if (signature != 0x4f54544f && signature != 0x00010000) {
    throw const FormatException('Invalid OpenType face');
  }
  final tableCount = source.getUint16(faceOffset + 4);
  _requireRange(collection, faceOffset + 12, tableCount * 16);

  final tables = <_TableRecord>[];
  var outputOffset = _align4(12 + tableCount * 16);
  for (var index = 0; index < tableCount; index++) {
    final recordOffset = faceOffset + 12 + index * 16;
    final length = source.getUint32(recordOffset + 12);
    final sourceOffset = source.getUint32(recordOffset + 8);
    _requireRange(collection, sourceOffset, length);
    tables.add(
      _TableRecord(
        tag: source.getUint32(recordOffset),
        checksum: source.getUint32(recordOffset + 4),
        sourceOffset: sourceOffset,
        outputOffset: outputOffset,
        length: length,
      ),
    );
    outputOffset = _align4(outputOffset + length);
  }

  final output = Uint8List(outputOffset);
  final target = ByteData.sublistView(output);
  output.setRange(0, 12, collection, faceOffset);
  for (var index = 0; index < tables.length; index++) {
    final table = tables[index];
    final recordOffset = 12 + index * 16;
    target.setUint32(recordOffset, table.tag);
    target.setUint32(recordOffset + 4, table.checksum);
    target.setUint32(recordOffset + 8, table.outputOffset);
    target.setUint32(recordOffset + 12, table.length);
    output.setRange(
      table.outputOffset,
      table.outputOffset + table.length,
      collection,
      table.sourceOffset,
    );
  }

  final head = tables.where((table) => table.tag == 0x68656164).firstOrNull;
  if (head == null || head.length < 12) {
    throw const FormatException('OpenType face has no valid head table');
  }
  target.setUint32(head.outputOffset + 8, 0);
  var checksum = 0;
  for (var offset = 0; offset < output.length; offset += 4) {
    checksum = (checksum + target.getUint32(offset)) & 0xffffffff;
  }
  target.setUint32(head.outputOffset + 8, (0xb1b0afba - checksum) & 0xffffffff);
  return output;
}

void _requireRange(Uint8List bytes, int offset, int length) {
  if (offset < 0 || length < 0 || offset > bytes.length - length) {
    throw const FormatException('Invalid OpenType table range');
  }
}

int _align4(int value) => (value + 3) & ~3;

final class _TableRecord {
  const _TableRecord({
    required this.tag,
    required this.checksum,
    required this.sourceOffset,
    required this.outputOffset,
    required this.length,
  });

  final int tag;
  final int checksum;
  final int sourceOffset;
  final int outputOffset;
  final int length;
}
