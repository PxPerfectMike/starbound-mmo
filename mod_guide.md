# Starbound Modding Guide

A comprehensive reference for creating Starbound mods, based on official documentation and community resources.

## Sources
- [Starbounder Wiki - Panes (GUI)](https://starbounder.org/Modding:JSON/Variables/Panes_(GUI))
- [Starbounder Wiki - ActiveItem Table](https://starbounder.org/Modding:Lua/Tables/Activeitem)
- [Starbounder Wiki - Object Hooks](https://starbounder.org/Modding:Lua/Hooks/Object)
- [Starbounder Wiki - Widget Table](https://starbounder.org/Modding:Lua/Tables/Widget)
- [Silverfeelin's ItemInterfaces](https://github.com/Silverfeelin/Starbound-ItemInterfaces)
- [Silverfeelin's CompactInterfaces](https://github.com/Silverfeelin/Starbound-CompactInterfaces)

---

## Part 1: Mod Structure

### Basic Folder Structure
```
mymod/
├── _metadata                    # Mod info (required)
├── items/
│   └── active/                  # Active items (held items)
├── objects/                     # Placeable objects
├── interface/                   # GUI configurations
├── scripts/                     # Lua scripts
└── *.patch                      # JSON patches to vanilla files
```

### _metadata File
```json
{
  "name": "MyMod",
  "friendlyName": "My Mod Name",
  "description": "Description of the mod",
  "author": "Author Name",
  "version": "1.0.0",
  "link": "",
  "steamContentId": "",
  "tags": "",
  "includes": [],
  "requires": [],
  "priority": 0
}
```

### Asset Paths
- All asset paths in Starbound are **absolute from the assets root**
- Paths start with `/` (e.g., `/interface/inventory/x.png`)
- Paths are case-sensitive on some systems

---

## Part 2: ScriptPane Interfaces (GUI)

### How ScriptPanes Work
A ScriptPane is an in-game window consisting of:
1. **Background** - The window frame (determines window size)
2. **Widgets** - UI elements (buttons, labels, lists, etc.)
3. **Scripts** - Lua code for interactivity

### Coordinate System
- Origin is **bottom-left corner** (0, 0)
- X increases rightward
- Y increases upward

### Basic ScriptPane Config
```json
{
  "gui": {
    "background": {
      "type": "background",
      "fileHeader": "/interface/streamingvideo/header.png",
      "fileBody": "/interface/streamingvideo/body.png",
      "fileFooter": "/interface/streamingvideo/footer.png"
    },
    "close": {
      "type": "button",
      "base": "/interface/inventory/x.png",
      "hover": "/interface/inventory/xhover.png",
      "press": "/interface/inventory/xpress.png",
      "position": [252, 206]
    },
    "myLabel": {
      "type": "label",
      "position": [10, 10],
      "value": "Hello World"
    }
  },
  "scripts": ["/interface/mymod/myscript.lua"],
  "scriptDelta": 10
}
```

### Background Widget
The background widget is **required** and determines window size.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | Always `"background"` |
| `fileHeader` | string | No | Top section image |
| `fileBody` | string | Yes | Middle section (stretches) |
| `fileFooter` | string | No | Bottom section image |

**Note:** Background has NO `position` parameter - it fills the entire window.

### Vanilla Background Paths That Work
```
/interface/streamingvideo/header.png
/interface/streamingvideo/body.png
/interface/streamingvideo/footer.png

/interface/scripted/mmupgrade/header.png
/interface/scripted/mmupgrade/body.png
/interface/scripted/mmupgrade/footer.png

/interface/crafting/craftingfurnitureheader.png
/interface/crafting/craftingfurniturebody.png
/interface/crafting/craftingfurniturefooter.png
```

### Vanilla Button/UI Paths
```
/interface/inventory/x.png
/interface/inventory/xhover.png
/interface/inventory/xpress.png

/interface/x.png
/interface/xhover.png
/interface/xpress.png
```

---

## Part 3: Widget Types

### Common Widget Parameters
All widgets share these:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | string | Required | Widget type |
| `position` | [x, y] | Required* | Position from bottom-left |
| `visible` | bool | true | Show/hide widget |
| `zlevel` | int | 0 | Layer depth (higher = front) |

### LabelWidget
```json
{
  "myLabel": {
    "type": "label",
    "position": [10, 50],
    "value": "Hello ^orange;World^reset;",
    "hAnchor": "left",
    "vAnchor": "bottom",
    "wrapWidth": 200
  }
}
```

Color codes: `^red;`, `^orange;`, `^yellow;`, `^green;`, `^blue;`, `^cyan;`, `^gray;`, `^reset;`

### ButtonWidget
```json
{
  "myButton": {
    "type": "button",
    "position": [10, 10],
    "base": "/path/to/button.png",
    "hover": "/path/to/buttonhover.png",
    "pressed": "/path/to/buttonpress.png",
    "caption": "Click Me",
    "callback": "onMyButtonClick"
  }
}
```

**Important:** Callbacks must be listed in `scriptWidgetCallbacks`:
```json
{
  "gui": { ... },
  "scripts": ["/interface/mymod/script.lua"],
  "scriptWidgetCallbacks": ["onMyButtonClick", "onOtherButton"]
}
```

### ItemSlotWidget
```json
{
  "myItemSlot": {
    "type": "itemSlot",
    "position": [10, 10],
    "callback": "onItemSlotClick"
  }
}
```

### ScrollAreaWidget
```json
{
  "myScrollArea": {
    "type": "scrollArea",
    "rect": [5, 25, 300, 200],
    "children": {
      "myList": {
        "type": "list",
        "schema": {
          "selectedBG": "/path/to/selected.png",
          "unselectedBG": "/path/to/unselected.png",
          "spacing": [0, 1],
          "memberSize": [280, 36],
          "listTemplate": {
            "itemName": {
              "type": "label",
              "position": [5, 10],
              "value": "Item"
            }
          }
        }
      }
    }
  }
}
```

Access child widgets with dot notation: `"myScrollArea.myList"`

---

## Part 4: Opening Interfaces

### Method 1: From Objects (Recommended for Terminals)
In the `.object` file:
```json
{
  "objectName": "myTerminal",
  "interactive": true,
  "interactAction": "ScriptPane",
  "interactData": "/interface/mymod/myinterface.config",
  "scripts": ["/objects/mymod/myterminal.lua"]
}
```

**Critical:** `interactData` must be a **string path**, NOT an object!

Wrong:
```json
"interactData": { "config": "/interface/mymod/myinterface.config" }
```

Right:
```json
"interactData": "/interface/mymod/myinterface.config"
```

### Method 2: From Object Script (onInteraction)
```lua
function onInteraction(args)
  return {"ScriptPane", "/interface/mymod/myinterface.config"}
end
```

**Warning:** If your object script has `onInteraction()`, it may override the JSON `interactAction`. Usually the JSON's interactAction is what doesn't work.

### Method 3: From Active Items
```lua
function activate(fireMode, shiftHeld)
  if fireMode == "primary" then
    local cfg = root.assetJson("/interface/mymod/myinterface.config")
    activeItem.interact("ScriptPane", cfg)
  end
end
```

### Method 4: From Player Scripts
```lua
player.interact("ScriptPane", "/interface/mymod/myinterface.config")
```

---

## Part 5: Active Items

### What Are Active Items?
Active items are held items (tools, weapons) that can execute scripts when used.

### Basic Active Item Structure
```
items/active/mymod/
├── myitem.activeitem      # Item definition
├── myitem.lua             # Item script
└── myitem.animation       # Animation definition (often required)
```

### Simple Active Item (.activeitem)
```json
{
  "itemName": "myItem",
  "shortdescription": "My Item",
  "description": "Description here",
  "rarity": "Common",
  "maxStack": 1,
  "twoHanded": false,
  "category": "tool",

  "inventoryIcon": "/interface/bookmarks/icons/beamparty.png",

  "scripts": ["/items/active/mymod/myitem.lua"],
  "scriptDelta": 5
}
```

### Active Item Script (.lua)
```lua
function init()
  -- Called when item is equipped
end

function update(dt, fireMode, shiftHeld)
  -- Called every scriptDelta ticks
  -- fireMode: "none", "primary", "alt"
end

function activate(fireMode, shiftHeld)
  -- Called when fire starts
  if fireMode == "primary" then
    -- Open an interface
    local cfg = root.assetJson("/interface/mymod/myinterface.config")
    activeItem.interact("ScriptPane", cfg)
  end
end

function uninit()
  -- Called when item is unequipped
end
```

### Active Item with Animation (Required for Visual Items)
Many active items need an animation file. Without it, they may show default/broken sprites.

**myitem.animation:**
```json
{
  "animatedParts": {
    "stateTypes": {
      "activity": {
        "default": "idle",
        "states": {
          "idle": {}
        }
      }
    },
    "parts": {
      "middle": {
        "properties": {
          "centered": true,
          "image": "<partImage>",
          "offset": [0, 0]
        }
      }
    }
  }
}
```

Then in .activeitem:
```json
{
  "animation": "/items/active/mymod/myitem.animation",
  "animationParts": {
    "middle": "/items/active/mymod/myitem.png"
  }
}
```

### Using Silverfeelin's ItemInterfaces (Recommended)
For multiplayer-compatible item interfaces, use the [ItemInterfaces mod](https://github.com/Silverfeelin/Starbound-ItemInterfaces):

```json
{
  "name": "fossilbrushbeginner",
  "count": 1,
  "parameters": {
    "shortdescription": "Market Remote",
    "itemInterface": {
      "path": "/interface/mymod/myinterface.config",
      "type": "ScriptPane",
      "holding": false,
      "primary": true
    }
  }
}
```

---

## Part 6: Objects

### Basic Object Structure
```
objects/mymod/
├── myobject.object        # Object definition
├── myobject.png           # Sprite
├── myobjecticon.png       # Inventory icon
└── myobject.lua           # Optional script
```

### Object Definition (.object)
```json
{
  "objectName": "myObject",
  "colonyTags": ["electronic"],
  "rarity": "Common",
  "category": "decorative",
  "price": 100,
  "printable": false,

  "description": "A description",
  "shortdescription": "My Object",
  "race": "generic",

  "inventoryIcon": "/objects/mymod/myobjecticon.png",

  "orientations": [
    {
      "image": "/objects/mymod/myobject.png",
      "imagePosition": [-8, 0],
      "spaceScan": 0.1,
      "anchors": ["bottom"]
    }
  ],

  "interactive": true,
  "interactAction": "ScriptPane",
  "interactData": "/interface/mymod/myinterface.config"
}
```

### Object with Script
```json
{
  "objectName": "myObject",
  "scripts": ["/objects/mymod/myobject.lua"],
  "scriptDelta": 20,

  "interactive": true
}
```

**myobject.lua:**
```lua
function init()
  object.setInteractive(true)
end

function onInteraction(args)
  return {"ScriptPane", "/interface/mymod/myinterface.config"}
end
```

---

## Part 7: Lua Scripting

### Global Tables Available

**In Interface Scripts (ScriptPane):**
- `player` - Player functions
- `world` - World functions
- `widget` - Widget manipulation
- `pane` - Pane functions
- `config` - Config access
- `sb` - Starbound utilities
- `root` - Asset access

**In Object Scripts:**
- `object` - Object functions
- `world` - World functions
- `entity` - Entity functions
- `animator` - Animation control
- `config` - Config access

**In Active Item Scripts:**
- `activeItem` - Active item functions
- `animator` - Animation control
- `config` - Config access

### Common Widget Functions
```lua
-- Set text
widget.setText("labelName", "New text")

-- Get text
local text = widget.getText("textboxName")

-- Show/hide
widget.setVisible("widgetName", true)

-- Set position
widget.setPosition("widgetName", {10, 20})

-- Clear list
widget.clearListItems("scrollArea.listName")

-- Add list item
local itemId = widget.addListItem("scrollArea.listName")
widget.setText("scrollArea.listName." .. itemId .. ".labelName", "Item text")

-- Set item slot
widget.setItemSlotItem("slotName", {name = "ironbar", count = 5})

-- Get widget data
local data = widget.getData("widgetName")
widget.setData("widgetName", {myKey = "myValue"})
```

### Common Root Functions
```lua
-- Load JSON asset
local cfg = root.assetJson("/path/to/file.json")

-- Check if asset exists
local exists = root.assetExists("/path/to/file.png")

-- Get item config
local itemCfg = root.itemConfig("ironbar")
```

---

## Part 8: JSON Patches

### Patch File Naming
To patch `player.config`, create `player.config.patch`

### Patch Operations
```json
[
  {
    "op": "add",
    "path": "/defaultItems/-",
    "value": { "item": "myItem" }
  },
  {
    "op": "replace",
    "path": "/someValue",
    "value": "newValue"
  },
  {
    "op": "remove",
    "path": "/unwantedKey"
  }
]
```

### Path Syntax
- `/key` - Access object key
- `/array/-` - Append to array
- `/array/0` - First array element

---

## Part 9: Debugging

### Log Location
```
Windows: %APPDATA%\Starbound\starbound.log
Linux: ~/.local/share/Starbound/starbound.log
Mac: ~/Library/Application Support/Starbound/starbound.log
```

### Logging from Lua
```lua
sb.logInfo("Info message: %s", variable)
sb.logWarn("Warning: %s", variable)
sb.logError("Error: %s", variable)
```

### Common Errors

**"No such key in Json::get"**
- Usually means a config path is wrong or JSON structure is invalid

**"Cannot call get with key on Json type null"**
- The config file doesn't exist or has wrong structure

**Widget callback errors**
- Make sure callback is in `scriptWidgetCallbacks` array
- Make sure the function exists in your Lua script
- Function name must match exactly (case-sensitive)

**Background not showing (only title visible)**
- Background image paths are wrong or don't exist
- Check that header/body/footer paths point to real vanilla assets

**Active item shows wrong sprite**
- Need animation file or correct `inventoryIcon`
- Animation parts may be misconfigured

---

## Part 10: Best Practices

1. **Always use vanilla asset paths for UI backgrounds** until custom images are verified working

2. **Test with /spawnitem command** before adding to default items

3. **Check starbound.log** after every test for errors

4. **Use absolute paths** starting with `/`

5. **Keep scriptDelta reasonable** (10-20 for UI, 20+ for objects)

6. **For objects:** Use `interactAction`/`interactData` in JSON rather than `onInteraction` in Lua when possible

7. **For active items:** Consider using Silverfeelin's ItemInterfaces for multiplayer compatibility

8. **Naming convention:** Prefix with mod name to avoid conflicts (e.g., `mmo_marketremote`)

---

## Quick Reference: Working Examples

### Minimal Working ScriptPane
```json
{
  "gui": {
    "background": {
      "type": "background",
      "fileHeader": "/interface/streamingvideo/header.png",
      "fileBody": "/interface/streamingvideo/body.png",
      "fileFooter": "/interface/streamingvideo/footer.png"
    },
    "close": {
      "type": "button",
      "base": "/interface/x.png",
      "hover": "/interface/xhover.png",
      "pressed": "/interface/xpress.png",
      "position": [252, 206]
    },
    "testLabel": {
      "type": "label",
      "position": [20, 100],
      "value": "Hello World!"
    }
  },
  "scripts": ["/interface/mymod/test.lua"],
  "scriptDelta": 10
}
```

### Minimal Working Object
```json
{
  "objectName": "mmo_terminal",
  "shortdescription": "MMO Terminal",
  "description": "Opens the MMO interface",
  "race": "generic",
  "category": "decorative",
  "price": 0,

  "inventoryIcon": "/objects/outpost/outpostbutton/outpostbuttonicon.png",
  "orientations": [{
    "image": "/objects/outpost/outpostbutton/outpostbutton.png:off",
    "imagePosition": [-8, 0],
    "spaceScan": 0.1,
    "anchors": ["bottom"]
  }],

  "interactive": true,
  "interactAction": "ScriptPane",
  "interactData": "/interface/mmo/market/market.config"
}
```
