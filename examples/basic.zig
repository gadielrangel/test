const std = @import("std");
const menubar = @import("menubar");

const Menu = menubar.Menu;
const MenuItem = menubar.MenuItem;
const MenuBar = menubar.MenuBar;
const Shortcut = menubar.Shortcut;
const Modifiers = menubar.Modifiers;
const gtk = menubar.backend;

// Callback functions
fn onNew(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("New file\n", .{});
}

fn onOpen(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Open file\n", .{});
}

fn onSave(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Save file\n", .{});
}

fn onQuit(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Quit application\n", .{});
    gtk.c.gtk_main_quit();
}

fn onUndo(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Undo\n", .{});
}

fn onRedo(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Redo\n", .{});
}

fn onCut(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Cut\n", .{});
}

fn onCopy(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Copy\n", .{});
}

fn onPaste(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Paste\n", .{});
}

fn onShowSidebar(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Toggle sidebar\n", .{});
}

fn onShowToolbar(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Toggle toolbar\n", .{});
}

fn onZoomIn(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Zoom in\n", .{});
}

fn onZoomOut(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Zoom out\n", .{});
}

fn onAbout(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("About this application\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize GTK
    gtk.init();

    // Create menu bar following macOS convention
    var mb = MenuBar.init(allocator);
    defer mb.deinit();

    // Application menu (first menu in macOS style)
    {
        const app_menu = try mb.createMenu("MyApp");
        try app_menu.addItem(MenuItem.normalWithCallback("About MyApp", onAbout));
        try app_menu.addSeparator();
        try app_menu.addItem(MenuItem.normal("Preferences").withShortcut(
            Shortcut.init(",", Modifiers.cmd),
        ).disabled());
        try app_menu.addSeparator();
        try app_menu.addItem(MenuItem.normalWithCallback("Quit MyApp", onQuit).withShortcut(
            Shortcut.init("q", Modifiers.cmd),
        ));
    }

    // File menu
    {
        const file_menu = try mb.createMenu("File");
        try file_menu.addItem(MenuItem.normalWithCallback("New", onNew).withShortcut(
            Shortcut.init("n", Modifiers.cmd),
        ));
        try file_menu.addItem(MenuItem.normalWithCallback("Open...", onOpen).withShortcut(
            Shortcut.init("o", Modifiers.cmd),
        ));
        try file_menu.addSeparator();
        try file_menu.addItem(MenuItem.normalWithCallback("Save", onSave).withShortcut(
            Shortcut.init("s", Modifiers.cmd),
        ));
        try file_menu.addItem(MenuItem.normal("Save As...").withShortcut(
            Shortcut.init("s", Modifiers.cmdShift),
        ));
        try file_menu.addSeparator();
        try file_menu.addItem(MenuItem.normal("Close Window").withShortcut(
            Shortcut.init("w", Modifiers.cmd),
        ));
    }

    // Edit menu
    {
        const edit_menu = try mb.createMenu("Edit");
        try edit_menu.addItem(MenuItem.normalWithCallback("Undo", onUndo).withShortcut(
            Shortcut.init("z", Modifiers.cmd),
        ));
        try edit_menu.addItem(MenuItem.normalWithCallback("Redo", onRedo).withShortcut(
            Shortcut.init("z", Modifiers.cmdShift),
        ));
        try edit_menu.addSeparator();
        try edit_menu.addItem(MenuItem.normalWithCallback("Cut", onCut).withShortcut(
            Shortcut.init("x", Modifiers.cmd),
        ));
        try edit_menu.addItem(MenuItem.normalWithCallback("Copy", onCopy).withShortcut(
            Shortcut.init("c", Modifiers.cmd),
        ));
        try edit_menu.addItem(MenuItem.normalWithCallback("Paste", onPaste).withShortcut(
            Shortcut.init("v", Modifiers.cmd),
        ));
        try edit_menu.addSeparator();
        try edit_menu.addItem(MenuItem.normal("Select All").withShortcut(
            Shortcut.init("a", Modifiers.cmd),
        ));
    }

    // View menu with checkboxes
    {
        const view_menu = try mb.createMenu("View");
        try view_menu.addItem(MenuItem.checkboxWithCallback("Show Sidebar", true, onShowSidebar).withShortcut(
            Shortcut.init("s", Modifiers.cmdOption),
        ));
        try view_menu.addItem(MenuItem.checkboxWithCallback("Show Toolbar", true, onShowToolbar));
        try view_menu.addSeparator();
        try view_menu.addItem(MenuItem.normalWithCallback("Zoom In", onZoomIn).withShortcut(
            Shortcut.init("+", Modifiers.cmd),
        ));
        try view_menu.addItem(MenuItem.normalWithCallback("Zoom Out", onZoomOut).withShortcut(
            Shortcut.init("-", Modifiers.cmd),
        ));
        try view_menu.addItem(MenuItem.normal("Actual Size").withShortcut(
            Shortcut.init("0", Modifiers.cmd),
        ));
    }

    // Window menu
    {
        const window_menu = try mb.createMenu("Window");
        try window_menu.addItem(MenuItem.normal("Minimize").withShortcut(
            Shortcut.init("m", Modifiers.cmd),
        ));
        try window_menu.addItem(MenuItem.normal("Zoom"));
        try window_menu.addSeparator();
        try window_menu.addItem(MenuItem.normal("Bring All to Front"));
    }

    // Help menu
    {
        const help_menu = try mb.createMenu("Help");
        try help_menu.addItem(MenuItem.normal("MyApp Help"));
        try help_menu.addSeparator();

        // Submenu example
        const submenu_ptr = try allocator.create(Menu);
        submenu_ptr.* = Menu.init(allocator, "More Resources");
        try submenu_ptr.addItem(MenuItem.normal("Documentation"));
        try submenu_ptr.addItem(MenuItem.normal("Community Forum"));
        try submenu_ptr.addItem(MenuItem.normal("Report Bug"));

        try help_menu.addItem(MenuItem.submenu("More Resources", submenu_ptr));
    }

    // Create GTK backend
    var backend = try gtk.GtkBackend.createFromMenuBar(allocator, &mb);
    defer backend.deinit();

    // Create window with menu bar
    const window = gtk.createWindowWithMenuBar("Menu Bar Example - macOS Style on Linux", &backend);
    gtk.showAll(window);

    std.debug.print("\n=== Menu Bar Demo ===\n", .{});
    std.debug.print("This demonstrates a macOS-like menu bar on Linux using GTK3\n", .{});
    std.debug.print("Features:\n", .{});
    std.debug.print("  - Application menu (MyApp)\n", .{});
    std.debug.print("  - Standard menus (File, Edit, View, Window, Help)\n", .{});
    std.debug.print("  - Keyboard shortcuts (displayed in menu)\n", .{});
    std.debug.print("  - Separators\n", .{});
    std.debug.print("  - Checkable items\n", .{});
    std.debug.print("  - Submenus\n", .{});
    std.debug.print("  - Disabled items\n", .{});
    std.debug.print("\nClick menu items to see console output!\n\n", .{});

    // Run the application
    gtk.run();
}
