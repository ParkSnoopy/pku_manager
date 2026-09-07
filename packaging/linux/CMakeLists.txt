cmake_minimum_required(VERSION 3.20)
project(PkuAppImage NONE)
set(BUNDLE "${CMAKE_CURRENT_SOURCE_DIR}/../../build/linux/x64/release/bundle" CACHE PATH "Flutter release bundle")
find_program(APPIMAGETOOL appimagetool REQUIRED)
set(RUNTIME "" CACHE FILEPATH "Checksum-verified AppImage runtime")
if(NOT EXISTS "${RUNTIME}")
  message(FATAL_ERROR "Supply a checksum-verified runtime with -DRUNTIME=...")
endif()
set(APPDIR "${CMAKE_CURRENT_BINARY_DIR}/PKUManager.AppDir")
add_custom_target(appimage
  COMMAND ${CMAKE_COMMAND} -E rm -rf "${APPDIR}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${APPDIR}"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${BUNDLE}" "${APPDIR}"
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/AppRun" "${APPDIR}/AppRun"
  COMMAND chmod +x "${APPDIR}/AppRun"
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/pku_manager.desktop" "${APPDIR}/pku_manager.desktop"
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/../../linux/runner/resources/pku_manager.svg" "${APPDIR}/pku_manager.svg"
  COMMAND ${CMAKE_COMMAND} -E env ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "${APPIMAGETOOL}" --runtime-file "${RUNTIME}" "${APPDIR}" "${CMAKE_CURRENT_BINARY_DIR}/pku-manager.AppImage"
  VERBATIM)
