-- if curious, you may request this script to be documented
-- note: this is legacy, updates are now lazy
-- im lazy as shit now btw so this code just becomes worse and worse

local emptyFunc = function() end
local cons = gui.cons
local tabs = {
    Player = 1,
    Server = 2,
    Teleports = 3,
	Cosmetics = 4
}
tabs = gui:Init({
    tabs = tabs,
    changelog = [[
    + kill all is back and better then ever
    + insta kill is back
    + majority of og features have returned

    + zombie/human team change is back
    - cure/virus items are patched
    ]]
}).tabs

-- do
    -- local tab = gui:CreateTab("Changelog")
    -- local btn = tab:CreateButton("test").inst
    -- btn.Size = UDim2.new(1, 0, 1, 0)
    -- btn.TextScaled = false
    -- btn.TextYAlignment = Enum.TextYAlignment.Top
    -- btn.TextSize = 24
    -- btn.Text = [[
    -- + Added ESP
    -- + Readded God Npc Zombies
    -- + Added Equip Scientist outfit
    -- + Added Equip Patient outfit
    -- - Cure/Virus are still broken right now because of current update.
    -- ]]
-- end

local plrs = cloneref(game:GetService("Players"))
local starGui = cloneref(game:GetService("StarterGui"))
local starPlr = cloneref(game:GetService("StarterPlayer"))
local rStor = cloneref(game:GetService("ReplicatedStorage"))
local runServ = cloneref(game:GetService("RunService"))
local networkCli = cloneref(game:GetService("NetworkClient"))
local Teams = cloneref(game:GetService("Teams"))
local TeleportService = cloneref(game:GetService("TeleportService"))

local lplr : Player = plrs.LocalPlayer
local pStats = lplr:WaitForChild("stats")

function GetHumRootPart(char)
    local HumRootPart = char:FindFirstChild("HumanoidRootPart")
    return HumRootPart
end

local find = {
    Gun = "InflictTarget",
    Knife = "SecondaryEquipment",
    Infect = "Infect"
}

do
	local desFind = function(res, class)
		local last = res
		
		while true do
			local s, r = pcall(function()
				return last and typeof(last) == "Instance" and last.Parent and last.ClassName
			end)
			
			if not s or string.find(string.lower(last.ClassName), class) then
				break
			end
			last = last.Parent
			task.wait()
		end
		
		return last
	end

	for i, v in find do
		find[i] = function(recurs)
			local res = (recurs and (plrs:FindFirstChild(v, true) or workspace:FindFirstChild(v, true))) or (lplr.Backpack:FindFirstChild(v, true) or lplr.Character:FindFirstChild(v, true))
			return (res and desFind(res, "tool"))
		end
	end
end

do
    local blacklistedScripts = {
        "States",
        -- "Anti-Exploits"
    }

    if lplr.Character then
        for _, v in blacklistedScripts do
            if lplr.Character:FindFirstChild(v) then
                lplr.Character[v]:Destroy()
            end
        end
    end
    table.insert(cons, lplr.CharacterAdded:Connect(function(chr)
        for _, v in blacklistedScripts do
            chr:WaitForChild(v):Destroy()
        end
    end))
    networkCli:SetOutgoingKBPSLimit(tonumber("-inf")) -- experimental
end


tabs.Player:CreateButton("Destroy Zones", function()
    for _, v in {starGui:FindFirstChild("PlayerLocalScripts(ReOnSp)"), lplr.PlayerGui:FindFirstChild("PlayerLocalScripts(ReOnSp)")} do
        if v then
            for _, v in v:GetChildren() do
                if v.ClassName == "LocalScript" then
                    v:Destroy()
                end
            end
        end
    end

    workspace.AntiGlitch:Destroy()
    workspace.ZombieBlockers:Destroy()
    workspace["Map Wall"].BaseWalls:Destroy()
end)

do
    local function AddHighlight(plr)
        local res = plr.Character and plr.Character:FindFirstChildWhichIsA("Highlight")

        if not res then
            local highlight = Instance.new("Highlight")
            highlight.Adornee = plr.Character
            highlight.Parent = plr.Character 
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = plr.TeamColor.Color
            highlight.OutlineColor = Color3.fromRGB(235,235,235)
            highlight.FillTransparency = .3

            return highlight
        end
    end

    local function RemoveHighlights(plr)
        local highlight = plr.Character and plr.Character:FindFirstChildWhichIsA("Highlight")

        if highlight then
            highlight:Destroy()
        end
    end

    local function ActuallyAddingHighlights(plr) 
        local ratlight

        if plr.CharacterAdded then
            ratlight = AddHighlight(plr)
        end

        if plr.CharacterRemoving then
            RemoveHighlights(plr)
        end

        if plrs.PlayerAdded then
            ratlight = AddHighlight(plr)
        end

        if plr.Character then
            ratlight = AddHighlight(plr)
        end

        plr:GetPropertyChangedSignal("TeamColor"):connect(function()
            if ratlight and ratlight.Parent then
                ratlight.FillColor = plr.TeamColor.Color
            end
        end)
    end

    local tgl
    tgl = tabs.Player:CreateToggle("ESP", function()
        if tgl.Enabled then
            repeat
                for _,v in plrs:GetPlayers() do 
                    if lplr ~= v then
                    ActuallyAddingHighlights(v)
                    end
                end
            task.wait(0.1)
            until not tgl.Enabled
            for _,v in plrs:GetPlayers() do
                RemoveHighlights(v)
            end
        end
    end)
end



do
    local godGun = {
        FireRate = 0,
        Auto = true,
        AmmoPerClip = math.huge,
        ReloadTime = 0,
        BaseDamage = 9e9,
        HeadshotDamageMultiplier = 9e9,
        Spread = 0,
        CameraShakingEnabled = false,
        BulletSpeed = 9e9,
        Piercing = 1
    }
    local spamGun = table.clone(godGun)
    spamGun.Auto = false
    spamGun.FireRate = 0

    local modGun = function(conf)
        local gun = find.Gun()
        assert(gun, "You dont have a gun")

        local mod = gun:FindFirstChild("Setting")
        assert(mod, "Your gun is broken")
        mod = require(mod)

        for i, v in conf do
            mod[i] = v
        end

        if gun.Parent == lplr.Character then
            lplr.Character.Humanoid:UnequipTools()
            lplr.Character.Humanoid:EquipTool(gun)
        end
    end
    tabs.Player:CreateButton("God Gun", modGun, godGun)
    tabs.Player:CreateButton("Spam Gun", modGun, spamGun)
end

tabs.Player:CreateToggle("Ragdoll", function()
    rStor.Remotes.ChangeState:FireServer("Ragdoll")
end)

local itemFuncs = { 
    Virus = emptyFunc,
    Cure = emptyFunc
}
do
    -- local itemRemotes = {
        -- Virus = game:GetService("ReplicatedStorage").Remotes.GiveVirus,
        -- Cure = game:GetService("ReplicatedStorage").Remotes.GiveCure
    -- }

    local transTbl = {
        Virus = Teams.Zombie,
        Cure = Teams.Human
    }

    -- for i, v in itemRemotes do
        -- tabs.Items:CreateButton("Give " .. i, v.FireServer, v)

        -- itemFuncs[i] = function()
            -- v.FireServer(v)
            -- local res = plrs.LocalPlayer.Backpack:WaitForChild(i, 1)
            -- if res then
                -- plrs.LocalPlayer.Backpack[i].Name ..= "_used"
                -- res:WaitForChild("UseSelf"):FireServer()
            -- else
                -- itemFuncs[i]()
            -- end
        -- end
        -- tabs.Teams:CreateButton("Become " .. transTbl[i].Name, itemFuncs[i])
    -- end

    -- local tCons = {}
    -- tabs.Extra:CreateToggle("Cure Autofarm", function(callback)
        -- if callback then
            -- local changed = true
            -- table.insert(tCons, pStats.Credits:GetPropertyChangedSignal("Value"):Connect(function()
                -- changed = true
            -- end))

            -- table.insert(tCons, runServ.PreRender:Connect(function()
                -- if changed then
                    -- changed = false
                    -- itemFuncs.Cure()
                -- end
            -- end))

            -- for _, v in tCons do
                -- table.insert(cons, v)
            -- end
        -- elseif #tCons > 0 then
            -- for _, v in tCons do
                -- v:Disconnect()
            -- end
            -- table.clear(tCons)
        -- end
    -- end)
	
	local room = workspace.Lab.Machines["Virus Room"]
	local prompt = room.Button.Button.Trigger
	local selfInfect
	itemFuncs.Virus = function()
		if not room.Smoke:FindFirstChildWhichIsA("TouchTransmitter") then
			repeat
				lplr.Character.PrimaryPart.CFrame = prompt.Parent.CFrame
				fireproximityprompt(prompt)
				task.wait()
			until room.Smoke:FindFirstChildWhichIsA("TouchTransmitter")
		end
		
		for i = 0, 1 do
			firetouchinterest(lplr.Character.PrimaryPart, room.Smoke, i)
		end
		
		local timeout = tick() + .5
		repeat
			task.wait()
		until lplr.Character.Ragdoll.Value or (tick() >= timeout)
		if tick() >= timeout then return itemFuncs.Virus() end
	end
	
	itemFuncs.Cure = function()
		if #plrs:GetPlayers() <= 1 then
			lplr:Kick()
		end
		TeleportService:Teleport(game.PlaceId)
	end
	
	for i, v in itemFuncs do
		tabs.Player:CreateButton("Become " .. transTbl[i].Name, v)
	end
end

local changeTeam
do
    local transTbl = {
        Zombie = itemFuncs.Virus,
        Human = itemFuncs.Cure
    }
    changeTeam = function(t)
        return transTbl[t.Name]()
    end
end

local checkTeam = function(v)
    -- assert(lplr.Team == Teams.Z, ("You must manually turn into a ".. string.format(v.Name))) -- ignore assrt also printing in console, this is only temp till catboy korean twink fixes his fucking remotes.
	if v:IsA("Team") and lplr.Team ~= v then
        changeTeam(v)

        repeat
            task.wait()
        until lplr.Team == v
    end
end

local buyItem = rStor:WaitForChild("BuyItem")
local remote
local gun
local cooldown = 0
local findRemote = function()
    if not remote or not remote.Parent or not gun or not gun.Parent then
        gun = find.Gun(true)
        if not gun then return find.Gun(true) end
        remote = gun:FindFirstChild("InflictTarget", true)
		
		if toolCheck and toolCheck.Enabled then
			cooldown = gun:FindFirstChild("Setting")
			cooldown = (cooldown and require(cooldown).FireRate) or .2
			local gun = gun
			if gun.Parent ~= lplr.Character and gun.Parent ~= lplr.Backpack then
				buyItem:InvokeServer("Pistol")
				gun = lplr.Backpack:WaitForChild("Pistol")
				gun.Parent = lplr.Character
			else
				gun.Parent = lplr.Character
				gun.Parent = lplr.Character.PrimaryPart
			end
		end
    end
end

local shootPlr
local lastShot = 0
do
	shootPlr = function(v, dmg)
		-- if os.clock() > lastShot then
			-- lastShot = os.clock() + cooldown
			local v = (v.ClassName == "Player" and v.Character and v.Character:FindFirstChild("Humanoid")) or v:FindFirstChild("Humanoid")
			local part = (v and v.Parent and v.Parent:FindFirstChildWhichIsA("BasePart")) or nil
			if v and part then
				coroutine.wrap(remote.FireServer)(remote,
					v,
					part,
					(dmg or v.MaxHealth),
					Vector3.zero,
					-- CFrame.new((lplr.Character.Humanoid.RootPart.CFrame * CFrame.new(0, 1.5, 0)).Position, v.Character.Humanoid.RootPart.Position).LookVector,
					2,
					0,
					false
				)
			end
		-- end
	end
end

--[[
local shootTillDead = function(...)
	local p = ...
	local hum = (p.ClassName == "Player" and p.Character and p.Character:FindFirstChild("Humanoid")) or p:FindFirstChild("Humanoid")
	if not hum or not hum.Parent then return end
	local con
	con = hum.Died:Connect(function()
		con:Disconnect()
	end)
	
	-- local cam = workspace.CurrentCamera
	-- local og = cam.CameraSubject
	-- cam.CameraSubject = hum.RootPart
	-- lastShot = 0
	repeat
		shootPlr(...)
		task.wait()
	until not con.Connected or (hum.Health <= 0)
	if con.Connected then
		con:Disconnect()
	end
	-- cam.CameraSubject = og
end
]]

local shootTillDead = shootPlr

do
	local waitForChild = game.WaitForChild
	-- local isAlive = function(p, rootCheck)
	-- 	local p = (p.ClassName == "Player" and p.Character) or p
	-- 	if p then
	-- 		-- local hum = waitForChild(p, "Humanoid", 1)
	-- 		-- local root
			
	-- 		-- if not hum then return end
	-- 		-- if not rootCheck then
	-- 		-- 	do
	-- 		-- 		local timeout = tick() + 1
	-- 		-- 		repeat
	-- 		-- 			root = hum.RootPart or root
	-- 		-- 			task.wait()
	-- 		-- 		until root or tick() > timeout
	-- 		-- 	end
	-- 		-- 	if not root then return end
	-- 		-- end
			
	-- 		-- return p:WaitForChild("HumanoidRootPart")
    --         return p:FindFirstChild("HumanoidRootPart")
	-- 	end
	-- end

    local isAlive = function(p, await)
		local p = (p.ClassName == "Player" and p.Character) or p
		if p then
            return ((await and p.WaitForChild) or p.FindFirstChild)(p, "Head")
		end
	end

    local loopTbl = {}
    local hookChr = function(p)
		if p.ClassName == "Player" and p.Team == lplr.Team then return end
        if isAlive(p, true) then
            table.insert(loopTbl, p)
        end
    end
    local tCons = {}
    local hookPlr = function(p)
        if p.Character then
            coroutine.wrap(hookChr)(p)
        end
        table.insert(tCons, p.CharacterAdded:Connect(function(c)
            hookChr(p)
        end))
    end

    local transTbl = {
        Zombie = "Humans",
        Human = "Zombies",
		Zombies = "NPCs"
    }
	local teamScan = Teams:GetTeams()
	table.insert(teamScan, workspace:WaitForChild("Zombies"))
    for _, team in teamScan do
        if team then
			local tName = transTbl[team.Name]
			local isTeam = (team.ClassName == "Team")
			tabs.Server:CreateButton("Kill " .. tName, function()
				checkTeam(team)
				findRemote()

				for _, v in ((isTeam and plrs:GetPlayers()) or team:GetChildren()) do
					if (isTeam and lplr ~= v and v.Team ~= lplr.Team and isAlive(v)) or isAlive(v) then
						shootTillDead(v)
					end
				end
			end)

			tabs.Server:CreateButton("God " .. tName, function()
				checkTeam(team)
				findRemote()
				
                for _, v in ((isTeam and plrs:GetPlayers()) or team:GetChildren()) do
					if (isTeam and lplr ~= v and v.Team ~= lplr.Team and isAlive(v)) or isAlive(v) then
						shootPlr(v, tonumber("nan"))
					end
				end
				gui:Notify(string.format("made %s immune", tName))
			end)

			local loop
			loop = tabs.Server:CreateToggle("Loop Kill " .. transTbl[team.Name], function(v)
				if v then
					checkTeam(team)

                    -- print(isTeam)
					table.insert(tCons, (isTeam and plrs.PlayerAdded:Connect(hookPlr)) or team.ChildAdded:Connect(hookChr))
					if isTeam then
						for _, v in plrs:GetPlayers() do
							coroutine.wrap(hookPlr)(v)
						end
					else
						for _, v in team:GetChildren() do
							coroutine.wrap(hookChr)(v)
						end
					end
					
					repeat
						for i, v in loopTbl do
							-- coroutine.wrap(function()
                                if (isTeam and v.Team and v.Team == lplr.Team) then table.remove(loopTbl, i) continue end
                                if isAlive(v, true) then
                                    findRemote()
                                    shootTillDead(v)
                                end
                            -- end)()
						end
						task.wait()
					until not loop.Enabled
				else
					for _, v in tCons do
						v:Disconnect()
					end
					table.clear(tCons)
					table.clear(loopTbl)
				end
			end)
		end
    end
end

-- tabs.Server:CreateButton("God Npc Zombies", function()
    -- checkTeam(team)
    -- findRemote()

    -- for _, v in game.workspace.Zombies:GetChildren() do
        -- if v.Humanoid and v.HumanoidRootPart then
            -- remote:FireServer(
                -- v.Humanoid,
                -- v.HumanoidRootPart,
                -- tonumber("nan"),
                -- 2,
                -- 0,
                -- false
            -- )
        -- end
    -- end
-- end)

tabs.Server:CreateButton("Infect Humans", function()
    checkTeam(Teams.Zombie)
    local inf = find.Infect()
    if inf then
        table.insert(cons, inf.Activated:Connect(function()
            for _, v in plrs:GetPlayers() do
                if lplr ~= v and v.Character and v.Team ~= lplr.Team and v.Character.PrimaryPart then
                    firetouchinterest(lplr.Character.RightHand, v.Character.PrimaryPart, 0)
                    firetouchinterest(lplr.Character.RightHand, v.Character.PrimaryPart, 1)
                end
            end
        end))
        gui:Notify("Equip and spam the infect tool to infect")
    else
        gui:Notify("You must have a infect tool inorder to use this")
    end
end)

do
    local remotes = {}
    local tCons = {}
    local warning
    local tog
    tog = tabs.Server:CreateToggle("Lag Server", function(callback)
        if not warning then
            warning = true
            tog.Enabled = false
            gui:Notify("Your ping will NOT recover, rejoin after disabling")
            return
        end

        if callback then
            for _, v in plrs:GetPlayers() do
                table.insert(remotes, v.Backpack:FindFirstChild("reload", true))
                if v.Character then
                    table.insert(remotes, v.Character:FindFirstChild("reload", true))
                end
            end

            local packetSize = #remotes * 700
            for i = 1, #remotes do
                local v = remotes[i]
                table.insert(tCons, runServ.PreRender:Connect(function()
                    coroutine.wrap(function()
                        for _ = 1, packetSize do
                            coroutine.wrap(v.FireServer)(v)
                        end
                    end)()
                end))
            end
        else
            coroutine.wrap(TeleportService.TeleportToPlaceInstance)(TeleportService, game.PlaceId, game.JobId)
            for _, v in tCons do
                v:Disconnect()
            end
            table.clear(tCons)
            table.clear(remotes)
        end
    end)
end

do
    local tog
	local cache = {}
	
	local forceParent
	forceParent = function(og, new)
		local s, r = pcall(function()
			og.Parent = new
		end)
		
		-- if not s then
			-- coroutine.wrap(forceParent)(og, new)
		-- end
	end
	
    tog = tabs.Server:CreateToggle("Lag Other Players", function(callback)
        if callback then
			if lplr.Team ~= Teams.Zombie then
				itemFuncs.Virus()
			end
			coroutine.wrap(gui.Notify)(gui, "disable knife lag server to release buffer")
			
			local ogWeight = #lplr.Character:GetChildren()
            repeat
				buyItem:InvokeServer("Knife")
				for _, v in lplr.Backpack:GetChildren() do
					if v.Name == "Knife" and not table.find(cache, v) then
						table.insert(cache, v)
						coroutine.wrap(forceParent)(v, lplr.Character)
					end
				end
				task.wait()
			until not tog.Enabled --or (#lplr.Character:GetChildren() - ogWeight) >= 1000
			
			for _, v in cache do
				coroutine.wrap(forceParent)(v, lplr.Character)
			end
			for _, v in cache do
				coroutine.wrap(forceParent)(v, workspace)
			end
			for _, v in cache do
				coroutine.wrap(forceParent)(v, nil)
			end
			-- table.clear(cache)
        end
    end)
end
-- level 100 boss's code above

do
	local stats = game:GetService("Stats")
	local knife
	local con
	local ping
	
	tabs.Player:CreateToggle("Spam Knife", function(c)
		if c then
			con = lplr:GetMouse().Button1Down:Connect(function()
				if knife and knife.Parent then
					if knife.Parent == lplr.Character and lplr.Character and lplr.Character and lplr.Character:FindFirstChild("Cooldown") and lplr.Character.Cooldown.Value then
						buyItem:InvokeServer(knife.Name)
						knife = lplr.Backpack:WaitForChild(knife.Name)
						ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
						task.wait((ping < 150 and .1) or 0)
						knife.Parent = lplr.Character
					end
				else
					knife = find.Knife()
				end
			end)
		elseif con and con.Connected then
			con:Disconnect()
		end
	end)
end

-- do
	-- local runServ = game:GetService("RunService")

-- local root = chr.HumanoidRootPart
-- local limbs = {}

-- chr.Archivable = true
-- local clone = chr:Clone()
-- clone.Parent = chr



-- workspace.CurrentCamera.CameraSubject = clone
-- local con
	-- tabs.Player:CreateToggle("Noclip", function(c)
		-- if c then
			-- for _, v in clone:GetDescendants() do
				-- if v:IsA("BasePart") or v.ClassName == "Decal" then
					-- v.Transparency = 1
				-- end
			-- end

			-- for _, v in {clone, chr} do
				-- for _, v in clone:GetChildren() do
					-- if v:IsA("BasePart") then
						-- table.insert(limbs, v)
					-- end
				-- end
			-- end
		
			-- con = runServ.PreRender:Connect(function()
				-- if chr and chr.Parent == workspace then
					-- clone.Humanoid:Move(chr.Humanoid.MoveDirection)
					-- clone.Humanoid:ChangeState(chr.Humanoid:GetState())
					-- root.CFrame = clone.HumanoidRootPart.CFrame
					-- root.Velocity = clone.HumanoidRootPart.Velocity
					-- for _, v in limbs do
						-- v.Massless = true
						-- v.LocalTransparencyModifier = clone[v.Name].LocalTransparencyModifier
						-- v.CanCollide = false
					-- end
				-- else
					-- con:Disconnect()
				-- end
			-- end)
		-- else
			-- table.clear(limbs)
			-- if clone and clone.Parent then
				-- clone:Destroy()
			-- end
			-- if con.Connected then
				-- con:Disconnect()
			-- end
		-- end
	-- end)
-- end


-- dogshit niggas code below
tabs.Cosmetics:CreateButton("Change Zombie Face", function()
    lplr.PlayerGui.Main.ChooseFaceFrame.Visible = true
end)

tabs.Cosmetics:CreateButton("Change Zombie Skincolor", function()
    lplr.PlayerGui.Main.ChooseColorFrame.Visible = true
end)

-- tabs.Gamepass:CreateButton("Cure/Virus machines Gamepass", function()
    -- for _, v in rStor.LocalFolder:GetChildren() do
        -- if v.ClassName == "Model" then
            -- v.Parent = workspace
        -- end
    -- end
    -- gui:Notify("Gamepass Machines are currently broken.")
-- end)

tabs.Teleports:CreateButton("Human Spawn", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(108.507301, 2.99802589, 21.1811543, -0.999974489, 6.69067859e-08, -0.00714055588, 6.73346392e-08, 1, -5.96783067e-08, 0.00714055588, -6.01575962e-08, -0.999974489)
end)

tabs.Teleports:CreateButton("Zombie Spawn", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(-77.0017929, 2.99802589, 88.050827, 0.999998748, -2.56961403e-08, 0.00158172031, 2.56525929e-08, 1, 2.75529164e-08, -0.00158172031, -2.75123071e-08, 0.999998748)
end)

tabs.Teleports:CreateButton("Virus Room", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(-62.0080452, -15.501976, -51.7825928, 0.999956429, 2.60252282e-08, 0.00933171995, -2.59568829e-08, 1, -7.44509965e-09, -0.00933171995, 7.20255322e-09, 0.999956429)
end)

tabs.Teleports:CreateButton("Upstairs Cure room", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(-37.5837288, 2.99802613, -6.82807255, 0.999866545, 2.99475147e-08, 0.0163355526, -3.00902876e-08, 1, 8.49411652e-09, -0.0163355526, -8.98452512e-09, 0.999866545)
end)

tabs.Teleports:CreateButton("Downstairs Cure room", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(-89.571701, -15.5019779, 68.9455948, 0.999979734, -5.49140289e-09, -0.00636379281, 5.43602141e-09, 1, -8.71987904e-09, 0.00636379281, 8.68510863e-09, 0.999979734)
end)

tabs.Teleports:CreateButton("Secruity Room", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(170.688843, 2.99802589, -7.46687269, -0.00315899728, -1.09685722e-07, -0.999994993, -1.74622983e-10, 1, -1.09685722e-07, 0.999994993, -1.74622983e-10, -0.00315899728)
end)

tabs.Teleports:CreateButton("Roof", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(10.5755024, 25.498024, 32.7063293, -0.999892056, 1.2178937e-08, 0.0146923074, 1.24196662e-08, 1, 1.62934413e-08, -0.0146923074, 1.64741554e-08, -0.999892056)
end)

tabs.Teleports:CreateButton("Outside of Map", function()
    GetHumRootPart(lplr.Character).CFrame = CFrame.new(40.5333252, 2.59802508, 1005.94537, -0.999990642, -3.43452164e-08, -0.00432587136, -3.4408604e-08, 1, 1.45791699e-08, 0.00432587136, 1.47278811e-08, -0.999990642)
end)

tabs.Cosmetics:CreateButton("Scientist outfit", function()
    fireclickdetector(workspace.Lab.Specials["Doctor/Physician"].ClickPart.ClickDetector)
end)

tabs.Cosmetics:CreateButton("Patient outfit", function()
    fireclickdetector(workspace.Lab.Specials.Experimental.ClickPart.ClickDetector)
end)

tabs.Player:CreateButton("Godmode", function()
    gui:Notify("If it fails then retry")
    rStor.Remotes.ChangeState:FireServer("Died")
    task.wait(plrs.RespawnTime + .2)
    rStor.Remotes.ChangeState:FireServer("Died")
end)

-- do
--     local cache = {}
--     tabs.Server:CreateButton("Bring All NPCs", function()
--         table.clear(cache)
--         for _, v in workspace.Zombies:GetChildren() do
--             lplr.ReplicationFocus = v
--             for _ = 1, 10 do
--                 v.PrimaryPart.CFrame = lplr.Character.PrimaryPart.CFrame
--                 task.wait()
--             end
--         end
--         lplr.ReplicationFocus = nil
--     end)
-- end
