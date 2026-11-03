#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* window_channel;
  // Closing the window hides it so that reminders keep working.
  gboolean hide_on_close;
  // Started with --background (session autostart): no window at first.
  gboolean start_hidden;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  if (!self->start_hidden) {
    gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  }
}

static gboolean window_delete_cb(GtkWidget* widget, GdkEvent* event,
                                 MyApplication* self) {
  if (self->hide_on_close) {
    gtk_widget_hide(widget);
    return TRUE;
  }
  return FALSE;
}

// Messages from Dart on "org.poulapp.poulplan/window":
// setHideOnClose(bool), show(), quit().
static void window_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(method, "setHideOnClose") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    self->hide_on_close = fl_value_get_type(args) == FL_VALUE_TYPE_BOOL &&
                          fl_value_get_bool(args);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "show") == 0) {
    self->start_hidden = FALSE;
    gtk_window_present(self->window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "quit") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(call, response, nullptr);
    g_application_quit(G_APPLICATION(self));
    return;
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Single instance: launching Poulplan again shows the running one.
  if (self->window != nullptr) {
    self->start_hidden = FALSE;
    gtk_window_present(self->window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Always keep the system title bar (server-side decorations on KDE
  // Plasma/Wayland): client-side header bars caused issues in Poulpoints.
  gtk_window_set_title(window, "Poulplan");

  // Window icon for X11; on Wayland the compositor uses the .desktop file
  // matching the application id.
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  g_autofree gchar* icon_path =
      g_build_filename(exe_dir, "data", "flutter_assets", "assets", "branding",
                       "poulplan-logo.png", nullptr);
  gtk_window_set_icon_from_file(window, icon_path, nullptr);

  gtk_window_set_default_size(window, 1280, 720);
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_cb), self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "org.poulapp.poulplan/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  for (gchar** arg = *arguments + 1; *arg != nullptr; arg++) {
    if (g_strcmp0(*arg, "--background") == 0) self->start_hidden = TRUE;
  }

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  // In a second instance, this asks the running one to show its window.
  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  // Unique application: a second launch activates the running instance
  // (which may be running hidden, for reminders).
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_DEFAULT_FLAGS, nullptr));
}
