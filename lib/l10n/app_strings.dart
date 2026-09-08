import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

enum AppLanguage {
  ko('ko'),
  en('en'),
  zhHans('zh');

  const AppLanguage(this.code);
  final String code;
  Locale get locale => Locale(code);
  static const defaultLanguage = ko;
  static AppLanguage parse(String value) => values.firstWhere(
    (language) => language.code == value,
    orElse: () => defaultLanguage,
  );
}

enum AppText {
  appTitle,
  timetable,
  settings,
  import,
  export,
  exportPng,
  exportXlsx,
  rollColors,
  weekUnavailable,
  week,
  odd,
  even,
  previousDay,
  nextDay,
  courseDetails,
  course,
  room,
  weekday,
  firstPeriod,
  lastPeriod,
  frequency,
  notes,
  exam,
  completeInformation,
  sourceUnchanged,
  rejectIgnore,
  required,
  enterRange,
  lastBeforeFirst,
  save,
  cancel,
  remove,
  theme,
  accentColor,
  language,
  korean,
  english,
  chinese,
  editCourse,
  addCourse,
  chooseTutorialRoom,
  next,
  back,
  finish,
  noTimetable,
  exportFailed,
}

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('ko'), Locale('en'), Locale('zh')];
  static const delegate = _AppStringsDelegate();
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  String text(AppText key) =>
      (_values[locale.languageCode] ?? _values['ko']!)[key]!;

  String weekLabel(int number, bool isOdd) =>
      '${text(AppText.week)} $number · ${text(isOdd ? AppText.odd : AppText.even)}';

  String weekday(int value) =>
      (_weekdays[locale.languageCode] ?? _weekdays['ko']!)[value - 1];

  static const _weekdays = <String, List<String>>{
    'ko': ['월요일', '화요일', '수요일', '목요일', '금요일'],
    'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    'zh': ['星期一', '星期二', '星期三', '星期四', '星期五'],
  };

  static const _values = <String, Map<AppText, String>>{
    'ko': {
      AppText.appTitle: 'PKU Manager',
      AppText.timetable: '시간표',
      AppText.settings: '설정',
      AppText.import: '가져오기',
      AppText.export: '내보내기',
      AppText.exportPng: 'PNG로 내보내기',
      AppText.exportXlsx: 'XLSX로 내보내기',
      AppText.rollColors: '색상 조합 변경',
      AppText.weekUnavailable: '주차 정보 없음',
      AppText.week: '주차',
      AppText.odd: '홀수 주',
      AppText.even: '짝수 주',
      AppText.previousDay: '이전 요일',
      AppText.nextDay: '다음 요일',
      AppText.courseDetails: '강의 정보',
      AppText.course: '강의',
      AppText.room: '강의실',
      AppText.weekday: '요일',
      AppText.firstPeriod: '시작 교시',
      AppText.lastPeriod: '종료 교시',
      AppText.frequency: '주기',
      AppText.notes: '메모',
      AppText.exam: '시험',
      AppText.completeInformation: '정보 완성',
      AppText.sourceUnchanged: '원본 파일은 변경되지 않습니다. 모든 필수 정보를 입력하거나 가져오기를 취소하세요.',
      AppText.rejectIgnore: '거부하고 무시',
      AppText.required: '필수',
      AppText.enterRange: '범위 안의 값을 입력하세요',
      AppText.lastBeforeFirst: '종료 교시는 시작 교시보다 빠를 수 없습니다',
      AppText.save: '저장',
      AppText.cancel: '취소',
      AppText.remove: '삭제',
      AppText.theme: '테마',
      AppText.accentColor: '강조 색상',
      AppText.language: '언어',
      AppText.korean: '한국어',
      AppText.english: 'English',
      AppText.chinese: '简体中文',
      AppText.editCourse: '강의 편집',
      AppText.addCourse: '강의 추가',
      AppText.chooseTutorialRoom: '연습 수업 강의실 선택',
      AppText.next: '다음',
      AppText.back: '이전',
      AppText.finish: '가져오기',
      AppText.noTimetable: '내보낸 schedule.xls 파일을 가져오세요.\n시간표는 이 기기에만 저장됩니다.',
      AppText.exportFailed: '내보내기에 실패했습니다',
    },
    'en': {
      AppText.appTitle: 'PKU Manager',
      AppText.timetable: 'Timetable',
      AppText.settings: 'Settings',
      AppText.import: 'Import',
      AppText.export: 'Export',
      AppText.exportPng: 'Export PNG',
      AppText.exportXlsx: 'Export XLSX',
      AppText.rollColors: 'Roll colors',
      AppText.weekUnavailable: 'Week unavailable',
      AppText.week: 'Week',
      AppText.odd: 'Odd',
      AppText.even: 'Even',
      AppText.previousDay: 'Previous day',
      AppText.nextDay: 'Next day',
      AppText.courseDetails: 'Course details',
      AppText.course: 'Course',
      AppText.room: 'Room',
      AppText.weekday: 'Weekday',
      AppText.firstPeriod: 'First period',
      AppText.lastPeriod: 'Last period',
      AppText.frequency: 'Frequency',
      AppText.notes: 'Notes',
      AppText.exam: 'Exam',
      AppText.completeInformation: 'Complete information',
      AppText.sourceUnchanged: 'The original workbook stays unchanged. Complete every required field or reject this import.',
      AppText.rejectIgnore: 'Reject and ignore',
      AppText.required: 'Required',
      AppText.enterRange: 'Enter a value in range',
      AppText.lastBeforeFirst: 'Last period must not precede first period',
      AppText.save: 'Save',
      AppText.cancel: 'Cancel',
      AppText.remove: 'Remove',
      AppText.theme: 'Theme',
      AppText.accentColor: 'Accent color',
      AppText.language: 'Language',
      AppText.korean: '한국어',
      AppText.english: 'English',
      AppText.chinese: '简体中文',
      AppText.editCourse: 'Edit course',
      AppText.addCourse: 'Add course',
      AppText.chooseTutorialRoom: 'Choose tutorial room',
      AppText.next: 'Next',
      AppText.back: 'Back',
      AppText.finish: 'Import',
      AppText.noTimetable: 'Import your exported schedule.xls.\nYour timetable stays on this device.',
      AppText.exportFailed: 'Export failed',
    },
    'zh': {
      AppText.appTitle: 'PKU Manager',
      AppText.timetable: '课程表',
      AppText.settings: '设置',
      AppText.import: '导入',
      AppText.export: '导出',
      AppText.exportPng: '导出 PNG',
      AppText.exportXlsx: '导出 XLSX',
      AppText.rollColors: '更换配色',
      AppText.weekUnavailable: '周次不可用',
      AppText.week: '第',
      AppText.odd: '单周',
      AppText.even: '双周',
      AppText.previousDay: '前一天',
      AppText.nextDay: '后一天',
      AppText.courseDetails: '课程信息',
      AppText.course: '课程',
      AppText.room: '教室',
      AppText.weekday: '星期',
      AppText.firstPeriod: '开始节次',
      AppText.lastPeriod: '结束节次',
      AppText.frequency: '频率',
      AppText.notes: '备注',
      AppText.exam: '考试',
      AppText.completeInformation: '补全信息',
      AppText.sourceUnchanged: '原始工作簿不会改变。请补全全部必填信息，或拒绝本次导入。',
      AppText.rejectIgnore: '拒绝并忽略',
      AppText.required: '必填',
      AppText.enterRange: '请输入范围内的值',
      AppText.lastBeforeFirst: '结束节次不能早于开始节次',
      AppText.save: '保存',
      AppText.cancel: '取消',
      AppText.remove: '删除',
      AppText.theme: '主题',
      AppText.accentColor: '强调色',
      AppText.language: '语言',
      AppText.korean: '한국어',
      AppText.english: 'English',
      AppText.chinese: '简体中文',
      AppText.editCourse: '编辑课程',
      AppText.addCourse: '添加课程',
      AppText.chooseTutorialRoom: '选择习题课教室',
      AppText.next: '下一项',
      AppText.back: '上一项',
      AppText.finish: '导入',
      AppText.noTimetable: '请导入已导出的 schedule.xls。\n课程表仅保存在此设备上。',
      AppText.exportFailed: '导出失败',
    },
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      const {'ko', 'en', 'zh'}.contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
