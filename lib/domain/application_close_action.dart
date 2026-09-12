enum ApplicationCloseAction {
  closeApp('close'),
  exitToSystemTray('tray');

  const ApplicationCloseAction(this.code);

  final String code;

  static ApplicationCloseAction parse(String value) => values.firstWhere(
    (action) => action.code == value,
    orElse: () => closeApp,
  );
}
