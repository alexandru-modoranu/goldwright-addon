-- Reads the Level up planner's recipe table (RecipeData.lua, generated). Recipes are stored packed
-- and unpacked here on first use.
local _, GW = ...

local unpacked = {}

--- One recipe from the table, or nil when it isn't there.
---@param skillLine number base profession skill line (Leatherworking 165, ...)
---@param spell number recipe spell id (the client's recipeID)
--- `learn` is nil and `unknown` true for recipes in the game data that no source lists (probably not
--- obtainable yet): plan them only once learned.
---@return table|nil recipe { spell, learn, yellow, green, grey, skillUps, trainer, unknown, specialization, cost, item, makes, reagents = { {item, count}, ... } }
function GW.RecipeInfo(skillLine, spell)
  local key = skillLine .. ":" .. spell
  if unpacked[key] then return unpacked[key] end
  local packed = GW.RECIPES and GW.RECIPES[skillLine] and GW.RECIPES[skillLine][spell]
  if not packed then return nil end
  local f = {}
  for v in string.gmatch(packed .. ",", "([^,]*),") do
    f[#f + 1] = v
  end
  local yellow, grey = tonumber(f[2]), tonumber(f[3])
  local source = f[5]
  local r = {
    spell = spell,
    learn = tonumber(f[1]),
    yellow = yellow,
    green = math.floor((yellow + grey) / 2),
    grey = grey,
    skillUps = tonumber(f[4]),
    trainer = source == "T" or tonumber(source) ~= nil,
    unknown = source == "U",
    specialization = tonumber(source),
    cost = tonumber(f[6]),
    item = tonumber(f[7]) or 0,
    makes = tonumber(f[8]) or 1,
    reagents = {},
  }
  for i = 9, #f do
    local item, count = string.match(f[i], "^(%d+):(%d+)$")
    if item then r.reagents[#r.reagents + 1] = { tonumber(item), tonumber(count) } end
  end
  unpacked[key] = r
  return r
end

local patterns = {}

--- The pattern (recipe item) that teaches a recipe, or nil when no item does.
---@param skillLine number base profession skill line
---@param spell number recipe spell id
---@return table|nil pattern { items = {id, ...} (vendor-sold first), skill, A, H (cheapest vendor price
---  per faction in copper, nil = no vendor), limited, vendors = { {name, zone, alliance, horde}, ... } }
function GW.RecipePattern(skillLine, spell)
  local key = skillLine .. ":" .. spell
  if patterns[key] ~= nil then return patterns[key] or nil end
  local packed = GW.RECIPE_PATTERNS and GW.RECIPE_PATTERNS[skillLine] and GW.RECIPE_PATTERNS[skillLine][spell]
  if not packed then
    patterns[key] = false
    return nil
  end
  local items, skill, a, h, limited, vendors = string.match(packed, "^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
  local p = {
    items = {},
    skill = tonumber(skill) or 0,
    A = tonumber(a),
    H = tonumber(h),
    limited = limited == "1",
    vendors = {},
  }
  for id in string.gmatch(items or "", "%d+") do
    p.items[#p.items + 1] = tonumber(id)
  end
  for name, zone, sides in string.gmatch(vendors or "", "([^;@]+)@(%d+)@(%a*)") do
    p.vendors[#p.vendors + 1] = {
      name = name,
      zone = tonumber(zone),
      alliance = sides:find("A", 1, true) ~= nil,
      horde = sides:find("H", 1, true) ~= nil,
    }
  end
  patterns[key] = p
  return p
end

--- The recipe spell ids of a profession in the table, lowest learn skill first (yellow level for
--- recipes whose learn skill is unknown).
---@param skillLine number base profession skill line
---@return number[] spells
function GW.RecipeSpells(skillLine)
  local list = {}
  for spell in pairs(GW.RECIPES and GW.RECIPES[skillLine] or {}) do
    list[#list + 1] = spell
  end
  table.sort(list, function(a, b)
    local ra, rb = GW.RecipeInfo(skillLine, a), GW.RecipeInfo(skillLine, b)
    local la, lb = ra.learn or ra.yellow, rb.learn or rb.yellow
    if la ~= lb then return la < lb end
    return a < b
  end)
  return list
end
