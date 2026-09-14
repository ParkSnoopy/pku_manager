#include "my_application.h"

int main(int argc, char** argv) {
  const gchar* backend = g_getenv("GDK_BACKEND");
  const gchar* x_display = g_getenv("DISPLAY");
  const gchar* wayland_display = g_getenv("WAYLAND_DISPLAY");
  if ((backend == nullptr || *backend == '\0') && x_display != nullptr &&
      *x_display != '\0' && wayland_display != nullptr &&
      *wayland_display != '\0') {
    g_setenv("GDK_BACKEND", "x11", FALSE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
