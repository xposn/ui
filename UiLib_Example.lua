--[[
    UiLib - Drawing-based UI Library for v-severe executor

    ═══════════════════════════════════════════════════════════════════
    QUICK START
    ═══════════════════════════════════════════════════════════════════

    local UiLib = loadstring(game:HttpGet(""))()
    local Window = UiLib:CreateWindow({ Title = "My Script" })
    local Tab = Window:CreateTab("Main")

    Tab:CreateToggle({ Name = "Enabled", Callback = function(v) print(v) end })
    Tab:CreateSlider({ Name = "Speed", Min = 0, Max = 100, Callback = function(v) print(v) end })
    Tab:CreateButton({ Name = "Click Me", Callback = function() print("Clicked!") end })

    ═══════════════════════════════════════════════════════════════════
    WINDOW OPTIONS
    ═══════════════════════════════════════════════════════════════════

    UiLib:CreateWindow({
        Title = "Window Title",     -- Window title (required)
        Subtitle = "v1.0",          -- Subtitle below title (optional)
        Position = Vector2(20, 80), -- Starting position (optional)
        Width = 240,                -- Window width (optional, default 240)
        ToggleKey = "F3",           -- Key to show/hide (optional, default F3)
        Theme = { ... }             -- Custom theme colors (optional)
    })

    ═══════════════════════════════════════════════════════════════════
    ELEMENTS
    ═══════════════════════════════════════════════════════════════════

    All elements support optional Tooltip = "description" for hover tooltips.

    Toggle:
        Tab:CreateToggle({ Name = "Name", Default = false, Tooltip = "desc", Callback = function(value) end })
        Methods: :Set(bool), :Get() -> bool

    Slider:
        Tab:CreateSlider({ Name = "Name", Min = 0, Max = 100, Default = 50, Tooltip = "desc", Callback = function(value) end })
        Methods: :Set(number), :Get() -> number

    Button:
        Tab:CreateButton({ Name = "Name", Tooltip = "desc", Callback = function() end })

    Keybind:
        Tab:CreateKeybind({ Name = "Name", Default = "E", Mode = "toggle", Tooltip = "desc", Callback = function(active) end })
        Modes: "toggle" (default), "hold"
        Methods: :SetKey(string), :GetKey() -> string

    Dropdown:
        Tab:CreateDropdown({ Name = "Name", Options = {"A", "B"}, Default = "A", Tooltip = "desc", Callback = function(value) end })
        Methods: :Set(string), :Get() -> string, :SetOptions(table)

    Colorpicker:
        Tab:CreateColorpicker({ Name = "Name", Default = Color3.fromRGB(255,0,0), Tooltip = "desc", Callback = function(color) end })
        Methods: :Set(Color3), :Get() -> Color3

    TextInput:
        Tab:CreateTextInput({ Name = "Name", Default = "", Placeholder = "Type...", Tooltip = "desc", Callback = function(text) end })
        Methods: :Set(string), :Get() -> string

    Label:
        Tab:CreateLabel({ Text = "Label Text" })

    Divider:
        Tab:CreateDivider()

    ═══════════════════════════════════════════════════════════════════
    WINDOW METHODS
    ═══════════════════════════════════════════════════════════════════

    Window:Toggle()              -- Toggle visibility
    Window:Show() / :Hide()      -- Show/hide window
    Window:Notify(text, seconds) -- Show notification
    Window:Destroy()             -- Remove window

    -- Keybind List (floating panel showing active keybinds)
    Window:ShowKeybindList() / :HideKeybindList() / :ToggleKeybindList()

    -- Config System
    Window:SaveToFile("config.json")
    Window:LoadFromFile("config.json")
    Window:ResetToDefaults()         -- Reset all elements to defaults

    -- Profiles
    Window:SaveProfile("name")
    Window:LoadProfile("name")
    Window:DeleteProfile("name")
    Window:GetProfiles() -> table

    ═══════════════════════════════════════════════════════════════════
    TIPS
    ═══════════════════════════════════════════════════════════════════

    - Right-click elements for context menu (copy/paste colors, clear keybinds, etc.)
    - Drag window header to move
    - Keybind list works even when menu is hidden
    - Press F3 (default) to toggle menu visibility
]]

local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/xposn/Ui-Testing/refs/heads/main/UiLib.lua"))()

-- Get screen size for centering
local camera = game:GetService("Workspace").CurrentCamera
local screenSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
local menuWidth = 400
local menuHeight = 400 -- approximate height
local centerX = (screenSize.X - menuWidth) / 2
local centerY = (screenSize.Y - menuHeight) / 2

-- Create Window
local Window = UiLib:CreateWindow({
    Title = "@p3psi.",
    Subtitle = "F3 to close",
    Position = Vector2.new(centerX, centerY),
    Width = menuWidth,
    ToggleKey = "F3"
})

-- Optional: Customize theme
Window:SetTheme({
    Accent = Color3.fromRGB(130, 90, 255),
    On = Color3.fromRGB(0, 255, 180),
    Off = Color3.fromRGB(255, 60, 85)
})

------------------------------------------
-- Test Tab (one of each element)
------------------------------------------
local TestTab = Window:CreateTab("Test")

-- Label
TestTab:CreateLabel({
    Text = "UI Elements"
})

-- Toggle
local TestToggle = TestTab:CreateToggle({
    Name = "Test Toggle",
    Default = false,
    Callback = function(value)
        print("Test Toggle:", value)
    end
})

-- Keybind (linked to toggle for activation test - toggle mode)
local TestKeybind = TestTab:CreateKeybind({
    Name = "Toggle Key",
    Default = nil,
    Mode = "toggle",
    LinkedToggle = TestToggle,
    Callback = function(key)
        print("Test Key:", key)
    end,
    ActivateCallback = function(active)
        print("Keybind activated:", active)
    end
})

-- Slider
local TestSlider = TestTab:CreateSlider({
    Name = "Test Slider",
    Min = 0,
    Max = 100,
    Default = 0,
    Step = 5,
    Suffix = "%",
    Callback = function(value)
        print("Test Slider:", value)
    end
})

TestTab:CreateDivider()

-- Dropdown
local TestDropdown = TestTab:CreateDropdown({
    Name = "Test Cycle",
    Options = {"Option 1", "Option 2", "Option 3"},
    Default = "Option 1",
    Callback = function(value)
        print("Test Cycle:", value)
    end
})

-- Colorpicker
local TestColor = TestTab:CreateColorpicker({
    Name = "Test Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        print("Test Color:", color)
    end
})

-- TextInput
local TestInput = TestTab:CreateTextInput({
    Name = "Test Input",
    Default = "",
    Placeholder = "Type here...",
    Callback = function(text)
        print("Test Input:", text)
    end
})

TestTab:CreateDivider()

-- Button
local TestButton = TestTab:CreateButton({
    Name = "Test Button",
    Callback = function()
        print("Button clicked!")
        Window:Notify("Clicked!", 2)
    end
})

------------------------------------------
-- Settings Tab
------------------------------------------
local SettingsTab = Window:CreateTab("Settings")

-- Keybind List toggle (draggable floating panel)
local ShowKeybindList = SettingsTab:CreateToggle({
    Name = "Show Keybind List",
    Default = false,
    Callback = function(value)
        if value then
            Window:ShowKeybindList()
        else
            Window:HideKeybindList()
        end
    end
})

SettingsTab:CreateDivider()

-- Profiles Section
SettingsTab:CreateLabel({
    Text = "Profiles"
})

-- Get available profiles
local function GetProfileOptions()
    local profiles = Window:GetProfiles()
    local options = {"Default"}
    for _, profile in ipairs(profiles) do
        table.insert(options, profile)
    end
    return options
end

-- Profiles dropdown
local ProfilesDropdown = SettingsTab:CreateDropdown({
    Name = "Profile",
    Options = GetProfileOptions(),
    Default = "Default",
    Callback = function(value)
        print("Selected profile:", value)
    end
})

-- Profile name input for saving
local ProfileNameInput = SettingsTab:CreateTextInput({
    Name = "Profile Name",
    Default = "MyProfile",
    Placeholder = "Enter name...",
    Callback = function(text)
        print("Profile name:", text)
    end
})

-- Profile buttons
local SaveProfileButton = SettingsTab:CreateButton({
    Name = "Save Profile",
    Callback = function()
        local name = ProfileNameInput.Value
        if name and name ~= "" then
            if Window:SaveProfile(name) then
                Window:Notify("Saved: " .. name, 2)
                -- Refresh dropdown options
                ProfilesDropdown.Options = GetProfileOptions()
            else
                Window:Notify("Save failed", 2)
            end
        else
            Window:Notify("Enter name first", 2)
        end
    end
})

local LoadProfileButton = SettingsTab:CreateButton({
    Name = "Load Profile",
    Callback = function()
        local name = ProfilesDropdown.Value
        if name == "Default" then
            -- Reset all elements to default values
            Window:ResetToDefaults()
            Window:Notify("Reset to defaults", 2)
        elseif name then
            if Window:LoadProfile(name) then
                Window:Notify("Loaded: " .. name, 2)
            else
                Window:Notify("Load failed", 2)
            end
        else
            Window:Notify("Select profile first", 2)
        end
    end
})

local DeleteProfileButton = SettingsTab:CreateButton({
    Name = "Delete Profile",
    Callback = function()
        local name = ProfilesDropdown.Value
        if name and name ~= "Default" then
            if Window:DeleteProfile(name) then
                Window:Notify("Deleted: " .. name, 2)
                -- Refresh dropdown options
                ProfilesDropdown.Options = GetProfileOptions()
                ProfilesDropdown:Set(ProfilesDropdown.Options[1] or "Default")
            else
                Window:Notify("Delete failed", 2)
            end
        else
            Window:Notify("Select profile first", 2)
        end
    end
})


------------------------------------------
-- API Usage Examples
------------------------------------------

-- Get/Set values programmatically
-- TriggerBotToggle:Set(true)
-- DelaySlider:Set(150)
-- ModeDropdown:Set("always")

-- Show notifications
-- Window:Notify("Hello!", 3)

-- Toggle window visibility
-- Window:Toggle()
-- Window:Show()
-- Window:Hide()

-- Config/Profile system
-- Window:SaveToFile("config.json")
-- Window:LoadFromFile("config.json")
-- Window:SaveProfile("MyProfile")
-- Window:LoadProfile("MyProfile")
-- Window:DeleteProfile("MyProfile")
-- local profiles = Window:GetProfiles()

-- Keybind List (draggable floating panel)
-- Window:ShowKeybindList()
-- Window:HideKeybindList()
-- Window:ToggleKeybindList()

-- Destroy window when done
-- Window:Destroy()

print("UiLib loaded! Press F3 to toggle menu. Right-click elements for context menu.")
