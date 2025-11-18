# macOS Menu Bar - Complete Specification
## Version 1.0 - Comprehensive Design Document

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Menu Item Types](#menu-item-types)
4. [Visual Design](#visual-design)
5. [Interaction Patterns](#interaction-patterns)
6. [Keyboard Navigation](#keyboard-navigation)
7. [Dynamic Behavior](#dynamic-behavior)
8. [Accessibility](#accessibility)
9. [Customization System](#customization-system)
10. [Configuration Format](#configuration-format)
11. [Advanced Features](#advanced-features)
12. [Implementation Patterns](#implementation-patterns)

---

## 1. Overview

### 1.1 Purpose
A complete, production-ready menu bar system that replicates macOS functionality on Linux while providing extensive customization for power users.

### 1.2 Design Principles
- **Native Feel**: Behaves exactly like macOS menu bar
- **Zero Compromises**: Every macOS feature supported
- **Power User Ready**: Deep customization without complexity
- **Accessible First**: Full keyboard, screen reader, and alternative input support
- **Performance**: Sub-millisecond response times
- **Memory Efficient**: Minimal allocations, lazy loading

### 1.3 Scope
- Global menu bar (application-level)
- Context menus (right-click)
- Menu bar extras (system tray items)
- Touch Bar virtual menus
- Services menu integration

---

## 2. Architecture

### 2.1 Core Components

```
MenuBarSystem
├── MenuBar (top-level container)
│   ├── Menu[] (File, Edit, View, etc.)
│   │   ├── MenuItem[]
│   │   │   ├── NormalItem
│   │   │   ├── CheckItem
│   │   │   ├── RadioItem
│   │   │   ├── SeparatorItem
│   │   │   ├── SubmenuItem
│   │   │   ├── RecentItem
│   │   │   └── CustomItem
│   │   └── MenuSection[] (logical groupings)
│   └── MenuBarExtra[] (system tray icons)
├── KeyboardManager (shortcuts, navigation)
├── ValidationSystem (enable/disable logic)
├── ThemeEngine (styling, dark mode)
├── CustomizationManager (user preferences)
└── AccessibilityController (VoiceOver, etc.)
```

### 2.2 Data Flow

```
User Input → Event Handler → Validation → Action → State Update → Visual Update
     ↓
Keyboard Shortcut → Direct Action (bypass menu UI)
     ↓
Configuration → Parse → Validate → Apply → Persist
```

### 2.3 State Management

```zig
pub const MenuState = struct {
    // Current state
    open_menu: ?MenuHandle,
    highlighted_item: ?ItemHandle,
    keyboard_mode: bool,

    // Persistent state
    checked_items: HashMap(ItemId, bool),
    radio_selections: HashMap(GroupId, ItemId),
    recent_items: RingBuffer(RecentItem),
    disabled_items: HashSet(ItemId),
    hidden_items: HashSet(ItemId),

    // User preferences
    custom_shortcuts: HashMap(ItemId, Shortcut),
    menu_order: []MenuId,
    toolbar_items: []ItemId,
};
```

---

## 3. Menu Item Types

### 3.1 Normal Item
**Purpose**: Execute an action when clicked

**Properties**:
- `id`: Unique identifier
- `title`: Display text
- `action`: Callback function
- `shortcut`: Keyboard shortcut (optional)
- `icon`: Icon/SF Symbol (optional)
- `tooltip`: Hover text (optional)
- `enabled`: Dynamic enable/disable
- `visible`: Dynamic show/hide
- `badge`: Badge text/count (optional)

**Example**:
```yaml
- id: file.new
  type: normal
  title: "New"
  shortcut: "Cmd+N"
  icon: "doc.badge.plus"
  action: createNewDocument
```

### 3.2 Check Item
**Purpose**: Toggle boolean state

**Properties**:
- All Normal Item properties
- `checked`: Boolean state
- `on_toggle`: Callback when state changes
- `state_key`: Key for persistent state

**States**:
- Checked (✓)
- Unchecked ( )
- Mixed/Indeterminate (−) [for hierarchical selections]

**Example**:
```yaml
- id: view.sidebar
  type: check
  title: "Show Sidebar"
  shortcut: "Cmd+Option+S"
  checked: true
  state_key: "ui.sidebar.visible"
  on_toggle: toggleSidebar
```

### 3.3 Radio Item
**Purpose**: Mutually exclusive selection within a group

**Properties**:
- All Normal Item properties
- `group`: Radio group ID
- `selected`: Boolean (only one per group)
- `on_select`: Callback when selected

**Example**:
```yaml
- id: view.layout.grid
  type: radio
  title: "Grid Layout"
  group: "view.layout"
  selected: false

- id: view.layout.list
  type: radio
  title: "List Layout"
  group: "view.layout"
  selected: true
```

### 3.4 Separator
**Purpose**: Visual grouping of related items

**Types**:
- Standard separator (horizontal line)
- Labeled separator (with title)
- Spacer (invisible spacing)

**Example**:
```yaml
- type: separator

- type: separator
  title: "Recent Files"
```

### 3.5 Submenu
**Purpose**: Hierarchical menu organization

**Properties**:
- All Normal Item properties
- `items`: Array of menu items
- `max_depth`: Maximum nesting (default: 5)
- `dynamic`: Load items on-demand

**Example**:
```yaml
- id: file.export
  type: submenu
  title: "Export"
  icon: "arrow.up.doc"
  items:
    - title: "PDF"
      action: exportPDF
    - title: "HTML"
      action: exportHTML
```

### 3.6 Recent Items
**Purpose**: Auto-populated recent files/actions

**Properties**:
- `source`: Data source (files, searches, etc.)
- `max_count`: Maximum items (default: 10)
- `clear_action`: Callback to clear history
- `template`: Item template for rendering

**Example**:
```yaml
- id: file.recent
  type: recent
  title: "Recent Files"
  source: recent_files
  max_count: 15
  items:
    - type: separator
    - title: "Clear Menu"
      action: clearRecentFiles
```

### 3.7 Dynamic Item
**Purpose**: Programmatically generated items

**Properties**:
- `generator`: Function that returns items
- `refresh_on`: Events that trigger regeneration
- `cache_duration`: How long to cache (ms)

**Example**:
```yaml
- id: view.themes
  type: dynamic
  title: "Themes"
  generator: loadAvailableThemes
  refresh_on: ["theme_installed", "theme_removed"]
```

### 3.8 Alternate Item
**Purpose**: Show different item when modifier held (Option key)

**Properties**:
- Base item properties
- `alternate`: Alternate item definition
- `modifier`: Trigger modifier (default: Option)

**Example**:
```yaml
- id: file.close
  title: "Close Window"
  shortcut: "Cmd+W"
  alternate:
    title: "Close All Windows"
    shortcut: "Cmd+Option+W"
    action: closeAllWindows
```

### 3.9 Template Item
**Purpose**: Reusable item definitions

**Example**:
```yaml
templates:
  action_item:
    type: normal
    icon_style: "colored"
    show_shortcut: true

items:
  - template: action_item
    id: edit.undo
    title: "Undo"
    action: undo
```

---

## 4. Visual Design

### 4.1 Menu Bar Dimensions

```
Height: 24px (standard), 28px (accessibility mode)
Padding: 8px horizontal between menus
Font: System (13pt regular, 12pt for items)
Active Background: rgba(0, 0, 0, 0.1) light / rgba(255, 255, 255, 0.1) dark
```

### 4.2 Menu Dropdown

```
Width: Auto-fit content, min 180px, max 400px
Padding: 6px vertical, 0px horizontal
Corner Radius: 6px
Shadow: 0 8px 24px rgba(0,0,0,0.15)
Background: System background material (blur)
```

### 4.3 Menu Item Layout

```
┌────────────────────────────────────────┐
│ [I] Title                    Shortcut │  ← Normal item
│ [✓] Checked Item                 ⌥⌘S │  ← Check item
│ ──────────────────────────────────── │  ← Separator
│     Indented Item                    │  ← Nested level
│ Submenu Item                       ▸ │  ← Has submenu
│ [🔴] With Badge              3    ⌘N │  ← Badge count
└────────────────────────────────────────┘

Layout:
  Left margin: 20px (24px with icon)
  Icon size: 16x16px
  Icon to text: 8px
  Text to shortcut: 32px min
  Shortcut to right edge: 16px
  Right margin (submenu arrow): 8px
  Item height: 22px
  Item padding: 4px vertical
```

### 4.4 Icons

**Types**:
- SF Symbols (macOS)
- Unicode symbols
- Custom bitmaps (16x16, 32x32 retina)
- Emoji

**Rendering**:
- Template mode (respects theme)
- Full color mode
- Automatic dark mode inversion

**Example**:
```yaml
icon: "doc.badge.plus"          # SF Symbol
icon: "📄"                       # Emoji
icon: "assets/custom-icon.png"  # Custom
```

### 4.5 Typography

**Menu Titles**:
- Font: System Medium
- Size: 13pt
- Letter spacing: -0.2px
- Color: Primary text

**Menu Items**:
- Font: System Regular
- Size: 13pt (12pt for subtext)
- Line height: 1.4
- Color: Primary text / Secondary (disabled)

**Shortcuts**:
- Font: System Regular
- Size: 12pt
- Color: Secondary text
- Symbols: ⌘ ⇧ ⌥ ⌃ (Command, Shift, Option, Control)

### 4.6 States & Animations

**Hover**:
```
Background: System selection color
Transition: 100ms ease-out
Cursor: pointer
```

**Active/Pressed**:
```
Background: Darker selection color
Scale: 0.98 (subtle)
Transition: 50ms ease-in
```

**Disabled**:
```
Opacity: 0.4
Cursor: not-allowed
Text color: Secondary (dimmed)
```

**Opening Animation**:
```
Duration: 150ms
Easing: ease-out-back
Effect: Scale from 0.95 + fade in
Origin: Top edge of menu bar
```

**Closing Animation**:
```
Duration: 100ms
Easing: ease-in
Effect: Scale to 0.95 + fade out
```

### 4.7 Dark Mode

**Automatic switching**:
- Follows system preference
- Per-app override option
- Smooth transition (250ms)

**Color adjustments**:
```yaml
light_mode:
  background: rgba(255, 255, 255, 0.95)
  text: rgba(0, 0, 0, 0.85)
  secondary_text: rgba(0, 0, 0, 0.5)
  separator: rgba(0, 0, 0, 0.1)
  selection: rgba(0, 122, 255, 1.0)

dark_mode:
  background: rgba(30, 30, 30, 0.95)
  text: rgba(255, 255, 255, 0.85)
  secondary_text: rgba(255, 255, 255, 0.5)
  separator: rgba(255, 255, 255, 0.1)
  selection: rgba(10, 132, 255, 1.0)
```

---

## 5. Interaction Patterns

### 5.1 Mouse Interactions

**Click to Open**:
1. User clicks menu title
2. Menu animates open
3. First item highlighted (optional)
4. Other menus show hover state

**Hover to Switch**:
1. User hovers over another menu title (while menu open)
2. Current menu closes
3. New menu opens immediately
4. No click required

**Click Item**:
1. User clicks menu item
2. Action executes
3. Menu closes with animation
4. Visual feedback (flash/ripple)

**Hover Item**:
1. Item background changes
2. Submenu opens after 300ms delay
3. Previous submenu closes

**Click Outside**:
1. Menu closes immediately
2. No action executed
3. Focus returns to previous element

**Right Click (Context Menu)**:
1. Context menu appears at cursor
2. Standard menu interactions apply
3. Closes on selection or outside click

### 5.2 Keyboard Interactions

**Open Menu**:
- `F10` or `Alt`: Activate menu bar, highlight first menu
- `Alt+Letter`: Jump to menu (underlined mnemonic)

**Navigate Menus**:
- `←/→`: Move between menu titles
- `↓`: Open current menu / move to first item
- `↑`: Move to previous item / close menu
- `Enter/Space`: Activate highlighted item
- `Esc`: Close menu / go up one level

**Type-Ahead Search**:
- Type letters to search menu items
- Highlights first match
- Buffer clears after 1 second
- Case-insensitive
- Searches by title start or contains

**Shortcuts**:
- Direct action execution (menu doesn't open)
- Visual flash on menu bar (feedback)
- Works globally or when app focused

### 5.3 Touch/Trackpad

**Tap**:
- Same as click

**Two-Finger Swipe**:
- Switch between menus (horizontal)
- Scroll long menus (vertical)

**Force Touch**:
- Show item details/preview
- Quick action (configurable)

**Pinch**:
- Zoom menu text (accessibility)

### 5.4 Touch Bar (Virtual)

**Display**:
- Show relevant menu items in touch bar
- Context-aware (active menu/app state)
- Customizable slots

**Interaction**:
- Tap to execute action
- Hold for submenu
- Swipe to see more items

---

## 6. Keyboard Navigation

### 6.1 Shortcut System

**Format**:
```
[Modifiers]+[Key]

Modifiers:
  Cmd/Super  (⌘) - Primary modifier
  Shift      (⇧) - Secondary modifier
  Option/Alt (⌥) - Alternate actions
  Control    (⌃) - Tertiary modifier

Keys:
  - Letters: A-Z
  - Numbers: 0-9
  - Function: F1-F12
  - Special: Enter, Space, Tab, Esc, Delete
  - Arrows: ↑ ↓ ← →
  - Symbols: + - = / [ ] ; ' , . `
```

**Shortcut Priority**:
1. User-customized shortcuts
2. Application shortcuts
3. System shortcuts
4. Default shortcuts

**Conflict Resolution**:
```yaml
conflict_strategy:
  - user_wins: true           # User shortcuts override all
  - warn_on_conflict: true    # Show warning dialog
  - suggest_alternative: true # Suggest available shortcut
  - allow_override: false     # Prevent critical system shortcuts
```

### 6.2 Mnemonics

**Underlined Letters**:
- First letter of menu/item underlined
- Press Alt+Letter to activate
- Auto-assigned or manual

**Example**:
```
File  Edit  View  Window  Help
 ▔         ▔         ▔
F     E    V    W      H
```

### 6.3 Navigation Modes

**Mouse Mode** (default):
- Menu bar inactive until clicked
- Shortcuts work globally

**Keyboard Mode**:
- Activated by F10 or Alt
- Visual indicator (highlight first menu)
- Arrow key navigation
- Type-ahead search active
- Esc to exit

**Hybrid Mode**:
- Auto-switch based on last input
- Seamless transition
- Persistent state across activations

---

## 7. Dynamic Behavior

### 7.1 Validation System

**Item Validation**:
```zig
pub const ValidatorFn = fn(item: *MenuItem, context: *AppContext) ValidationResult;

pub const ValidationResult = struct {
    enabled: bool,
    visible: bool,
    title: ?[]const u8,        // Dynamic title
    checked: ?bool,            // For check items
    badge: ?[]const u8,        // Badge text/count
};
```

**Validation Triggers**:
- Menu about to open
- Selection changed (document/focus)
- Application state changed
- Timer-based (for async updates)

**Example Validators**:
```yaml
- id: edit.undo
  title: "Undo"
  validator: |
    enabled: hasUndoHistory()
    title: "Undo " + lastAction()

- id: edit.paste
  title: "Paste"
  validator: |
    enabled: clipboardHasContent()
    title: "Paste " + clipboardType()
```

### 7.2 Dynamic Titles

**Use Cases**:
- Undo/Redo (show action name)
- Copy/Paste (show content type)
- Recent items (show file names)
- Conditional actions (context-dependent)

**Example**:
```
Static:  "Undo"
Dynamic: "Undo Typing"
         "Undo Delete"
         "Undo Move"
```

### 7.3 Badge System

**Types**:
- Count badge (number)
- Text badge (string)
- Icon badge (symbol)
- Color badge (dot)

**Positions**:
- Right-aligned (default)
- Inline with title
- Separate line (for counts)

**Example**:
```yaml
- title: "Messages"
  badge:
    type: count
    value: unreadCount()
    color: "red"
    max_display: 99      # Shows "99+" if > 99
```

### 7.4 State Persistence

**Saved State**:
- Checked/unchecked items
- Radio selections
- Recent items history
- Window positions
- User customizations

**Storage**:
```yaml
state_file: ~/.config/myapp/menu_state.json

persistence:
  auto_save: true
  save_delay: 500ms          # Debounce
  save_on_exit: true
  restore_on_launch: true
```

---

## 8. Accessibility

### 8.1 Screen Reader Support

**VoiceOver/Orca**:
- Full menu structure announced
- Item states read (checked, disabled)
- Shortcuts announced
- Submenu navigation feedback
- Type-ahead search results

**ARIA Attributes**:
```html
role="menubar"
  role="menu"
    role="menuitem"
    role="menuitemcheckbox" aria-checked="true"
    role="menuitemradio" aria-checked="false"
    role="separator"
```

**Announcements**:
```
"File menu"
"Edit menu, 8 items"
"Undo, Command Z, enabled"
"Show Sidebar, checked, Command Option S"
"Zoom, submenu"
```

### 8.2 Keyboard-Only Navigation

**Full Coverage**:
- No mouse-only features
- All actions accessible via keyboard
- Visible focus indicators
- Skip navigation for efficiency

**Focus Management**:
```yaml
focus:
  visible_indicator: true
  indicator_width: 2px
  indicator_color: "accent"
  indicator_style: "outline"  # or "background"
  trap_focus: true            # Keep focus in open menu
```

### 8.3 Visual Accessibility

**High Contrast Mode**:
```yaml
high_contrast:
  enabled: auto              # Follow system
  increase_border: true
  increase_spacing: true
  remove_transparency: true
  stronger_colors: true
```

**Large Text**:
```yaml
text_size:
  small: 11pt
  normal: 13pt
  large: 16pt
  extra_large: 20pt
  respect_system: true
```

**Reduced Motion**:
```yaml
reduced_motion:
  enabled: auto
  disable_animations: true
  instant_transitions: true
  crossfade_only: true
```

**Color Blindness**:
```yaml
color_modes:
  - normal
  - protanopia      # Red-blind
  - deuteranopia    # Green-blind
  - tritanopia      # Blue-blind
  - grayscale

# Use icons + text, not just color
use_redundant_cues: true
```

### 8.4 Alternative Input

**Voice Control**:
- Number overlays for items
- "Click menu item 3"
- "Show File menu"

**Switch Control**:
- Sequential scanning
- Group scanning
- Auto-scanning intervals

**Eye Tracking**:
- Dwell-to-click
- Adjustable dwell time
- Visual feedback

---

## 9. Customization System

### 9.1 User Interface Customization

**Customization Dialog**:
```
┌─ Customize Menu Bar ────────────────────┐
│                                          │
│  [Menus] [Shortcuts] [Appearance]       │
│                                          │
│  ┌─ Available Items ──┐  ┌─ Menu Bar ─┐│
│  │ • New Window       │  │ File       ││
│  │ • Print            │  │ Edit       ││
│  │ • Export           │  │ View       ││
│  │ • Preferences      │  │ Window     ││
│  └────────────────────┘  │ Help       ││
│                          └────────────┘│
│  Drag items to reorder or remove        │
│                                          │
│  [Reset to Defaults]        [Apply]     │
└──────────────────────────────────────────┘
```

**Operations**:
- Drag to reorder menus
- Drag to reorder items within menu
- Drag to move items between menus
- Right-click to hide/remove
- Double-click to edit properties

### 9.2 Shortcut Customization

**Shortcut Editor**:
```
┌─ Keyboard Shortcuts ────────────────────┐
│                                          │
│  Search: [____________]    🔍           │
│                                          │
│  Category: [All ▼]                      │
│                                          │
│  Command             Shortcut    Action │
│  ────────────────────────────────────── │
│  New                 ⌘N          [Edit] │
│  Open                ⌘O          [Edit] │
│  Save                ⌘S          [Edit] │
│  Undo                ⌘Z          [Edit] │
│  Copy                ⌘C          [Edit] │
│                                          │
│  Conflicts: [⚠️ 2]   [Export] [Import] │
│                                          │
│  [Reset]                        [Done]  │
└──────────────────────────────────────────┘
```

**Features**:
- Search/filter shortcuts
- Click to record new shortcut
- Automatic conflict detection
- Suggest alternatives
- Import/export shortcuts
- Profiles (Developer, Writer, etc.)

### 9.3 Appearance Customization

**Theme Options**:
```yaml
appearance:
  # Menu bar
  menu_bar_height: 24px         # 20-32px
  menu_bar_background: auto     # auto/custom color
  menu_bar_blur: true
  menu_bar_transparency: 0.95   # 0.0-1.0

  # Menus
  menu_corner_radius: 6px       # 0-12px
  menu_shadow: true
  menu_icons: true              # Show/hide icons
  menu_shortcuts: "right"       # right/hidden/below

  # Text
  font_family: "System"
  font_size: 13pt               # 10-20pt
  font_weight: "regular"        # light/regular/medium

  # Colors
  accent_color: "system"        # system/custom
  custom_colors:
    selection: "#0078D4"
    text: "auto"
    background: "auto"

  # Animation
  animation_speed: "normal"     # fast/normal/slow/none
  hover_delay: 300ms            # 0-1000ms

  # Spacing
  item_height: 22px             # 18-32px
  item_padding: 4px             # 0-12px
  separator_margin: 6px         # 0-12px
```

### 9.4 Behavior Customization

**Interaction Settings**:
```yaml
behavior:
  # Opening
  click_to_open: true
  hover_to_open: false          # Auto-open on hover
  hover_delay: 500ms
  double_click_menu_bar: false  # Double-click to minimize

  # Navigation
  type_ahead: true
  type_ahead_timeout: 1000ms
  wrap_navigation: true         # Arrow keys wrap around
  auto_highlight_first: false   # Highlight first item on open

  # Closing
  click_outside_closes: true
  escape_closes: true
  execute_closes: true          # Close after action
  submenu_timeout: 300ms        # Delay before opening submenu

  # Feedback
  flash_on_shortcut: true       # Visual feedback
  sound_on_action: false        # Audio feedback
  haptic_feedback: false        # Trackpad vibration (macOS)
```

### 9.5 Power User Features

**Advanced Settings**:
```yaml
advanced:
  # Performance
  lazy_load_menus: true         # Load on-demand
  cache_menu_state: true
  preload_next_menu: false      # Predictive loading

  # Developer
  debug_mode: false
  show_item_ids: false
  log_interactions: false

  # Scripting
  enable_scripts: true
  script_language: "lua"        # lua/python/js
  script_location: "~/.config/myapp/scripts"

  # Plugins
  enable_plugins: true
  plugin_directory: "~/.config/myapp/plugins"
  auto_update_plugins: true
```

---

## 10. Configuration Format

### 10.1 YAML Schema

**Complete Example**:
```yaml
# Menu Bar Configuration
# Version: 1.0

meta:
  name: "MyApp Menu Configuration"
  version: "1.0.0"
  author: "User Name"
  description: "Custom menu layout for development workflow"

# Global settings
settings:
  appearance:
    theme: "auto"                    # auto/light/dark
    accent_color: "system"
    font_size: 13
    show_icons: true
    animation_speed: "normal"

  behavior:
    type_ahead: true
    hover_to_switch: true
    close_on_execute: true

  accessibility:
    high_contrast: false
    reduce_motion: false
    large_text: false

# Keyboard shortcuts (global overrides)
shortcuts:
  "Cmd+N": file.new
  "Cmd+O": file.open
  "Cmd+S": file.save
  "Cmd+Shift+S": file.save_as
  "Cmd+Q": app.quit

# Templates for reusable item definitions
templates:
  standard_action:
    type: normal
    show_shortcut: true
    enabled: true

  toggle_view:
    type: check
    state_persistent: true

# Menu definitions
menus:
  # Application Menu
  - id: app
    title: "${APP_NAME}"           # Variable substitution
    position: 0
    items:
      - id: app.about
        template: standard_action
        title: "About ${APP_NAME}"
        action: showAboutDialog

      - type: separator

      - id: app.preferences
        title: "Preferences..."
        shortcut: "Cmd+,"
        action: showPreferences
        icon: "gear"

      - type: separator

      - id: app.services
        type: submenu
        title: "Services"
        dynamic: true
        generator: loadSystemServices

      - type: separator

      - id: app.hide
        title: "Hide ${APP_NAME}"
        shortcut: "Cmd+H"
        action: hideApplication

      - id: app.hide_others
        title: "Hide Others"
        shortcut: "Cmd+Option+H"
        action: hideOtherApplications

      - id: app.show_all
        title: "Show All"
        action: showAllApplications

      - type: separator

      - id: app.quit
        title: "Quit ${APP_NAME}"
        shortcut: "Cmd+Q"
        action: quitApplication

  # File Menu
  - id: file
    title: "File"
    position: 1
    items:
      - id: file.new
        title: "New"
        shortcut: "Cmd+N"
        action: createNew
        icon: "doc.badge.plus"

        # Alternate item (shown when Option held)
        alternate:
          title: "New from Template"
          shortcut: "Cmd+Option+N"
          action: createFromTemplate

      - id: file.new_window
        title: "New Window"
        shortcut: "Cmd+Shift+N"
        action: createNewWindow

      - type: separator

      - id: file.open
        title: "Open..."
        shortcut: "Cmd+O"
        action: openFile
        icon: "folder"

      - id: file.recent
        type: recent
        title: "Open Recent"
        source: recent_files
        max_items: 10
        icon: "clock"
        items:
          - type: separator
          - title: "Clear Menu"
            action: clearRecentFiles

      - type: separator

      - id: file.close
        title: "Close"
        shortcut: "Cmd+W"
        action: closeDocument
        validator: hasOpenDocument

      - id: file.save
        title: "Save"
        shortcut: "Cmd+S"
        action: saveDocument
        validator: |
          enabled: hasOpenDocument() && isModified()
          title: isModified() ? "Save" : "Save"

      - id: file.save_as
        title: "Save As..."
        shortcut: "Cmd+Shift+S"
        action: saveDocumentAs
        validator: hasOpenDocument

      - id: file.revert
        title: "Revert to Saved"
        action: revertDocument
        validator: hasOpenDocument() && isModified()

      - type: separator

      - id: file.export
        type: submenu
        title: "Export"
        icon: "arrow.up.doc"
        items:
          - title: "PDF..."
            action: exportPDF
            icon: "doc.richtext"

          - title: "HTML..."
            action: exportHTML
            icon: "globe"

          - title: "Markdown..."
            action: exportMarkdown
            icon: "doc.text"

      - type: separator

      - id: file.share
        type: submenu
        title: "Share"
        icon: "square.and.arrow.up"
        dynamic: true
        generator: loadShareServices

      - type: separator

      - id: file.page_setup
        title: "Page Setup..."
        shortcut: "Cmd+Shift+P"
        action: showPageSetup

      - id: file.print
        title: "Print..."
        shortcut: "Cmd+P"
        action: printDocument
        validator: hasOpenDocument
        icon: "printer"

  # Edit Menu
  - id: edit
    title: "Edit"
    position: 2
    items:
      - id: edit.undo
        title: "Undo"
        shortcut: "Cmd+Z"
        action: undo
        validator: |
          enabled: canUndo()
          title: "Undo " + undoActionName()
        icon: "arrow.uturn.backward"

      - id: edit.redo
        title: "Redo"
        shortcut: "Cmd+Shift+Z"
        action: redo
        validator: |
          enabled: canRedo()
          title: "Redo " + redoActionName()
        icon: "arrow.uturn.forward"

      - type: separator

      - id: edit.cut
        title: "Cut"
        shortcut: "Cmd+X"
        action: cut
        validator: hasSelection
        icon: "scissors"

      - id: edit.copy
        title: "Copy"
        shortcut: "Cmd+C"
        action: copy
        validator: hasSelection
        icon: "doc.on.doc"

      - id: edit.paste
        title: "Paste"
        shortcut: "Cmd+V"
        action: paste
        validator: |
          enabled: clipboardHasContent()
          title: "Paste" + (clipboardType() ? " " + clipboardType() : "")
        icon: "doc.on.clipboard"

      - id: edit.paste_match_style
        title: "Paste and Match Style"
        shortcut: "Cmd+Option+Shift+V"
        action: pasteMatchStyle
        validator: clipboardHasContent

      - id: edit.delete
        title: "Delete"
        action: delete
        validator: hasSelection
        icon: "trash"

      - id: edit.select_all
        title: "Select All"
        shortcut: "Cmd+A"
        action: selectAll

      - type: separator

      - id: edit.find
        type: submenu
        title: "Find"
        icon: "magnifyingglass"
        items:
          - title: "Find..."
            shortcut: "Cmd+F"
            action: showFind

          - title: "Find Next"
            shortcut: "Cmd+G"
            action: findNext

          - title: "Find Previous"
            shortcut: "Cmd+Shift+G"
            action: findPrevious

          - title: "Use Selection for Find"
            shortcut: "Cmd+E"
            action: useSelectionForFind

          - type: separator

          - title: "Find and Replace..."
            shortcut: "Cmd+Option+F"
            action: showFindReplace

      - type: separator

      - id: edit.spelling
        type: submenu
        title: "Spelling and Grammar"
        items:
          - title: "Show Spelling and Grammar"
            shortcut: "Cmd+:"
            action: showSpelling

          - title: "Check Document Now"
            shortcut: "Cmd+;"
            action: checkSpelling

          - type: separator

          - type: check
            title: "Check Spelling While Typing"
            checked: true
            action: toggleSpellCheck

          - type: check
            title: "Check Grammar With Spelling"
            checked: false
            action: toggleGrammarCheck

  # View Menu
  - id: view
    title: "View"
    position: 3
    items:
      - id: view.sidebar
        type: check
        title: "Show Sidebar"
        shortcut: "Cmd+Option+S"
        checked: true
        state_key: "ui.sidebar.visible"
        action: toggleSidebar
        icon: "sidebar.left"

      - id: view.toolbar
        type: check
        title: "Show Toolbar"
        checked: true
        state_key: "ui.toolbar.visible"
        action: toggleToolbar
        icon: "hammer"

      - id: view.statusbar
        type: check
        title: "Show Status Bar"
        checked: true
        state_key: "ui.statusbar.visible"
        action: toggleStatusBar

      - type: separator

      - id: view.layout
        type: submenu
        title: "Layout"
        items:
          - type: radio
            id: view.layout.grid
            title: "Grid"
            group: "layout"
            selected: false
            action: setGridLayout

          - type: radio
            id: view.layout.list
            title: "List"
            group: "layout"
            selected: true
            action: setListLayout

          - type: radio
            id: view.layout.columns
            title: "Columns"
            group: "layout"
            selected: false
            action: setColumnsLayout

      - type: separator

      - id: view.zoom_in
        title: "Zoom In"
        shortcut: "Cmd++"
        action: zoomIn
        icon: "plus.magnifyingglass"

      - id: view.zoom_out
        title: "Zoom Out"
        shortcut: "Cmd+-"
        action: zoomOut
        icon: "minus.magnifyingglass"

      - id: view.actual_size
        title: "Actual Size"
        shortcut: "Cmd+0"
        action: zoomActualSize

      - type: separator

      - id: view.fullscreen
        title: "Enter Full Screen"
        shortcut: "Cmd+Ctrl+F"
        action: toggleFullscreen
        validator: |
          title: isFullscreen() ? "Exit Full Screen" : "Enter Full Screen"
        icon: "arrow.up.left.and.arrow.down.right"

  # Window Menu
  - id: window
    title: "Window"
    position: 4
    items:
      - id: window.minimize
        title: "Minimize"
        shortcut: "Cmd+M"
        action: minimizeWindow
        icon: "minus.rectangle"

      - id: window.zoom
        title: "Zoom"
        action: zoomWindow

      - type: separator

      - id: window.bring_all_to_front
        title: "Bring All to Front"
        action: bringAllToFront

      - type: separator

      # Dynamic list of open windows
      - id: window.list
        type: dynamic
        generator: listOpenWindows
        refresh_on: ["window_opened", "window_closed", "window_renamed"]

  # Help Menu
  - id: help
    title: "Help"
    position: 5
    items:
      - id: help.search
        title: "Search"
        icon: "magnifyingglass"
        type: search_field
        placeholder: "Search Help"
        action: searchHelp

      - type: separator

      - id: help.docs
        title: "${APP_NAME} Help"
        shortcut: "Cmd+?"
        action: openDocumentation
        icon: "book"

      - type: separator

      - id: help.whats_new
        title: "What's New"
        action: showWhatsNew
        badge:
          type: dot
          color: "blue"
          visible: hasUnseenReleaseNotes

      - id: help.release_notes
        title: "Release Notes"
        action: showReleaseNotes

      - type: separator

      - id: help.keyboard_shortcuts
        title: "Keyboard Shortcuts"
        action: showKeyboardShortcuts
        icon: "command"

      - type: separator

      - id: help.report_bug
        title: "Report a Bug..."
        action: reportBug
        icon: "ant"

      - id: help.feature_request
        title: "Request a Feature..."
        action: requestFeature

      - type: separator

      - id: help.community
        type: submenu
        title: "Community"
        items:
          - title: "Forum"
            action: openForum
            icon: "bubble.left.and.bubble.right"

          - title: "Discord"
            action: openDiscord
            icon: "message"

          - title: "Twitter"
            action: openTwitter

# Context menus (right-click)
context_menus:
  - id: text_context
    trigger: text_selection
    items:
      - title: "Cut"
        action: cut
        validator: hasSelection

      - title: "Copy"
        action: copy
        validator: hasSelection

      - title: "Paste"
        action: paste
        validator: clipboardHasContent

      - type: separator

      - title: "Look Up"
        action: lookupWord
        validator: hasSingleWord

      - type: separator

      - type: submenu
        title: "Transformations"
        items:
          - title: "Make Uppercase"
            action: makeUppercase
          - title: "Make Lowercase"
            action: makeLowercase
          - title: "Capitalize"
            action: capitalize

# Menu bar extras (system tray)
menu_bar_extras:
  - id: notifications
    icon: "bell"
    position: right
    badge:
      type: count
      value: unreadNotifications
      color: "red"
    menu:
      - title: "Notifications"
        type: header
      - type: separator
      - type: dynamic
        generator: loadNotifications
        max_items: 5
      - type: separator
      - title: "See All..."
        action: showAllNotifications

# Profiles (quick switch between configurations)
profiles:
  - id: default
    name: "Default"
    description: "Standard menu layout"

  - id: developer
    name: "Developer"
    description: "Optimized for coding"
    shortcuts:
      "Cmd+B": "Build"
      "Cmd+R": "Run"
      "Cmd+T": "Test"

  - id: writer
    name: "Writer"
    description: "Focused writing environment"
    hidden_menus: ["view", "window"]
    shortcuts:
      "Cmd+D": "Define Word"
      "Cmd+T": "Thesaurus"

# Scripting hooks
scripts:
  on_menu_open:
    - script: "scripts/track_analytics.lua"
    - script: "scripts/update_recents.lua"

  on_item_select:
    - script: "scripts/log_action.lua"

  on_shortcut:
    - script: "scripts/validate_context.lua"
```

### 10.2 JSON Schema

For programmatic validation:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Menu Bar Configuration",
  "type": "object",
  "required": ["menus"],
  "properties": {
    "meta": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "version": {"type": "string"},
        "author": {"type": "string"},
        "description": {"type": "string"}
      }
    },
    "settings": {
      "type": "object",
      "properties": {
        "appearance": {"$ref": "#/definitions/appearance"},
        "behavior": {"$ref": "#/definitions/behavior"},
        "accessibility": {"$ref": "#/definitions/accessibility"}
      }
    },
    "shortcuts": {
      "type": "object",
      "patternProperties": {
        "^(Cmd|Shift|Option|Ctrl)\\+.+$": {"type": "string"}
      }
    },
    "menus": {
      "type": "array",
      "items": {"$ref": "#/definitions/menu"}
    }
  },
  "definitions": {
    "menu": {
      "type": "object",
      "required": ["id", "title", "items"],
      "properties": {
        "id": {"type": "string"},
        "title": {"type": "string"},
        "position": {"type": "integer"},
        "visible": {"type": "boolean"},
        "items": {
          "type": "array",
          "items": {"$ref": "#/definitions/menuItem"}
        }
      }
    },
    "menuItem": {
      "type": "object",
      "properties": {
        "id": {"type": "string"},
        "type": {
          "enum": ["normal", "check", "radio", "separator", "submenu", "recent", "dynamic"]
        },
        "title": {"type": "string"},
        "action": {"type": "string"},
        "shortcut": {"type": "string"},
        "icon": {"type": "string"},
        "enabled": {"type": "boolean"},
        "visible": {"type": "boolean"},
        "validator": {"type": "string"}
      }
    }
  }
}
```

### 10.3 Migration & Versioning

**Version Updates**:
```yaml
migrations:
  "1.0.0":
    - rename_key: ["old_key", "new_key"]
    - remove_key: "deprecated_key"
    - add_default: ["new_key", "default_value"]

  "1.1.0":
    - transform:
        key: "shortcuts"
        from: "string"
        to: "object"
        converter: parseShortcutString
```

**Backward Compatibility**:
- Old format auto-migrated on load
- Backup created before migration
- Validation warnings for deprecated features
- Graceful fallback for unknown properties

---

## 11. Advanced Features

### 11.1 Services Menu

**macOS Services Integration**:
- Automatic population from system
- Context-aware (based on selection)
- Text, image, file services

**Example**:
```yaml
- id: services
  type: submenu
  title: "Services"
  dynamic: true
  generator: loadSystemServices
  items:
    # Auto-populated based on:
    # - Current selection type
    # - Available system services
    # - User preferences
```

### 11.2 Spotlight/Search Integration

**Menu Search**:
```
┌─ Search All Menus ──────────────┐
│  [new file_______________] 🔍   │
│                                  │
│  Results:                        │
│  • File > New              ⌘N   │
│  • File > New Window       ⌘⇧N  │
│  • Edit > New Selection         │
│                                  │
│  Press ↩ to execute             │
└──────────────────────────────────┘
```

**Activation**:
- `Cmd+Shift+/` (customizable)
- Type to search all menus
- Fuzzy matching
- Recent items boosted
- Execute from search

### 11.3 Touch Bar Support

**Virtual Touch Bar**:
```yaml
touch_bar:
  enabled: true
  mode: "context_aware"     # context_aware/custom/off

  # Default items
  default_items:
    - type: button
      title: "New"
      action: file.new
      icon: "doc.badge.plus"

    - type: button
      title: "Save"
      action: file.save
      icon: "square.and.arrow.down"

  # Context-specific
  contexts:
    - trigger: text_editing
      items:
        - type: button
          title: "Bold"
          action: format.bold

        - type: button
          title: "Italic"
          action: format.italic
```

### 11.4 Internationalization (i18n)

**Multi-Language Support**:
```yaml
# English (default)
menus:
  - id: file
    title: "File"
    items:
      - id: file.new
        title: "New"

# Spanish
i18n:
  es:
    menus.file.title: "Archivo"
    menus.file.items.file.new.title: "Nuevo"

# French
i18n:
  fr:
    menus.file.title: "Fichier"
    menus.file.items.file.new.title: "Nouveau"
```

**Locale Detection**:
```yaml
i18n:
  auto_detect: true
  fallback: "en"
  supported: ["en", "es", "fr", "de", "ja", "zh-CN"]
```

### 11.5 Scripting & Automation

**Lua Scripting**:
```lua
-- scripts/custom_validator.lua
function validate_save_item(item, context)
    local doc = context.current_document

    return {
        enabled = doc ~= nil and doc.is_modified,
        title = "Save " .. (doc and doc.name or ""),
        badge = doc and doc.is_modified and "•" or nil
    }
end

-- Register validator
menu.register_validator("file.save", validate_save_item)
```

**Python Scripting**:
```python
# scripts/dynamic_themes.py
def generate_theme_menu(context):
    themes = load_available_themes()
    current = get_current_theme()

    items = []
    for theme in themes:
        items.append({
            'type': 'radio',
            'title': theme.name,
            'group': 'themes',
            'selected': theme.id == current,
            'action': lambda: apply_theme(theme.id)
        })

    return items

menu.register_generator('view.themes', generate_theme_menu)
```

### 11.6 Plugin System

**Plugin Architecture**:
```yaml
plugins:
  enabled: true
  directory: "~/.config/myapp/plugins"
  auto_load: true
  sandbox: true              # Restrict plugin capabilities

# Plugin manifest (plugin.yaml)
plugin:
  id: "com.example.gitintegration"
  name: "Git Integration"
  version: "1.0.0"
  author: "Example Corp"

  permissions:
    - file_system
    - network
    - menu_modification

  menu_items:
    - menu: "file"
      position: 10
      items:
        - id: "git.commit"
          title: "Commit..."
          shortcut: "Cmd+K"
          action: "plugins.git.commit"
          icon: "plugins/git/icons/commit.png"

  shortcuts:
    "Cmd+K": "git.commit"
    "Cmd+Shift+K": "git.push"
```

---

## 12. Implementation Patterns

### 12.1 Performance Optimization

**Lazy Loading**:
```zig
pub const Menu = struct {
    items: union(enum) {
        eager: ArrayList(MenuItem),
        lazy: struct {
            loader: *const fn() []MenuItem,
            cache: ?[]MenuItem,
        },
    },

    pub fn getItems(self: *Menu) ![]MenuItem {
        switch (self.items) {
            .eager => |items| return items.items,
            .lazy => |*lazy| {
                if (lazy.cache) |cache| return cache;
                lazy.cache = try lazy.loader();
                return lazy.cache.?;
            },
        }
    }
};
```

**Virtual Scrolling**:
```zig
// For menus with 100+ items
pub const VirtualMenu = struct {
    items: []MenuItem,
    viewport_height: u32,
    item_height: u32,
    scroll_offset: u32,

    pub fn visibleItems(self: *VirtualMenu) []MenuItem {
        const start = self.scroll_offset / self.item_height;
        const count = (self.viewport_height / self.item_height) + 2;
        const end = @min(start + count, self.items.len);
        return self.items[start..end];
    }
};
```

**Debouncing**:
```zig
// Debounce menu validation
pub const Debouncer = struct {
    last_call: i64,
    delay_ms: u32,

    pub fn shouldRun(self: *Debouncer) bool {
        const now = std.time.milliTimestamp();
        if (now - self.last_call >= self.delay_ms) {
            self.last_call = now;
            return true;
        }
        return false;
    }
};
```

### 12.2 Memory Management

**Object Pooling**:
```zig
pub const MenuItemPool = struct {
    allocator: Allocator,
    pool: ArrayList(*MenuItem),
    capacity: usize,

    pub fn acquire(self: *MenuItemPool) !*MenuItem {
        if (self.pool.items.len > 0) {
            return self.pool.pop();
        }
        return try self.allocator.create(MenuItem);
    }

    pub fn release(self: *MenuItemPool, item: *MenuItem) !void {
        if (self.pool.items.len < self.capacity) {
            item.reset();
            try self.pool.append(item);
        } else {
            self.allocator.destroy(item);
        }
    }
};
```

**Arena Allocator for Menus**:
```zig
pub fn createMenu(global_allocator: Allocator) !Menu {
    var arena = std.heap.ArenaAllocator.init(global_allocator);
    errdefer arena.deinit();

    const allocator = arena.allocator();

    var menu = Menu{
        .arena = arena,
        .items = ArrayList(MenuItem).init(allocator),
    };

    // All allocations use arena
    // Single deinit() frees everything

    return menu;
}
```

### 12.3 Event System

**Observer Pattern**:
```zig
pub const MenuEvent = union(enum) {
    opened: MenuId,
    closed: MenuId,
    item_selected: ItemId,
    item_hovered: ItemId,
    shortcut_triggered: ItemId,
    validation_needed: MenuId,
};

pub const EventBus = struct {
    listeners: HashMap(MenuEvent.Tag, ArrayList(Listener)),

    pub fn emit(self: *EventBus, event: MenuEvent) void {
        const tag = @as(MenuEvent.Tag, event);
        if (self.listeners.get(tag)) |listeners| {
            for (listeners.items) |listener| {
                listener.callback(event);
            }
        }
    }

    pub fn subscribe(
        self: *EventBus,
        event_type: MenuEvent.Tag,
        callback: *const fn(MenuEvent) void
    ) !void {
        // Add listener
    }
};
```

### 12.4 Testing Strategies

**Unit Tests**:
```zig
test "menu item creation" {
    const allocator = testing.allocator;

    var menu = Menu.init(allocator, "File");
    defer menu.deinit();

    try menu.addItem(MenuItem.normal("New"));
    try menu.addItem(MenuItem.separator());
    try menu.addItem(MenuItem.normal("Quit"));

    try testing.expectEqual(@as(usize, 3), menu.items.items.len);
}

test "keyboard shortcut parsing" {
    const shortcut = try Shortcut.parse("Cmd+Shift+S");

    try testing.expect(shortcut.modifiers.command);
    try testing.expect(shortcut.modifiers.shift);
    try testing.expectEqualStrings("s", shortcut.key);
}

test "menu validation" {
    var context = TestContext{
        .has_document = false,
        .is_modified = false,
    };

    const item = MenuItem.normal("Save")
        .withValidator(hasDocumentValidator);

    const result = item.validate(&context);
    try testing.expect(!result.enabled);
}
```

**Integration Tests**:
```zig
test "menu interaction flow" {
    var app = try TestApp.init(testing.allocator);
    defer app.deinit();

    // Open menu
    try app.clickMenuTitle("File");
    try testing.expect(app.isMenuOpen("File"));

    // Hover item
    try app.hoverMenuItem("file.new");
    try testing.expect(app.isItemHighlighted("file.new"));

    // Execute action
    var executed = false;
    app.setCallback("file.new", &executed);
    try app.clickMenuItem("file.new");

    try testing.expect(executed);
    try testing.expect(!app.isMenuOpen("File"));
}
```

---

## Appendix

### A. macOS Menu Guidelines

Reference: [Apple Human Interface Guidelines - Menus](https://developer.apple.com/design/human-interface-guidelines/menus)

**Standard Menu Order**:
1. Application Menu (app name)
2. File
3. Edit
4. Format (if applicable)
5. View
6. Window
7. Help

**Application Menu Items** (standard):
- About [App Name]
- Preferences... (⌘,)
- Services >
- Hide [App Name] (⌘H)
- Hide Others (⌘⌥H)
- Show All
- Quit [App Name] (⌘Q)

**File Menu Items** (standard):
- New (⌘N)
- Open... (⌘O)
- Open Recent >
- Close (⌘W)
- Save (⌘S)
- Save As... (⌘⇧S)
- Revert to Saved
- Page Setup... (⌘⇧P)
- Print... (⌘P)

**Edit Menu Items** (standard):
- Undo (⌘Z)
- Redo (⌘⇧Z)
- Cut (⌘X)
- Copy (⌘C)
- Paste (⌘V)
- Paste and Match Style (⌘⌥⇧V)
- Delete
- Select All (⌘A)
- Find >
- Spelling and Grammar >

### B. Keyboard Shortcut Standards

**Reserved macOS Shortcuts** (do not override):
- ⌘Q: Quit
- ⌘W: Close Window
- ⌘M: Minimize
- ⌘H: Hide Application
- ⌘⌥H: Hide Others
- ⌘Tab: Switch Applications
- ⌘`: Switch Windows

**Common Patterns**:
- ⌘N: New
- ⌘O: Open
- ⌘S: Save
- ⌘⇧S: Save As
- ⌘P: Print
- ⌘Z: Undo
- ⌘⇧Z: Redo
- ⌘X: Cut
- ⌘C: Copy
- ⌘V: Paste
- ⌘A: Select All
- ⌘F: Find
- ⌘,: Preferences

### C. Accessibility Checklist

- [ ] All menu items accessible via keyboard
- [ ] Screen reader announces all elements
- [ ] Focus visible at all times
- [ ] High contrast mode supported
- [ ] Large text mode supported
- [ ] Reduced motion respected
- [ ] Color not sole indicator of state
- [ ] Keyboard shortcuts documented
- [ ] Alternative input methods supported
- [ ] Touch targets minimum 44x44pt

### D. Performance Targets

**Metrics**:
- Menu open latency: < 16ms (60fps)
- Item hover response: < 8ms (120fps)
- Shortcut execution: < 5ms
- Validation run: < 1ms per item
- Configuration load: < 100ms
- Memory per menu: < 1KB
- Memory per item: < 100 bytes

**Optimization Checklist**:
- [ ] Lazy load dynamic menus
- [ ] Cache validation results
- [ ] Virtual scroll long lists
- [ ] Debounce hover events
- [ ] Pool menu item objects
- [ ] Use arena allocators
- [ ] Minimize redraws
- [ ] GPU-accelerated rendering

---

## Implementation Priority

### Phase 1: Core (MVP)
1. Basic menu structure (Menu, MenuItem)
2. Normal items with callbacks
3. Separators
4. Keyboard shortcuts (display only)
5. GTK3 backend
6. Mouse interactions (click, hover)

### Phase 2: Essential
1. Check items
2. Submenus
3. Keyboard navigation
4. Item validation (enable/disable)
5. Recent items
6. Dark mode

### Phase 3: Advanced
1. Radio items
2. Dynamic items
3. Alternate items
4. Badges
5. Icons
6. Full shortcut system
7. YAML configuration

### Phase 4: Power User
1. Customization UI
2. Shortcut editor
3. Profiles
4. Scripting support
5. Plugin system
6. Advanced accessibility

### Phase 5: Polish
1. Animations
2. Touch Bar
3. Services menu
4. Search integration
5. Themes
6. Analytics

---

**End of Specification**

This specification covers every aspect of a production-ready macOS-style menu bar system with comprehensive customization options for power users.
