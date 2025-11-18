const std = @import("std");
pub const menu = @import("menu.zig");
pub const backend = @import("backend/gtk.zig");

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
