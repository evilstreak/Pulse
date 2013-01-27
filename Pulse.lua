local Pulse = {}

Pulse.OnAddonLoaded = function( self, name )
  -- bail if it's not this addon
  if name ~= 'Pulse' then return end

  -- Keep 5s of history in 0.2s blocks
  Pulse.timer = 0
  Pulse.History = {}
  for i = 1, 25 do
    table.insert( Pulse.History, { 0, 0 } )
  end

  -- set up all other event handlers
  PulseFrame:RegisterEvent( "UNIT_COMBAT" )
  PulseFrame:RegisterEvent( "PLAYER_REGEN_DISABLED" )
  PulseFrame:RegisterEvent( "PLAYER_REGEN_ENABLED" )
  PulseFrame:RegisterEvent( "ZONE_CHANGED_NEW_AREA" )
  PulseFrame:RegisterEvent( "PLAYER_EQUIPMENT_CHANGED" )
  PulseFrame:RegisterEvent( "UNIT_AURA" )
  PulseFrame:SetScript( "OnUpdate", Pulse.OnUpdate );

  Pulse.CreateTicker()

  -- Set a value for health so we don't try calculations against nil
  Pulse.playerLife = 1
end

Pulse.OnUnitCombat = function( self, unitID, action, descriptor, damage, damageType )
  -- we only want to track damage to the player
  if unitID == 'player' and action ~= 'HEAL' then
    local i = 1
    if damageType ~= 1 then i = 2 end

    Pulse.History[ #Pulse.History ][ i ] = Pulse.History[ #Pulse.History ][ i ] + damage
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
  elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_EQUIPMENT_CHANGED" then
    Pulse.CachePlayerHealth()
  elseif event == "UNIT_AURA" then
    Pulse.OnUnitAura( self, ... )
  end
end

Pulse.OnUpdate = function( self, elapsed )
  Pulse.timer = Pulse.timer + elapsed
  if Pulse.timer >= 0.2 then
    -- move our history on one block
    table.insert( Pulse.History, { 0, 0 } )
    table.remove( Pulse.History, 1 )
    Pulse.timer = Pulse.timer - 0.2

    Pulse.UpdateTicker()
  end
end

Pulse.CreateTicker = function()
  local f = CreateFrame( "FRAME", nil, UIParent )

  f:SetFrameStrata( "BACKGROUND" )
  f:SetWidth( 8 * #Pulse.History + 30 )
  f:SetHeight( 128 )

  -- create a texture for each tick
  f.Ticks = {}
  for i, _ in ipairs( Pulse.History ) do
    -- first we need a texture to show physical damage
    local p = f:CreateTexture( nil, "ARTWORK" )
    p:SetTexture( "Interface\\AddOns\\Pulse\\tick.tga", true )

    p:SetHorizTile( true )
    p:SetVertTile( true )

    p:SetSize( 8, 4 )

    p:ClearAllPoints()
    p:SetPoint( "BOTTOMRIGHT", f, "BOTTOMLEFT", i * 8, 1 )

    -- second we need a texture to show magical damage
    local m = f:CreateTexture( nil, "ARTWORK" )
    m:SetTexture( "Interface\\AddOns\\Pulse\\tick.tga", true )
    m:SetVertexColor( 0.5, 0.75, 1 )

    m:SetHorizTile( true )
    m:SetVertTile( true )

    m:SetSize( 8, 4 )

    m:ClearAllPoints()
    m:SetPoint( "BOTTOMLEFT", p, "TOPLEFT", 0, 0 )

    table.insert( f.Ticks, { p, m } )
  end

  -- set a line under the ticks
  local t = f:CreateTexture( nil, "ARTWORK" )
  t:SetTexture( 1, 1, 1, 0.35 )
  t:ClearAllPoints()
  t:SetWidth( #Pulse.History * 8 - 1 )
  t:SetHeight( 1 )
  t:SetPoint( "BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0 )

  f.Total = f:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  f.Total:SetSize( 30, 30 )
  f.Total:SetJustifyH( "CENTER" )
  f.Total:SetJustifyV( "BOTTOM" )
  f.Total:SetPoint( "BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0 )

  -- create a stack to show the active blood shield
  f.BloodShield = f:CreateTexture( nil, "ARTWORK" )
  f.BloodShield:SetTexture( "Interface\\AddOns\\Pulse\\tick.tga", true )
  f.BloodShield:SetVertexColor( 1, 1, 0 )

  f.BloodShield:SetHorizTile( true )
  f.BloodShield:SetVertTile( true )

  f.BloodShield:SetSize( 8, 4 )
  f.BloodShield:ClearAllPoints()
  f.BloodShield:SetPoint( "BOTTOMRIGHT", f, "BOTTOMLEFT", 0, 1 )
  f.BloodShield:Hide()


  f:ClearAllPoints()
  f:SetPoint( "BOTTOM", 0, 130 )

  f:SetAlpha( 0 )

  Pulse.Ticker = f
end

Pulse.UpdateTicker = function()
  -- update the total amount lost
  local total = 0
  for _, v in ipairs( Pulse.History ) do
    total = total + v[ 1 ] + v[ 2 ]
  end
  total = math.floor( total / Pulse.playerLife * 100 )
  Pulse.Ticker.Total:SetText( total )

  -- update each tick
  for i, v in ipairs( Pulse.History ) do
    for j = 1, 2 do
      local t = Pulse.Ticker.Ticks[ i ][ j ]
      local x = math.floor( v[ j ] / Pulse.playerLife * 100 )

      -- if we're at less than 1% but do have actual data, show a faded block
      if x == 0 and v[ j ] > 0 then
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

      -- reanchor the magical damage bar to deal with 0 physical damage
      if j == 2 then
        local p = Pulse.Ticker.Ticks[ i ][ 1 ]
        t:ClearAllPoints()

        if v[ j - 1 ] == 0 then
          local point, relativeTo, relativePoint, xOffset, yOffset = p:GetPoint(index)
          t:SetPoint( point, relativeTo, relativePoint, xOffset, yOffset )
        else
          t:SetPoint( "BOTTOMLEFT", Pulse.Ticker.Ticks[ i ][ j - 1 ], "TOPLEFT", 0, 0 )
        end
      end
    end
  end
end

Pulse.OnPlayerRegenDisabled = function()
  -- if we're entering combat and still haven't fetched health, do it now
  if Pulse.playerLife == 1 then
    Pulse.CachePlayerHealth()
  end

  Pulse.Ticker:SetAlpha( 1 )
end

Pulse.OnPlayerRegenEnabled = function()
  -- UIFrameFadeOut( Pulse.Ticker, 5, 1, 0 )
  Pulse.Ticker:SetAlpha( 0 )
end

-- cache the maximum life of the player
Pulse.CachePlayerHealth = function()
  -- TODO find a way to get the base life, without buffs
  Pulse.playerLife = UnitHealthMax( "player" )
end

Pulse.OnUnitAura = function( self, unit )
  -- bail if this aura isn't on the player
  if unit ~= "player" then return end

  local bloodShieldPresent = false

  for i = 1, 40 do
    name, _, _, _, _, _, _, _, _, _, id, _, _, _, value, _, _ = UnitAura( "player", i )

    -- check it's Blood Shield
    if id == 77535 then
      bloodShieldPresent = true

      local size = math.floor( value / Pulse.playerLife * 100 )
      -- update the height of the blood shield bar
      Pulse.Ticker.BloodShield:SetHeight( size * 4 )

      if size == 0 then
        Pulse.Ticker.BloodShield:Hide()
      else
        Pulse.Ticker.BloodShield:Show()
      end
    end
  end

  if not bloodShieldPresent then
    Pulse.Ticker.BloodShield:Hide()
  end
end

-- create the frame and set up the first event handler
local PulseFrame = CreateFrame( "FRAME", "PulseFrame", UIParent )
PulseFrame:RegisterEvent( "ADDON_LOADED" )
PulseFrame:SetScript( "OnEvent", Pulse.OnEvent )
