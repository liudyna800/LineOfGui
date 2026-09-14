-- LineOfBots v20 Beta 2 -- Inventory module (p.3)
-- Умный поиск: окончания, транслит, нечёткое сравнение.
-- бутылки->Бутылка, биту->Bat, бутылку->Bottle.

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

-- Транслит RU->EN.
local TR = {
	["а"]="a",["б"]="b",["в"]="v",["г"]="g",["д"]="d",["е"]="e",["ё"]="yo",
	["ж"]="zh",["з"]="z",["и"]="i",["й"]="y",["к"]="k",["л"]="l",["м"]="m",
	["н"]="n",["о"]="o",["п"]="p",["р"]="r",["с"]="s",["т"]="t",["у"]="u",
	["ф"]="f",["х"]="kh",["ц"]="ts",["ч"]="ch",["ш"]="sh",["щ"]="shch",
	["ъ"]="",["ы"]="y",["ь"]="",["э"]="e",["ю"]="yu",["я"]="ya",
}
local function translit(s)
	local out = {}
	for _, cp in utf8.codes(s) do
		local ch = utf8.char(cp)
		local r = TR[ch]
		if r ~= nil then table.insert(out, r) else table.insert(out, ch) end
	end
	return table.concat(out)
end

-- Стемминг: срезать русские окончания и английские хвосты.
local RU_ENDS = { "ами", "ями", "ов", "ев", "ей", "ой", "ем", "ом", "ам", "ям", "ах", "ях", "ую", "юю", "ая", "яя", "ое", "ее", "ые", "ие", "ого", "его", "ому", "ему", "а", "я", "у", "ю", "о", "е", "ы", "и", "й", "ь" }
local function stem(s)
	s = norm(s)
	for _, e in ipairs(RU_ENDS) do
		if #s > #e + 2 and s:sub(-#e) == e then
			s = s:sub(1, -#e - 1)
			break
		end
	end
	if not s:find("[\128-\255]") then
		if #s > 4 and s:sub(-3) == "ing" then s = s:sub(1, -4)
		elseif #s > 3 and s:sub(-2) == "es" then s = s:sub(1, -3)
		elseif #s > 3 and s:sub(-1) == "s" then s = s:sub(1, -2) end
	end
	return s
end

local function consonants(s)
	return (s:gsub("[aeiouyаеёиоуыэюя]", ""))
end
-- Skel
local function skel(s)
	local t = translit(stem(s))
	t = t:gsub("(.)%1+", "%1")
	t = consonants(t)
	return t
end

-- Левенштейн с ранним выходом.
local function lev(a, b, lim)
	lim = lim or 99
	local la, lb = #a, #b
	if math.abs(la - lb) > lim then return lim + 1 end
	if la == 0 then return lb end
	if lb == 0 then return la end
	local prev, cur = {}, {}
	for j = 0, lb do prev[j] = j end
	for i = 1, la do
		cur[0] = i
		local ai = a:sub(i, i)
		local rowMin = i
		for j = 1, lb do
			local cost = (ai == b:sub(j, j)) and 0 or 1
			local v = math.min(prev[j] + 1, cur[j-1] + 1, prev[j-1] + cost)
			cur[j] = v
			if v < rowMin then rowMin = v end
		end
		if rowMin > lim then return lim + 1 end
		prev, cur = cur, prev
	end
	return prev[lb]
end

-- Мини-словарь: стем RU -> варианты EN (ключи уже в стем-форме).
local DICT_RU = {
	["бутылк"] = {"bottle"},
	["бит"] = {"bat"},
	["медвед"] = {"teddy", "bear"},
	["меч"] = {"sword"},
	["нож"] = {"knife"},
	["пистолет"] = {"pistol", "gun"},
	["яблок"] = {"apple"},
	["сэндвич"] = {"sandwich"},
	["ед"] = {"food"},
	["ключ"] = {"key"},
	["аптечк"] = {"medkit"},
	["топор"] = {"axe"},
	["молот"] = {"hammer"},
	["фонарик"] = {"flashlight"},
	["веревк"] = {"rope"},
	["лопат"] = {"shovel"},
	["жел"] = {"jelly"},
	["мел"] = {"chalk"},
	["мелок"] = {"chalk"},
	["молок"] = {"milk"},
	["хлеб"] = {"bread"},
	["ручк"] = {"pen"},
	["карандаш"] = {"pencil"},
	["бумаг"] = {"paper"},
	["ластик"] = {"eraser"},
	["ножниц"] = {"scissors"},
	["кле"] = {"glue"},
	["чашк"] = {"cup", "mug"},
	["вод"] = {"water"},
	["сок"] = {"juice"},
	["банан"] = {"banana"},
	["печень"] = {"cookie"},
	["конфет"] = {"candy"},
	["шоколад"] = {"chocolate"},
	["сыр"] = {"cheese"},
	["яйц"] = {"egg"},
	["рыб"] = {"fish"},
	["мяс"] = {"meat"},
	["мяч"] = {"ball"},
	["шар"] = {"balloon"},
	["воздушн"] = {"balloon"},
	["зонт"] = {"umbrella"},
	["вертолет"] = {"helicopter"},
	["машин"] = {"car", "vehicle"},
	["самолет"] = {"plane"},
	["лодк"] = {"boat"},
	["велосипед"] = {"bike", "bicycle"},
	["кукл"] = {"doll", "toy"},
	["игрушк"] = {"toy"},
}

-- Все ключи имени: стем, транслит стема, словарные варианты.
local function keysOf(raw)
	local s = stem(raw)
	local k = { [s] = true }
	local ts = translit(s)
	k[ts] = true
	local d = DICT_RU[s]
	if d then
		for _, alt in ipairs(d) do k[alt] = true end
	end
	return k
end

-- Оценка пары: 0 = совпало, 1 = почти (опечатка), 99 = мимо.
local function pairScore(wantRaw, toolRaw)
	local w, t = norm(wantRaw), norm(toolRaw)
	if w == "" or t == "" then return 99 end
	if w == t then return 0 end
	if t:find(w, 1, true) or w:find(t, 1, true) then return 0 end
	local kw, kt = keysOf(wantRaw), keysOf(toolRaw)
	for k in pairs(kw) do
		if kt[k] then return 0 end
	end
	for k1 in pairs(kw) do
		for k2 in pairs(kt) do
			if #k1 >= 3 and #k2 >= 3 and (k1:find(k2, 1, true) or k2:find(k1, 1, true)) then
				return 0
			end
		end
	end
	local tw, tt = translit(stem(wantRaw)), translit(stem(toolRaw))
	if tw ~= "" and tt ~= "" and lev(tw, tt, 1) <= 1 then return 1 end
	local sw2, st2 = skel(wantRaw), skel(toolRaw)
	if sw2 ~= "" and st2 ~= "" and #sw2 >= 2 and #st2 >= 2 and lev(sw2, st2, 1) <= 1 then return 1 end
	return 99
end

local function acceptScore(d)
	return d <= 1
end

-- Все места где могут лежать Tools: руки, рюкзак, PlayerGui.
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

-- Найти Tool: лучший по оценке, с приоритетом руки -> рюкзак -> gui.
function InventoryBeta2.FindTool(name)
	local want = norm(name)
	if want == "" then return nil end
	local order = { hands = 1, backpack = 2, gui = 3 }
	local best, bestScore, bestRank = nil, 99, 99
	for _, e in ipairs(scanSources()) do
		local d = pairScore(want, e.tool.Name)
		local r = order[e.where] or 50
		if d < bestScore or (d == bestScore and r < bestRank) then
			best, bestScore, bestRank = e.tool, d, r
		end
	end
	if best and acceptScore(bestScore) then
		for _, e in ipairs(scanSources()) do
			if e.tool == best then return best, e.where, bestScore end
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

function InventoryBeta2.DoTake(name)
	local tool, where, score = InventoryBeta2.FindTool(name)
	if not tool then
        InventoryBeta2.lastScore = nil
		print("[INV] dump on fail:\n" .. InventoryBeta2.DumpAll())
		return false, InventoryBeta2.SayInventory(name)
	end
	print("[INV] matched '" .. tostring(name) .. "' -> '" .. tool.Name .. "' score=" .. tostring(score))
        InventoryBeta2.lastScore = score
	if where == "hands" then
		return true, "взял " .. tool.Name .. " (уже в руках)"
	end
	if where == "gui" then
		return false, tool.Name .. " в меню, руками взять не могу — нажми сам"
	end
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:EquipTool(tool) end)
	end
	return true, "взял " .. tool.Name .. " в руки"
end

-- Использовать: если предмет назван — взять (даже из рюкзака) и сразу применить.
-- Без названия — применить то, что уже в руках.
function InventoryBeta2.DoUse(name)
	if name and name ~= "" then
		local tool, where = InventoryBeta2.FindTool(name)
		if not tool then
			print("[INV] dump on fail:\n" .. InventoryBeta2.DumpAll())
			InventoryBeta2.lastScore = nil
			return false, InventoryBeta2.SayInventory(name)
		end
		print("[INV] use-matched '" .. tostring(name) .. "' -> '" .. tool.Name .. "'")
		if where == "gui" then
			return false, tool.Name .. " в меню, руками взять не могу — нажми сам"
		end
		if where == "backpack" then
			local hum0 = getHumanoid()
			if hum0 then pcall(function() hum0:EquipTool(tool) end) end
			task.wait(0.5)
		end
	end
	local ch = getChar()
	local held = ch and ch:FindFirstChildOfClass("Tool")
	if not held then
		return false, InventoryBeta2.SayInventory()
	end
	pcall(function() held:Activate() end)
	return true, "использую " .. held.Name
end

function InventoryBeta2.DoPutaway()
	local hum = getHumanoid()
	if hum then
		pcall(function() hum:UnequipTools() end)
	end
	return true, "убрал"
end

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

function InventoryBeta2.ExtractName(msg)
	msg = tostring(msg or "")
	local m = msg:lower()
	local last = m:match("%S+%s+(%S+)%s*$") or m:match("(%S+)%s*$") or ""
	last = last:gsub("[%p%c]+$", ""):gsub("^[%p%c]+", "")
	local stopVerbs = { ["это"]=1, ["it"]=1, ["меня"]=1, ["его"]=1, ["возьми"]=1, ["возьму"]=1, ["взять"]=1, ["используй"]=1, ["использую"]=1, ["использовать"]=1, ["убери"]=1, ["убрать"]=1, ["убираю"]=1, ["съешь"]=1, ["съесть"]=1, ["скушай"]=1, ["take"]=1, ["use"]=1, ["using"]=1, ["eat"]=1, ["put"]=1, ["away"]=1, ["equip"]=1, ["держи"]=1, ["покажи"]=1, ["дай"]=1 }
	if last == "" or stopVerbs[last] then
		return ""
	end
	return last
end

return InventoryBeta2