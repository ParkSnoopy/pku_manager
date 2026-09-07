!include "MUI2.nsh"
!ifndef BUNDLE
!define BUNDLE "..\..\build\windows\x64\runner\Release"
!endif
Name "PKU Manager"
OutFile "pku-manager-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\PKU Manager"
RequestExecutionLevel user
SetCompressor /SOLID lzma
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${BUNDLE}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\PKU Manager"
  CreateShortcut "$SMPROGRAMS\PKU Manager\PKU Manager.lnk" "$INSTDIR\pku_manager.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PKU Manager" "DisplayName" "PKU Manager"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PKU Manager" "UninstallString" '$"$INSTDIR\Uninstall.exe$"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PKU Manager" "InstallLocation" "$INSTDIR"
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
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PKU Manager"
  ; Application-support SQLite data is deliberately retained.
SectionEnd
