const timetableClassStarts = <int, String>{
  1: '08:00',
  2: '09:00',
  3: '10:10',
  4: '11:10',
  5: '13:00',
  6: '14:00',
  7: '15:10',
  8: '16:10',
  9: '17:10',
  10: '18:40',
  11: '19:40',
  12: '20:40',
};

String timetableClassEnd(String start) {
  final parts = start.split(':').map(int.parse).toList(growable: false);
  final end = parts[0] * 60 + parts[1] + 50;
  return '${(end ~/ 60).toString().padLeft(2, '0')}:'
      '${(end % 60).toString().padLeft(2, '0')}';
}
