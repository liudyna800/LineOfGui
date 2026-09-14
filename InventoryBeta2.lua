-- LineOfBots v20 Beta 2 -- Inventory module (p.3)
-- Любые предметы (Tools), без хардкода названий.
-- Состояния: рюкзак -> руки -> используется -> убрано.

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

-- Найти Tool по части имени (без учёта регистра). Сначала руки, потом рюкзак.
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
		return "INVENTORY: пусто"
	end
	local parts = {}
	if hands then table.insert(parts, "в руках: " .. hands) end
	if #backpack > 0 then table.insert(parts, "рюкзак: " .. table.concat(backpack, ", ")) end
	return "INVENTORY: " .. table.concat(parts, " | ")
end

function InventoryBeta2.SayInventory(wantName)
	local backpack, hands = InventoryBeta2.ListInventory()
	local have = {}
	if hands then table.insert(have, hands) end
	for _, n in ipairs(backpack) do table.insert(have, n) end
	if #have == 0 then
		return "у меня нет этого предмета"
	end
	if wantName and wantName ~= "" then
		return "у меня нет " .. tostring(wantName) .. ", но есть: " .. table.concat(have, ", ") .. " — могу использовать их"
	end
	return "у меня есть: " .. table.concat(have, ", ")
end

-- Взять в руки.
function InventoryBeta2.DoTake(name)
	local tool, where = InventoryBeta2.FindTool(name)
	if not tool then
		return false, InventoryBeta2.SayInventory(name)
	end
	if where == "hands" then
		return true, "взял " .. tool.Name .. " (уже в руках)"
	end
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:EquipTool(tool) end)
	end
	return true, "взял " .. tool.Name .. " в руки"
end

-- Использовать то, что в руках.
function InventoryBeta2.DoUse()
	local ch = getChar()
	local tool = ch and ch:FindFirstChildOfClass("Tool")
	if not tool then
		return false, InventoryBeta2.SayInventory()
	end
	pcall(function() tool:Activate() end)
	return true, "использую " .. tool.Name
end

-- Убрать из рук.
function InventoryBeta2.DoPutaway()
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:UnequipTools() end)
	end
	return true, "убрал"
end

-- Съесть цепочкой: взять -> использовать -> убрать.
function InventoryBeta2.DoEat(name)
	local ok, msg = InventoryBeta2.DoTake(name)
	if not ok then
		return false, msg
	end
	task.wait(0.4)
	InventoryBeta2.DoUse()
	task.wait(0.8)
	InventoryBeta2.DoPutaway()
	return true, "съел " .. tostring(name) .. " и убрал"
end

-- Вытащить название предмета из просьбы (последнее слово).
function InventoryBeta2.ExtractName(msg)
	msg = tostring(msg or "")
	local m = msg:lower()
	local last = m:match("%S+%s+(%S+)%s*$") or m:match("(%S+)%s*$") or ""
	last = last:gsub("[%p%c]+$", ""):gsub("^[%p%c]+", "")
	if last == "" or last == "это" or last == "it" or last == "меня" or last == "его" then
		return ""
	end
	return last
end

return InventoryBeta2
