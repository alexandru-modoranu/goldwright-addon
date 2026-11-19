--- Controller support for WoW Forever's gamepad interface (the Gamepad interface style in the game's
--- settings). The game keeps a list of open windows: the D-pad cursor moves over the buttons of the
--- one it focuses, A presses the selected button, B closes the window, and the triggers (LT/RT) move
--- the focus to the window on the left or right. The game's own windows join that list by
--- themselves; an add-on's window has to announce itself, or the cursor never reaches it (it stays
--- on the auction house window while Goldwright's Sell window is open).
---
--- Every Goldwright window (UI.Window) is handed to GW.Gamepad.Add. While the gamepad style is in
--- use, an open window joins the list a frame after it shows and leaves it a frame after it hides.
--- Since build 70707 (2 Nov 2026) the game lets add-ons call FrameShown / FrameHidden and runs them
--- securely (SecureHelper:WrapFunction), but only out of combat. So every window leaves the list as
--- combat starts, and open ones join again after it: a window left in the list through a fight and
--- closed then stays in, hidden, and the controller drives an invisible window. Switching between
--- mouse and controller in game (INPUT_DEVICE_INTERFACE_TRANSITION) is followed on the next frame.
---
--- Rules (BetterBags' and Baganator's notes, Blizzard's forever branch): never write into the game's
--- binding groups or prompt footers, and never let the game click the window's CloseButton (it does
--- so tainted on purpose): B goes to SmartNavigationCloseHandler, which hides the window itself.
--- The next-frame pass runs from an OnUpdate of our own, not C_Timer (GW2_UI found a C_Timer
--- started from hooks tainted the gamepad UI). Nothing here runs with mouse and keyboard.
local _, GW = ...

---@class GoldwrightGamepad
---@field windows table[] { frame, listed } per window, in the order they were added
---@field on boolean the gamepad interface style is the one in use
---@field combat boolean between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED
---@field driver? table frame whose OnUpdate runs Update once on the next frame
local Gamepad = { windows = {}, byFrame = {}, on = false, combat = false }
GW.Gamepad = Gamepad

--- Whether this client has the game's gamepad interface (WoW Forever).
---@return boolean
function Gamepad.Available()
  return GamepadMode ~= nil
    and GamepadMode.FrameControlsManager ~= nil
    and InputUtil ~= nil
    and InputUtil.IsGamepadUIEnabled ~= nil
end

--- Whether the game refuses an add-on's calls to its gamepad interface right now (combat).
---@return boolean
local function restricted()
  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType then
    if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat) then return true end
  end
  return InCombatLockdown() and true or false
end

--- Runs Update on the next frame.
function Gamepad.Schedule()
  if Gamepad.driver then Gamepad.driver:Show() end
end

--- Takes a Goldwright window into the controller support: while the gamepad style is in use and it
--- is open (out of combat), it is in the game's window list.
---@param frame table the window (UI.Window)
---@return string what "added", "already" or "unavailable"
function Gamepad.Add(frame)
  if not Gamepad.Available() then return "unavailable" end
  if Gamepad.byFrame[frame] then return "already" end
  local rec = { frame = frame, listed = false }
  table.insert(Gamepad.windows, rec)
  Gamepad.byFrame[frame] = rec
  frame:HookScript("OnShow", Gamepad.Schedule)
  frame:HookScript("OnHide", Gamepad.Schedule)
  -- B on the window: hide it ourselves, so the game never clicks our CloseButton (tainted).
  frame.SmartNavigationCloseHandler = function()
    frame:Hide()
    return true
  end
  Gamepad.Schedule()
  return "added"
end

--- Brings the game's window list in line with what is open: each open window in it, each hidden
--- one out. In combat nothing changes (the windows already left: LeaveForCombat) and the pass runs
--- again when combat ends. Returns how many Goldwright windows are in the list.
---@return number listed
function Gamepad.Update()
  local manager = GamepadMode.FrameControlsManager
  local blocked = Gamepad.combat or restricted()
  local listed = 0
  for _, rec in ipairs(Gamepad.windows) do
    local want = Gamepad.on and rec.frame:IsShown()
    if want and not rec.listed and not blocked then
      rec.listed = true
      manager:FrameShown(rec.frame)
    elseif not want and rec.listed and not blocked then
      rec.listed = false
      manager:FrameHidden(rec.frame)
    end
    if rec.listed then listed = listed + 1 end
  end
  return listed
end

--- Takes every window out of the game's list and its cursor before the combat restriction comes
--- (ADDON_RESTRICTION_STATE_CHANGED Activating, or PLAYER_REGEN_DISABLED if that comes first);
--- under the restriction the game refuses to take one out. Returns how many left.
---@return number left
function Gamepad.LeaveForCombat()
  if not Gamepad.on then return 0 end
  local manager = GamepadMode.FrameControlsManager
  local left = 0
  for _, rec in ipairs(Gamepad.windows) do
    if rec.listed then
      rec.listed = false
      manager:FrameHidden(rec.frame)
      left = left + 1
      if SmartNavigation and SmartNavigation.RemovePanelInfo then SmartNavigation:RemovePanelInfo(rec.frame) end
    end
  end
  return left
end

--- What the controller support knows, one line (for /gw gamepad).
---@return string
function Gamepad.Status()
  if not Gamepad.Available() then return "Gamepad: not on this client." end
  local mine = {}
  for _, rec in ipairs(Gamepad.windows) do
    if rec.frame:IsShown() then
      table.insert(mine, (rec.frame:GetName() or "?") .. (rec.listed and " (in list)" or " (not in list)"))
    end
  end
  local shown = {}
  local manager = GamepadMode.FrameControlsManager
  for _, f in ipairs(manager.shownFrames or {}) do
    table.insert(shown, type(f) == "table" and f.GetName and f:GetName() or "?")
  end
  return string.format(
    "Gamepad: style %s, combat %s. Goldwright windows open: %s. Game's window list: %s.",
    Gamepad.on and "controller" or "mouse",
    (Gamepad.combat or restricted()) and "yes" or "no",
    #mine > 0 and table.concat(mine, ", ") or "none",
    #shown > 0 and table.concat(shown, ", ") or "empty"
  )
end

if Gamepad.Available() then
  Gamepad.on = InputUtil.IsGamepadUIEnabled() and true or false

  local driver = CreateFrame("Frame")
  driver:Hide()
  driver:SetScript("OnUpdate", function(self)
    self:Hide()
    Gamepad.Update()
  end)
  Gamepad.driver = driver

  local ev = CreateFrame("Frame")
  for _, e in ipairs({
    "INPUT_DEVICE_INTERFACE_TRANSITION",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ADDON_RESTRICTION_STATE_CHANGED",
    "PLAYER_ENTERING_WORLD",
  }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_ENTERING_WORLD" then
      Gamepad.on = InputUtil.IsGamepadUIEnabled() and true or false
      Gamepad.Schedule()
    elseif event == "PLAYER_REGEN_DISABLED" then
      Gamepad.combat = true
      Gamepad.LeaveForCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
      Gamepad.combat = false
      Gamepad.Schedule()
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
      local E = Enum or {}
      local combatType = E.AddOnRestrictionType and E.AddOnRestrictionType.Combat
      local activating = E.AddOnRestrictionState and E.AddOnRestrictionState.Activating
      if combatType ~= nil and a1 == combatType and a2 == activating then
        Gamepad.LeaveForCombat()
      else
        Gamepad.Schedule()
      end
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
      local types = Enum and Enum.InputDeviceInterfaceType
      if types and types.Gamepad ~= nil then
        Gamepad.on = a1 == types.Gamepad
      else
        Gamepad.on = InputUtil.IsGamepadUIEnabled() and true or false
      end
      -- Leaving the gamepad style, the game forgets its window list itself.
      if not Gamepad.on then
        for _, rec in ipairs(Gamepad.windows) do
          rec.listed = false
        end
      end
      Gamepad.Schedule()
    end
  end)
end
