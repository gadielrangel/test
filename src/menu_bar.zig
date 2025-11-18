const std = @import("std");
const builtin = @import("builtin");

pub const menu = @import("menu.zig");

/// Comptime platform selection (Ghostty pattern)
/// At compile time, select the appropriate backend based on the OS
pub const backend = switch (builtin.os.tag) {
    .linux => @import("backend/gtk.zig"),
    // Future platform support can be added here:
    // .macos => @import("backend/cocoa.zig"),
    // .windows => @import("backend/win32.zig"),
    else => @compileError("Platform not supported. Only Linux is currently supported. " ++
        "To add support for your platform, implement a backend for " ++ @tagName(builtin.os.tag)),
};

pub const Menu = menu.Menu;
pub const MenuItem = menu.MenuItem;
pub const MenuItemKind = menu.MenuItemKind;
pub const Shortcut = menu.Shortcut;
pub const Modifiers = menu.Modifiers;
pub const MenuItemCallback = menu.MenuItemCallback;

/// MenuBar is the top-level container for menus
/// Following macOS convention, the first menu is typically the application menu
pub const MenuBar = struct {
    menus: std.ArrayList(*Menu),
    allocator: std.mem.Allocator,
    backend_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator) MenuBar {
        return .{
            .menus = std.ArrayList(*Menu).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MenuBar) void {
        for (self.menus.items) |m| {
            m.deinit();
            self.allocator.destroy(m);
        }
        self.menus.deinit();
    }

    pub fn addMenu(self: *MenuBar, menu_ptr: *Menu) !void {
        try self.menus.append(menu_ptr);
    }

    /// Create and add a new menu
    pub fn createMenu(self: *MenuBar, title: []const u8) !*Menu {
        const menu_ptr = try self.allocator.create(Menu);
        errdefer self.allocator.destroy(menu_ptr);
        menu_ptr.* = Menu.init(self.allocator, title);
        try self.addMenu(menu_ptr);
        return menu_ptr;
    }
};

/// Builder pattern for creating menu bars (inspired by Zed's clean API)
pub const Builder = struct {
    menubar: MenuBar,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{ .menubar = MenuBar.init(allocator) };
    }

    pub fn withAppMenu(self: *Builder, app_name: []const u8) !*Menu {
        return try self.menubar.createMenu(app_name);
    }

    pub fn withMenu(self: *Builder, title: []const u8) !*Menu {
        return try self.menubar.createMenu(title);
    }

    pub fn build(self: *Builder) MenuBar {
        return self.menubar;
    }
};

// ============================================================================
// COMPREHENSIVE TEST SUITE
// ============================================================================

test "menubar creation" {
    const allocator = std.testing.allocator;

    var builder = Builder.init(allocator);
    var menubar = builder.build();
    defer menubar.deinit();

    var file_menu = try menubar.createMenu("File");
    try file_menu.addItem(MenuItem.normal("New"));
    try file_menu.addItem(MenuItem.normal("Open"));

    try std.testing.expectEqual(@as(usize, 1), menubar.menus.items.len);
    try std.testing.expectEqual(@as(usize, 2), file_menu.items.items.len);
}

test "menubar with multiple menus" {
    const allocator = std.testing.allocator;

    var menubar = MenuBar.init(allocator);
    defer menubar.deinit();

    _ = try menubar.createMenu("File");
    _ = try menubar.createMenu("Edit");
    _ = try menubar.createMenu("View");

    try std.testing.expectEqual(@as(usize, 3), menubar.menus.items.len);
}

test "builder pattern usage" {
    const allocator = std.testing.allocator;

    var builder = Builder.init(allocator);

    // Create app menu
    const app_menu = try builder.withAppMenu("MyApp");
    try app_menu.addItem(MenuItem.normal("About"));
    try app_menu.addSeparator();
    try app_menu.addItem(MenuItem.normal("Quit"));

    // Create additional menus
    const file_menu = try builder.withMenu("File");
    try file_menu.addItem(MenuItem.normal("New"));

    var menubar = builder.build();
    defer menubar.deinit();

    try std.testing.expectEqual(@as(usize, 2), menubar.menus.items.len);
}

test "menubar with nested submenus" {
    const allocator = std.testing.allocator;

    var menubar = MenuBar.init(allocator);
    defer menubar.deinit();

    const file_menu = try menubar.createMenu("File");

    // Create submenu
    const export_menu = try allocator.create(Menu);
    export_menu.* = Menu.init(allocator, "Export");
    try export_menu.addItem(MenuItem.normal("As PDF"));
    try export_menu.addItem(MenuItem.normal("As HTML"));

    try file_menu.addItem(MenuItem.submenu("Export", export_menu));

    try std.testing.expectEqual(@as(usize, 1), menubar.menus.items.len);
    try std.testing.expectEqual(@as(usize, 1), file_menu.items.items.len);
}
