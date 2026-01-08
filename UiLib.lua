local UiLib = {}
UiLib.__index = UiLib

-- Services
local RunService = game:GetService("RunService")

-- Default Theme
local Theme = {
    On = Color3.fromRGB(0, 255, 180),
    Off = Color3.fromRGB(255, 60, 85),
    Accent = Color3.fromRGB(130, 90, 255),
    AccentDark = Color3.fromRGB(100, 70, 200),
    Bg = Color3.fromRGB(15, 15, 20),
    BgSecondary = Color3.fromRGB(25, 25, 35),
    BgHover = Color3.fromRGB(35, 35, 50),
    Border = Color3.fromRGB(130, 90, 255),
    Text = Color3.fromRGB(235, 235, 245),
    TextDim = Color3.fromRGB(100, 100, 120),
    TextMuted = Color3.fromRGB(70, 70, 90)
}

-- Animation Helpers
local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function LerpColor(c1, c2, t)
    return Color3.fromRGB(
        Lerp(c1.R * 255, c2.R * 255, t),
        Lerp(c1.G * 255, c2.G * 255, t),
        Lerp(c1.B * 255, c2.B * 255, t)
    )
end

-- Drawing Helpers
local OFF_SCREEN = Vector2.new(-9999, -9999)

local function CreateText(size, color, center)
    local text = Drawing.new("Text")
    text.Size = size or 14
    text.Color = color or Theme.Text
    text.Center = center or false
    text.Outline = true
    text.OutlineColor = Color3.fromRGB(0, 0, 0)
    pcall(function() text.Visible = true end)
    return text
end

local function CreateSquare(filled, color, rounding)
    local square = Drawing.new("Square")
    square.Filled = filled or false
    square.Color = color or Theme.Bg
    square.Rounding = rounding or 0
    pcall(function() square.Visible = true end)
    return square
end

local function CreateLine(color, thickness)
    local line = Drawing.new("Line")
    line.Color = color or Theme.Accent
    line.Thickness = thickness or 1
    pcall(function() line.Visible = true end)
    return line
end

-- JSON encoder/decoder (v-severe doesn't have HttpService)
local function JSONEncode(obj)
    local function encode(val)
        local t = type(val)
        if t == "nil" then
            return "null"
        elseif t == "boolean" then
            return val and "true" or "false"
        elseif t == "number" then
            return tostring(val)
        elseif t == "string" then
            -- Escape special characters
            local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
            return '"' .. escaped .. '"'
        elseif t == "table" then
            -- Check if array or object
            local isArray = true
            local maxIndex = 0
            for k, v in pairs(val) do
                if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                    isArray = false
                    break
                end
                maxIndex = math.max(maxIndex, k)
            end
            isArray = isArray and maxIndex == #val

            if isArray then
                local parts = {}
                for i, v in ipairs(val) do
                    table.insert(parts, encode(v))
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                local parts = {}
                for k, v in pairs(val) do
                    if type(k) == "string" then
                        table.insert(parts, '"' .. k .. '":' .. encode(v))
                    end
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
        return "null"
    end
    return encode(obj)
end

local function JSONDecode(str)
    local pos = 1
    local function skipWhitespace()
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    local function parseValue()
        skipWhitespace()
        local char = str:sub(pos, pos)

        if char == '"' then
            -- String
            pos = pos + 1
            local start = pos
            local result = ""
            while pos <= #str do
                local c = str:sub(pos, pos)
                if c == '"' then
                    pos = pos + 1
                    return result
                elseif c == '\\' then
                    pos = pos + 1
                    local escape = str:sub(pos, pos)
                    if escape == 'n' then result = result .. '\n'
                    elseif escape == 'r' then result = result .. '\r'
                    elseif escape == 't' then result = result .. '\t'
                    elseif escape == '"' then result = result .. '"'
                    elseif escape == '\\' then result = result .. '\\'
                    else result = result .. escape
                    end
                else
                    result = result .. c
                end
                pos = pos + 1
            end
            return result
        elseif char == '{' then
            -- Object
            pos = pos + 1
            local obj = {}
            skipWhitespace()
            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            end
            while true do
                skipWhitespace()
                if str:sub(pos, pos) ~= '"' then break end
                local key = parseValue()
                skipWhitespace()
                if str:sub(pos, pos) == ':' then pos = pos + 1 end
                obj[key] = parseValue()
                skipWhitespace()
                if str:sub(pos, pos) == ',' then
                    pos = pos + 1
                elseif str:sub(pos, pos) == '}' then
                    pos = pos + 1
                    break
                else
                    break
                end
            end
            return obj
        elseif char == '[' then
            -- Array
            pos = pos + 1
            local arr = {}
            skipWhitespace()
            if str:sub(pos, pos) == ']' then
                pos = pos + 1
                return arr
            end
            while true do
                table.insert(arr, parseValue())
                skipWhitespace()
                if str:sub(pos, pos) == ',' then
                    pos = pos + 1
                elseif str:sub(pos, pos) == ']' then
                    pos = pos + 1
                    break
                else
                    break
                end
            end
            return arr
        elseif str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        else
            -- Number
            local numStr = str:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
            if numStr then
                pos = pos + #numStr
                return tonumber(numStr)
            end
        end
        return nil
    end

    return parseValue()
end

-- Color to Hex conversion
local function ColorToHex(color)
    local r = math.floor(color.R * 255 + 0.5)
    local g = math.floor(color.G * 255 + 0.5)
    local b = math.floor(color.B * 255 + 0.5)
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Hex to Color conversion
local function HexToColor(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0
        return Color3.fromRGB(r, g, b)
    end
    return nil
end

-- Clipboard storage (per-window, since v-severe doesn't have system clipboard)
local ClipboardColor = nil

-- Key display name mapping
local KeyDisplayNames = {
    ["XButton1"] = "M4",
    ["XButton2"] = "M5",
    ["MouseButton1"] = "M1",
    ["MouseButton2"] = "M2",
    ["MouseButton3"] = "M3",
}

local function GetKeyDisplayName(key)
    if not key then return "None" end
    return KeyDisplayNames[key] or key
end

-- Element Base Class
local Element = {}
Element.__index = Element

function Element.new(elementType)
    local self = setmetatable({}, Element)
    self.Type = elementType
    self.Visible = true
    self.Selected = false
    self.SubIndex = 1
    self.SubCount = 1
    self.Drawings = {}
    return self
end

function Element:SetVisible(visible)
    self.Visible = visible
    -- Move all drawings off screen to hide them
    if not visible then
        for key, drawing in pairs(self.Drawings) do
            -- Handle nested arrays (like colorGrid, hueColors, optionBgs, optionTexts) by checking key name
            if key == "colorGrid" or key == "hueColors" or key == "optionBgs" or key == "optionTexts" then
                for _, subDrawing in ipairs(drawing) do
                    pcall(function() subDrawing.Position = OFF_SCREEN end)
                end
            else
                -- Use pcall since not all drawings have Position/From
                pcall(function() drawing.Position = OFF_SCREEN end)
                pcall(function() drawing.From = OFF_SCREEN end)
                pcall(function() drawing.To = OFF_SCREEN end)
            end
        end
    end
    -- When visible=true, the Render function will set proper positions
end

function Element:Remove()
    for key, drawing in pairs(self.Drawings) do
        -- Handle nested arrays (like colorGrid, hueColors, optionBgs, optionTexts) by checking key name
        if key == "colorGrid" or key == "hueColors" or key == "optionBgs" or key == "optionTexts" then
            for _, subDrawing in ipairs(drawing) do
                pcall(function() subDrawing:Remove() end)
            end
        else
            pcall(function() drawing:Remove() end)
        end
    end
end

-- Toggle Element (Switch style)
local Toggle = setmetatable({}, Element)
Toggle.__index = Toggle

function Toggle.new(options)
    local self = setmetatable(Element.new("Toggle"), Toggle)
    self.Name = options.Name or "Toggle"
    self.Value = options.Default or false
    self.Callback = options.Callback or function() end
    self.Tooltip = options.Tooltip
    self.Hovered = false

    -- Animation state
    self.AnimProgress = self.Value and 1 or 0
    self.AnimSpeed = 10 -- Higher = faster animation

    -- Create drawings
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 4)
    self.Drawings.label = CreateText(13, Theme.Text, false)
    -- Switch track
    self.Drawings.switchTrack = CreateSquare(true, Theme.BgHover, 7)
    -- Switch knob
    self.Drawings.switchKnob = CreateSquare(true, Theme.TextDim, 5)

    return self
end

function Toggle:Set(value)
    self.Value = value
    if self.Callback then
        self.Callback(value)
    end
end

function Toggle:Get()
    return self.Value
end

function Toggle:OnSelect()
    self.Value = not self.Value
    if self.Callback then
        self.Callback(self.Value)
    end
end

function Toggle:Render(x, y, width, hovered, theme, deltaTime)
    local rowH = 28

    -- Animate progress towards target
    local targetProgress = self.Value and 1 or 0
    local dt = deltaTime or 0.016
    self.AnimProgress = Lerp(self.AnimProgress, targetProgress, math.min(1, self.AnimSpeed * dt))

    -- Background (shows on hover)
    self.Drawings.bg.Size = Vector2.new(width, rowH)
    self.Drawings.bg.Color = hovered and theme.BgHover or theme.BgSecondary
    self.Drawings.bg.Position = Vector2.new(x, y)

    -- Label
    self.Drawings.label.Text = self.Name
    self.Drawings.label.Color = hovered and theme.Text or theme.TextDim
    self.Drawings.label.Position = Vector2.new(x + 10, y + 6)

    -- Switch track (right side) - animated color
    local switchX = x + width - 42
    local switchY = y + 6
    self.Drawings.switchTrack.Size = Vector2.new(32, 16)
    self.Drawings.switchTrack.Color = LerpColor(theme.BgHover, theme.Accent, self.AnimProgress)
    self.Drawings.switchTrack.Position = Vector2.new(switchX, switchY)

    -- Switch knob - animated position
    local knobOffX = switchX + 2
    local knobOnX = switchX + 18
    local knobX = Lerp(knobOffX, knobOnX, self.AnimProgress)
    self.Drawings.switchKnob.Size = Vector2.new(12, 12)
    self.Drawings.switchKnob.Color = theme.Text
    self.Drawings.switchKnob.Position = Vector2.new(knobX, switchY + 2)

    return rowH
end

-- Slider Element (Visual slider bar)
local Slider = setmetatable({}, Element)
Slider.__index = Slider

function Slider.new(options)
    local self = setmetatable(Element.new("Slider"), Slider)
    self.Name = options.Name or "Slider"
    self.Value = options.Default or options.Min or 0
    self.Min = options.Min or 0
    self.Max = options.Max or 100
    self.Step = options.Step or 1
    self.Suffix = options.Suffix or ""
    self.Callback = options.Callback or function() end
    self.Tooltip = options.Tooltip
    self.Dragging = false

    -- Animation state
    self.AnimValue = self.Value
    self.AnimSpeed = 12

    -- Create drawings
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 4)
    self.Drawings.label = CreateText(13, Theme.Text, false)
    self.Drawings.value = CreateText(13, Theme.Accent, false)
    -- Slider bar
    self.Drawings.sliderBg = CreateSquare(true, Theme.BgHover, 4)
    self.Drawings.sliderFill = CreateSquare(true, Theme.Accent, 4)

    return self
end

function Slider:Set(value)
    self.Value = math.clamp(value, self.Min, self.Max)
    -- Round to step
    self.Value = math.floor(self.Value / self.Step + 0.5) * self.Step
    self.Value = math.clamp(self.Value, self.Min, self.Max)
    if self.Callback then
        self.Callback(self.Value)
    end
end

function Slider:Get()
    return self.Value
end

function Slider:OnLeft()
    self:Set(self.Value - self.Step)
end

function Slider:OnRight()
    self:Set(self.Value + self.Step)
end

function Slider:OnSelect()
    -- Toggle dragging or increment
    self:Set(self.Value + self.Step)
end

function Slider:Render(x, y, width, hovered, theme, deltaTime)
    local rowH = 38

    -- Animate towards target value
    local dt = deltaTime or 0.016
    self.AnimValue = Lerp(self.AnimValue, self.Value, math.min(1, self.AnimSpeed * dt))

    -- Background
    self.Drawings.bg.Size = Vector2.new(width, rowH)
    self.Drawings.bg.Color = hovered and theme.BgHover or theme.BgSecondary
    self.Drawings.bg.Position = Vector2.new(x, y)

    -- Label
    self.Drawings.label.Text = self.Name
    self.Drawings.label.Color = hovered and theme.Text or theme.TextDim
    self.Drawings.label.Position = Vector2.new(x + 10, y + 4)

    -- Value text (right side)
    self.Drawings.value.Text = tostring(self.Value) .. self.Suffix
    self.Drawings.value.Color = theme.Accent
    self.Drawings.value.Position = Vector2.new(x + width - 45, y + 4)

    -- Slider bar - use animated value for smooth fill
    local barX = x + 10
    local barY = y + 22
    local barW = width - 20
    local barH = 8
    local percent = (self.AnimValue - self.Min) / (self.Max - self.Min)
    local fillW = math.max(4, barW * percent)

    self.Drawings.sliderBg.Size = Vector2.new(barW, barH)
    self.Drawings.sliderBg.Position = Vector2.new(barX, barY)

    self.Drawings.sliderFill.Size = Vector2.new(fillW, barH)
    self.Drawings.sliderFill.Position = Vector2.new(barX, barY)

    -- Store bounds for click detection
    self.SliderBounds = {x = barX, y = barY, w = barW, h = barH}

    return rowH
end

-- Button Element (Hover-styled button)
local Button = setmetatable({}, Element)
Button.__index = Button

function Button.new(options)
    local self = setmetatable(Element.new("Button"), Button)
    self.Name = options.Name or "Button"
    self.Callback = options.Callback or function() end
    self.Tooltip = options.Tooltip
    self.SubCount = 1

    -- Create drawings
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 6)
    self.Drawings.border = CreateSquare(false, Theme.Border, 6)
    self.Drawings.border.Thickness = 1
    self.Drawings.text = CreateText(13, Theme.Text, true)

    return self
end

function Button:OnSelect()
    if self.Callback then
        self.Callback()
    end
end

function Button:Render(x, y, width, hovered, theme)
    local btnH = 28

    self.Drawings.bg.Position = Vector2.new(x, y)
    self.Drawings.bg.Size = Vector2.new(width, btnH)
    self.Drawings.bg.Color = hovered and theme.Accent or theme.BgSecondary

    self.Drawings.border.Position = Vector2.new(x, y)
    self.Drawings.border.Size = Vector2.new(width, btnH)
    self.Drawings.border.Color = hovered and theme.Accent or theme.Border

    self.Drawings.text.Text = self.Name
    self.Drawings.text.Color = theme.Text
    self.Drawings.text.Position = Vector2.new(x + width / 2, y + 7)

    return btnH + 4
end

-- Keybind Element (Click to bind style)
local Keybind = setmetatable({}, Element)
Keybind.__index = Keybind

function Keybind.new(options)
    local self = setmetatable(Element.new("Keybind"), Keybind)
    self.Name = options.Name or "Keybind"
    self.Value = options.Default
    self.Mode = options.Mode or "toggle" -- toggle, hold
    self.Active = false -- Whether the keybind is currently activated
    self.LinkedToggle = options.LinkedToggle -- Reference to a toggle to control
    self.ActivateCallback = options.ActivateCallback -- Called when keybind activates/deactivates
    self.Callback = options.Callback or function() end
    self.ModeCallback = options.ModeCallback or function() end
    self.Tooltip = options.Tooltip
    self.WaitingForKey = false
    self.SubCount = 1

    -- Create drawings
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 4)
    self.Drawings.label = CreateText(13, Theme.Text, false)
    -- Key button
    self.Drawings.keyBg = CreateSquare(true, Theme.BgHover, 4)
    self.Drawings.keyText = CreateText(12, Theme.Text, true)
    -- Mode button
    self.Drawings.modeBg = CreateSquare(true, Theme.BgHover, 4)
    self.Drawings.modeText = CreateText(10, Theme.TextDim, true)

    return self
end

function Keybind:SetKey(key)
    self.Value = key
    self.WaitingForKey = false
    if self.Callback then
        self.Callback(key)
    end
end

function Keybind:GetKey()
    return self.Value
end

function Keybind:OnSelect()
    -- Primary click triggers keybind capture
    self.WaitingForKey = true
end

function Keybind:ToggleMode()
    self.Mode = self.Mode == "toggle" and "hold" or "toggle"
    if self.ModeCallback then
        self.ModeCallback(self.Mode)
    end
end

function Keybind:Activate(active)
    if self.Active == active then return end
    self.Active = active

    -- Control linked toggle if present
    if self.LinkedToggle then
        self.LinkedToggle:Set(active)
    end

    -- Call activate callback
    if self.ActivateCallback then
        self.ActivateCallback(active)
    end
end

function Keybind:LinkToggle(toggle)
    self.LinkedToggle = toggle
end

function Keybind:Render(x, y, width, hovered, theme)
    local rowH = 28

    -- Background
    self.Drawings.bg.Size = Vector2.new(width, rowH)
    self.Drawings.bg.Color = hovered and theme.BgHover or theme.BgSecondary
    self.Drawings.bg.Position = Vector2.new(x, y)

    -- Label
    self.Drawings.label.Text = self.Name
    self.Drawings.label.Color = hovered and theme.Text or theme.TextDim
    self.Drawings.label.Position = Vector2.new(x + 10, y + 6)

    -- Key button (right side)
    local keyW = 45
    local keyX = x + width - keyW - 50
    local keyY = y + 4
    local keyText = self.WaitingForKey and "..." or GetKeyDisplayName(self.Value)

    self.Drawings.keyBg.Size = Vector2.new(keyW, 20)
    self.Drawings.keyBg.Color = self.WaitingForKey and theme.Accent or theme.BgHover
    self.Drawings.keyBg.Position = Vector2.new(keyX, keyY)

    self.Drawings.keyText.Text = keyText
    self.Drawings.keyText.Color = self.WaitingForKey and theme.Bg or theme.Text
    self.Drawings.keyText.Position = Vector2.new(keyX + keyW / 2, keyY + 4)

    -- Mode button (far right)
    local modeW = 40
    local modeX = x + width - modeW - 5
    local modeY = y + 4

    self.Drawings.modeBg.Size = Vector2.new(modeW, 20)
    self.Drawings.modeBg.Color = theme.BgHover
    self.Drawings.modeBg.Position = Vector2.new(modeX, modeY)

    self.Drawings.modeText.Text = self.Mode
    self.Drawings.modeText.Color = theme.TextDim
    self.Drawings.modeText.Position = Vector2.new(modeX + modeW / 2, modeY + 5)

    -- Store bounds for click detection
    self.KeyBounds = {x = keyX, y = keyY, w = keyW, h = 20}
    self.ModeBounds = {x = modeX, y = modeY, w = modeW, h = 20}

    return rowH
end

-- Dropdown Element (Expandable list)
local Dropdown = setmetatable({}, Element)
Dropdown.__index = Dropdown

function Dropdown.new(options)
    local self = setmetatable(Element.new("Dropdown"), Dropdown)
    self.Name = options.Name or "Dropdown"
    self.Options = options.Options or {}
    self.Value = options.Default or (self.Options[1] or "")
    self.Callback = options.Callback or function() end
    self.Tooltip = options.Tooltip
    self.Expanded = false
    self.HoveredOption = 0
    self.SubCount = 1
    self.ListDrawingsCreated = false

    -- Create drawings (only the main button, not the list)
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 4)
    self.Drawings.label = CreateText(13, Theme.Text, false)
    -- Dropdown button
    self.Drawings.dropBg = CreateSquare(true, Theme.BgHover, 4)
    self.Drawings.dropBorder = CreateSquare(false, Theme.Border, 4)
    self.Drawings.dropBorder.Thickness = 1
    self.Drawings.dropText = CreateText(11, Theme.Text, false)
    self.Drawings.arrow = CreateText(10, Theme.TextDim, false)
    -- List drawings created lazily for z-order
    self.Drawings.optionBgs = {}
    self.Drawings.optionTexts = {}

    return self
end

function Dropdown:CreateListDrawings()
    if self.ListDrawingsCreated then return end
    self.ListDrawingsCreated = true

    -- Create list drawings lazily (ensures they render on top)
    self.Drawings.listBg = CreateSquare(true, Theme.Bg, 4)
    self.Drawings.listBorder = CreateSquare(false, Theme.Border, 4)
    self.Drawings.listBorder.Thickness = 1

    -- Create max 8 option slots
    for i = 1, 8 do
        self.Drawings.optionBgs[i] = CreateSquare(true, Theme.BgHover, 2)
        self.Drawings.optionTexts[i] = CreateText(11, Theme.Text, false)
    end
end

function Dropdown:Set(value)
    self.Value = value
    self.Expanded = false
    if self.Callback then
        self.Callback(value)
    end
end

function Dropdown:Get()
    return self.Value
end

function Dropdown:SetOptions(options)
    self.Options = options
    if not table.find(options, self.Value) then
        self.Value = options[1]
    end
end

function Dropdown:OnSelect()
    self.Expanded = not self.Expanded
end

function Dropdown:Close()
    self.Expanded = false
end

function Dropdown:Render(x, y, width, hovered, theme)
    local rowH = 28
    local optionH = 20
    local maxVisible = math.min(#self.Options, 8)
    local listH = maxVisible * optionH + 4

    -- Background
    self.Drawings.bg.Size = Vector2.new(width, rowH)
    self.Drawings.bg.Color = hovered and theme.BgHover or theme.BgSecondary
    self.Drawings.bg.Position = Vector2.new(x, y)

    -- Label
    self.Drawings.label.Text = self.Name
    self.Drawings.label.Color = hovered and theme.Text or theme.TextDim
    self.Drawings.label.Position = Vector2.new(x + 10, y + 6)

    -- Dropdown button (right side)
    local dropW = 90
    local dropX = x + width - dropW - 5
    local dropY = y + 4

    self.Drawings.dropBg.Size = Vector2.new(dropW, 20)
    self.Drawings.dropBg.Color = self.Expanded and theme.AccentDark or theme.BgHover
    self.Drawings.dropBg.Position = Vector2.new(dropX, dropY)

    self.Drawings.dropBorder.Size = Vector2.new(dropW, 20)
    self.Drawings.dropBorder.Color = self.Expanded and theme.Accent or theme.Border
    self.Drawings.dropBorder.Position = Vector2.new(dropX, dropY)

    -- Current value text (truncate if too long)
    local displayText = tostring(self.Value)
    if #displayText > 9 then
        displayText = displayText:sub(1, 8) .. ".."
    end
    self.Drawings.dropText.Text = displayText
    self.Drawings.dropText.Color = theme.Text
    self.Drawings.dropText.Position = Vector2.new(dropX + 6, dropY + 4)

    -- Arrow indicator
    self.Drawings.arrow.Text = self.Expanded and "^" or "v"
    self.Drawings.arrow.Color = theme.TextDim
    self.Drawings.arrow.Position = Vector2.new(dropX + dropW - 14, dropY + 5)

    -- Store button bounds
    self.DropBounds = {x = dropX, y = dropY, w = dropW, h = 20}

    -- Expanded options list
    if self.Expanded and #self.Options > 0 then
        -- Create list drawings lazily (ensures they render on top)
        self:CreateListDrawings()

        local listY = dropY + 22

        -- List background
        self.Drawings.listBg.Size = Vector2.new(dropW, listH)
        self.Drawings.listBg.Color = theme.Bg
        self.Drawings.listBg.Position = Vector2.new(dropX, listY)

        self.Drawings.listBorder.Size = Vector2.new(dropW, listH)
        self.Drawings.listBorder.Color = theme.Border
        self.Drawings.listBorder.Position = Vector2.new(dropX, listY)

        -- Render options
        for i = 1, maxVisible do
            local opt = self.Options[i]
            local optY = listY + 2 + (i - 1) * optionH
            local isHovered = (self.HoveredOption == i)
            local isSelected = (opt == self.Value)

            -- Option background
            if isHovered or isSelected then
                self.Drawings.optionBgs[i].Position = Vector2.new(dropX + 2, optY)
                self.Drawings.optionBgs[i].Size = Vector2.new(dropW - 4, optionH - 2)
                self.Drawings.optionBgs[i].Color = isHovered and theme.BgHover or theme.AccentDark
            else
                self.Drawings.optionBgs[i].Position = OFF_SCREEN
            end

            -- Option text
            local optText = tostring(opt)
            if #optText > 10 then
                optText = optText:sub(1, 9) .. ".."
            end
            self.Drawings.optionTexts[i].Text = optText
            self.Drawings.optionTexts[i].Color = isSelected and theme.Accent or (isHovered and theme.Text or theme.TextDim)
            self.Drawings.optionTexts[i].Position = Vector2.new(dropX + 6, optY + 2)
        end

        -- Hide unused slots
        for i = maxVisible + 1, 8 do
            self.Drawings.optionBgs[i].Position = OFF_SCREEN
            self.Drawings.optionTexts[i].Position = OFF_SCREEN
        end

        -- Store list bounds
        self.ListBounds = {x = dropX, y = listY, w = dropW, h = listH, optionH = optionH}
    elseif self.ListDrawingsCreated then
        -- Hide list when collapsed (only if drawings exist)
        self.Drawings.listBg.Position = OFF_SCREEN
        self.Drawings.listBorder.Position = OFF_SCREEN
        for i = 1, 8 do
            self.Drawings.optionBgs[i].Position = OFF_SCREEN
            self.Drawings.optionTexts[i].Position = OFF_SCREEN
        end
        self.ListBounds = nil
    else
        self.ListBounds = nil
    end

    return rowH
end

-- Colorpicker Element (Color box style)
local Colorpicker = setmetatable({}, Element)
Colorpicker.__index = Colorpicker

-- HSV to RGB conversion
local function HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return Color3.fromRGB(r * 255, g * 255, b * 255)
end

-- RGB to HSV conversion
local function RGBtoHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v
    v = max
    local d = max - min
    s = max == 0 and 0 or d / max
    if max == min then
        h = 0
    else
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, v
end

function Colorpicker.new(options)
    local self = setmetatable(Element.new("Colorpicker"), Colorpicker)
    self.Name = options.Name or "Color"
    self.Value = options.Default or Color3.fromRGB(255, 255, 255)
    self.Callback = options.Callback or function() end
    self.Tooltip = options.Tooltip
    self.Expanded = false
    self.SubCount = 1

    -- HSV values
    local h, s, v = RGBtoHSV(self.Value)
    self.Hue = h
    self.Sat = s
    self.Val = v

    -- Create drawings
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 4)
    self.Drawings.label = CreateText(13, Theme.Text, false)
    -- Color preview box
    self.Drawings.preview = CreateSquare(true, self.Value, 4)
    self.Drawings.previewBorder = CreateSquare(false, Theme.Border, 4)
    self.Drawings.previewBorder.Thickness = 1

    -- Expanded picker elements
    self.Drawings.pickerBg = CreateSquare(true, Theme.BgSecondary, 4)

    -- Color box grid (for saturation/value gradient simulation)
    -- Use a grid to simulate the gradient since Drawing API doesn't support gradients
    local gridSize = 10 -- 10x10 grid = 100 squares
    self.Drawings.colorGrid = {}
    for i = 1, gridSize * gridSize do
        self.Drawings.colorGrid[i] = CreateSquare(true, Color3.fromRGB(255, 255, 255), 0)
    end
    self.GridSize = gridSize

    -- Cursors
    self.Drawings.boxCursor = CreateSquare(false, Color3.fromRGB(255, 255, 255), 2)
    self.Drawings.boxCursor.Thickness = 2
    self.Drawings.hueCursor = CreateSquare(true, Color3.fromRGB(255, 255, 255), 1)

    -- Hue gradient squares (we'll draw multiple for the rainbow effect)
    self.Drawings.hueColors = {}
    for i = 1, 6 do
        self.Drawings.hueColors[i] = CreateSquare(true, HSVtoRGB((i-1)/6, 1, 1), 0)
    end

    return self
end

function Colorpicker:Set(color)
    self.Value = color
    local h, s, v = RGBtoHSV(color)
    self.Hue = h
    self.Sat = s
    self.Val = v
    if self.Callback then
        self.Callback(color)
    end
end

function Colorpicker:Get()
    return self.Value
end

function Colorpicker:UpdateFromHSV()
    self.Value = HSVtoRGB(self.Hue, self.Sat, self.Val)
    if self.Callback then
        self.Callback(self.Value)
    end
end

function Colorpicker:OnSelect()
    self.Expanded = not self.Expanded
end

function Colorpicker:Render(x, y, width, hovered, theme)
    local rowH = self.Expanded and 120 or 28

    -- Update value from HSV to ensure preview shows correct color
    self.Value = HSVtoRGB(self.Hue, self.Sat, self.Val)

    -- Background
    self.Drawings.bg.Size = Vector2.new(width, 28)
    self.Drawings.bg.Color = hovered and theme.BgHover or theme.BgSecondary
    self.Drawings.bg.Position = Vector2.new(x, y)

    -- Label
    self.Drawings.label.Text = self.Name
    self.Drawings.label.Color = hovered and theme.Text or theme.TextDim
    self.Drawings.label.Position = Vector2.new(x + 10, y + 6)

    -- Color preview box (right side) - shows the actual selected color
    local previewW = 40
    local previewX = x + width - previewW - 5
    local previewY = y + 4

    self.Drawings.preview.Size = Vector2.new(previewW, 20)
    self.Drawings.preview.Color = self.Value
    self.Drawings.preview.Position = Vector2.new(previewX, previewY)

    self.Drawings.previewBorder.Size = Vector2.new(previewW, 20)
    self.Drawings.previewBorder.Position = Vector2.new(previewX, previewY)

    -- Store preview bounds for click
    self.PreviewBounds = {x = previewX, y = previewY, w = previewW, h = 20}

    if self.Expanded then
        -- Picker background
        local pickerY = y + 30
        local pickerH = 85
        self.Drawings.pickerBg.Size = Vector2.new(width, pickerH)
        self.Drawings.pickerBg.Color = theme.Bg
        self.Drawings.pickerBg.Position = Vector2.new(x, pickerY)

        -- Color box (saturation X, value Y)
        local boxX = x + 10
        local boxY = pickerY + 5
        local boxW = width - 40
        local boxH = 75

        -- Draw color grid (simulates gradient)
        local gridSize = self.GridSize
        local cellW = boxW / gridSize
        local cellH = boxH / gridSize

        for row = 0, gridSize - 1 do
            for col = 0, gridSize - 1 do
                local idx = row * gridSize + col + 1
                -- Saturation increases left to right (col)
                -- Value decreases top to bottom (row)
                local sat = col / (gridSize - 1)
                local val = 1 - (row / (gridSize - 1))
                local cellColor = HSVtoRGB(self.Hue, sat, val)

                self.Drawings.colorGrid[idx].Size = Vector2.new(cellW + 1, cellH + 1)
                self.Drawings.colorGrid[idx].Color = cellColor
                self.Drawings.colorGrid[idx].Position = Vector2.new(boxX + col * cellW, boxY + row * cellH)
            end
        end

        -- Box cursor - use contrasting color for visibility
        local cursorX = boxX + self.Sat * boxW - 4
        local cursorY = boxY + (1 - self.Val) * boxH - 4
        self.Drawings.boxCursor.Size = Vector2.new(8, 8)
        -- Use black outline on bright colors, white on dark
        local brightness = self.Val * (1 - self.Sat * 0.5)
        self.Drawings.boxCursor.Color = brightness > 0.5 and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        self.Drawings.boxCursor.Position = Vector2.new(cursorX, cursorY)

        -- Hue bar (vertical on right side)
        local hueX = x + width - 25
        local hueY = pickerY + 5
        local hueW = 15
        local hueH = 75

        -- Draw hue gradient segments
        local segH = hueH / 6
        for i = 1, 6 do
            self.Drawings.hueColors[i].Size = Vector2.new(hueW, segH + 1)
            self.Drawings.hueColors[i].Color = HSVtoRGB((i-1)/6, 1, 1)
            self.Drawings.hueColors[i].Position = Vector2.new(hueX, hueY + (i-1) * segH)
        end

        -- Hue cursor
        local hueCursorY = hueY + self.Hue * hueH - 2
        self.Drawings.hueCursor.Size = Vector2.new(hueW, 4)
        self.Drawings.hueCursor.Color = Color3.fromRGB(255, 255, 255)
        self.Drawings.hueCursor.Position = Vector2.new(hueX, hueCursorY)

        -- Store bounds
        self.ColorBoxBounds = {x = boxX, y = boxY, w = boxW, h = boxH}
        self.HueBarBounds = {x = hueX, y = hueY, w = hueW, h = hueH}
    else
        -- Hide expanded elements
        self.Drawings.pickerBg.Position = OFF_SCREEN
        for i = 1, self.GridSize * self.GridSize do
            self.Drawings.colorGrid[i].Position = OFF_SCREEN
        end
        self.Drawings.boxCursor.Position = OFF_SCREEN
        self.Drawings.hueCursor.Position = OFF_SCREEN
        for i = 1, 6 do
            self.Drawings.hueColors[i].Position = OFF_SCREEN
        end
        self.ColorBoxBounds = nil
        self.HueBarBounds = nil
    end

    return rowH
end

-- TextInput Element (Click to type)
local TextInput = setmetatable({}, Element)
TextInput.__index = TextInput

function TextInput.new(options)
    local self = setmetatable(Element.new("TextInput"), TextInput)
    self.Name = options.Name or "Input"
    self.Value = options.Default or ""
    self.Placeholder = options.Placeholder or ""
    self.Callback = options.Callback or function() end
    self.Tooltip = options.Tooltip
    self.Focused = false
    self.CursorBlink = 0
    self.SubCount = 1

    -- Create drawings
    self.Drawings.bg = CreateSquare(true, Theme.BgSecondary, 4)
    self.Drawings.label = CreateText(13, Theme.Text, false)
    -- Input box
    self.Drawings.inputBg = CreateSquare(true, Theme.Bg, 4)
    self.Drawings.inputBorder = CreateSquare(false, Theme.Border, 4)
    self.Drawings.inputBorder.Thickness = 1
    self.Drawings.inputText = CreateText(12, Theme.Text, false)
    self.Drawings.cursor = CreateSquare(true, Theme.Text, 0)

    return self
end

function TextInput:Set(value)
    self.Value = tostring(value)
    if self.Callback then
        self.Callback(self.Value)
    end
end

function TextInput:Get()
    return self.Value
end

function TextInput:OnSelect()
    self.Focused = true
    self.CursorBlink = os.clock()
end

function TextInput:Unfocus()
    if self.Focused then
        self.Focused = false
        if self.Callback then
            self.Callback(self.Value)
        end
    end
end

-- Shift key character mapping for special characters
local ShiftCharMap = {
    ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
    ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
    ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|",
    [";"] = ":", ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?",
    ["`"] = "~",
    ["Minus"] = "_", ["Equals"] = "+", ["LeftBracket"] = "{", ["RightBracket"] = "}",
    ["Backslash"] = "|", ["Semicolon"] = ":", ["Quote"] = "\"", ["Comma"] = "<",
    ["Period"] = ">", ["Slash"] = "?", ["BackQuote"] = "~", ["Backquote"] = "~"
}

-- Normal key to character mapping
local KeyCharMap = {
    ["Minus"] = "-", ["Equals"] = "=", ["LeftBracket"] = "[", ["RightBracket"] = "]",
    ["Backslash"] = "\\", ["Semicolon"] = ";", ["Quote"] = "'", ["Comma"] = ",",
    ["Period"] = ".", ["Slash"] = "/", ["BackQuote"] = "`", ["Backquote"] = "`"
}

function TextInput:HandleKey(key, shiftHeld)
    if not self.Focused then return false end

    if key == "Backspace" then
        if #self.Value > 0 then
            self.Value = string.sub(self.Value, 1, -2)
        end
        return true
    elseif key == "Space" then
        self.Value = self.Value .. " "
        return true
    elseif key == "Return" or key == "Escape" then
        self:Unfocus()
        return true
    elseif key == "LeftShift" or key == "RightShift" or key == "LeftControl" or key == "RightControl" or key == "LeftAlt" or key == "RightAlt" then
        -- Ignore modifier keys
        return false
    elseif #key == 1 then
        -- Single character keys (letters and numbers)
        local char = key
        if shiftHeld then
            -- Check for special character mapping first
            if ShiftCharMap[key] then
                char = ShiftCharMap[key]
            else
                -- Uppercase letter
                char = string.upper(key)
            end
        else
            -- Lowercase letter
            char = string.lower(key)
        end
        self.Value = self.Value .. char
        return true
    else
        -- Multi-character key names (like Semicolon, Period, etc.)
        if shiftHeld and ShiftCharMap[key] then
            self.Value = self.Value .. ShiftCharMap[key]
            return true
        elseif KeyCharMap[key] then
            self.Value = self.Value .. KeyCharMap[key]
            return true
        end
    end
    return false
end

function TextInput:Render(x, y, width, hovered, theme)
    local rowH = 28

    -- Background
    self.Drawings.bg.Size = Vector2.new(width, rowH)
    self.Drawings.bg.Color = hovered and theme.BgHover or theme.BgSecondary
    self.Drawings.bg.Position = Vector2.new(x, y)

    -- Label
    self.Drawings.label.Text = self.Name
    self.Drawings.label.Color = hovered and theme.Text or theme.TextDim
    self.Drawings.label.Position = Vector2.new(x + 10, y + 6)

    -- Input box (right side)
    local inputW = 80
    local inputX = x + width - inputW - 5
    local inputY = y + 4

    self.Drawings.inputBg.Size = Vector2.new(inputW, 20)
    self.Drawings.inputBg.Color = theme.Bg
    self.Drawings.inputBg.Position = Vector2.new(inputX, inputY)

    self.Drawings.inputBorder.Size = Vector2.new(inputW, 20)
    self.Drawings.inputBorder.Color = self.Focused and theme.Accent or theme.Border
    self.Drawings.inputBorder.Position = Vector2.new(inputX, inputY)

    -- Display text or placeholder
    local displayText = self.Value
    if #displayText == 0 and not self.Focused then
        displayText = self.Placeholder
        self.Drawings.inputText.Color = theme.TextDim
    else
        self.Drawings.inputText.Color = theme.Text
    end

    -- Truncate if too long
    if #displayText > 10 then
        displayText = "..." .. string.sub(displayText, -7)
    end

    self.Drawings.inputText.Text = displayText
    self.Drawings.inputText.Position = Vector2.new(inputX + 5, inputY + 4)

    -- Cursor (blinking)
    if self.Focused then
        local blinkOn = (os.clock() - self.CursorBlink) % 1 < 0.5
        if blinkOn then
            local textWidth = #self.Value * 6 -- Approximate width
            if textWidth > inputW - 10 then textWidth = inputW - 10 end
            self.Drawings.cursor.Size = Vector2.new(1, 14)
            self.Drawings.cursor.Color = theme.Text
            self.Drawings.cursor.Position = Vector2.new(inputX + 5 + math.min(textWidth, 60), inputY + 3)
        else
            self.Drawings.cursor.Position = OFF_SCREEN
        end
    else
        self.Drawings.cursor.Position = OFF_SCREEN
    end

    -- Store bounds
    self.InputBounds = {x = inputX, y = inputY, w = inputW, h = 20}

    return rowH
end

-- Label Element
local Label = setmetatable({}, Element)
Label.__index = Label

function Label.new(options)
    local self = setmetatable(Element.new("Label"), Label)
    self.Text = options.Text or "Label"
    self.Color = options.Color
    self.SubCount = 0
    self.Selectable = false

    -- Create drawings
    self.Drawings.text = CreateText(12, Theme.TextDim, false)

    return self
end

function Label:SetText(text)
    self.Text = text
end

function Label:Render(x, y, width, hovered, theme)
    local rowH = 22

    self.Drawings.text.Text = self.Text
    self.Drawings.text.Color = self.Color or theme.TextDim
    self.Drawings.text.Position = Vector2.new(x + 10, y + 4)

    return rowH
end

-- Divider Element
local Divider = setmetatable({}, Element)
Divider.__index = Divider

function Divider.new(options)
    local self = setmetatable(Element.new("Divider"), Divider)
    self.SubCount = 0
    self.Selectable = false

    -- Create drawings
    self.Drawings.line = CreateLine(Theme.BgHover, 1)

    return self
end

function Divider:Render(x, y, width, hovered, theme)
    local h = 12

    self.Drawings.line.From = Vector2.new(x + 10, y + h / 2)
    self.Drawings.line.To = Vector2.new(x + width - 10, y + h / 2)
    self.Drawings.line.Color = theme.BgHover

    return h
end

-- Tab Class
local Tab = {}
Tab.__index = Tab

function Tab.new(name, window)
    local self = setmetatable({}, Tab)
    self.Name = name
    self.Window = window
    self.Elements = {}
    self.SelectedIndex = 1
    return self
end

function Tab:CreateToggle(options)
    local element = Toggle.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateSlider(options)
    local element = Slider.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateButton(options)
    local element = Button.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateKeybind(options)
    local element = Keybind.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateDropdown(options)
    local element = Dropdown.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateColorpicker(options)
    local element = Colorpicker.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateTextInput(options)
    local element = TextInput.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateLabel(options)
    local element = Label.new(options)
    table.insert(self.Elements, element)
    return element
end

function Tab:CreateDivider()
    local element = Divider.new({})
    table.insert(self.Elements, element)
    return element
end

function Tab:GetSelectableElements()
    local selectable = {}
    for i, element in ipairs(self.Elements) do
        if element.Selectable ~= false then
            table.insert(selectable, {index = i, element = element})
        end
    end
    return selectable
end

function Tab:Hide()
    for _, element in ipairs(self.Elements) do
        element:SetVisible(false)
    end
end

function Tab:Remove()
    for _, element in ipairs(self.Elements) do
        element:Remove()
    end
end

-- Window Class
local Window = {}
Window.__index = Window

function Window.new(options)
    local self = setmetatable({}, Window)
    self.Title = options.Title or "Window"
    self.Subtitle = options.Subtitle or ""
    self.Position = options.Position or Vector2.new(20, 80)
    self.Width = options.Width or 240
    self.Theme = options.Theme or Theme
    self.ToggleKey = options.ToggleKey or "F3"
    self.Visible = true
    self.Tabs = {}
    self.CurrentTabIndex = 1
    self.WaitingForKeybind = nil

    -- Mouse states
    self.MouseStates = {
        down = false,
        position = Vector2.new(0, 0)
    }
    self.LastToggleState = false
    self.LastKeyStates = {} -- Track key states for edge detection (text input)
    self.LastRebindKey = nil -- Track last key for keybind edge detection
    self.Dragging = false
    self.DragOffset = Vector2.new(0, 0)
    self.DraggingSlider = nil
    self.HoveredElement = nil

    -- Animation/timing
    self.LastRenderTime = os.clock()
    self.DeltaTime = 0.016

    -- Menu open/close animation
    self.MenuAnimProgress = 1 -- 0 = closed, 1 = open
    self.MenuAnimTarget = 1
    self.MenuAnimSpeed = 8

    -- Create window drawings
    self.Drawings = {}

    -- Shadow/glow layers (rendered behind main window)
    self.Drawings.shadow1 = CreateSquare(true, Color3.fromRGB(0, 0, 0), 12)
    self.Drawings.shadow2 = CreateSquare(true, Color3.fromRGB(0, 0, 0), 10)
    self.Drawings.glow = CreateSquare(false, self.Theme.Accent, 10)
    self.Drawings.glow.Thickness = 2

    self.Drawings.bg = CreateSquare(true, self.Theme.Bg, 8)
    self.Drawings.border = CreateSquare(false, self.Theme.Border, 8)
    self.Drawings.border.Thickness = 1
    self.Drawings.title = CreateText(16, self.Theme.Accent, false)
    self.Drawings.subtitle = CreateText(11, self.Theme.TextMuted, false)
    self.Drawings.tabBg = CreateSquare(true, self.Theme.BgSecondary, 4)
    self.Drawings.tabIndicator = CreateSquare(true, self.Theme.Accent, 3)
    self.Drawings.divider = CreateLine(self.Theme.Border, 1)
    self.Drawings.tabTexts = {}

    -- Notification system
    self.Drawings.notifBg = CreateSquare(true, self.Theme.BgSecondary, 6)
    self.Drawings.notifBorder = CreateSquare(false, self.Theme.Accent, 6)
    self.Drawings.notifBorder.Thickness = 1
    self.Drawings.notifText = CreateText(13, self.Theme.Text, true)
    self.NotificationText = nil
    self.NotificationUntil = 0

    -- Tooltip system (drawings created lazily to ensure they render on top)
    self.Tooltip = {
        Visible = false,
        Text = "",
        HoverTime = 0,
        HoverDelay = 0.5 -- seconds before tooltip shows
    }

    -- Context menu system (drawings created lazily to ensure they render on top)
    self.ContextMenu = {
        Visible = false,
        Position = Vector2.new(0, 0),
        Element = nil,
        Options = {},
        HoveredIndex = 0,
        HexInputActive = false,
        HexInputValue = ""
    }
    self.ContextMenuDrawingsCreated = false
    self.LastRightClickState = false
    self.LastContextHexKey = nil

    -- Keybind List panel (draggable floating list of active keybinds)
    self.KeybindList = {
        Visible = false,
        Position = Vector2.new(self.Position.X + self.Width + 10, self.Position.Y),
        Width = 120,
        Dragging = false,
        DragOffset = Vector2.new(0, 0)
    }
    self.KeybindListDrawingsCreated = false

    -- Start render loop (context menu drawings created on first use)
    self:StartRenderLoop()

    return self
end

function Window:CreateTab(name)
    local tab = Tab.new(name, self)
    table.insert(self.Tabs, tab)

    -- Create tab text drawing
    local tabText = CreateText(12, self.Theme.TextDim, true)
    table.insert(self.Drawings.tabTexts, tabText)

    return tab
end

function Window:SetTheme(theme)
    for k, v in pairs(theme) do
        self.Theme[k] = v
    end
end

function Window:Notify(text, duration)
    self.NotificationText = text
    self.NotificationUntil = os.clock() + (duration or 2)
end

function Window:Toggle()
    if self.Visible then
        self:Hide()
    else
        self:Show()
    end
end

function Window:Show()
    self.Visible = true
    self.MenuAnimTarget = 1
end

function Window:Hide()
    self.MenuAnimTarget = 0
    -- Visible will be set to false when animation completes
end

-- Config Save/Load System
function Window:GetConfig()
    local config = {
        elements = {},
        position = {x = self.Position.X, y = self.Position.Y},
        width = self.Width
    }

    for tabIndex, tab in ipairs(self.Tabs) do
        for elemIndex, element in ipairs(tab.Elements) do
            local key = tab.Name .. ":" .. (element.Name or elemIndex)
            if element.Type == "Toggle" then
                config.elements[key] = {type = "Toggle", value = element.Value}
            elseif element.Type == "Slider" then
                config.elements[key] = {type = "Slider", value = element.Value}
            elseif element.Type == "Keybind" then
                config.elements[key] = {type = "Keybind", value = element.Value, mode = element.Mode}
            elseif element.Type == "Dropdown" then
                config.elements[key] = {type = "Dropdown", value = element.Value}
            elseif element.Type == "Colorpicker" then
                config.elements[key] = {type = "Colorpicker", r = element.Value.R, g = element.Value.G, b = element.Value.B}
            elseif element.Type == "TextInput" then
                config.elements[key] = {type = "TextInput", value = element.Value}
            end
        end
    end

    return config
end

function Window:LoadConfig(config)
    if not config then return false end

    -- Load position and width
    if config.position then
        self.Position = Vector2.new(config.position.x or 20, config.position.y or 80)
    end
    if config.width then
        self.Width = config.width
    end

    -- Load element values
    if config.elements then
        for tabIndex, tab in ipairs(self.Tabs) do
            for elemIndex, element in ipairs(tab.Elements) do
                local key = tab.Name .. ":" .. (element.Name or elemIndex)
                local saved = config.elements[key]

                if saved then
                    if element.Type == "Toggle" and saved.type == "Toggle" then
                        element:Set(saved.value)
                    elseif element.Type == "Slider" and saved.type == "Slider" then
                        element:Set(saved.value)
                    elseif element.Type == "Keybind" and saved.type == "Keybind" then
                        element:SetKey(saved.value)
                        if saved.mode then element.Mode = saved.mode end
                    elseif element.Type == "Dropdown" and saved.type == "Dropdown" then
                        element:Set(saved.value)
                    elseif element.Type == "Colorpicker" and saved.type == "Colorpicker" then
                        element:Set(Color3.fromRGB(saved.r * 255, saved.g * 255, saved.b * 255))
                    elseif element.Type == "TextInput" and saved.type == "TextInput" then
                        element:Set(saved.value)
                    end
                end
            end
        end
    end

    return true
end

function Window:ResetToDefaults()
    for _, tab in ipairs(self.Tabs) do
        for _, element in ipairs(tab.Elements) do
            if element.Type == "Toggle" then
                element:Set(false)
            elseif element.Type == "Slider" then
                element:Set(element.Min)
            elseif element.Type == "Keybind" then
                element:SetKey(nil)
            elseif element.Type == "Dropdown" then
                if element.Options[1] then
                    element:Set(element.Options[1])
                end
            elseif element.Type == "Colorpicker" then
                element:Set(Color3.fromRGB(255, 255, 255))
            elseif element.Type == "TextInput" then
                element:Set("")
            end
        end
    end
end

function Window:SaveToFile(filename)
    local config = self:GetConfig()
    local json = JSONEncode(config)
    if writefile then
        writefile(filename, json)
        return true
    end
    return false
end

function Window:LoadFromFile(filename)
    if readfile and isfile and isfile(filename) then
        local json = readfile(filename)
        local config = JSONDecode(json)
        return self:LoadConfig(config)
    end
    return false
end

-- Profiles System
function Window:GetProfiles(folder)
    local profiles = {}
    folder = folder or "UiLib_Profiles"

    if isfolder and listfiles then
        if isfolder(folder) then
            local files = listfiles(folder)
            for _, path in ipairs(files) do
                local name = path:match("([^/\\]+)%.json$")
                if name then
                    table.insert(profiles, name)
                end
            end
        end
    end

    return profiles
end

function Window:SaveProfile(name, folder)
    folder = folder or "UiLib_Profiles"

    if makefolder and not isfolder(folder) then
        makefolder(folder)
    end

    return self:SaveToFile(folder .. "/" .. name .. ".json")
end

function Window:LoadProfile(name, folder)
    folder = folder or "UiLib_Profiles"
    return self:LoadFromFile(folder .. "/" .. name .. ".json")
end

function Window:DeleteProfile(name, folder)
    folder = folder or "UiLib_Profiles"
    local path = folder .. "/" .. name .. ".json"

    if delfile and isfile and isfile(path) then
        delfile(path)
        return true
    end
    return false
end

function Window:GetCurrentTab()
    return self.Tabs[self.CurrentTabIndex]
end

-- Context Menu Methods
function Window:CreateTooltipDrawings()
    if self.TooltipDrawingsCreated then return end

    -- Create tooltip drawings (created lazily so they render on top of everything)
    self.Drawings.tooltipBg = CreateSquare(true, self.Theme.Bg, 4)
    self.Drawings.tooltipBorder = CreateSquare(false, self.Theme.Border, 4)
    self.Drawings.tooltipBorder.Thickness = 1
    self.Drawings.tooltipText = CreateText(11, self.Theme.Text, false)

    self.TooltipDrawingsCreated = true
end

function Window:RenderTooltip(mousePos)
    if not self.Tooltip.Visible or self.Tooltip.Text == "" then
        if self.TooltipDrawingsCreated then
            self.Drawings.tooltipBg.Position = OFF_SCREEN
            self.Drawings.tooltipBorder.Position = OFF_SCREEN
            self.Drawings.tooltipText.Position = OFF_SCREEN
        end
        return
    end

    self:CreateTooltipDrawings()

    local text = self.Tooltip.Text
    local textW = #text * 6 -- approximate text width
    local tooltipW = textW + 16
    local tooltipH = 22
    local tooltipX = mousePos.X + 15
    local tooltipY = mousePos.Y + 15

    -- Keep tooltip on screen
    local screenW = 1920 -- approximate
    if tooltipX + tooltipW > screenW then
        tooltipX = mousePos.X - tooltipW - 5
    end

    self.Drawings.tooltipBg.Position = Vector2.new(tooltipX, tooltipY)
    self.Drawings.tooltipBg.Size = Vector2.new(tooltipW, tooltipH)
    self.Drawings.tooltipBg.Color = self.Theme.Bg

    self.Drawings.tooltipBorder.Position = Vector2.new(tooltipX, tooltipY)
    self.Drawings.tooltipBorder.Size = Vector2.new(tooltipW, tooltipH)
    self.Drawings.tooltipBorder.Color = self.Theme.Border

    self.Drawings.tooltipText.Text = text
    self.Drawings.tooltipText.Position = Vector2.new(tooltipX + 8, tooltipY + 4)
    self.Drawings.tooltipText.Color = self.Theme.TextDim
end

function Window:CreateContextMenuDrawings()
    if self.ContextMenuDrawingsCreated then return end

    -- Create context menu drawings (created lazily so they render on top of everything)
    self.Drawings.contextBg = CreateSquare(true, self.Theme.Bg, 4)
    self.Drawings.contextBorder = CreateSquare(false, self.Theme.Border, 4)
    self.Drawings.contextBorder.Thickness = 1
    self.Drawings.contextOptions = {}
    self.Drawings.contextOptionBgs = {}

    -- Pre-create max 5 context menu options
    for i = 1, 5 do
        self.Drawings.contextOptionBgs[i] = CreateSquare(true, self.Theme.BgHover, 2)
        self.Drawings.contextOptions[i] = CreateText(11, self.Theme.Text, false)
    end

    -- Hex input field for colorpicker context menu
    self.Drawings.contextHexInputBg = CreateSquare(true, self.Theme.BgSecondary, 3)
    self.Drawings.contextHexInputBorder = CreateSquare(false, self.Theme.Accent, 3)
    self.Drawings.contextHexInputBorder.Thickness = 1
    self.Drawings.contextHexInputText = CreateText(11, self.Theme.Text, false)
    self.Drawings.contextHexLabel = CreateText(10, self.Theme.TextDim, false)

    self.ContextMenuDrawingsCreated = true
end

function Window:ShowContextMenu(element, mousePos)
    -- Create context menu drawings lazily (ensures they render on top)
    self:CreateContextMenuDrawings()

    local options = {}

    -- Reset hex input state
    self.ContextMenu.HexInputActive = false
    self.ContextMenu.HexInputValue = ""

    -- Build context menu options based on element type
    -- Toggle: no context menu
    -- Dropdown: no context menu
    if element.Type == "Slider" then
        table.insert(options, {Name = "Reset", Action = function() element:Set(element.Min) end})
    elseif element.Type == "Keybind" then
        table.insert(options, {Name = "Clear Key", Action = function() element:SetKey(nil) end})
    elseif element.Type == "Colorpicker" then
        -- Hex input is shown inline, Copy and Paste are options
        self.ContextMenu.HexInputActive = true
        self.ContextMenu.HexInputValue = ColorToHex(element.Value):sub(2) -- Remove # prefix
        table.insert(options, {Name = "Copy", Action = function()
            ClipboardColor = element.Value
            self:Notify("Copied", 1)
        end})
        table.insert(options, {Name = "Paste", Action = function()
            if ClipboardColor then
                element:Set(ClipboardColor)
                self.ContextMenu.HexInputValue = ColorToHex(ClipboardColor):sub(2)
                self:Notify("Pasted", 1)
            else
                self:Notify("Nothing to paste", 1)
            end
        end})
    elseif element.Type == "TextInput" then
        table.insert(options, {Name = "Clear Text", Action = function() element:Set("") end})
    end

    if #options > 0 or self.ContextMenu.HexInputActive then
        self.ContextMenu.Visible = true
        self.ContextMenu.Position = mousePos
        self.ContextMenu.Element = element
        self.ContextMenu.Options = options
        self.ContextMenu.HoveredIndex = 0
    end
end

function Window:HideContextMenu()
    self.ContextMenu.Visible = false
    self.ContextMenu.Element = nil
    self.ContextMenu.Options = {}
    self.ContextMenu.HexInputActive = false
    self.ContextMenu.HexInputValue = ""
end

-- Keybind List Methods
function Window:CreateKeybindListDrawings()
    if self.KeybindListDrawingsCreated then return end

    -- Create keybind list drawings (created lazily)
    self.Drawings.kbListBg = CreateSquare(true, self.Theme.Bg, 6)
    self.Drawings.kbListBorder = CreateSquare(false, self.Theme.Border, 6)
    self.Drawings.kbListBorder.Thickness = 1
    self.Drawings.kbListTitle = CreateText(12, self.Theme.Accent, false)
    self.Drawings.kbListItems = {}
    self.Drawings.kbListKeys = {}

    -- Pre-create max 10 keybind list items
    for i = 1, 10 do
        self.Drawings.kbListItems[i] = CreateText(11, self.Theme.TextDim, false)
        self.Drawings.kbListKeys[i] = CreateText(11, self.Theme.Text, false)
    end

    self.KeybindListDrawingsCreated = true
end

function Window:GetActiveKeybinds()
    local keybinds = {}

    for _, tab in ipairs(self.Tabs) do
        for _, element in ipairs(tab.Elements) do
            if element.Type == "Keybind" and element.Value then
                -- Check LinkedToggle state if available, otherwise use Active
                local isActive = element.Active
                if element.LinkedToggle then
                    isActive = element.LinkedToggle.Value
                end
                table.insert(keybinds, {
                    Name = element.Name,
                    Key = element.Value,
                    Mode = element.Mode,
                    Active = isActive
                })
            end
        end
    end

    return keybinds
end

function Window:ShowKeybindList()
    self:CreateKeybindListDrawings()
    self.KeybindList.Visible = true
end

function Window:HideKeybindList()
    self.KeybindList.Visible = false
end

function Window:ToggleKeybindList()
    if self.KeybindList.Visible then
        self:HideKeybindList()
    else
        self:ShowKeybindList()
    end
end

function Window:IsPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function Window:UnfocusAllTextInputs()
    for _, tab in ipairs(self.Tabs) do
        for _, element in ipairs(tab.Elements) do
            if element.Type == "TextInput" and element.Focused then
                element:Unfocus()
            end
        end
    end
    self.FocusedTextInput = nil
end

function Window:CloseAllDropdowns(exceptElement)
    for _, tab in ipairs(self.Tabs) do
        for _, element in ipairs(tab.Elements) do
            if element.Type == "Dropdown" and element.Expanded and element ~= exceptElement then
                element:Close()
            end
        end
    end
end

function Window:ProcessKeybinds()
    -- Get currently pressed keys
    local pressedKeys = {}
    if getpressedkeys then
        local keys = getpressedkeys()
        if type(keys) == "table" then
            for _, key in ipairs(keys) do
                pressedKeys[key] = true
                pressedKeys[string.upper(key)] = true
                pressedKeys[string.lower(key)] = true
            end
        end
    end

    -- Process all keybinds in all tabs
    for _, tab in ipairs(self.Tabs) do
        for _, element in ipairs(tab.Elements) do
            if element.Type == "Keybind" and element.Value and not element.WaitingForKey then
                local keyPressed = pressedKeys[element.Value] or
                                   pressedKeys[string.upper(element.Value)] or
                                   pressedKeys[string.lower(element.Value)]

                if element.Mode == "hold" then
                    -- Hold mode: active while key is held
                    element:Activate(keyPressed == true)
                else
                    -- Toggle mode: toggle on key press (edge detection)
                    if keyPressed and not element.LastKeyState then
                        -- Sync Active state with LinkedToggle before toggling
                        local currentState = element.Active
                        if element.LinkedToggle then
                            currentState = element.LinkedToggle.Value
                            element.Active = currentState
                        end
                        element:Activate(not currentState)
                    end
                    element.LastKeyState = keyPressed
                end
            end
        end
    end
end

function Window:HandleInput()
    local togglePressed = false
    local rebindKey = nil
    local mouseDown = false
    local mousePos = Vector2.new(0, 0)

    -- Get mouse position
    if getmouseposition then
        local success, pos = pcall(getmouseposition)
        if success and pos then
            mousePos = pos
        end
    end

    -- Fallback to MouseService
    if mousePos.X == 0 and mousePos.Y == 0 then
        pcall(function()
            local MouseService = game:GetService("MouseService")
            mousePos = MouseService:GetMouseLocation()
        end)
    end

    -- Check mouse button
    if isleftpressed then
        local success, pressed = pcall(isleftpressed)
        if success then
            mouseDown = pressed
        end
    end

    -- Check right mouse button for context menu
    local rightMouseDown = false
    if isrightpressed then
        local success, pressed = pcall(isrightpressed)
        if success then
            rightMouseDown = pressed
        end
    end

    -- Check keyboard for toggle key and keybind capture
    if getpressedkeys then
        local pressedKeys = getpressedkeys()
        if type(pressedKeys) == "table" then
            for _, key in ipairs(pressedKeys) do
                -- Check toggle key
                local toggleKey = self.ToggleKey
                if key == toggleKey or key == string.upper(toggleKey) or key == string.lower(toggleKey) then
                    togglePressed = true
                end

                -- Capture keybind or text input (any key except toggle key)
                if key ~= self.ToggleKey and key ~= toggleKey then
                    rebindKey = key
                end
            end
        end
    end

    -- Toggle window visibility
    if togglePressed and not self.LastToggleState then
        self:Toggle()
    end
    self.LastToggleState = togglePressed

    -- Process keybind activations (works even when UI is hidden)
    self:ProcessKeybinds()

    local mouseJustPressed = mouseDown and not self.MouseStates.down
    local mouseJustReleased = not mouseDown and self.MouseStates.down

    -- Handle KeybindList dragging (only when menu is visible)
    if self.KeybindList.Visible then
        local kbX = self.KeybindList.Position.X
        local kbY = self.KeybindList.Position.Y
        local kbW = self.KeybindList.Width

        -- Only allow drag initiation when menu is open
        if mouseJustPressed and self.Visible then
            if self:IsPointInRect(mousePos.X, mousePos.Y, kbX, kbY, kbW, 24) then
                self.KeybindList.Dragging = true
                self.KeybindList.DragOffset = Vector2.new(mousePos.X - kbX, mousePos.Y - kbY)
            end
        end

        if mouseJustReleased then
            self.KeybindList.Dragging = false
        end

        if self.KeybindList.Dragging and mouseDown then
            self.KeybindList.Position = Vector2.new(
                mousePos.X - self.KeybindList.DragOffset.X,
                mousePos.Y - self.KeybindList.DragOffset.Y
            )
        end
    end

    if not self.Visible then
        self.MouseStates.down = mouseDown
        self.MouseStates.position = mousePos
        self.Dragging = false
        self.DraggingSlider = nil
        return
    end

    -- Handle keybind capture (with edge detection to avoid capturing the click that started binding)
    if self.WaitingForKeybind and rebindKey then
        -- Ignore mouse buttons for keybind capture (the click that started binding)
        local isMouseButton = rebindKey == "MouseButton1" or rebindKey == "MouseButton2" or rebindKey == "MouseButton3"

        -- Only capture on key down (edge detection)
        if not isMouseButton and not self.LastRebindKey then
            self.WaitingForKeybind:SetKey(rebindKey)
            self.WaitingForKeybind = nil
        end
    end
    self.LastRebindKey = rebindKey

    -- Handle text input keyboard with edge detection (fix key repeat issue)
    if self.FocusedTextInput and not self.WaitingForKeybind then
        -- Get all currently pressed keys
        local currentKeys = {}
        local shiftHeld = false
        if getpressedkeys then
            local keys = getpressedkeys()
            if type(keys) == "table" then
                for _, key in ipairs(keys) do
                    currentKeys[key] = true
                    -- Check if shift is held
                    if key == "LeftShift" or key == "RightShift" then
                        shiftHeld = true
                    end
                end
            end
        end

        -- Only trigger on key down (edge detection)
        for key, _ in pairs(currentKeys) do
            if not self.LastKeyStates[key] then
                -- Key just pressed - pass shift state
                self.FocusedTextInput:HandleKey(key, shiftHeld)
            end
        end

        -- Update last key states
        self.LastKeyStates = currentKeys
    else
        -- Clear key states when not focused on text input
        self.LastKeyStates = {}
    end

    local menuX, menuY = self.Position.X, self.Position.Y
    local menuW = self.Width
    local pad = 14
    local headerHeight = 48
    local tabY = menuY + 48
    local tabCount = #self.Tabs

    local rightMouseJustPressed = rightMouseDown and not self.LastRightClickState

    -- Handle context menu
    if self.ContextMenu.Visible then
        local ctxX = self.ContextMenu.Position.X
        local ctxY = self.ContextMenu.Position.Y
        local ctxW = 120
        local hexInputH = self.ContextMenu.HexInputActive and 28 or 0
        local ctxH = #self.ContextMenu.Options * 24 + hexInputH + 8
        local optH = 24

        -- Check if hovering over context menu options (offset by hex input height)
        self.ContextMenu.HoveredIndex = 0
        local optStartY = ctxY + 4 + hexInputH
        for i, opt in ipairs(self.ContextMenu.Options) do
            local optY = optStartY + (i - 1) * optH
            if self:IsPointInRect(mousePos.X, mousePos.Y, ctxX + 4, optY, ctxW - 8, optH) then
                self.ContextMenu.HoveredIndex = i
                break
            end
        end

        -- Handle hex input keyboard
        if self.ContextMenu.HexInputActive and rebindKey then
            local key = rebindKey
            -- Only on key down (edge detection)
            if not self.LastContextHexKey then
                if key == "Return" or key == "Enter" then
                    -- Apply hex value
                    local color = HexToColor(self.ContextMenu.HexInputValue)
                    if color and self.ContextMenu.Element then
                        self.ContextMenu.Element:Set(color)
                    end
                    self:HideContextMenu()
                elseif key == "Escape" then
                    -- Cancel and close
                    self:HideContextMenu()
                elseif key == "Backspace" then
                    if #self.ContextMenu.HexInputValue > 0 then
                        self.ContextMenu.HexInputValue = self.ContextMenu.HexInputValue:sub(1, -2)
                    end
                else
                    -- Valid hex characters: 0-9, A-F
                    local char = key:upper()
                    if #char == 1 and char:match("[0-9A-F]") and #self.ContextMenu.HexInputValue < 6 then
                        self.ContextMenu.HexInputValue = self.ContextMenu.HexInputValue .. char
                    end
                end
            end
        end
        self.LastContextHexKey = rebindKey

        -- Click on context menu option
        if mouseJustPressed then
            if self.ContextMenu.HoveredIndex > 0 then
                local opt = self.ContextMenu.Options[self.ContextMenu.HoveredIndex]
                if opt and opt.Action then
                    opt.Action()
                end
                -- Don't hide if it was paste (so we can see updated hex)
                if opt.Name ~= "Paste" then
                    self:HideContextMenu()
                end
            elseif not self:IsPointInRect(mousePos.X, mousePos.Y, ctxX, ctxY, ctxW, ctxH) then
                -- Clicked outside context menu
                self:HideContextMenu()
            end
        end
    else
        self.LastContextHexKey = nil
    end

    -- Right-click to show context menu
    if rightMouseJustPressed and self.HoveredElement and not self.ContextMenu.Visible then
        self:ShowContextMenu(self.HoveredElement, mousePos)
    elseif rightMouseJustPressed and not self.HoveredElement then
        self:HideContextMenu()
    end

    -- Check hover state for elements
    local prevHovered = self.HoveredElement
    self.HoveredElement = nil
    local currentTab = self:GetCurrentTab()
    if currentTab then
        local elemY = tabY + 38
        for _, element in ipairs(currentTab.Elements) do
            local elemH = self:GetElementHeight(element)
            if element.Selectable ~= false then
                if self:IsPointInRect(mousePos.X, mousePos.Y, menuX + pad, elemY, menuW - pad * 2, elemH) then
                    self.HoveredElement = element
                end
            end

            -- Handle dropdown option hover
            if element.Type == "Dropdown" and element.Expanded and element.ListBounds then
                local lb = element.ListBounds
                element.HoveredOption = 0
                if self:IsPointInRect(mousePos.X, mousePos.Y, lb.x, lb.y, lb.w, lb.h) then
                    local relY = mousePos.Y - lb.y - 2
                    local optIdx = math.floor(relY / lb.optionH) + 1
                    if optIdx >= 1 and optIdx <= math.min(#element.Options, 8) then
                        element.HoveredOption = optIdx
                    end
                end
            end

            elemY = elemY + elemH
        end
    end

    -- Tooltip handling
    if self.HoveredElement and self.HoveredElement.Tooltip then
        if self.HoveredElement == prevHovered then
            -- Same element, accumulate hover time
            self.Tooltip.HoverTime = self.Tooltip.HoverTime + self.DeltaTime
            if self.Tooltip.HoverTime >= self.Tooltip.HoverDelay then
                self.Tooltip.Visible = true
                self.Tooltip.Text = self.HoveredElement.Tooltip
            end
        else
            -- New element, reset timer
            self.Tooltip.HoverTime = 0
            self.Tooltip.Visible = false
            self.Tooltip.Text = ""
        end
    else
        -- No element hovered or no tooltip
        self.Tooltip.HoverTime = 0
        self.Tooltip.Visible = false
        self.Tooltip.Text = ""
    end

    -- Window dragging (header area)
    if mouseJustPressed then
        if self:IsPointInRect(mousePos.X, mousePos.Y, menuX, menuY, menuW, headerHeight) then
            self.Dragging = true
            self.DragOffset = Vector2.new(mousePos.X - menuX, mousePos.Y - menuY)
        end
    end

    if mouseJustReleased then
        self.Dragging = false
        self.DraggingSlider = nil
        self.DraggingColorBox = nil
        self.DraggingHueBar = nil
    end

    if self.Dragging and mouseDown then
        self.Position = Vector2.new(mousePos.X - self.DragOffset.X, mousePos.Y - self.DragOffset.Y)
    end

    -- Slider dragging
    if self.DraggingSlider and mouseDown then
        local slider = self.DraggingSlider
        if slider.SliderBounds then
            local bounds = slider.SliderBounds
            local relX = math.clamp(mousePos.X - bounds.x, 0, bounds.w)
            local percent = relX / bounds.w
            local newValue = slider.Min + (slider.Max - slider.Min) * percent
            slider:Set(newValue)
        end
    end

    -- Colorpicker color box dragging
    if self.DraggingColorBox and mouseDown then
        local picker = self.DraggingColorBox
        if picker.ColorBoxBounds then
            local box = picker.ColorBoxBounds
            picker.Sat = math.clamp((mousePos.X - box.x) / box.w, 0, 1)
            picker.Val = math.clamp(1 - (mousePos.Y - box.y) / box.h, 0, 1)
            picker:UpdateFromHSV()
        end
    end

    -- Colorpicker hue bar dragging
    if self.DraggingHueBar and mouseDown then
        local picker = self.DraggingHueBar
        if picker.HueBarBounds then
            local hue = picker.HueBarBounds
            picker.Hue = math.clamp((mousePos.Y - hue.y) / hue.h, 0, 1)
            picker:UpdateFromHSV()
        end
    end

    -- Mouse clicks
    if mouseJustPressed and not self.Dragging then
        -- First, check if clicking on any expanded dropdown list (they extend beyond element bounds)
        local clickedOnDropdownList = false
        if currentTab then
            for _, element in ipairs(currentTab.Elements) do
                if element.Type == "Dropdown" and element.Expanded and element.ListBounds then
                    local lb = element.ListBounds
                    if self:IsPointInRect(mousePos.X, mousePos.Y, lb.x, lb.y, lb.w, lb.h) then
                        -- Calculate which option was clicked
                        local relY = mousePos.Y - lb.y - 2
                        local optIdx = math.floor(relY / lb.optionH) + 1
                        if optIdx >= 1 and optIdx <= #element.Options then
                            element:Set(element.Options[optIdx])
                        end
                        clickedOnDropdownList = true
                        break
                    end
                end
            end
        end

        if not clickedOnDropdownList then
            -- Close all dropdowns when clicking elsewhere
            self:CloseAllDropdowns(nil)

            -- Check if clicking on any TextInput's input bounds
            local clickedOnTextInput = false
            if currentTab then
                for _, element in ipairs(currentTab.Elements) do
                    if element.Type == "TextInput" and element.InputBounds then
                        if self:IsPointInRect(mousePos.X, mousePos.Y, element.InputBounds.x, element.InputBounds.y, element.InputBounds.w, element.InputBounds.h) then
                            clickedOnTextInput = true
                            break
                        end
                    end
                end
            end
            -- Unfocus text inputs if clicking anywhere else
            if not clickedOnTextInput then
                self:UnfocusAllTextInputs()
            end

            -- Tab clicks
            if tabCount > 0 then
                local tabIndW = (menuW - pad * 2) / tabCount
                for i = 1, tabCount do
                    local tabX = menuX + pad + tabIndW * (i - 1)
                    if self:IsPointInRect(mousePos.X, mousePos.Y, tabX, tabY, tabIndW, 24) then
                        self.CurrentTabIndex = i
                        self.WaitingForKeybind = nil
                        self:CloseAllDropdowns(nil)
                        break
                    end
                end
            end

            -- Element clicks
            if currentTab then
                local elemY = tabY + 38

                for _, element in ipairs(currentTab.Elements) do
                    local elemH = self:GetElementHeight(element)

                    if element.Selectable ~= false then
                        if self:IsPointInRect(mousePos.X, mousePos.Y, menuX + pad, elemY, menuW - pad * 2, elemH) then
                            if element.Type == "Slider" and element.SliderBounds then
                                local bounds = element.SliderBounds
                                if self:IsPointInRect(mousePos.X, mousePos.Y, bounds.x, bounds.y, bounds.w, bounds.h) then
                                    self.DraggingSlider = element
                                    local relX = math.clamp(mousePos.X - bounds.x, 0, bounds.w)
                                    local percent = relX / bounds.w
                                    local newValue = element.Min + (element.Max - element.Min) * percent
                                    element:Set(newValue)
                                end
                            elseif element.Type == "Keybind" then
                                if element.ModeBounds and self:IsPointInRect(mousePos.X, mousePos.Y, element.ModeBounds.x, element.ModeBounds.y, element.ModeBounds.w, element.ModeBounds.h) then
                                    element:ToggleMode()
                                elseif element.KeyBounds and self:IsPointInRect(mousePos.X, mousePos.Y, element.KeyBounds.x, element.KeyBounds.y, element.KeyBounds.w, element.KeyBounds.h) then
                                    element:OnSelect()
                                    self.WaitingForKeybind = element
                                end
                            elseif element.Type == "Dropdown" then
                                -- Check if clicking on dropdown button
                                if element.DropBounds and self:IsPointInRect(mousePos.X, mousePos.Y, element.DropBounds.x, element.DropBounds.y, element.DropBounds.w, element.DropBounds.h) then
                                    -- Toggle dropdown (close others first)
                                    self:CloseAllDropdowns(element)
                                    element:OnSelect()
                                end
                            elseif element.Type == "Colorpicker" then
                                if element.Expanded and element.ColorBoxBounds then
                                    local box = element.ColorBoxBounds
                                    if self:IsPointInRect(mousePos.X, mousePos.Y, box.x, box.y, box.w, box.h) then
                                        self.DraggingColorBox = element
                                        element.Sat = math.clamp((mousePos.X - box.x) / box.w, 0, 1)
                                        element.Val = math.clamp(1 - (mousePos.Y - box.y) / box.h, 0, 1)
                                        element:UpdateFromHSV()
                                    end
                                end
                                if element.Expanded and element.HueBarBounds then
                                    local hue = element.HueBarBounds
                                    if self:IsPointInRect(mousePos.X, mousePos.Y, hue.x, hue.y, hue.w, hue.h) then
                                        self.DraggingHueBar = element
                                        element.Hue = math.clamp((mousePos.Y - hue.y) / hue.h, 0, 1)
                                        element:UpdateFromHSV()
                                    end
                                end
                                if element.PreviewBounds and self:IsPointInRect(mousePos.X, mousePos.Y, element.PreviewBounds.x, element.PreviewBounds.y, element.PreviewBounds.w, element.PreviewBounds.h) then
                                    element:OnSelect()
                                end
                            elseif element.Type == "TextInput" then
                                if element.InputBounds and self:IsPointInRect(mousePos.X, mousePos.Y, element.InputBounds.x, element.InputBounds.y, element.InputBounds.w, element.InputBounds.h) then
                                    element:OnSelect()
                                    self.FocusedTextInput = element
                                end
                            else
                                if element.OnSelect then
                                    element:OnSelect()
                                end
                            end
                            break
                        end
                    end

                    elemY = elemY + elemH
                end
            end
        end
    end

    self.MouseStates.down = mouseDown
    self.MouseStates.position = mousePos
    self.LastRightClickState = rightMouseDown
end

function Window:GetElementHeight(element)
    if element.Type == "Toggle" then return 28
    elseif element.Type == "Slider" then return 38
    elseif element.Type == "Button" then return 32
    elseif element.Type == "Keybind" then return 28
    elseif element.Type == "Dropdown" then return 28
    elseif element.Type == "Colorpicker" then return element.Expanded and 120 or 28
    elseif element.Type == "TextInput" then return 28
    elseif element.Type == "Label" then return 22
    elseif element.Type == "Divider" then return 12
    else return 28
    end
end

function Window:CalculateHeight()
    local currentTab = self:GetCurrentTab()
    if not currentTab then return 100 end

    local height = 85 -- Header + tabs + divider
    for _, element in ipairs(currentTab.Elements) do
        height = height + self:GetElementHeight(element)
    end
    return height + 10
end

function Window:RenderKeybindList(theme)
    if not self.KeybindListDrawingsCreated then return end

    if self.KeybindList.Visible then
        local keybinds = self:GetActiveKeybinds()
        local kbX = self.KeybindList.Position.X
        local kbY = self.KeybindList.Position.Y
        local kbW = self.KeybindList.Width
        local itemH = 18
        local headerH = 24
        local count = math.min(#keybinds, 10)
        local kbH = headerH + count * itemH + 8

        -- Background
        self.Drawings.kbListBg.Position = Vector2.new(kbX, kbY)
        self.Drawings.kbListBg.Size = Vector2.new(kbW, kbH)
        self.Drawings.kbListBg.Color = theme.Bg

        self.Drawings.kbListBorder.Position = Vector2.new(kbX, kbY)
        self.Drawings.kbListBorder.Size = Vector2.new(kbW, kbH)
        self.Drawings.kbListBorder.Color = theme.Border

        -- Title
        self.Drawings.kbListTitle.Text = "Keybinds"
        self.Drawings.kbListTitle.Color = theme.Accent
        self.Drawings.kbListTitle.Position = Vector2.new(kbX + 8, kbY + 5)

        -- Keybind items
        for i = 1, count do
            local kb = keybinds[i]
            local itemY = kbY + headerH + (i - 1) * itemH

            -- Name (left side)
            self.Drawings.kbListItems[i].Text = kb.Name
            self.Drawings.kbListItems[i].Color = kb.Active and theme.Accent or theme.TextDim
            self.Drawings.kbListItems[i].Position = Vector2.new(kbX + 8, itemY)

            -- Key (right side)
            self.Drawings.kbListKeys[i].Text = "[" .. GetKeyDisplayName(kb.Key) .. "]"
            self.Drawings.kbListKeys[i].Color = kb.Active and theme.Text or theme.TextMuted
            self.Drawings.kbListKeys[i].Position = Vector2.new(kbX + kbW - 45, itemY)
        end

        -- Hide unused slots
        for i = count + 1, 10 do
            self.Drawings.kbListItems[i].Position = OFF_SCREEN
            self.Drawings.kbListKeys[i].Position = OFF_SCREEN
        end
    else
        -- Hide keybind list
        self.Drawings.kbListBg.Position = OFF_SCREEN
        self.Drawings.kbListBorder.Position = OFF_SCREEN
        self.Drawings.kbListTitle.Position = OFF_SCREEN
        for i = 1, 10 do
            self.Drawings.kbListItems[i].Position = OFF_SCREEN
            self.Drawings.kbListKeys[i].Position = OFF_SCREEN
        end
    end
end

function Window:Render()
    local theme = self.Theme
    local currentTime = os.clock()

    -- Calculate delta time for animations
    self.DeltaTime = currentTime - self.LastRenderTime
    self.LastRenderTime = currentTime

    -- Animate menu open/close
    self.MenuAnimProgress = Lerp(self.MenuAnimProgress, self.MenuAnimTarget, math.min(1, self.MenuAnimSpeed * self.DeltaTime))

    -- Set Visible to false when close animation completes
    if self.MenuAnimTarget == 0 and self.MenuAnimProgress < 0.01 then
        self.Visible = false
        self.MenuAnimProgress = 0
    end

    if not self.Visible and self.MenuAnimProgress < 0.01 then
        -- Hide all window drawings by moving off screen (except keybind list)
        for key, drawing in pairs(self.Drawings) do
            -- Skip keybind list drawings - they render independently
            if key:sub(1, 6) == "kbList" then
                -- Skip these, handled below
            elseif key == "tabTexts" then
                for _, tabText in ipairs(drawing) do
                    pcall(function() tabText.Position = OFF_SCREEN end)
                end
            elseif key == "contextOptions" or key == "contextOptionBgs" then
                for _, item in ipairs(drawing) do
                    pcall(function() item.Position = OFF_SCREEN end)
                end
            else
                pcall(function() drawing.Position = OFF_SCREEN end)
                pcall(function() drawing.From = OFF_SCREEN end)
                pcall(function() drawing.To = OFF_SCREEN end)
            end
        end
        for _, tab in ipairs(self.Tabs) do
            tab:Hide()
        end

        -- Still render KeybindList when menu is hidden
        self:RenderKeybindList(theme)
        return
    end

    -- Animation scale and transparency
    local animScale = self.MenuAnimProgress
    local animAlpha = self.MenuAnimProgress

    local menuW = self.Width
    local menuH = self:CalculateHeight()
    local headerH = 48
    local pad = 14

    -- Animate from center
    local targetX, targetY = self.Position.X, self.Position.Y
    local centerX = targetX + menuW / 2
    local centerY = targetY + menuH / 2
    local animW = menuW * animScale
    local animH = menuH * animScale
    local menuX = centerX - animW / 2
    local menuY = centerY - animH / 2

    -- Shadow layers (rendered behind main window)
    local shadowOffset = 4 * animScale
    self.Drawings.shadow1.Position = Vector2.new(menuX + shadowOffset, menuY + shadowOffset)
    self.Drawings.shadow1.Size = Vector2.new(animW, animH)
    self.Drawings.shadow1.Color = Color3.fromRGB(0, 0, 0)
    self.Drawings.shadow1.Transparency = 0.7 + (1 - animAlpha) * 0.3

    self.Drawings.shadow2.Position = Vector2.new(menuX + 2 * animScale, menuY + 2 * animScale)
    self.Drawings.shadow2.Size = Vector2.new(animW, animH)
    self.Drawings.shadow2.Color = Color3.fromRGB(0, 0, 0)
    self.Drawings.shadow2.Transparency = 0.85 + (1 - animAlpha) * 0.15

    -- Glow effect (subtle accent border glow)
    self.Drawings.glow.Position = Vector2.new(menuX - 1, menuY - 1)
    self.Drawings.glow.Size = Vector2.new(animW + 2, animH + 2)
    self.Drawings.glow.Color = theme.Accent
    self.Drawings.glow.Transparency = 0.5 + (1 - animAlpha) * 0.5

    -- Background
    self.Drawings.bg.Position = Vector2.new(menuX, menuY)
    self.Drawings.bg.Size = Vector2.new(animW, animH)
    self.Drawings.bg.Transparency = 1 - animAlpha

    self.Drawings.border.Position = Vector2.new(menuX, menuY)
    self.Drawings.border.Size = Vector2.new(animW, animH)
    self.Drawings.border.Transparency = 1 - animAlpha

    -- Hide content during animation (only show when nearly complete)
    if animScale < 0.9 then
        -- Hide tabs and elements during scale animation
        for _, tab in ipairs(self.Tabs) do
            tab:Hide()
        end
        self.Drawings.title.Position = OFF_SCREEN
        self.Drawings.subtitle.Position = OFF_SCREEN
        self.Drawings.tabBg.Position = OFF_SCREEN
        self.Drawings.tabIndicator.Position = OFF_SCREEN
        self.Drawings.divider.From = OFF_SCREEN
        self.Drawings.divider.To = OFF_SCREEN
        for _, tabText in ipairs(self.Drawings.tabTexts) do
            tabText.Position = OFF_SCREEN
        end
        self:RenderKeybindList(theme)
        return
    end

    -- Use actual position for content when animation is nearly complete
    menuX, menuY = self.Position.X, self.Position.Y

    -- Title
    self.Drawings.title.Text = self.Title
    self.Drawings.title.Position = Vector2.new(menuX + pad, menuY + 12)

    self.Drawings.subtitle.Text = self.Subtitle
    self.Drawings.subtitle.Position = self.Subtitle ~= "" and Vector2.new(menuX + pad, menuY + 30) or OFF_SCREEN

    -- Tabs
    local tabY = menuY + 48
    local tabCount = #self.Tabs

    if tabCount > 0 then
        self.Drawings.tabBg.Position = Vector2.new(menuX + pad, tabY)
        self.Drawings.tabBg.Size = Vector2.new(menuW - pad * 2, 24)

        local tabIndW = (menuW - pad * 2) / tabCount
        local tabOffset = (self.CurrentTabIndex - 1) * tabIndW
        self.Drawings.tabIndicator.Position = Vector2.new(menuX + pad + tabOffset, tabY)
        self.Drawings.tabIndicator.Size = Vector2.new(tabIndW, 24)

        for i, tab in ipairs(self.Tabs) do
            local tabText = self.Drawings.tabTexts[i]
            if tabText then
                tabText.Text = tab.Name
                tabText.Color = self.CurrentTabIndex == i and theme.Text or theme.TextDim
                tabText.Position = Vector2.new(menuX + pad + tabIndW * (i - 0.5), tabY + 5)
            end
        end

        -- Hide unused tab texts
        for i = tabCount + 1, #self.Drawings.tabTexts do
            self.Drawings.tabTexts[i].Position = OFF_SCREEN
        end
    end

    -- Divider
    if tabCount > 0 then
        self.Drawings.divider.From = Vector2.new(menuX + pad, tabY + 30)
        self.Drawings.divider.To = Vector2.new(menuX + menuW - pad, tabY + 30)
    else
        self.Drawings.divider.From = OFF_SCREEN
        self.Drawings.divider.To = OFF_SCREEN
    end

    -- Hide ALL tabs first, then render current
    for _, tab in ipairs(self.Tabs) do
        tab:Hide()
    end

    -- Render current tab elements
    local currentTab = self:GetCurrentTab()
    if currentTab then
        local y = tabY + 38

        for i, element in ipairs(currentTab.Elements) do
            -- Use hover state for interactive elements
            local hovered = (self.HoveredElement == element)
            local height = element:Render(menuX + pad, y, menuW - pad * 2, hovered, theme, self.DeltaTime)
            y = y + height
        end
    end

    -- Notification
    if currentTime < self.NotificationUntil and self.NotificationText then
        local notifX = menuX + menuW + 12
        local notifY = menuY
        local notifW = 120
        local notifH = 35

        self.Drawings.notifBg.Position = Vector2.new(notifX, notifY)
        self.Drawings.notifBg.Size = Vector2.new(notifW, notifH)

        self.Drawings.notifBorder.Position = Vector2.new(notifX, notifY)
        self.Drawings.notifBorder.Size = Vector2.new(notifW, notifH)

        self.Drawings.notifText.Text = self.NotificationText
        self.Drawings.notifText.Position = Vector2.new(notifX + notifW / 2, notifY + 10)
    else
        self.Drawings.notifBg.Position = OFF_SCREEN
        self.Drawings.notifBorder.Position = OFF_SCREEN
        self.Drawings.notifText.Position = OFF_SCREEN
    end

    -- KeybindList Panel
    self:RenderKeybindList(theme)

    -- Context Menu (only render if drawings have been created)
    if self.ContextMenuDrawingsCreated then
        if self.ContextMenu.Visible then
            local ctxX = self.ContextMenu.Position.X
            local ctxY = self.ContextMenu.Position.Y
            local ctxW = 120
            local optH = 24
            local hexInputH = self.ContextMenu.HexInputActive and 28 or 0
            local ctxH = #self.ContextMenu.Options * optH + hexInputH + 8

            -- Background
            self.Drawings.contextBg.Position = Vector2.new(ctxX, ctxY)
            self.Drawings.contextBg.Size = Vector2.new(ctxW, ctxH)
            self.Drawings.contextBg.Color = theme.Bg

            self.Drawings.contextBorder.Position = Vector2.new(ctxX, ctxY)
            self.Drawings.contextBorder.Size = Vector2.new(ctxW, ctxH)
            self.Drawings.contextBorder.Color = theme.Border

            local currentY = ctxY + 4

            -- Hex input field (if active)
            if self.ContextMenu.HexInputActive then
                local hexY = currentY
                local inputW = ctxW - 16

                -- Label
                self.Drawings.contextHexLabel.Text = "#"
                self.Drawings.contextHexLabel.Color = theme.TextDim
                self.Drawings.contextHexLabel.Position = Vector2.new(ctxX + 8, hexY + 5)

                -- Input background
                self.Drawings.contextHexInputBg.Position = Vector2.new(ctxX + 20, hexY)
                self.Drawings.contextHexInputBg.Size = Vector2.new(inputW - 12, 22)
                self.Drawings.contextHexInputBg.Color = theme.BgSecondary

                -- Input border
                self.Drawings.contextHexInputBorder.Position = Vector2.new(ctxX + 20, hexY)
                self.Drawings.contextHexInputBorder.Size = Vector2.new(inputW - 12, 22)
                self.Drawings.contextHexInputBorder.Color = theme.Accent

                -- Input text with cursor
                local displayText = self.ContextMenu.HexInputValue
                if math.floor(currentTime * 2) % 2 == 0 then
                    displayText = displayText .. "|"
                end
                self.Drawings.contextHexInputText.Text = displayText
                self.Drawings.contextHexInputText.Color = theme.Text
                self.Drawings.contextHexInputText.Position = Vector2.new(ctxX + 25, hexY + 4)

                currentY = currentY + hexInputH
            else
                -- Hide hex input drawings
                self.Drawings.contextHexLabel.Position = OFF_SCREEN
                self.Drawings.contextHexInputBg.Position = OFF_SCREEN
                self.Drawings.contextHexInputBorder.Position = OFF_SCREEN
                self.Drawings.contextHexInputText.Position = OFF_SCREEN
            end

            -- Options
            for i, opt in ipairs(self.ContextMenu.Options) do
                local optY = currentY + (i - 1) * optH
                local isHovered = (self.ContextMenu.HoveredIndex == i)

                -- Option background (hover highlight)
                if isHovered then
                    self.Drawings.contextOptionBgs[i].Position = Vector2.new(ctxX + 4, optY)
                    self.Drawings.contextOptionBgs[i].Size = Vector2.new(ctxW - 8, optH - 2)
                    self.Drawings.contextOptionBgs[i].Color = theme.BgHover
                else
                    self.Drawings.contextOptionBgs[i].Position = OFF_SCREEN
                end

                -- Option text
                self.Drawings.contextOptions[i].Text = opt.Name
                self.Drawings.contextOptions[i].Color = isHovered and theme.Text or theme.TextDim
                self.Drawings.contextOptions[i].Position = Vector2.new(ctxX + 10, optY + 4)
            end

            -- Hide unused option slots
            for i = #self.ContextMenu.Options + 1, 5 do
                self.Drawings.contextOptions[i].Position = OFF_SCREEN
                self.Drawings.contextOptionBgs[i].Position = OFF_SCREEN
            end
        else
            -- Hide context menu
            self.Drawings.contextBg.Position = OFF_SCREEN
            self.Drawings.contextBorder.Position = OFF_SCREEN
            self.Drawings.contextHexLabel.Position = OFF_SCREEN
            self.Drawings.contextHexInputBg.Position = OFF_SCREEN
            self.Drawings.contextHexInputBorder.Position = OFF_SCREEN
            self.Drawings.contextHexInputText.Position = OFF_SCREEN
            for i = 1, 5 do
                self.Drawings.contextOptions[i].Position = OFF_SCREEN
                self.Drawings.contextOptionBgs[i].Position = OFF_SCREEN
            end
        end
    end

    -- Tooltip (render last so it's on top)
    local mousePos = getmouseposition()
    self:RenderTooltip(mousePos)
end

function Window:StartRenderLoop()
    -- Support both v-severe (Render) and standard Roblox (RenderStepped/Heartbeat)
    local renderEvent = RunService.Render or RunService.RenderStepped or RunService.Heartbeat
    self.RenderConnection = renderEvent:Connect(function()
        self:HandleInput()
        self:Render()
    end)
end

function Window:Destroy()
    if self.RenderConnection then
        self.RenderConnection:Disconnect()
    end

    for key, drawing in pairs(self.Drawings) do
        if key == "tabTexts" or key == "contextOptions" or key == "contextOptionBgs" or key == "kbListItems" or key == "kbListKeys" then
            for _, item in ipairs(drawing) do
                pcall(function() item:Remove() end)
            end
        else
            pcall(function() drawing:Remove() end)
        end
    end

    for _, tab in ipairs(self.Tabs) do
        tab:Remove()
    end
end

-- Main UiLib
function UiLib:CreateWindow(options)
    return Window.new(options or {})
end

function UiLib:SetTheme(theme)
    for k, v in pairs(theme) do
        Theme[k] = v
    end
end

function UiLib:GetTheme()
    return Theme
end

-- Export
return UiLib
