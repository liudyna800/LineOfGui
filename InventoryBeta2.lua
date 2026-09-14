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

local function getGui()
	local p = getPlayer()
	return p and p:FindFirstChildOfClass("PlayerGui")
end

local function norm(s)
	s = tostring(s or ""):lower()
	s = s:gsub("%s+", " ")
	s = s:match("^%s*(.-)%s*$") or ""
	return s
end

-- Все места где могут лежать Tools: руки, рюкзак, PlayerGui (кастомные инвентари).
local function scanSources()
	local out = {}
	local ch = getChar()
	if ch then
		for _, c in ipairs(ch:GetChildren()) do
			if c:IsA("Tool") then table.insert(out, { tool = c, where = "hands" }) end
		end
	end
	local bp = getBackpack()
	if bp then
		for _, c in ipairs(bp:GetChildren()) do
			if c:IsA("Tool") then table.insert(out, { tool = c, where = "backpack" }) end
		end
	end
	local gui = getGui()
	if gui then
		for _, c in ipairs(gui:GetDescendants()) do
			if c:IsA("Tool") then table.insert(out, { tool = c, where = "gui" }) end
		end
	end
	return out
end

-- Дамп для консоли (F9): что реально есть и где лежит.
function InventoryBeta2.DumpAll()
	local lines = {}
	local p = getPlayer()
	table.insert(lines, "player=" .. tostring(p and p.Name or "?"))
	local found = scanSources()
	if #found == 0 then
		table.insert(lines, "TOOLS: none anywhere")
	end
	for _, e in ipairs(found) do
		table.insert(lines, "TOOL [" .. e.where .. "]: " .. e.tool.Name .. " parent=" .. tostring(e.tool.Parent and e.tool.Parent.Name or "?"))
	end
	local bp = getBackpack()
	table.insert(lines, "backpackExists=" .. tostring(bp ~= nil))
	return table.concat(lines, "\n")
end

-- Найти Tool по части имени (без учёта регистра). Руки -> рюкзак -> gui.
function InventoryBeta2.FindTool(name)
	local want = norm(name)
	if want == "" then return nil end
	local order = { hands = 1, backpack = 2, gui = 3 }
	local best, bestRank = nil, 99
	for _, e in ipairs(scanSources()) do
		if norm(e.tool.Name):find(want, 1, true) then
			local r = order[e.where] or 50
			if r < bestRank then best, bestRank = e.tool, r end
		end
	end
	if best then
		for _, e in ipairs(scanSources()) do
			if e.tool == best then return best, e.where end
		end
	end
	return nil
end

function InventoryBeta2.ListInventory()
	local backpack = {}
	local hands = nil
	local guiList = {}
	for _, e in ipairs(scanSources()) do
		if e.where == "hands" and not hands then hands = e.tool.Name end
		if e.where == "backpack" then table.insert(backpack, e.tool.Name) end
		if e.where == "gui" then table.insert(guiList, e.tool.Name) end
	end
	table.sort(backpack)
	table.sort(guiList)
	return backpack, hands, guiList
end

function InventoryBeta2.InventoryLine()
	local backpack, hands, guiList = InventoryBeta2.ListInventory()
	if (not hands) and (#backpack == 0) and (#guiList == 0) then
		return "INVENTORY: пусто"
	end
	local parts = {}
	if hands then table.insert(parts, "в руках: " .. hands) end
	if #backpack > 0 then table.insert(parts, "рюкзак: " .. table.concat(backpack, ", ")) end
	if #guiList > 0 then table.insert(parts, "GUI (обычно взять нельзя): " .. table.concat(guiList, ", ")) end
	return "INVENTORY: " .. table.concat(parts, " | ")
end

function InventoryBeta2.SayInventory(wantName)
	local backpack, hands, guiList = InventoryBeta2.ListInventory()
	local have = {}
	if hands then table.insert(have, hands) end
	for _, n in ipairs(backpack) do table.insert(have, n) end
	for _, n in ipairs(guiList) do table.insert(have, n .. " (в меню)") end
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
		print("[INV] dump on fail:\n" .. InventoryBeta2.DumpAll())
		return false, InventoryBeta2.SayInventory(name)
	end
	if where == "hands" then
		return true, "взял " .. tool.Name .. " (уже в руках)"
	end
	if where == "gui" then
		print("[INV] dump gui-tool:\n" .. InventoryBeta2.DumpAll())
		return false, tool.Name .. " в меню, руками взять не могу — нажми сам"
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
