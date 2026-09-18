local PARRY_TARGET =
"Function /Game/jRPGTemplate/Blueprints/Components/AC_jRPG_CharacterBattleStats.AC_jRPG_CharacterBattleStats_C:TryParryHitFromCharacter"
local hooked = false

---@param Context RemoteUnrealParam<UAC_jRPG_CharacterBattleStats_C>
---@param AttackingCharacter RemoteUnrealParam<UAC_jRPG_CharacterBattleStats_C>
local function on_tryparry(Context, AttackingCharacter, Successful)
  local self = Context and Context:get()
  ---@cast self UAC_jRPG_CharacterBattleStats_C
  local owner = self:GetOwner()
  ---@cast owner ABP_jRPG_Character_Battle_Base_C
  local isHero = owner.IsPlayerControlledCharacter

  if isHero then
    -- Play the real parry animation/immunity window instead of just
    -- flipping the Successful bool. TryStartParry internally checks
    -- parry locks / CanDoDefensiveMove, so it's safe to call even if
    -- the character can't currently parry right now (it'll just no-op).
    local ok, out = pcall(function()
      local result = {}
      owner:TryStartParry(result)
      return result
    end)

    if not ok or not out or not out.Success then
      -- fallback path
      pcall(function()
        owner:TryStartGradientParry({})
      end)
    end
  end

  Successful:set(isHero)
end

--try immediately
pcall(function()
  RegisterHook(PARRY_TARGET, on_tryparry)
  hooked = true
end)

-- if not yet loaded, wait for the Function object to be created
if not hooked then
  NotifyOnNewObject("/Script/Engine.PlayerController", function(obj)
    if hooked or not obj then return end
    local ok, err = pcall(function() RegisterHook(PARRY_TARGET, on_tryparry) end)
    if ok then
      hooked = true
      print("[ParryTrace] registered late")
    else
      print("[ParryTrace] late registration failed:", tostring(err))
    end

    return true
  end)
end
