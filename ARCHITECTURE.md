# Architecture

## Overview

This menu bar implementation follows modern Zig patterns inspired by high-quality projects like TigerBeetle, Ghostty, Zed, and macOS.

## Design Patterns

### 1. Comptime Platform Abstraction (Ghostty)

The core menu types are platform-agnostic, with backend-specific code isolated:

```zig
// Platform-agnostic core (src/menu.zig, src/menu_bar.zig)
pub const Menu = struct { ... };
pub const MenuItem = struct { ... };
pub const MenuBar = struct { ... };

// Platform-specific backend (src/backend/gtk.zig)
pub const GtkBackend = struct { ... };
```

This follows Ghostty's comptime interface pattern - the backend is determined at compile time with zero runtime overhead.

### 2. Memory Safety (TigerBeetle)

Every allocation is explicit and tracked:

```zig
// Explicit allocator parameter
pub fn init(allocator: std.mem.Allocator, title: []const u8) Menu

// Clear ownership with RAII
var menu = Menu.init(allocator, "File");
defer menu.deinit(); // Automatic cleanup
```

No hidden allocations. All memory management is visible to the caller.

### 3. Builder Pattern (Zed)

Fluent API for ergonomic menu construction:

```zig
try file_menu.addItem(
    MenuItem.normal("Save")
        .withShortcut(Shortcut.init("s", Modifiers.cmd))
        .disabled()
);
```

Method chaining makes complex menu structures readable and maintainable.

### 4. Type Safety

Strong typing throughout with explicit error handling:

```zig
// All possible menu item types enumerated
pub const MenuItemKind = union(enum) {
    normal: struct { callback: ?MenuItemCallback },
    separator,
    checkbox: struct { checked: bool, callback: ?MenuItemCallback },
    submenu: struct { menu: *Menu },
};

// Explicit error handling
pub fn addItem(self: *Menu, item: MenuItem) !void
```

### 5. Platform-Native Feel (macOS)

Keyboard shortcuts use macOS naming but map to Linux equivalents:

```zig
pub const Modifiers = packed struct {
    command: bool = false,  // -> Super/Meta on Linux
    shift: bool = false,
    option: bool = false,   // -> Alt on Linux
    control: bool = false,
};
```

This provides a familiar API while working correctly on Linux.

## Data Flow

1. **Menu Construction** (Platform-agnostic)
   ```
   User Code -> MenuBar.createMenu() -> Menu.addItem() -> MenuItem
   ```

2. **Backend Creation** (Platform-specific)
   ```
   MenuBar -> GtkBackend.createFromMenuBar() -> GTK C API
   ```

3. **Event Handling** (Platform-specific)
   ```
   GTK Event -> menuItemActivated() -> MenuItemCallback
   ```

## Memory Layout

```
MenuBar
├─ ArrayList(*Menu)          [heap-allocated]
│  ├─ Menu
│  │  ├─ ArrayList(MenuItem) [heap-allocated]
│  │  │  ├─ MenuItem (stack)
│  │  │  ├─ MenuItem (stack)
│  │  │  └─ ...
│  │  └─ ...
│  └─ ...
└─ backend_handle: ?*anyopaque [opaque pointer to GTK menubar]

GtkBackend
├─ gtk_menubar: *GtkWidget
└─ callback_data: ArrayList(*GtkMenuItemData) [heap-allocated]
```

## Error Handling

Following TigerBeetle's explicit error handling:

```zig
// Clear error propagation
pub fn createFromMenuBar(
    allocator: std.mem.Allocator,
    menubar: *MenuBar
) !GtkBackend {
    var backend = try init(allocator);
    errdefer backend.deinit(); // Cleanup on error

    for (menubar.menus.items) |menu_ptr| {
        try backend.addMenu(menu_ptr); // Propagate errors
    }

    return backend;
}
```

Errors are:
- Explicit in function signatures
- Propagated with `try`
- Cleaned up with `errdefer`

## GTK Integration

The GTK backend provides a thin wrapper around GTK3:

```zig
// Zig types -> GTK C types
MenuItem.normal -> gtk_menu_item_new_with_label()
MenuItem.separator -> gtk_separator_menu_item_new()
MenuItem.checkbox -> gtk_check_menu_item_new_with_label()
MenuItem.submenu -> gtk_menu_item_set_submenu()
```

Callbacks are wrapped to provide type-safe Zig interface:

```zig
// C callback signature
fn menuItemActivated(widget: *GtkWidget, user_data: ?*anyopaque) callconv(.C) void

// Calls Zig callback
pub const MenuItemCallback = *const fn (user_data: ?*anyopaque) void
```

## Modularity

The project is designed for easy extension:

1. **Add new menu item types**: Extend `MenuItemKind` union
2. **Add new backends**: Implement backend interface (e.g., GTK4, Wayland)
3. **Add features**: Extend core types without breaking existing code

## Testing Strategy

- Unit tests for core types (`menu.zig`, `menu_bar.zig`)
- Integration tests would require GTK (not in current test suite)
- Example application serves as integration test

## Performance Characteristics

- **Compile time**: Platform abstraction has zero runtime cost
- **Memory**: All allocations explicit, no hidden overhead
- **Callbacks**: Direct function pointers, no vtable overhead
- **GTK calls**: Thin wrapper, minimal Zig overhead

## Comparison to Referenced Projects

| Pattern | TigerBeetle | Ghostty | Zed | macOS | This Project |
|---------|-------------|---------|-----|-------|--------------|
| Memory Safety | Explicit allocators | ✓ | ✓ | N/A | ✓ |
| Comptime | ✓ | Interfaces | ✓ | N/A | Platform abstraction |
| Error Handling | Explicit | ✓ | ✓ | N/A | ✓ |
| Builder Pattern | Limited | Limited | ✓ | N/A | ✓ |
| Platform Native | N/A | ✓ | ✓ | ✓ | GTK on Linux |

## Future Enhancements

Potential additions following the established patterns:

1. **GTK4 backend**: Comptime switch between GTK3/GTK4
2. **Accelerator groups**: Full keyboard shortcut support
3. **Icons**: Menu item icons
4. **Dynamic menus**: Runtime menu modification
5. **Accessibility**: GTK accessibility features
6. **Themes**: Custom styling support
