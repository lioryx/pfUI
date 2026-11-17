pfUI:RegisterModule("bgscore", function ()
  -- Unlock handle for the battleground score. It is a normal movable frame:
  -- drag, scale, reset and the position dock all come from unlock mode.
  -- WorldStateAlwaysUpFrame itself stays a tiny blizzard frame, so the handle
  -- is what you grab, and the score follows it.
  local bgframe = WorldStateAlwaysUpFrame
  if not bgframe then
    bgframe = CreateFrame("Frame", "WorldStateAlwaysUpFrame", UIParent)
    bgframe:SetWidth(10)
    bgframe:SetHeight(10)
    bgframe:SetPoint("TOP", UIParent, "TOP", -5, -15)
    bgframe:Hide()
  end

  local anchor = CreateFrame("Frame", "pfBGScore", UIParent)
  anchor:SetWidth(220)
  anchor:SetHeight(24)
  anchor:SetFrameStrata("DIALOG")
  anchor:SetPoint("TOP", UIParent, "TOP", -5, -15)
  anchor:Hide()

  local function CallSetPoint(fn, self, a1, a2, a3, a4, a5)
    if a5 ~= nil then
      return fn(self, a1, a2, a3, a4, a5)
    elseif a4 ~= nil then
      return fn(self, a1, a2, a3, a4)
    elseif a3 ~= nil then
      return fn(self, a1, a2, a3)
    elseif a2 ~= nil then
      return fn(self, a1, a2)
    elseif a1 ~= nil then
      return fn(self, a1)
    end
  end

  -- GetLeft/GetTop are nil while a frame is hidden.
  local function MeasuredTopLeft(frame)
    local shown = frame:IsShown()
    if not shown then frame:Show() end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not shown then frame:Hide() end
    return left, top
  end

  local function HasSavedPosition()
    local saved = C.position and C.position[anchor:GetName()]
    return saved and (saved.xpos ~= nil or saved.scale ~= nil)
  end

  -- Older builds stored an absolute screen point under a different key.
  local legacy = pfUI_config.positions and pfUI_config.positions["WorldStateAlwaysUpFrame"]
  if legacy and type(legacy.x) == "number" and type(legacy.y) == "number" then
    local screenHeight = GetScreenHeight()
    if screenHeight and screenHeight > 0 and not HasSavedPosition() then
      C.position = C.position or {}
      C.position[anchor:GetName()] = {
        xpos = round(legacy.x),
        ypos = round(legacy.y - screenHeight),
        anchor = "TOPLEFT",
        parent = "UIParent",
      }
    end
    if HasSavedPosition() then
      pfUI_config.positions["WorldStateAlwaysUpFrame"] = nil
    end
  end

  local lastKey

  local function ApplyPosition(force)
    if anchor.applying then return true end
    anchor.applying = true

    local aLeft, aTop = MeasuredTopLeft(anchor)
    if not aLeft or not aTop then
      anchor.applying = false
      return false
    end

    local scale = anchor:GetScale() or 1
    local key = floor(aLeft * 100 + 0.5) .. ":" .. floor(aTop * 100 + 0.5) .. ":" .. tostring(scale)
    if not force and key == lastKey then
      anchor.applying = false
      return true
    end
    lastKey = key

    if abs(bgframe:GetScale() - scale) > 0.001 then
      bgframe:SetScale(scale)
    end
    bgframe:ClearAllPoints()
    bgframe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", aLeft, aTop)

    anchor.applying = false
    return true
  end

  -- UIParent_ManageFramePositions snaps the score back to the top of the screen.
  local origSetPoint = bgframe.SetPoint
  bgframe.SetPoint = function(self, a1, a2, a3, a4, a5)
    if anchor.applying then
      return CallSetPoint(origSetPoint, self, a1, a2, a3, a4, a5)
    end
    local editing = pfUI.unlock and pfUI.unlock:IsShown()
    if (editing or HasSavedPosition()) and ApplyPosition(true) then
      return
    end
    return CallSetPoint(origSetPoint, self, a1, a2, a3, a4, a5)
  end

  local origAnchorSetPoint = anchor.SetPoint
  anchor.SetPoint = function(self, a1, a2, a3, a4, a5)
    if anchor.applying then
      return CallSetPoint(origAnchorSetPoint, self, a1, a2, a3, a4, a5)
    end
    CallSetPoint(origAnchorSetPoint, self, a1, a2, a3, a4, a5)
    local editing = pfUI.unlock and pfUI.unlock:IsShown()
    if editing or HasSavedPosition() then
      ApplyPosition(true)
    end
  end

  anchor.OnMove = function()
    ApplyPosition(true)
  end

  -- No saved position yet: open the handle on top of the live score.
  -- A reset still returns to the position captured at load.
  anchor:SetScript("OnShow", function()
    if anchor.applying or HasSavedPosition() then return end
    if not bgframe:IsShown() then return end
    local sLeft, sTop = bgframe:GetLeft(), bgframe:GetTop()
    if not sLeft or not sTop then return end
    anchor.applying = true
    anchor:ClearAllPoints()
    origAnchorSetPoint(anchor, "TOPLEFT", UIParent, "BOTTOMLEFT", sLeft, sTop)
    anchor.applying = false
    lastKey = nil
  end)

  -- Follow the handle while it is dragged. Hidden frames do not run OnUpdate.
  anchor:SetScript("OnUpdate", function()
    ApplyPosition(false)
  end)

  anchor:RegisterEvent("PLAYER_ENTERING_WORLD")
  anchor:RegisterEvent("UPDATE_WORLD_STATES")
  anchor:SetScript("OnEvent", function()
    if HasSavedPosition() then
      ApplyPosition(true)
    end
  end)

  UpdateMovable(anchor)

  if HasSavedPosition() and not ApplyPosition(true) then
    local retry = CreateFrame("Frame")
    local tries = 0
    retry:SetScript("OnUpdate", function()
      tries = tries + 1
      if ApplyPosition(true) or tries > 30 then
        this:SetScript("OnUpdate", nil)
        this:Hide()
      end
    end)
  end
end)
