cmake_minimum_required(VERSION 3.20)
project(PkuAppImage NONE)
set(BUNDLE "${CMAKE_CURRENT_SOURCE_DIR}/../../build/linux/x64/release/bundle" CACHE PATH "Flutter release bundle")
find_program(APPIMAGETOOL appimagetool REQUIRED)
set(RUNTIME "" CACHE FILEPATH "Checksum-verified AppImage runtime")
if(NOT EXISTS "${RUNTIME}")
  message(FATAL_ERROR "Supply a checksum-verified runtime with -DRUNTIME=...")
endif()
set(APPDIR "${CMAKE_CURRENT_BINARY_DIR}/PKUManager.AppDir")

function(find_portable_library variable soname)
  find_file(${variable}
    NAMES "${soname}"
    PATHS /usr/lib /lib
    PATH_SUFFIXES x86_64-linux-gnu
    REQUIRED)
endfunction()

find_portable_library(AYATANA_APPINDICATOR_LIBRARY libayatana-appindicator3.so.1)
find_portable_library(AYATANA_INDICATOR_LIBRARY libayatana-indicator3.so.7)
find_portable_library(AYATANA_IDO_LIBRARY libayatana-ido3-0.4.so.0)
find_portable_library(DBUSMENU_GLIB_LIBRARY libdbusmenu-glib.so.4)
find_portable_library(DBUSMENU_GTK_LIBRARY libdbusmenu-gtk3.so.4)
set(PORTABLE_LIBRARIES
  "${AYATANA_APPINDICATOR_LIBRARY}"
  "${AYATANA_INDICATOR_LIBRARY}"
  "${AYATANA_IDO_LIBRARY}"
  "${DBUSMENU_GLIB_LIBRARY}"
  "${DBUSMENU_GTK_LIBRARY}")
set(PORTABLE_LIBRARY_COPY_COMMANDS)
foreach(library IN LISTS PORTABLE_LIBRARIES)
  list(APPEND PORTABLE_LIBRARY_COPY_COMMANDS
    COMMAND ${CMAKE_COMMAND} -E copy "${library}" "${APPDIR}/lib/")
endforeach()

add_custom_target(appimage
  COMMAND ${CMAKE_COMMAND} -E rm -rf "${APPDIR}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${APPDIR}"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${BUNDLE}" "${APPDIR}"
  ${PORTABLE_LIBRARY_COPY_COMMANDS}
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/AppRun" "${APPDIR}/AppRun"
  COMMAND chmod +x "${APPDIR}/AppRun"
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/pku_manager.desktop" "${APPDIR}/pku_manager.desktop"
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/../../linux/runner/resources/pku_manager.svg" "${APPDIR}/pku_manager.svg"
  COMMAND ${CMAKE_COMMAND} -E env ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "${APPIMAGETOOL}" --runtime-file "${RUNTIME}" "${APPDIR}" "${CMAKE_CURRENT_BINARY_DIR}/pku-manager.AppImage"
  VERBATIM)
