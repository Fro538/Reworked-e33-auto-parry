-- Drop-in replacement for AutoParry/scripts/main.lua from "AutoDodge AutoParry"
-- (https://www.nexusmods.com/clairobscurexpedition33/mods/478) by Forsyte.
--
-- Same hook as the original, but instead of only flipping the 'Successful'
-- flag the hero really starts the parry, so the parry animation plays and the
-- parry window / rewards come from the game's own code.
--
-- Two things matter:
--   1. TryStartParry has a bool OUT parameter ("Success"). UE4SS needs a Lua
--      table for out parameters: owner:TryStartParry({}) - passing nothing
--      or false raises an error.
--   2. A gradient attack only accepts a GRADIENT parry (the game checks
--      owner.IsGradientParrying for those, owner.IsParrying for normal ones),
--      so the move is chosen from AttackingCharacter.IsCurrentAttackGradient.
--
-- UE4SS registers Lua hooks on Blueprint functions as POST callbacks: this
-- function runs after the Blueprint body, which is why Successful:set(true)
-- at the end still overrides the game's own result.

local PARRY_TARGET =
  "Function /Game/jRPGTemplate/Blueprints/Components/AC_jRPG_CharacterBattleStats.AC_jRPG_CharacterBattleStats_C:TryParryHitFromCharacter"
local hooked = false

-- Context            = the DEFENDING character's stats component
-- AttackingCharacter = the ATTACKER's stats component
-- Successful         = bool out parameter, the parry verdict
local function on_tryparry(Context, AttackingCharacter, Successful)
  local self = Context and Context:get()
  local owner = self and self:GetOwner()
  -- Enemies keep vanilla behaviour: touch nothing.
  if not owner or not owner.IsPlayerControlledCharacter then return end

  local attackerStats = AttackingCharacter and AttackingCharacter:get()
  local gradient = attackerStats and attackerStats.IsCurrentAttackGradient == true

  if gradient then
    -- Do not restart a gradient parry the player already pressed themselves.
    if not owner.IsGradientParrying then
      pcall(function() owner:TryStartGradientParry({}) end)
    end
  elseif not owner.IsParrying then
    -- TryStartParry checks the parry lock / CanDoDefensiveMove itself; when it
    -- refuses (e.g. second hero of a multi-hit AoE) there is simply no
    -- animation this time - the safety net below still blocks the damage.
    pcall(function() owner:TryStartParry({}) end)
  end

  -- Safety net. Runs after the Blueprint body, so this value wins.
  Successful:set(true)
end

pcall(function()
  RegisterHook(PARRY_TARGET, on_tryparry)
  hooked = true
end)

-- The battle Blueprint is not loaded at startup; retry once a PlayerController
-- exists (this is the same late-registration pattern as the original mod).
if not hooked then
  NotifyOnNewObject("/Script/Engine.PlayerController", function(obj)
    if hooked or not obj then return end
    local ok, err = pcall(function() RegisterHook(PARRY_TARGET, on_tryparry) end)
    if ok then
      hooked = true
      print("[AutoParry] hook registered late")
    else
      print("[AutoParry] late registration failed: " .. tostring(err))
    end
    return true
  end)
end
