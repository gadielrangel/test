const std = @import("std");
const menu_types = @import("../menu.zig");
const MenuBar = @import("../menu_bar.zig").MenuBar;
const Menu = menu_types.Menu;
const MenuItem = menu_types.MenuItem;
const MenuItemKind = menu_types.MenuItemKind;
const Modifiers = menu_types.Modifiers;

// GTK3 C bindings
pub const c = @cImport({
    @cInclude("gtk/gtk.h");
});

/// GTK-specific menu item data
const GtkMenuItemData = struct {
    callback: ?menu_types.MenuItemCallback,
    user_data: ?*anyopaque,
};

/// Context for GTK backend
pub const GtkBackend = struct {
    gtk_menubar: *c.GtkWidget,
    accel_group: *c.GtkAccelGroup,
    allocator: std.mem.Allocator,
    // Store callback data so it persists
    callback_data: std.ArrayList(*GtkMenuItemData),

    pub fn init(allocator: std.mem.Allocator) !GtkBackend {
        const menubar = c.gtk_menu_bar_new() orelse return error.GtkMenuBarCreationFailed;
        const accel_group = c.gtk_accel_group_new() orelse return error.GtkAccelGroupCreationFailed;

        return .{
            .gtk_menubar = menubar,
            .accel_group = accel_group,
            .allocator = allocator,
            .callback_data = std.ArrayList(*GtkMenuItemData).init(allocator),
        };
    }

    pub fn deinit(self: *GtkBackend) void {
        // Clean up callback data
        for (self.callback_data.items) |data| {
            self.allocator.destroy(data);
        }
        self.callback_data.deinit();

        // Unreference GTK objects (GTK uses reference counting)
        c.g_object_unref(self.accel_group);
        // Note: gtk_menubar is destroyed when the window is destroyed
    }

    pub fn createFromMenuBar(allocator: std.mem.Allocator, menubar: *MenuBar) !GtkBackend {
        var backend = try GtkBackend.init(allocator);
        errdefer backend.deinit();

        for (menubar.menus.items) |menu_ptr| {
            try backend.addMenu(menu_ptr);
        }

        menubar.backend_handle = backend.gtk_menubar;
        return backend;
    }

    fn addMenu(self: *GtkBackend, menu_ptr: *Menu) !void {
        const gtk_menu = c.gtk_menu_new() orelse return error.GtkMenuCreationFailed;

        // Create menu items
        for (menu_ptr.items.items) |item| {
            try self.addMenuItem(gtk_menu, &item);
        }

        // Create top-level menu item with null-terminated title
        const title_z = try self.allocator.dupeZ(u8, menu_ptr.title);
        defer self.allocator.free(title_z);

        const menu_item = c.gtk_menu_item_new_with_label(title_z.ptr) orelse
            return error.GtkMenuItemCreationFailed;

        c.gtk_menu_item_set_submenu(@ptrCast(menu_item), gtk_menu);
        c.gtk_menu_shell_append(@ptrCast(self.gtk_menubar), menu_item);
    }

    fn addMenuItem(self: *GtkBackend, gtk_menu: *c.GtkWidget, item: *const MenuItem) !void {
        switch (item.kind) {
            .separator => {
                const sep = c.gtk_separator_menu_item_new() orelse return error.GtkSeparatorCreationFailed;
                c.gtk_menu_shell_append(@ptrCast(gtk_menu), sep);
            },
            .normal => |normal| {
                const title_z = try self.allocator.dupeZ(u8, item.title);
                defer self.allocator.free(title_z);

                const gtk_item = c.gtk_menu_item_new_with_label(title_z.ptr) orelse
                    return error.GtkMenuItemCreationFailed;

                // Register accelerator if shortcut exists
                if (item.shortcut) |shortcut| {
                    try self.registerAccelerator(gtk_item, shortcut);
                }

                c.gtk_widget_set_sensitive(gtk_item, if (item.enabled) 1 else 0);

                if (normal.callback) |callback| {
                    const data = try self.allocator.create(GtkMenuItemData);
                    errdefer self.allocator.destroy(data);
                    data.* = .{
                        .callback = callback,
                        .user_data = null,
                    };
                    try self.callback_data.append(data);

                    _ = c.g_signal_connect_data(
                        gtk_item,
                        "activate",
                        @ptrCast(&menuItemActivated),
                        data,
                        null,
                        0,
                    );
                }

                c.gtk_menu_shell_append(@ptrCast(gtk_menu), gtk_item);
            },
            .checkbox => |checkbox| {
                const title_z = try self.allocator.dupeZ(u8, item.title);
                defer self.allocator.free(title_z);

                const gtk_item = c.gtk_check_menu_item_new_with_label(title_z.ptr) orelse
                    return error.GtkCheckMenuItemCreationFailed;

                c.gtk_check_menu_item_set_active(@ptrCast(gtk_item), if (checkbox.checked) 1 else 0);
                c.gtk_widget_set_sensitive(gtk_item, if (item.enabled) 1 else 0);

                if (checkbox.callback) |callback| {
                    const data = try self.allocator.create(GtkMenuItemData);
                    errdefer self.allocator.destroy(data);
                    data.* = .{
                        .callback = callback,
                        .user_data = null,
                    };
                    try self.callback_data.append(data);

                    _ = c.g_signal_connect_data(
                        gtk_item,
                        "toggled",
                        @ptrCast(&menuItemActivated),
                        data,
                        null,
                        0,
                    );
                }

                c.gtk_menu_shell_append(@ptrCast(gtk_menu), gtk_item);
            },
            .submenu => |submenu| {
                const gtk_submenu = c.gtk_menu_new() orelse return error.GtkMenuCreationFailed;

                for (submenu.menu.items.items) |subitem| {
                    try self.addMenuItem(gtk_submenu, &subitem);
                }

                const title_z = try self.allocator.dupeZ(u8, item.title);
                defer self.allocator.free(title_z);

                const gtk_item = c.gtk_menu_item_new_with_label(title_z.ptr) orelse
                    return error.GtkMenuItemCreationFailed;

                c.gtk_menu_item_set_submenu(@ptrCast(gtk_item), gtk_submenu);
                c.gtk_menu_shell_append(@ptrCast(gtk_menu), gtk_item);
            },
        }
    }

    /// Register a keyboard accelerator for a menu item
    fn registerAccelerator(self: *GtkBackend, gtk_item: *c.GtkWidget, shortcut: menu_types.Shortcut) !void {
        // Build accelerator string (e.g., "<Ctrl>O", "<Shift><Ctrl>S")
        var accel_buf: [128]u8 = undefined;
        var accel_len: usize = 0;

        // Bounds checking to prevent overflow
        const max_len = accel_buf.len - 1; // Reserve space for null terminator

        if (shortcut.modifiers.control and accel_len + 6 <= max_len) {
            @memcpy(accel_buf[accel_len..][0..6], "<Ctrl>");
            accel_len += 6;
        }
        if (shortcut.modifiers.shift and accel_len + 7 <= max_len) {
            @memcpy(accel_buf[accel_len..][0..7], "<Shift>");
            accel_len += 7;
        }
        if (shortcut.modifiers.option and accel_len + 5 <= max_len) {
            @memcpy(accel_buf[accel_len..][0..5], "<Alt>");
            accel_len += 5;
        }
        if (shortcut.modifiers.command and accel_len + 7 <= max_len) {
            @memcpy(accel_buf[accel_len..][0..7], "<Super>");
            accel_len += 7;
        }

        // Add key with bounds checking
        if (accel_len + shortcut.key.len <= max_len) {
            const key_upper = std.ascii.upperString(accel_buf[accel_len..][0..shortcut.key.len], shortcut.key);
            accel_len += key_upper.len;
        }

        // Ensure we have space for null terminator
        if (accel_len >= accel_buf.len) {
            return error.AcceleratorStringTooLong;
        }
        accel_buf[accel_len] = 0;

        // Parse accelerator string to get key and modifiers
        var accel_key: c.guint = 0;
        var accel_mods: c.GdkModifierType = 0;
        c.gtk_accelerator_parse(&accel_buf, &accel_key, &accel_mods);

        // Register the accelerator with the menu item
        if (accel_key != 0) {
            c.gtk_widget_add_accelerator(
                gtk_item,
                "activate",
                self.accel_group,
                accel_key,
                accel_mods,
                c.GTK_ACCEL_VISIBLE,
            );
        }
    }

    pub fn getWidget(self: *GtkBackend) *c.GtkWidget {
        return self.gtk_menubar;
    }
};

// Callback wrapper for menu item activation
fn menuItemActivated(widget: *c.GtkWidget, user_data: ?*anyopaque) callconv(.C) void {
    _ = widget;
    if (user_data) |data_ptr| {
        const data: *GtkMenuItemData = @ptrCast(@alignCast(data_ptr));
        if (data.callback) |callback| {
            callback(data.user_data);
        }
    }
}

/// Initialize GTK application
pub fn init() void {
    _ = c.gtk_init(null, null);
}

/// Create a simple window with a menu bar for testing
pub fn createWindowWithMenuBar(title: [:0]const u8, menubar: *GtkBackend) *c.GtkWidget {
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL) orelse @panic("Failed to create window");

    c.gtk_window_set_title(@ptrCast(window), title.ptr);
    c.gtk_window_set_default_size(@ptrCast(window), 800, 600);

    // Attach accelerator group to window (enables keyboard shortcuts)
    c.gtk_window_add_accel_group(@ptrCast(window), menubar.accel_group);

    // Create vertical box layout
    const vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0) orelse @panic("Failed to create box");

    // Add menu bar at the top
    c.gtk_box_pack_start(@ptrCast(vbox), menubar.getWidget(), 0, 0, 0);

    // Add some content area
    const label = c.gtk_label_new("Menu Bar Demo - Linux (macOS-style)") orelse @panic("Failed to create label");
    c.gtk_box_pack_start(@ptrCast(vbox), label, 1, 1, 0);

    c.gtk_container_add(@ptrCast(window), vbox);

    // Connect destroy signal
    _ = c.g_signal_connect_data(window, "destroy", @ptrCast(&c.gtk_main_quit), null, null, 0);

    return window;
}

/// Run the GTK main loop
pub fn run() void {
    c.gtk_main();
}

/// Show all widgets in a window
pub fn showAll(window: *c.GtkWidget) void {
    c.gtk_widget_show_all(window);
}
