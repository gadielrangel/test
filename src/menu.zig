const std = @import("std");

/// Keyboard modifiers for menu shortcuts (macOS-style naming)
pub const Modifiers = packed struct {
    command: bool = false, // Super/Meta key on Linux
    shift: bool = false,
    option: bool = false, // Alt key on Linux
    control: bool = false,

    pub const none = Modifiers{};
    pub const cmd = Modifiers{ .command = true };
    pub const cmdShift = Modifiers{ .command = true, .shift = true };
    pub const cmdOption = Modifiers{ .command = true, .option = true };
};

/// Keyboard shortcut for a menu item
/// Note: The key string should be a short identifier (e.g., "s", "o", "q")
/// and must remain valid for the lifetime of the menu
pub const Shortcut = struct {
    key: []const u8,
    modifiers: Modifiers,

    pub fn init(key: []const u8, modifiers: Modifiers) Shortcut {
        return .{ .key = key, .modifiers = modifiers };
    }
};

/// Menu item callback function type
pub const MenuItemCallback = *const fn (user_data: ?*anyopaque) void;

/// Menu item type
pub const MenuItemKind = union(enum) {
    normal: struct {
        callback: ?MenuItemCallback = null,
    },
    separator,
    checkbox: struct {
        checked: bool,
        callback: ?MenuItemCallback = null,
    },
    submenu: struct {
        menu: *Menu,
    },
};

/// A single menu item
/// Note: The title string must remain valid for the lifetime of the menu item.
/// Typically use string literals which are compile-time constants.
pub const MenuItem = struct {
    title: []const u8,
    kind: MenuItemKind,
    shortcut: ?Shortcut = null,
    enabled: bool = true,

    pub fn normal(title: []const u8) MenuItem {
        return .{
            .title = title,
            .kind = .{ .normal = .{} },
        };
    }

    pub fn normalWithCallback(title: []const u8, callback: MenuItemCallback) MenuItem {
        return .{
            .title = title,
            .kind = .{ .normal = .{ .callback = callback } },
        };
    }

    pub fn separator() MenuItem {
        return .{
            .title = "",
            .kind = .separator,
        };
    }

    pub fn checkbox(title: []const u8, checked: bool) MenuItem {
        return .{
            .title = title,
            .kind = .{ .checkbox = .{ .checked = checked } },
        };
    }

    pub fn checkboxWithCallback(title: []const u8, checked: bool, callback: MenuItemCallback) MenuItem {
        return .{
            .title = title,
            .kind = .{ .checkbox = .{ .checked = checked, .callback = callback } },
        };
    }

    pub fn submenu(title: []const u8, submenu: *Menu) MenuItem {
        return .{
            .title = title,
            .kind = .{ .submenu = .{ .menu = submenu } },
        };
    }

    pub fn withShortcut(self: MenuItem, shortcut: Shortcut) MenuItem {
        var item = self;
        item.shortcut = shortcut;
        return item;
    }

    pub fn disabled(self: MenuItem) MenuItem {
        var item = self;
        item.enabled = false;
        return item;
    }
};

/// A menu containing multiple items
/// Note: The title string must remain valid for the lifetime of the menu.
/// Typically use string literals which are compile-time constants.
pub const Menu = struct {
    title: []const u8,
    items: std.ArrayList(MenuItem),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, title: []const u8) Menu {
        return .{
            .title = title,
            .items = std.ArrayList(MenuItem).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Menu) void {
        // Recursively deinit submenus
        for (self.items.items) |item| {
            switch (item.kind) {
                .submenu => |submenu| {
                    submenu.menu.deinit();
                    self.allocator.destroy(submenu.menu);
                },
                else => {},
            }
        }
        self.items.deinit();
    }

    pub fn addItem(self: *Menu, item: MenuItem) !void {
        try self.items.append(item);
    }

    pub fn addSeparator(self: *Menu) !void {
        try self.addItem(MenuItem.separator());
    }
};

test "menu creation" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addItem(MenuItem.normal("New"));
    try menu.addItem(MenuItem.normal("Open").withShortcut(Shortcut.init("o", Modifiers.cmd)));
    try menu.addSeparator();
    try menu.addItem(MenuItem.normal("Quit").withShortcut(Shortcut.init("q", Modifiers.cmd)));

    try std.testing.expectEqual(@as(usize, 4), menu.items.items.len);
}
