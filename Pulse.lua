local Pulse = {}

Pulse.OnAddonLoaded = function( self, name )
  -- bail if it's not this addon
  if name ~= 'Pulse' then return end

  -- Keep 5s of history in 0.2s blocks
  Pulse.timer = 0
  Pulse.History = {}
  for i = 1, 25 do
    table.insert( Pulse.History, 0 )
  end

  -- set up all other event handlers
  PulseFrame:RegisterEvent( "UNIT_COMBAT" )
  PulseFrame:RegisterEvent( "PLAYER_REGEN_DISABLED" )
  PulseFrame:RegisterEvent( "PLAYER_REGEN_ENABLED" )
  PulseFrame:SetScript( "OnUpdate", Pulse.OnUpdate );

  Pulse.CreateTicker()

  -- cache the maximum life of the player
  -- TODO find a way to get the base life, without buffs
  Pulse.playerLife = UnitHealthMax( "unit" )
end

Pulse.OnUnitCombat = function( self, unitID, action, descriptor, damage, damageType )
  -- we only want to track damage to the player
  if unitID == 'player' and action ~= 'HEAL' then
    Pulse.History[ #Pulse.History ] = Pulse.History[ #Pulse.History ] + damage
  end
end

Pulse.OnEvent = function( self, event, ... )
  if event == "ADDON_LOADED" then
    Pulse.OnAddonLoaded( self, ... )
  elseif event == "UNIT_COMBAT" then
    Pulse.OnUnitCombat( self, ... )
  elseif event == "PLAYER_REGEN_DISABLED" then
    Pulse.OnPlayerRegenDisabled( self, ... )
  elseif event == "PLAYER_REGEN_ENABLED" then
    Pulse.OnPlayerRegenEnabled( self, ... )
  end
end

Pulse.OnUpdate = function( self, elapsed )
  Pulse.timer = Pulse.timer + elapsed
  if Pulse.timer >= 0.2 then
    -- move our history on one block
    table.insert( Pulse.History, 0 )
    table.remove( Pulse.History, 1 )
    Pulse.timer = Pulse.timer - 0.2

    Pulse.UpdateTicker()
  end
end

Pulse.CreateTicker = function()
  local f = CreateFrame( "FRAME", nil, UIParent )

  f:SetFrameStrata( "BACKGROUND" )
  f:SetWidth( 8 * #Pulse.History + 64 )
  f:SetHeight( 128 )

  -- create a texture for each tick
  f.Ticks = {}
  for i, _ in ipairs( Pulse.History ) do
    local t = f:CreateTexture( nil, "ARTWORK" )
    t:SetTexture( "Interface\\AddOns\\Pulse\\tick.tga", true )

    t:SetHorizTile( true )
    t:SetVertTile( true )

    t:SetSize( 8, 4 )

    t:ClearAllPoints()
    t:SetPoint( "BOTTOMRIGHT", f, "BOTTOMLEFT", i * 8, 1 )

    table.insert( f.Ticks, t )
  end

  -- set a line under the ticks
  local t = f:CreateTexture( nil, "ARTWORK" )
  t:SetTexture( 1, 1, 1, 0.35 )
  t:ClearAllPoints();
  t:SetWidth( #Pulse.History * 8 - 1 )
  t:SetHeight( 1 )
  t:SetPoint( "BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0 )

  f.Total = f:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  f.Total:SetSize( 64, 64 )
  f.Total:SetJustifyH( "CENTER" )
  f.Total:SetJustifyV( "BOTTOM" )
  f.Total:SetPoint( "BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0 )

  f:ClearAllPoints()
  f:SetPoint( "BOTTOM", 0, 128 )

  f:Hide()

  Pulse.Ticker = f
end

Pulse.UpdateTicker = function()
  -- update the total amount lost
  local total = 0
  for _, v in ipairs( Pulse.History ) do
    total = total + v
  end
  total = math.floor( total / Pulse.playerLife * 100 )
  Pulse.Ticker.Total:SetText( total )

  -- update each tick
  for i, v in ipairs( Pulse.History ) do
    local t = Pulse.Ticker.Ticks[ i ]
    local x = math.floor( v / Pulse.playerLife * 100 )

    -- if we're at less than 1% but do have actual data, show a sliver
    if x == 0 and v > 0 then
      x = 1
      t:SetAlpha( 0.35 )
    else
      t:SetAlpha( 1 )
    end

    t:SetHeight( x * 4 )
    if x == 0 then
      t:Hide()
    else
      t:Show()
    end
  end
end

Pulse.OnPlayerRegenDisabled = function()
  Pulse.Ticker:Show();
end

Pulse.OnPlayerRegenEnabled = function()
  Pulse.Ticker:Hide();
end

-- create the frame and set up the first event handler
local PulseFrame = CreateFrame( "FRAME", "PulseFrame", UIParent )
PulseFrame:RegisterEvent( "ADDON_LOADED" )
PulseFrame:SetScript( "OnEvent", Pulse.OnEvent )
