# Menu Bar Implementation Roadmap

## Overview

This document outlines the step-by-step implementation plan for building the complete macOS-style menu bar system on Linux as specified in `MENU_BAR_SPEC.md`.

---

## Architecture Layers

```
┌─────────────────────────────────────────┐
│         Application Layer               │  ← Your App
├─────────────────────────────────────────┤
│       Menu Bar API (Public)             │  ← Clean Zig API
├─────────────────────────────────────────┤
│      Core Menu System (Private)         │
│  ┌──────────┬──────────┬─────────────┐ │
│  │Validation│Shortcuts │ State Mgmt  │ │
│  └──────────┴──────────┴─────────────┘ │
├─────────────────────────────────────────┤
│    Platform Abstraction Layer           │
│  ┌──────────────────────────────────┐  │
│  │   Backend Interface (comptime)   │  │
│  └──────────────────────────────────┘  │
├─────────────────────────────────────────┤
│      Platform Backends                  │
│  ┌─────────┬──────────┬─────────────┐  │
│  │  GTK3   │   GTK4   │   Wayland   │  │
│  └─────────┴──────────┴─────────────┘  │
└─────────────────────────────────────────┘
```

---

## Phase 1: Foundation (Week 1-2)

### 1.1 Enhanced Core Types ✅ (Current Status)

**Completed**:
- [x] Basic Menu structure
- [x] MenuItem (normal, separator, checkbox, submenu)
- [x] MenuBar container
- [x] Modifiers and Shortcut types
- [x] GTK3 backend basics

**Remaining**:
```zig
// src/menu.zig additions needed

/// Radio button item group
pub const RadioGroup = struct {
    id: []const u8,
    selected_item: ?[]const u8,
    items: ArrayList(*MenuItem),

    pub fn select(self: *RadioGroup, item_id: []const u8) void {
        self.selected_item = item_id;
        // Update all items in group
        for (self.items.items) |item| {
            if (item.kind != .radio) continue;
            item.kind.radio.selected = std.mem.eql(u8, item.id, item_id);
        }
    }
};

/// Recent items manager
pub const RecentItems = struct {
    max_count: usize,
    items: RingBuffer(RecentItem),

    pub const RecentItem = struct {
        title: []const u8,
        data: *anyopaque,
        timestamp: i64,
    };

    pub fn add(self: *RecentItems, item: RecentItem) !void {
        try self.items.push(item);
    }

    pub fn getItems(self: *RecentItems) []RecentItem {
        return self.items.slice();
    }

    pub fn clear(self: *RecentItems) void {
        self.items.clear();
    }
};

/// Dynamic menu item generator
pub const DynamicGenerator = struct {
    generator_fn: *const fn(*anyopaque) anyerror![]MenuItem,
    context: *anyopaque,
    cache: ?[]MenuItem,
    cache_timestamp: i64,
    cache_duration_ms: i64,

    pub fn generate(self: *DynamicGenerator) ![]MenuItem {
        const now = std.time.milliTimestamp();

        if (self.cache) |cache| {
            if (now - self.cache_timestamp < self.cache_duration_ms) {
                return cache;
            }
        }

        self.cache = try self.generator_fn(self.context);
        self.cache_timestamp = now;
        return self.cache.?;
    }
};
```

### 1.2 Menu Item ID System

```zig
// src/menu_id.zig (new file)

/// Hierarchical menu item identifier
pub const MenuItemId = struct {
    path: []const u8,  // e.g., "file.recent.doc1"

    pub fn parse(path: []const u8) MenuItemId {
        return .{ .path = path };
    }

    pub fn parent(self: MenuItemId) ?MenuItemId {
        if (std.mem.lastIndexOf(u8, self.path, ".")) |idx| {
            return .{ .path = self.path[0..idx] };
        }
        return null;
    }

    pub fn leaf(self: MenuItemId) []const u8 {
        if (std.mem.lastIndexOf(u8, self.path, ".")) |idx| {
            return self.path[idx + 1..];
        }
        return self.path;
    }
};

/// Menu item registry for fast lookup
pub const MenuRegistry = struct {
    items: HashMap([]const u8, *MenuItem),
    menus: HashMap([]const u8, *Menu),

    pub fn register(self: *MenuRegistry, id: []const u8, item: *MenuItem) !void {
        try self.items.put(id, item);
    }

    pub fn find(self: *MenuRegistry, id: []const u8) ?*MenuItem {
        return self.items.get(id);
    }

    pub fn findMenu(self: *MenuRegistry, id: []const u8) ?*Menu {
        return self.menus.get(id);
    }
};
```

### 1.3 Validation System

```zig
// src/validation.zig (new file)

pub const ValidationContext = struct {
    // Application state
    has_document: bool,
    is_modified: bool,
    has_selection: bool,
    selection_type: ?SelectionType,

    // Clipboard state
    clipboard_has_content: bool,
    clipboard_type: ?[]const u8,

    // History state
    can_undo: bool,
    can_redo: bool,
    undo_action_name: ?[]const u8,
    redo_action_name: ?[]const u8,

    // Custom data
    user_data: ?*anyopaque,
};

pub const SelectionType = enum {
    none,
    text,
    image,
    file,
    mixed,
};

pub const ValidationResult = struct {
    enabled: bool = true,
    visible: bool = true,
    title: ?[]const u8 = null,
    checked: ?bool = null,
    badge: ?[]const u8 = null,
    icon: ?[]const u8 = null,
};

pub const Validator = struct {
    validate_fn: *const fn(*MenuItem, *ValidationContext) ValidationResult,

    pub fn validate(
        self: *Validator,
        item: *MenuItem,
        context: *ValidationContext
    ) ValidationResult {
        return self.validate_fn(item, context);
    }
};

// Common validators
pub fn hasDocumentValidator(item: *MenuItem, ctx: *ValidationContext) ValidationResult {
    _ = item;
    return .{ .enabled = ctx.has_document };
}

pub fn hasModifiedDocumentValidator(item: *MenuItem, ctx: *ValidationContext) ValidationResult {
    _ = item;
    return .{ .enabled = ctx.has_document and ctx.is_modified };
}

pub fn hasSelectionValidator(item: *MenuItem, ctx: *ValidationContext) ValidationResult {
    _ = item;
    return .{ .enabled = ctx.has_selection };
}

pub fn hasClipboardValidator(item: *MenuItem, ctx: *ValidationContext) ValidationResult {
    _ = item;
    return .{ .enabled = ctx.clipboard_has_content };
}

pub fn undoValidator(item: *MenuItem, ctx: *ValidationContext) ValidationResult {
    _ = item;
    var result = ValidationResult{ .enabled = ctx.can_undo };

    if (ctx.undo_action_name) |name| {
        var buf: [256]u8 = undefined;
        const title = std.fmt.bufPrint(&buf, "Undo {s}", .{name}) catch "Undo";
        result.title = title;
    }

    return result;
}
```

---

## Phase 2: Enhanced Interaction (Week 3-4)

### 2.1 Keyboard Navigation System

```zig
// src/keyboard.zig (new file)

pub const KeyboardNavigator = struct {
    menubar: *MenuBar,
    active_menu: ?*Menu,
    highlighted_item: ?*MenuItem,
    keyboard_mode: bool,
    type_ahead_buffer: ArrayList(u8),
    type_ahead_timer: i64,

    pub fn init(allocator: Allocator, menubar: *MenuBar) KeyboardNavigator {
        return .{
            .menubar = menubar,
            .active_menu = null,
            .highlighted_item = null,
            .keyboard_mode = false,
            .type_ahead_buffer = ArrayList(u8).init(allocator),
            .type_ahead_timer = 0,
        };
    }

    pub fn handleKey(self: *KeyboardNavigator, key: KeyEvent) !void {
        switch (key) {
            .F10, .Alt => try self.enterKeyboardMode(),
            .Escape => try self.exitKeyboardMode(),
            .ArrowLeft => try self.navigateLeft(),
            .ArrowRight => try self.navigateRight(),
            .ArrowUp => try self.navigateUp(),
            .ArrowDown => try self.navigateDown(),
            .Enter, .Space => try self.activate(),
            .Character => |char| try self.typeAhead(char),
            else => {},
        }
    }

    fn enterKeyboardMode(self: *KeyboardNavigator) !void {
        self.keyboard_mode = true;
        // Highlight first menu
        if (self.menubar.menus.items.len > 0) {
            self.active_menu = self.menubar.menus.items[0];
        }
    }

    fn typeAhead(self: *KeyboardNavigator, char: u8) !void {
        const now = std.time.milliTimestamp();

        // Clear buffer if timeout exceeded
        if (now - self.type_ahead_timer > 1000) {
            self.type_ahead_buffer.clearRetainingCapacity();
        }

        try self.type_ahead_buffer.append(char);
        self.type_ahead_timer = now;

        // Search for matching item
        if (self.active_menu) |menu| {
            const search_term = self.type_ahead_buffer.items;
            for (menu.items.items) |*item| {
                if (std.ascii.startsWithIgnoreCase(item.title, search_term)) {
                    self.highlighted_item = item;
                    break;
                }
            }
        }
    }
};

pub const KeyEvent = union(enum) {
    F10,
    Alt,
    Escape,
    ArrowLeft,
    ArrowRight,
    ArrowUp,
    ArrowDown,
    Enter,
    Space,
    Character: u8,
    Shortcut: Shortcut,
};
```

### 2.2 Shortcut System

```zig
// src/shortcuts.zig (new file)

pub const ShortcutManager = struct {
    shortcuts: HashMap(ShortcutKey, ShortcutAction),
    registry: *MenuRegistry,
    allocator: Allocator,

    pub const ShortcutKey = struct {
        modifiers: Modifiers,
        key: []const u8,

        pub fn hash(self: ShortcutKey) u64 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(@as([]const u8, @ptrCast(&self.modifiers)));
            hasher.update(self.key);
            return hasher.final();
        }

        pub fn eql(a: ShortcutKey, b: ShortcutKey) bool {
            return std.meta.eql(a.modifiers, b.modifiers) and
                   std.mem.eql(u8, a.key, b.key);
        }
    };

    pub const ShortcutAction = struct {
        item_id: []const u8,
        callback: ?MenuItemCallback,
    };

    pub fn register(
        self: *ShortcutManager,
        shortcut: Shortcut,
        item_id: []const u8,
        callback: ?MenuItemCallback
    ) !void {
        const key = ShortcutKey{
            .modifiers = shortcut.modifiers,
            .key = try self.allocator.dupe(u8, shortcut.key),
        };

        const action = ShortcutAction{
            .item_id = item_id,
            .callback = callback,
        };

        try self.shortcuts.put(key, action);
    }

    pub fn handleShortcut(
        self: *ShortcutManager,
        modifiers: Modifiers,
        key: []const u8
    ) bool {
        const shortcut_key = ShortcutKey{
            .modifiers = modifiers,
            .key = key,
        };

        if (self.shortcuts.get(shortcut_key)) |action| {
            if (action.callback) |callback| {
                callback(null);
                return true;
            }
        }

        return false;
    }

    pub fn findConflicts(self: *ShortcutManager, shortcut: Shortcut) []ShortcutAction {
        var conflicts = ArrayList(ShortcutAction).init(self.allocator);

        const key = ShortcutKey{
            .modifiers = shortcut.modifiers,
            .key = shortcut.key,
        };

        var iter = self.shortcuts.iterator();
        while (iter.next()) |entry| {
            if (ShortcutKey.eql(entry.key_ptr.*, key)) {
                try conflicts.append(entry.value_ptr.*);
            }
        }

        return conflicts.toOwnedSlice();
    }
};
```

---

## Phase 3: Advanced Features (Week 5-6)

### 3.1 Configuration System

```zig
// src/config.zig (new file)

const yaml = @import("yaml");  // External dependency

pub const ConfigLoader = struct {
    allocator: Allocator,

    pub fn loadFromFile(self: *ConfigLoader, path: []const u8) !MenuBarConfig {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        return try self.parseYAML(content);
    }

    pub fn parseYAML(self: *ConfigLoader, content: []const u8) !MenuBarConfig {
        var config = MenuBarConfig.init(self.allocator);

        const doc = try yaml.parse(self.allocator, content);
        defer doc.deinit();

        // Parse menus
        if (doc.get("menus")) |menus_node| {
            for (menus_node.array()) |menu_node| {
                const menu = try self.parseMenu(menu_node);
                try config.menus.append(menu);
            }
        }

        // Parse shortcuts
        if (doc.get("shortcuts")) |shortcuts_node| {
            var iter = shortcuts_node.object();
            while (iter.next()) |entry| {
                const shortcut = try Shortcut.parse(entry.key);
                const action_id = entry.value.string();
                try config.shortcuts.put(shortcut, action_id);
            }
        }

        // Parse settings
        if (doc.get("settings")) |settings_node| {
            config.settings = try self.parseSettings(settings_node);
        }

        return config;
    }

    fn parseMenu(self: *ConfigLoader, node: yaml.Node) !MenuConfig {
        var menu = MenuConfig{
            .id = node.get("id").?.string(),
            .title = node.get("title").?.string(),
            .items = ArrayList(MenuItemConfig).init(self.allocator),
        };

        if (node.get("items")) |items_node| {
            for (items_node.array()) |item_node| {
                const item = try self.parseMenuItem(item_node);
                try menu.items.append(item);
            }
        }

        return menu;
    }

    fn parseMenuItem(self: *ConfigLoader, node: yaml.Node) !MenuItemConfig {
        const item_type = node.get("type").?.string();

        if (std.mem.eql(u8, item_type, "separator")) {
            return .{ .separator = {} };
        }

        var item = MenuItemConfig{
            .normal = .{
                .id = node.get("id").?.string(),
                .title = node.get("title").?.string(),
            },
        };

        if (node.get("shortcut")) |shortcut_node| {
            item.normal.shortcut = try Shortcut.parse(shortcut_node.string());
        }

        if (node.get("action")) |action_node| {
            item.normal.action = action_node.string();
        }

        // ... parse other properties

        return item;
    }
};

pub const MenuBarConfig = struct {
    menus: ArrayList(MenuConfig),
    shortcuts: HashMap(Shortcut, []const u8),
    settings: Settings,

    pub fn init(allocator: Allocator) MenuBarConfig {
        return .{
            .menus = ArrayList(MenuConfig).init(allocator),
            .shortcuts = HashMap(Shortcut, []const u8).init(allocator),
            .settings = Settings{},
        };
    }
};
```

### 3.2 State Persistence

```zig
// src/state.zig (new file)

pub const MenuState = struct {
    checked_items: HashMap([]const u8, bool),
    radio_selections: HashMap([]const u8, []const u8),
    recent_items: HashMap([]const u8, RecentItems),
    user_shortcuts: HashMap([]const u8, Shortcut),
    hidden_items: HashSet([]const u8),
    menu_order: ArrayList([]const u8),

    allocator: Allocator,

    pub fn save(self: *MenuState, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var writer = std.json.writeStream(file.writer(), .{ .whitespace = .indent_2 });
        defer writer.deinit();

        try writer.beginObject();

        // Save checked items
        try writer.objectField("checked_items");
        try writer.beginObject();
        var checked_iter = self.checked_items.iterator();
        while (checked_iter.next()) |entry| {
            try writer.objectField(entry.key_ptr.*);
            try writer.write(entry.value_ptr.*);
        }
        try writer.endObject();

        // Save radio selections
        try writer.objectField("radio_selections");
        try writer.beginObject();
        var radio_iter = self.radio_selections.iterator();
        while (radio_iter.next()) |entry| {
            try writer.objectField(entry.key_ptr.*);
            try writer.write(entry.value_ptr.*);
        }
        try writer.endObject();

        // ... save other state

        try writer.endObject();
    }

    pub fn load(allocator: Allocator, path: []const u8) !MenuState {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            content,
            .{}
        );
        defer parsed.deinit();

        var state = MenuState.init(allocator);

        // Load checked items
        if (parsed.value.object.get("checked_items")) |checked_obj| {
            var iter = checked_obj.object.iterator();
            while (iter.next()) |entry| {
                try state.checked_items.put(
                    entry.key_ptr.*,
                    entry.value_ptr.bool
                );
            }
        }

        // ... load other state

        return state;
    }
};
```

---

## Phase 4: Customization UI (Week 7-8)

### 4.1 Customization Dialog

```zig
// src/ui/customization.zig (new file)

pub const CustomizationDialog = struct {
    window: *gtk.c.GtkWidget,
    menubar: *MenuBar,
    notebook: *gtk.c.GtkWidget,  // Tabs

    // Tabs
    menus_tab: *MenusCustomizer,
    shortcuts_tab: *ShortcutsCustomizer,
    appearance_tab: *AppearanceCustomizer,

    pub fn show(self: *CustomizationDialog) void {
        gtk.c.gtk_widget_show_all(self.window);
    }
};

pub const MenusCustomizer = struct {
    tree_view: *gtk.c.GtkWidget,
    available_items: *gtk.c.GtkWidget,
    toolbar: *gtk.c.GtkWidget,

    pub fn render(self: *MenusCustomizer, menubar: *MenuBar) !void {
        // Populate tree view with current menu structure
        // Allow drag-and-drop reordering
        // Show/hide toggles
    }
};

pub const ShortcutsCustomizer = struct {
    list_view: *gtk.c.GtkWidget,
    search_entry: *gtk.c.GtkWidget,
    record_button: *gtk.c.GtkWidget,
    conflict_label: *gtk.c.GtkWidget,

    pub fn render(self: *ShortcutsCustomizer, shortcuts: *ShortcutManager) !void {
        // Display all shortcuts in searchable list
        // Allow recording new shortcuts
        // Highlight conflicts
    }
};
```

---

## Phase 5: Testing & Polish (Week 9-10)

### 5.1 Comprehensive Test Suite

```zig
// tests/menu_tests.zig

test "menu creation and item addition" {
    const allocator = testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addItem(MenuItem.normal("New"));
    try menu.addItem(MenuItem.separator());
    try menu.addItem(MenuItem.checkbox("Auto-save", true));

    try testing.expectEqual(@as(usize, 3), menu.items.items.len);
}

test "radio group selection" {
    const allocator = testing.allocator;

    var group = RadioGroup.init(allocator, "layout");
    defer group.deinit();

    var item1 = MenuItem.radio("Grid", "layout", false);
    var item2 = MenuItem.radio("List", "layout", true);

    try group.addItem(&item1);
    try group.addItem(&item2);

    group.select("layout.grid");

    try testing.expect(item1.kind.radio.selected);
    try testing.expect(!item2.kind.radio.selected);
}

test "shortcut registration and conflict detection" {
    const allocator = testing.allocator;

    var manager = ShortcutManager.init(allocator);
    defer manager.deinit();

    const shortcut = Shortcut.init("s", Modifiers.cmd);

    try manager.register(shortcut, "file.save", null);

    // Try to register same shortcut
    const conflicts = manager.findConflicts(shortcut);
    try testing.expectEqual(@as(usize, 1), conflicts.len);
}

test "validation system" {
    const allocator = testing.allocator;

    var context = ValidationContext{
        .has_document = true,
        .is_modified = true,
    };

    var item = MenuItem.normal("Save");
    item.validator = hasModifiedDocumentValidator;

    const result = item.validate(&context);
    try testing.expect(result.enabled);
}

test "configuration loading" {
    const allocator = testing.allocator;

    const yaml_content =
        \\menus:
        \\  - id: file
        \\    title: "File"
        \\    items:
        \\      - id: file.new
        \\        title: "New"
        \\        shortcut: "Cmd+N"
    ;

    var loader = ConfigLoader{ .allocator = allocator };
    const config = try loader.parseYAML(yaml_content);
    defer config.deinit();

    try testing.expectEqual(@as(usize, 1), config.menus.items.len);
}

test "state persistence" {
    const allocator = testing.allocator;

    var state = MenuState.init(allocator);
    defer state.deinit();

    try state.checked_items.put("view.sidebar", true);
    try state.radio_selections.put("layout", "grid");

    const temp_path = "/tmp/menu_state_test.json";
    try state.save(temp_path);

    var loaded_state = try MenuState.load(allocator, temp_path);
    defer loaded_state.deinit();

    try testing.expect(loaded_state.checked_items.get("view.sidebar").?);
    try testing.expectEqualStrings("grid", loaded_state.radio_selections.get("layout").?);
}
```

---

## Milestones & Deliverables

### Milestone 1: Enhanced Core (End of Week 2)
- [ ] Radio items implemented
- [ ] Recent items system
- [ ] Dynamic menu generation
- [ ] Menu item registry
- [ ] Basic validation system

### Milestone 2: Keyboard Support (End of Week 4)
- [ ] Full keyboard navigation
- [ ] Type-ahead search
- [ ] Shortcut system with conflict detection
- [ ] Mnemonic support

### Milestone 3: Configuration (End of Week 6)
- [ ] YAML configuration loader
- [ ] State persistence (JSON)
- [ ] Profile system
- [ ] Migration support

### Milestone 4: Customization (End of Week 8)
- [ ] Customization dialog UI
- [ ] Menu reordering
- [ ] Shortcut editor
- [ ] Appearance settings

### Milestone 5: Production Ready (End of Week 10)
- [ ] Comprehensive test coverage (>90%)
- [ ] Performance optimization
- [ ] Full documentation
- [ ] Example applications
- [ ] Accessibility compliance

---

## Performance Targets (Revisited)

### Memory Footprint
- Menu structure: < 1KB per menu
- Menu item: < 100 bytes
- Total for 100 items: < 20KB

### Response Times
- Menu open: < 16ms (60fps)
- Item highlight: < 8ms (120fps)
- Shortcut execution: < 5ms
- Configuration load: < 100ms
- State save: < 50ms

### Optimization Techniques
1. **Lazy Loading**: Load submenu items on-demand
2. **Object Pooling**: Reuse menu item objects
3. **Arena Allocators**: Batch allocations per menu
4. **Virtual Scrolling**: Render only visible items
5. **Debouncing**: Rate-limit validation
6. **Caching**: Cache validation results

---

## Dependencies

### External Libraries
- GTK3: `libgtk-3-dev` (current)
- GTK4: `libgtk-4-dev` (future)
- YAML Parser: Consider `lyaml` or custom parser
- JSON: Standard library

### Build System
```zig
// build.zig additions

const yaml_dep = b.dependency("yaml", .{
    .target = target,
    .optimize = optimize,
});

menubar_mod.addImport("yaml", yaml_dep.module("yaml"));
```

---

## Documentation Plan

### User Documentation
1. **Quick Start Guide**: 15-minute tutorial
2. **API Reference**: Complete public API docs
3. **Configuration Guide**: YAML schema explained
4. **Customization Guide**: UI and manual customization
5. **Cookbook**: Common patterns and recipes

### Developer Documentation
1. **Architecture Overview**: System design
2. **Backend Development**: How to add new backends
3. **Testing Guide**: How to write tests
4. **Performance Guide**: Optimization techniques
5. **Contributing Guide**: How to contribute

### Examples
1. **Basic Example**: Simple menu bar (exists)
2. **Advanced Example**: Full-featured application
3. **Custom Backend**: Example of new backend
4. **Plugin Example**: Sample plugin
5. **Integration Example**: Using in real app

---

## Risk Mitigation

### Technical Risks
1. **GTK API Changes**: Abstract away GTK specifics
2. **Performance**: Profile early and often
3. **Memory Leaks**: Comprehensive leak testing
4. **Platform Differences**: Extensive cross-platform testing

### Mitigation Strategies
- Maintain backend abstraction layer
- Regular performance benchmarking
- Valgrind/AddressSanitizer in CI
- Test on multiple distros

---

## Future Enhancements (Post-1.0)

### Version 1.1
- GTK4 backend
- Wayland-native support
- Animated transitions
- Themes support

### Version 1.2
- Touch Bar emulation
- Voice control integration
- Eye tracking support
- Advanced scripting (Python/Lua)

### Version 2.0
- Cross-platform (Windows, Web)
- Cloud sync of preferences
- AI-powered menu suggestions
- Advanced analytics

---

**Next Steps**: Begin implementation of Phase 2 components while maintaining backward compatibility with existing API.
