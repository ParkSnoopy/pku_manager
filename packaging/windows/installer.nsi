!define APP_ICON "..\..\windows\runner\resources\app_icon.ico"
!define MUI_ICON "${APP_ICON}"
!define MUI_UNICON "${APP_ICON}"
!include "MUI2.nsh"
!ifndef BUNDLE
!define BUNDLE "..\..\build\windows\x64\runner\Release"
!endif
!ifndef VERSION
!error "VERSION is required"
!endif
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\PKU Manager"
Name "PKU Manager"
OutFile "pku-manager-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\PKU Manager"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetOverwrite on
Icon "${APP_ICON}"
UninstallIcon "${APP_ICON}"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "CompanyName" "ParkSnoopy"
VIAddVersionKey "FileDescription" "PKU Manager installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2026 ParkSnoopy. All rights reserved."
VIAddVersionKey "ProductName" "PKU Manager"
VIAddVersionKey "ProductVersion" "${VERSION}"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetShellVarContext current
  IfFileExists "$INSTDIR\pku_manager.exe" 0 install_payload
  ClearErrors
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\pku_manager.exe"
  IfErrors 0 install_payload
  Abort "Close PKU Manager before updating."
install_payload:
  SetOutPath "$INSTDIR"
  File /r "${BUNDLE}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\PKU Manager"
  CreateShortcut "$SMPROGRAMS\PKU Manager\PKU Manager.lnk" "$INSTDIR\pku_manager.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "PKU Manager"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "ParkSnoopy"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\pku_manager.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  Delete "$SMPROGRAMS\PKU Manager\PKU Manager.lnk"
  RMDir "$SMPROGRAMS\PKU Manager"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\pku_manager.exe"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  ; Application-support SQLite data is deliberately retained.
SectionEnd
