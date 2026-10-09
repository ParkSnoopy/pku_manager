#include "my_application.h"

int main(int argc, char** argv) {
  const gchar* backend = g_getenv("GDK_BACKEND");
  if (backend == nullptr || *backend == '\0') {
    g_setenv("GDK_BACKEND", "wayland,x11", FALSE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
