# Zig Menu Bar for Linux

A macOS-style menu bar implementation in Zig for Linux, following patterns from TigerBeetle, Ghostty, Zed, and macOS.

## Design Principles

This implementation follows modern Zig patterns and best practices:

### 1. Comptime Interfaces (Ghostty Pattern)
- Zero runtime overhead for platform abstraction
- Backend implementation determined at compile time
- Type-safe platform-specific code

### 2. Memory Safety (TigerBeetle Pattern)
- Explicit allocators - no hidden allocations
- Clear ownership semantics
- RAII-style resource management with `init()`/`deinit()`

### 3. Type Safety
- Strong typing throughout
- Explicit error handling with Zig's error unions
- No null pointers - using optionals where needed

### 4. Clean API (Zed Pattern)
- Builder pattern for ergonomic menu construction
- Method chaining for fluent interface
- Intuitive naming following macOS conventions

### 5. macOS-Style Features
- Application menu (first menu with app name)
- Standard menu structure (File, Edit, View, Window, Help)
- Keyboard shortcuts with modifiers
- Checkable menu items
- Separators
- Submenus
- Enabled/disabled states

## Architecture

```
src/
  menu_bar.zig        # Core menu bar types (platform-agnostic)
  menu.zig            # Menu and MenuItem types
  backend/
    gtk.zig           # GTK3 backend for Linux
examples/
  basic.zig           # Demo application
```

### Platform Abstraction

Following Ghostty's approach, the core menu data structures are platform-agnostic:
- `Menu` - A menu containing items
- `MenuItem` - Individual menu items (normal, separator, checkbox, submenu)
- `Shortcut` - Keyboard shortcuts with modifiers
- `MenuBar` - Top-level menu bar container

The GTK backend provides Linux-specific rendering and event handling while keeping the core API clean and portable.

## Features

- **Menu Types**
  - Normal menu items with callbacks
  - Separators for visual grouping
  - Checkable items (show/hide toggles)
  - Submenus for hierarchical organization

- **Keyboard Shortcuts**
  - macOS-style modifier keys (Command, Shift, Option, Control)
  - Mapped to Linux equivalents (Super, Shift, Alt, Control)
  - Visual display in menus

- **State Management**
  - Enable/disable menu items
  - Check/uncheck state for toggles
  - Callbacks with user data support

## Installation

### Prerequisites

- Zig 0.13.0 or later
- GTK3 development libraries

On Ubuntu/Debian:
```bash
sudo apt-get install libgtk-3-dev
```

On Fedora:
```bash
sudo dnf install gtk3-devel
```

On Arch:
```bash
sudo pacman -S gtk3
```

### Building

```bash
zig build
```

### Running the Example

```bash
zig build run
```

## Usage

### Basic Example

```zig
const std = @import("std");
const menubar = @import("menubar");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize GTK
    menubar.backend.init();

    // Create menu bar
    var mb = menubar.MenuBar.init(allocator);
    defer mb.deinit();

    // Add application menu
    const app_menu = try mb.createMenu("MyApp");
    try app_menu.addItem(menubar.MenuItem.normal("About MyApp"));
    try app_menu.addItem(menubar.MenuItem.normal("Quit").withShortcut(
        menubar.Shortcut.init("q", menubar.Modifiers.cmd)
    ));

    // Add File menu
    const file_menu = try mb.createMenu("File");
    try file_menu.addItem(menubar.MenuItem.normal("New").withShortcut(
        menubar.Shortcut.init("n", menubar.Modifiers.cmd)
    ));
    try file_menu.addItem(menubar.MenuItem.normal("Open").withShortcut(
        menubar.Shortcut.init("o", menubar.Modifiers.cmd)
    ));
    try file_menu.addSeparator();
    try file_menu.addItem(menubar.MenuItem.normal("Save").withShortcut(
        menubar.Shortcut.init("s", menubar.Modifiers.cmd)
    ));

    // Create GTK backend
    var backend = try menubar.backend.GtkBackend.createFromMenuBar(allocator, &mb);
    defer backend.deinit();

    // Create and show window
    const window = menubar.backend.createWindowWithMenuBar("My App", &backend);
    menubar.backend.showAll(window);
    menubar.backend.run();
}
```

### Menu Items with Callbacks

```zig
fn onSave(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Save clicked!\n", .{});
}

// In your menu setup:
try file_menu.addItem(
    menubar.MenuItem.normalWithCallback("Save", onSave)
        .withShortcut(menubar.Shortcut.init("s", menubar.Modifiers.cmd))
);
```

### Checkable Items

```zig
fn onToggleSidebar(user_data: ?*anyopaque) void {
    _ = user_data;
    std.debug.print("Sidebar toggled!\n", .{});
}

try view_menu.addItem(
    menubar.MenuItem.checkboxWithCallback("Show Sidebar", true, onToggleSidebar)
);
```

### Submenus

```zig
// Create submenu
const submenu_ptr = try allocator.create(menubar.Menu);
submenu_ptr.* = menubar.Menu.init(allocator, "Export");
try submenu_ptr.addItem(menubar.MenuItem.normal("As PDF"));
try submenu_ptr.addItem(menubar.MenuItem.normal("As HTML"));

// Add to parent menu
try file_menu.addItem(menubar.MenuItem.submenu("Export", submenu_ptr));
```

### Keyboard Shortcuts

```zig
// Predefined modifier combinations
const Modifiers = menubar.Modifiers;

// Command (Super on Linux)
.withShortcut(menubar.Shortcut.init("s", Modifiers.cmd))

// Command + Shift
.withShortcut(menubar.Shortcut.init("s", Modifiers.cmdShift))

// Command + Option (Alt)
.withShortcut(menubar.Shortcut.init("s", Modifiers.cmdOption))

// Custom combinations
.withShortcut(menubar.Shortcut.init("x", .{
    .command = true,
    .shift = true,
    .option = false,
    .control = false,
}))
```

## API Reference

### MenuBar

```zig
pub const MenuBar = struct {
    pub fn init(allocator: std.mem.Allocator) MenuBar
    pub fn deinit(self: *MenuBar) void
    pub fn addMenu(self: *MenuBar, menu_ptr: *Menu) !void
    pub fn createMenu(self: *MenuBar, title: []const u8) !*Menu
}
```

### Menu

```zig
pub const Menu = struct {
    pub fn init(allocator: std.mem.Allocator, title: []const u8) Menu
    pub fn deinit(self: *Menu) void
    pub fn addItem(self: *Menu, item: MenuItem) !void
    pub fn addSeparator(self: *Menu) !void
}
```

### MenuItem

```zig
pub const MenuItem = struct {
    // Constructors
    pub fn normal(title: []const u8) MenuItem
    pub fn normalWithCallback(title: []const u8, callback: MenuItemCallback) MenuItem
    pub fn separator() MenuItem
    pub fn checkbox(title: []const u8, checked: bool) MenuItem
    pub fn checkboxWithCallback(title: []const u8, checked: bool, callback: MenuItemCallback) MenuItem
    pub fn submenu(title: []const u8, submenu: *Menu) MenuItem

    // Modifiers
    pub fn withShortcut(self: MenuItem, shortcut: Shortcut) MenuItem
    pub fn disabled(self: MenuItem) MenuItem
}
```

### Modifiers

```zig
pub const Modifiers = packed struct {
    command: bool = false,  // Super/Meta on Linux
    shift: bool = false,
    option: bool = false,   // Alt on Linux
    control: bool = false,

    pub const cmd = Modifiers{ .command = true };
    pub const cmdShift = Modifiers{ .command = true, .shift = true };
    pub const cmdOption = Modifiers{ .command = true, .option = true };
}
```

## Patterns from Referenced Projects

### TigerBeetle
- **Memory safety**: Explicit allocators everywhere
- **Error handling**: All errors explicit in function signatures
- **No hidden costs**: No hidden allocations or runtime overhead

### Ghostty
- **Comptime interfaces**: Platform abstraction without runtime cost
- **Modular architecture**: Separation of core logic from platform code
- **Clean abstractions**: Simple, focused types

### Zed
- **Builder patterns**: Fluent API for construction
- **Method chaining**: Ergonomic interface design

### macOS
- **Menu structure**: Application menu, standard menus
- **Keyboard shortcuts**: Modifier key combinations
- **Visual design**: Separators, checkmarks, submenus

## Testing

Run the test suite:

```bash
zig build test
```

## License

This project is provided as an example implementation. Use as you see fit.

## Contributing

This is a demonstration project. Feel free to fork and adapt for your needs.

## Platform Support

Currently supports:
- **Linux**: GTK3 backend

Future possibilities:
- GTK4 backend
- Wayland-native implementation
- Additional Linux desktop environments

Following Ghostty's pattern, adding new backends is straightforward due to the platform-agnostic core design.
