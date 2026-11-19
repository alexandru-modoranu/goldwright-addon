--- Goldwright's windows in another UI add-on's look. ElvUI and EllesmereUI restyle Blizzard's own
--- windows, never an add-on's: each add-on opts in by handing its frames to the UI add-on's skin
--- functions. Every frame Goldwright makes goes through UI.Skin (UI.Window and the UI.lua
--- factories call it); this file decides whether and how it is styled.
---
--- One look at a time, the first that applies (LOOKS):
--- * EllesmereUI: through its public skinning API (EllesmereUI.RegisterSkin, SKINNING_API.md,
---   apiVersion 4). It calls us back at login with its primitives, only while the player has its
---   third-party skinning on for Goldwright (on by default, per add-on in its options), and keeps
---   the frames in sync with the player's theme from then on.
--- * ElvUI: through the functions ElvUI uses for Blizzard's frames
---   (ElvUI/Game/Shared/Modules/Skins/Skins.lua, 16.01), when its Blizzard skins are on and our
---   "Match ElvUI's look" setting is on.
--- Another look is one more entry in LOOKS: no panel needs to change.
---
--- Without such an add-on nothing here does anything. Every call is wrapped in pcall: a change in
--- the other add-on can leave a frame with the Blizzard look, never break it. A frame made before
--- the look is known (the Welcome window at login) is styled once it is. Switching a look's setting
--- takes effect after /reload.
local _, GW = ...
local UI = GW.UI

---@class GoldwrightLook
---@field find fun(): table|false|nil the look's state when it should be used, false when it is
---  absent or switched off, nil when it isn't known yet
---@field style table<string, fun(state: table, frame: table)> how each kind of widget is styled
---@field selected fun(state: table, button: table, on: boolean) shows a tab or toggle as selected

---------------------------------------------------------------------------
-- EllesmereUI
---------------------------------------------------------------------------
local euiSkin -- the primitives EllesmereUI handed us at login
local loginDone = false -- a frame after PLAYER_LOGIN: EllesmereUI has called back by then, or won't

if type(EllesmereUI) == "table" and type(EllesmereUI.RegisterSkin) == "function" then
  pcall(EllesmereUI.RegisterSkin, "Goldwright", function(S) euiSkin = S end)
end

---@type GoldwrightLook
local ellesmere = {
  style = {
    window = function(S, f)
      S.Shell(f)
      if f.Inset then S.Inset(f.Inset) end
      if f.CloseButton then S.CloseButton(f.CloseButton) end
    end,
    frame = function(S, f) S.Panel(f) end,
    button = function(S, f)
      S.Button(f)
      -- Its buttons' labels are white, grey while disabled; S.Button leaves the label alone.
      if S.StateButtonLabel then S.StateButtonLabel(f) end
    end,
    tab = function(S, f) S.Tab(f) end,
    editbox = function(S, f) S.EditBox(f) end,
    close = function(S, f) S.CloseButton(f) end,
    check = function(S, f) S.Checkbox(f) end,
    scrollbar = function(S, f) S.ScrollBar(f) end,
  },
}

function ellesmere.find()
  if type(EllesmereUI) ~= "table" or type(EllesmereUI.RegisterSkin) ~= "function" then return false end
  if euiSkin then return (not euiSkin.IsEnabled or euiSkin.IsEnabled()) and euiSkin or false end
  if loginDone then return false end -- the player turned EllesmereUI's skinning off for Goldwright
  return nil
end

--- Tabs: EllesmereUI's own selected tab (an accent underline, apiVersion 2). Other buttons that
--- stay selected (the Sell strategies): the label in the player's accent colour.
function ellesmere.selected(S, b, on)
  if b.gwKind == "tab" and S.SetTabSelection then
    S.SetTabSelection(b, on)
    return
  end
  local label = b.GetFontString and b:GetFontString()
  if not label then return end
  if not b.gwLabelColor then b.gwLabelColor = { label:GetTextColor() } end
  if on and S.GetAccentColor then
    label:SetTextColor(S.GetAccentColor())
  else
    local c = b.gwLabelColor
    label:SetTextColor(c[1], c[2], c[3])
  end
end

---------------------------------------------------------------------------
-- ElvUI
---------------------------------------------------------------------------
--- One of ElvUI's skin functions (S:HandleButton and so on).
local function elv(name)
  return function(skins, f) skins[name](skins, f) end
end

---@type GoldwrightLook
local elvui = {
  style = {
    window = elv("HandlePortraitFrame"), -- ButtonFrameTemplate windows (inset and close button too)
    frame = elv("HandleFrame"),
    button = elv("HandleButton"),
    tab = elv("HandleButton"), -- our tabs are buttons; ElvUI's HandleTab is for Blizzard's tab templates
    editbox = elv("HandleEditBox"),
    close = elv("HandleCloseButton"),
    check = elv("HandleCheckBox"),
    scrollbar = elv("HandleScrollBar"),
  },
}

function elvui.find()
  local E = type(ElvUI) == "table" and ElvUI[1]
  if not E then return false end
  if not E.Initialized then return nil end -- set at the end of E:Initialize (General/Core.lua)
  if GW.Opt("elvSkin") == false then return false end
  local s = E.private and E.private.skins and E.private.skins.blizzard
  if not (s and s.enable) then return false end
  local ok, skins = pcall(E.GetModule, E, "Skins", true)
  return ok and type(skins) == "table" and skins or false
end

--- ElvUI's button style has no highlight texture (its hover only changes the border), so the
--- selected button's background takes ElvUI's accent colour.
function elvui.selected(_, b, on)
  if not b.SetBackdropColor then return end
  local media = ElvUI[1].media
  local c = media and (on and media.rgbvaluecolor or media.backdropcolor)
  if type(c) == "table" then pcall(b.SetBackdropColor, b, c.r or c[1], c.g or c[2], c.b or c[3], on and 0.45 or 1) end
end

---------------------------------------------------------------------------
-- The look in use
---------------------------------------------------------------------------
--- The looks Goldwright knows, first match wins.
local LOOKS = { ellesmere, elvui }

local decided, active, state = false, nil, nil
local pending = {} -- { kind, frame } made before the look was known

--- Decides the look once every look has answered. A look that doesn't know yet keeps it open.
---@return boolean decided
local function decide()
  if decided then return true end
  for _, look in ipairs(LOOKS) do
    local s = look.find()
    if s == nil then return false end
    if s then
      active, state = look, s
      break
    end
  end
  decided = true
  return true
end

--- Styles one frame in the active look; returns whether it did.
local function apply(kind, frame)
  local fn = active and active.style[kind]
  if fn and pcall(fn, state, frame) then
    frame.gwSkinned, frame.gwKind = true, kind
    return true
  end
  return false
end

--- Styles the frames made before the look was known.
local function flush()
  local queued = pending
  pending = {}
  for _, p in ipairs(queued) do
    if not p[2].gwSkinned then apply(p[1], p[2]) end
  end
end

--- Whether Goldwright's frames take another add-on's look in this session.
---@return boolean
function UI.Skinned() return decide() and active ~= nil end

--- Styles one frame in the active look; without one, does nothing.
---@param kind string "window", "frame", "button", "tab", "editbox", "close", "check" or "scrollbar"
---@param frame any the frame (anything else is returned as it is)
---@return any frame the same frame
function UI.Skin(kind, frame)
  if type(frame) ~= "table" or frame.gwSkinned then return frame end
  frame.gwKind = kind
  if not decide() then
    table.insert(pending, { kind, frame })
    return frame
  end
  if #pending > 0 then flush() end
  apply(kind, frame)
  return frame
end

--- Styles the three boxes of a MoneyInputFrameTemplate (global name + Gold / Silver / Copper).
---@param name string the money frame's global name
function UI.SkinMoney(name)
  for _, part in ipairs({ "Gold", "Silver", "Copper" }) do
    UI.Skin("editbox", _G[name .. part])
  end
end

--- Shows a tab or toggle button as the selected one (or not): its highlight stays lit, and a
--- styled button also gets the look's own selected state.
---@param b table button
---@param on boolean selected
function UI.SetSelected(b, on)
  if on then
    b:LockHighlight()
  else
    b:UnlockHighlight()
  end
  if active and b.gwSkinned then pcall(active.selected, state, b, on) end
end

-- A frame after login: EllesmereUI has called back by then (or won't), ElvUI has initialised.
-- Style what was made before.
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(0, function()
    loginDone = true
    if decide() then flush() end
  end)
end)
