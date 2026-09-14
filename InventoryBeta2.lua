-- LineOfBots v20 Beta 2 -- Inventory module (p.3)
-- Any Tools, no hardcode. States: backpack -> hands -> used -> put away.
-- Integrates with LineOneGui: ACTION_HANDLERS + system prompt (INVENTORY: ...).
-- Usage from LineOneGui (add after ACTION_HANDLERS table):
--   local InventoryBeta2 = loadstring(game:HttpGet("https://raw.githubusercontent.com/liudyna800/LineOfGui/main/InventoryBeta2.lua"))()
--   ACTION_HANDLERS.take = function(p, msg) return InventoryBeta2.DoTake(InventoryBeta2.ExtractName(msg)) end
--   ACTION_HANDLERS.use = function() return InventoryBeta2.DoUse() end
--   ACTION_HANDLERS.putaway = function() return InventoryBeta2.DoPutaway() end
--   ACTION_HANDLERS.eat = function(p, msg) return InventoryBeta2.DoEat(InventoryBeta2.ExtractName(msg)) end
--   ACTION_HANDLERS.inventory = function() return InventoryBeta2.SayInventory() end

local InventoryBeta2 = {}

local Players = game:GetService("Players")

local function getPlayer()
	return Players.LocalPlayer
end

local function getChar()
	local p = getPlayer()
	return p and p.Character
end

local function getHumanoid()
	local ch = getChar()
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function getBackpack()
	local p = getPlayer()
	return p and p:FindFirstChildOfClass("Backpack")
end

local function norm(s)
	s = tostring(s or ""):lower()
	s = s:gsub("%s+", " ")
	s = s:match("^%s*(.-)%s*$") or ""
	return s
end

-- Find Tool by (partial, case-insensitive) name. Checks hands first, then backpack.
function InventoryBeta2.FindTool(name)
	local want = norm(name)
	if want == "" then return nil end
	local ch = getChar()
	if ch then
		for _, c in ipairs(ch:GetChildren()) do
			if c:IsA("Tool") and norm(c.Name):find(want, 1, true) then
				return c, "hands"
			end
		end
	end
	local bp = getBackpack()
	if bp then
		for _, c in ipairs(bp:GetChildren()) do
			if c:IsA("Tool") and norm(c.Name):find(want, 1, true) then
				return c, "backpack"
			end
		end
	end
	return nil
end

function InventoryBeta2.ListInventory()
	local backpack = {}
	local hands = nil
	local bp = getBackpack()
	if bp then
		for _, c in ipairs(bp:GetChildren()) do
			if c:IsA("Tool") then table.insert(backpack, c.Name) end
		end
	end
	local ch = getChar()
	if ch then
		for _, c in ipairs(ch:GetChildren()) do
			if c:IsA("Tool") then hands = c.Name break end
		end
	end
	table.sort(backpack)
	return backpack, hands
end

function InventoryBeta2.InventoryLine()
	local backpack, hands = InventoryBeta2.ListInventory()
	if (not hands) and (#backpack == 0) then
		return "INVENTORY: empty"
	end
	local parts = {}
	if hands then table.insert(parts, "in hands: " .. hands) end
	if #backpack > 0 then table.insert(parts, "backpack: " .. table.concat(backpack, ", ")) end
	return "INVENTORY: " .. table.concat(parts, " | ")
end

-- "I don't have X, but I have: ..." answer helper. Returns text for bot to say.
function InventoryBeta2.SayInventory(wantName)
	local backpack, hands = InventoryBeta2.ListInventory()
	local have = {}
	if hands then table.insert(have, hands) end
	for _, n in ipairs(backpack) do table.insert(have, n) end
	if #have == 0 then
		return "u menya net etogo predmeta"
	end
	if wantName and wantName ~= "" then
		return "u menya net " .. tostring(wantName) .. ", no est: " .. table.concat(have, ", ") .. " - mogu ispolzovat ikh"
	end
	return "u menya est: " .. table.concat(have, ", ")
end

-- Take into hands (equip). If already in hands -> ok.
function InventoryBeta2.DoTake(name)
	local tool, where = InventoryBeta2.FindTool(name)
	if not tool then
		return false, InventoryBeta2.SayInventory(name)
	end
	if where == "hands" then
		return true, "vzyal " .. tool.Name .. " (uzhe v rukakh)"
	end
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:EquipTool(tool) end)
	end
	return true, "vzyal " .. tool.Name .. " v ruki"
end

-- Use what is in hands (activate). Extra Activate call works in Delta.
function InventoryBeta2.DoUse()
	local ch = getChar()
	local tool = ch and ch:FindFirstChildOfClass("Tool")
	if not tool then
		return false, InventoryBeta2.SayInventory()
	end
	pcall(function() tool:Activate() end)
	return true, "ispolzuyu " .. tool.Name
end

-- Put away (unequip all).
function InventoryBeta2.DoPutaway()
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:UnequipTools() end)
	end
	return true, "ubral"
end

-- Eat chain: take -> use -> put away. Example: "syesh sendvich".
function InventoryBeta2.DoEat(name)
	local ok, msg = InventoryBeta2.DoTake(name)
	if not ok then
		return false, msg -- "u menya net ..."
	end
	task.wait(0.4)
	InventoryBeta2.DoUse()
	task.wait(0.8)
	InventoryBeta2.DoPutaway()
	return true, "syel " .. tostring(name) .. " i ubral"
end

-- Pull item name from player message. Takes last word after take/eat/use verbs (RU+EN).
function InventoryBeta2.ExtractName(msg)
	msg = tostring(msg or "")
	local m = msg:lower()
	-- "syesh sendvich" / "vozm sendvich" / "vzyal sendvich" / "take sandwich" / "eat sandwich"
	local last = m:match("[%z\1-\127\128-\255]+%s+([%z\1-\127\128-\255]+)%s*$")
	if last then
		last = last:gsub("[%p%c]+$", "")
		if last ~= "" and last ~= "eto" and last ~= "it" then
			return last
		end
	end
	return ""
end

-- System prompt block (honest inventory behavior, any items).
InventoryBeta2.PROMPT_RU = [[
INVESTORY RULES (strogo):
- Pered otvetom smotri na stroku INVENTORY: (背包 + руки).
- Lyubye predmety - po imeni Tool, bez hardkoda nazvaniy.
- "vozmi X" = tolko v ruki ([DO:take]). "ispolzuy" = to chto v rukakh ([DO:use]). "uberi" = ubrat iz ruk ([DO:putaway]). "syesh X" = srazu tsepochka vzyal->ispolzoval->ubral ([DO:eat]).
- Esli nuzhnogo net: skazhi "u menya net etogo predmeta". Esli est drugie: perechisli "no est: ..." i predlozhi ikh.
- Nikogda ne vrid chto predmet est, esli ego net v INVENTORY.
DO-tegi: [DO:take] [DO:use] [DO:putaway] [DO:eat] [DO:inventory].
]]

return InventoryBeta2
