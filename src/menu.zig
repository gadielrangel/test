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

    /// Create a submenu item
    /// IMPORTANT: The submenu pointer is consumed and will be deallocated
    /// when the parent menu calls deinit(). Do NOT manually destroy the submenu.
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

    /// Add or update callback for this menu item (method chaining)
    /// Works for normal and checkbox items, no-op for others
    pub fn withCallback(self: MenuItem, callback: MenuItemCallback) MenuItem {
        var item = self;
        switch (item.kind) {
            .normal => |*normal| normal.callback = callback,
            .checkbox => |*check| check.callback = callback,
            else => {},
        }
        return item;
    }

    pub fn disabled(self: MenuItem) MenuItem {
        var item = self;
        item.enabled = false;
        return item;
    }

    // Getter methods for state inspection
    pub fn isEnabled(self: *const MenuItem) bool {
        return self.enabled;
    }

    pub fn isChecked(self: *const MenuItem) bool {
        return switch (self.kind) {
            .checkbox => |c| c.checked,
            else => false,
        };
    }

    pub fn getCallback(self: *const MenuItem) ?MenuItemCallback {
        return switch (self.kind) {
            .normal => |n| n.callback,
            .checkbox => |c| c.callback,
            else => null,
        };
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
        // Recursively deinit and deallocate submenus
        // IMPORTANT: This assumes ownership of all submenu pointers
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

    /// Remove an item at the specified index
    /// Returns error.IndexOutOfBounds if index is invalid
    pub fn removeItem(self: *Menu, index: usize) !void {
        if (index >= self.items.items.len) {
            return error.IndexOutOfBounds;
        }

        // If removing a submenu, deinit and destroy it first
        const item = self.items.items[index];
        switch (item.kind) {
            .submenu => |submenu| {
                submenu.menu.deinit();
                self.allocator.destroy(submenu.menu);
            },
            else => {},
        }

        _ = self.items.orderedRemove(index);
    }

    /// Update an item at the specified index
    /// The old item is replaced; if it was a submenu, it is properly cleaned up
    pub fn updateItem(self: *Menu, index: usize, new_item: MenuItem) !void {
        if (index >= self.items.items.len) {
            return error.IndexOutOfBounds;
        }

        // Clean up old submenu if needed
        const old_item = self.items.items[index];
        switch (old_item.kind) {
            .submenu => |submenu| {
                submenu.menu.deinit();
                self.allocator.destroy(submenu.menu);
            },
            else => {},
        }

        self.items.items[index] = new_item;
    }

    /// Set enabled state for an item at the specified index
    pub fn setItemEnabled(self: *Menu, index: usize, enabled: bool) !void {
        if (index >= self.items.items.len) {
            return error.IndexOutOfBounds;
        }
        self.items.items[index].enabled = enabled;
    }

    /// Set checked state for a checkbox item at the specified index
    /// Returns error.NotACheckbox if the item is not a checkbox
    pub fn setItemChecked(self: *Menu, index: usize, checked: bool) !void {
        if (index >= self.items.items.len) {
            return error.IndexOutOfBounds;
        }

        switch (self.items.items[index].kind) {
            .checkbox => |*check| check.checked = checked,
            else => return error.NotACheckbox,
        }
    }

    /// Get the number of items in this menu
    pub fn itemCount(self: *const Menu) usize {
        return self.items.items.len;
    }

    /// Get an item at the specified index (read-only)
    pub fn getItem(self: *const Menu, index: usize) ?*const MenuItem {
        if (index >= self.items.items.len) {
            return null;
        }
        return &self.items.items[index];
    }
};

// ============================================================================
// COMPREHENSIVE TEST SUITE
// ============================================================================

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

test "MenuItem with callback" {
    const TestContext = struct {
        var called: bool = false;
        fn callback(_: ?*anyopaque) void {
            called = true;
        }
    };

    const item = MenuItem.normalWithCallback("Test", TestContext.callback);

    // Verify callback is set
    const callback = item.getCallback();
    try std.testing.expect(callback != null);

    // Invoke callback
    if (callback) |cb| {
        cb(null);
    }
    try std.testing.expect(TestContext.called);
}

test "MenuItem withCallback method chaining" {
    const TestContext = struct {
        fn callback(_: ?*anyopaque) void {}
    };

    var item = MenuItem.normal("Test")
        .withCallback(TestContext.callback)
        .withShortcut(Shortcut.init("t", Modifiers.cmd))
        .disabled();

    try std.testing.expect(item.getCallback() != null);
    try std.testing.expect(item.shortcut != null);
    try std.testing.expect(!item.isEnabled());
}

test "MenuItem checkbox state" {
    var item = MenuItem.checkbox("Show Sidebar", true);
    try std.testing.expect(item.isChecked());

    item = MenuItem.checkbox("Show Toolbar", false);
    try std.testing.expect(!item.isChecked());
}

test "MenuItem getters" {
    const item_enabled = MenuItem.normal("Test");
    try std.testing.expect(item_enabled.isEnabled());

    const item_disabled = MenuItem.normal("Test").disabled();
    try std.testing.expect(!item_disabled.isEnabled());

    const checkbox_checked = MenuItem.checkbox("Test", true);
    try std.testing.expect(checkbox_checked.isChecked());

    const checkbox_unchecked = MenuItem.checkbox("Test", false);
    try std.testing.expect(!checkbox_unchecked.isChecked());
}

test "Menu dynamic operations - remove item" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addItem(MenuItem.normal("New"));
    try menu.addItem(MenuItem.normal("Open"));
    try menu.addItem(MenuItem.normal("Save"));

    try std.testing.expectEqual(@as(usize, 3), menu.itemCount());

    // Remove middle item
    try menu.removeItem(1);
    try std.testing.expectEqual(@as(usize, 2), menu.itemCount());

    // Try to remove invalid index
    const result = menu.removeItem(10);
    try std.testing.expectError(error.IndexOutOfBounds, result);
}

test "Menu dynamic operations - update item" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addItem(MenuItem.normal("Old Name"));
    try std.testing.expectEqual(@as(usize, 1), menu.itemCount());

    // Update the item
    try menu.updateItem(0, MenuItem.normal("New Name"));

    const item = menu.getItem(0);
    try std.testing.expect(item != null);

    // Try to update invalid index
    const result = menu.updateItem(10, MenuItem.normal("Test"));
    try std.testing.expectError(error.IndexOutOfBounds, result);
}

test "Menu dynamic operations - set enabled" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addItem(MenuItem.normal("Test"));

    const item_before = menu.getItem(0);
    try std.testing.expect(item_before.?.isEnabled());

    // Disable the item
    try menu.setItemEnabled(0, false);

    const item_after = menu.getItem(0);
    try std.testing.expect(!item_after.?.isEnabled());
}

test "Menu dynamic operations - set checked" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "View");
    defer menu.deinit();

    try menu.addItem(MenuItem.checkbox("Show Sidebar", false));

    const item_before = menu.getItem(0);
    try std.testing.expect(!item_before.?.isChecked());

    // Check the item
    try menu.setItemChecked(0, true);

    const item_after = menu.getItem(0);
    try std.testing.expect(item_after.?.isChecked());

    // Try to check non-checkbox item
    try menu.addItem(MenuItem.normal("Not a checkbox"));
    const result = menu.setItemChecked(1, true);
    try std.testing.expectError(error.NotACheckbox, result);
}

test "Menu with submenu ownership" {
    const allocator = std.testing.allocator;

    var parent_menu = Menu.init(allocator, "File");
    defer parent_menu.deinit(); // This will also deinit the submenu

    // Create submenu (ownership will be transferred)
    const submenu_ptr = try allocator.create(Menu);
    submenu_ptr.* = Menu.init(allocator, "Export");
    try submenu_ptr.addItem(MenuItem.normal("As PDF"));
    try submenu_ptr.addItem(MenuItem.normal("As HTML"));

    try parent_menu.addItem(MenuItem.submenu("Export", submenu_ptr));

    try std.testing.expectEqual(@as(usize, 1), parent_menu.itemCount());

    // Note: Do NOT call allocator.destroy(submenu_ptr) here!
    // The parent menu owns it and will destroy it in deinit()
}

test "Keyboard modifiers" {
    const mod1 = Modifiers.cmd;
    try std.testing.expect(mod1.command);
    try std.testing.expect(!mod1.shift);
    try std.testing.expect(!mod1.option);
    try std.testing.expect(!mod1.control);

    const mod2 = Modifiers.cmdShift;
    try std.testing.expect(mod2.command);
    try std.testing.expect(mod2.shift);

    const mod3 = Modifiers.cmdOption;
    try std.testing.expect(mod3.command);
    try std.testing.expect(mod3.option);
}

test "Shortcut creation" {
    const shortcut = Shortcut.init("s", Modifiers.cmd);
    try std.testing.expectEqualStrings("s", shortcut.key);
    try std.testing.expect(shortcut.modifiers.command);
}

test "Menu edge cases - empty menu" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "Empty");
    defer menu.deinit();

    try std.testing.expectEqual(@as(usize, 0), menu.itemCount());

    const item = menu.getItem(0);
    try std.testing.expect(item == null);
}

test "Menu edge cases - separator only" {
    const allocator = std.testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addSeparator();
    try menu.addSeparator();

    try std.testing.expectEqual(@as(usize, 2), menu.itemCount());
}
