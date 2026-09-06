--[[
    EmoteAPI.lua
    Библиотека поиска + проигрывания эмоций для двухшаговой схемы с ИИ.
    Без GUI, без loadstring, без стороннего кода — только данные.

    СХЕМА РАБОТЫ (round-trip, как function calling):
        1. ИИ решает выполнить действие и пишет тег [DO:searchanim <query>]
        2. Код перехватывает тег, вызывает EmoteAPI.Search(query),
           формирует короткий текстовый список результатов и
           ВТОРЫМ запросом к провайдеру (Groq/Gemini) подсовывает его
           ИИ как системное сообщение — "вот результаты поиска, выбери id"
        3. ИИ во втором ответе пишет [DO:playanim <id>] — код проигрывает

    Публичное API:
        EmoteAPI.Search(query, limit)        -> {id, name}[] отсортированный список
        EmoteAPI.FormatResults(results)       -> строка для вставки в промпт ИИ
        EmoteAPI.PlayById(id, seconds)        -> проигрывает конкретный numeric ID
        EmoteAPI.PlayBuiltin(name, seconds)   -> проигрывает встроенную /e эмоцию
        EmoteAPI.Stop()                       -> останавливает текущую анимацию
        EmoteAPI.SetCustomEnabled(bool)       -> тумблер "кастомные анимации"
        EmoteAPI.LoadCustomDatabase(url)      -> подгружает доп. список (только JSON-данные)
]]

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local EmoteAPI = {}

-- Публичный URL большого стороннего каталога UGC-анимаций (id+имя, только данные,
-- никакого исполняемого кода). Используется по умолчанию, если LoadCustomDatabase
-- вызван без явного url или с пустой строкой.
EmoteAPI.DEFAULT_CUSTOM_DB_URL = "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json"

-- ==========================================================
-- 1. ЛОКАЛЬНАЯ БАЗА ЭМОЦИЙ
--    Только бесплатные, официально принадлежащие Roblox ID.
--    Ничего не качается по сети — работает всегда, без задержек.
-- ==========================================================
local EMOTES = {
    -- Встроенные /e эмоции (всегда доступны, работают через PlayEmote)
    { id = "wave",   name = "Wave",   builtin = true },
    { id = "laugh",  name = "Laugh",  builtin = true },
    { id = "cheer",  name = "Cheer",  builtin = true },
    { id = "point",  name = "Point",  builtin = true },
    { id = "sit",    name = "Sit",    builtin = true },
    { id = "dance",  name = "Dance",  builtin = true },
    { id = "dance2", name = "Dance 2", builtin = true },
    { id = "dance3", name = "Dance 3", builtin = true },

    -- Бесплатные каталожные анимации (rbxassetid, принадлежат Roblox)
    { id = 3576968026, name = "Shrug" },
    { id = 3576823880, name = "Point 2" },
    { id = 3360692915, name = "Tilt" },
    { id = 3576721660, name = "Robot" },
    { id = 3360686498, name = "Stadium" },
    { id = 3360689775, name = "Salute" },
    { id = 3576686446, name = "Hello" },
    { id = 3570649048, name = "Jacks" },
    { id = 3576747102, name = "Around Town" },
    { id = 3716633898, name = "Twirl" },
    { id = 3716636630, name = "Monkey" },
    { id = 3576754235, name = "Sneaky" },
    { id = 3762641826, name = "Side To Side" },
    { id = 3762654854, name = "Greatest" },
    { id = 3576751796, name = "Louder" },
    { id = 3934986896, name = "Dizzy" },
    { id = 3934984583, name = "Get Out" },
    { id = 3994129128, name = "Fishing" },
    { id = 4049634387, name = "Tree" },
    { id = 4049646104, name = "Line Dance" },
    { id = 4102315500, name = "Haha" },
    { id = 4102317848, name = "Idol" },
    { id = 3576719440, name = "T" },
    { id = 3570535774, name = "Top Rock" },
    { id = 4212496830, name = "Zombie" },
    { id = 4212499637, name = "Dorky Dance" },
    { id = 4272351660, name = "Fast Hands" },
    { id = 4272484885, name = "Baby Dance" },
    { id = 3994127840, name = "Celebrate" },
    { id = 3576717965, name = "Shy" },
}

-- ==========================================================
-- 1b. ТУМБЛЕР "КАСТОМНЫЕ АНИМАЦИИ" + доп. база (опционально)
--     Выключено по умолчанию = только проверенный список выше.
--     Включено = поиск также ищет по CUSTOM_EMOTES (если загружена).
-- ==========================================================
local _customEnabled = false
local CUSTOM_EMOTES = {}  -- заполняется через LoadCustomDatabase, если включено

function EmoteAPI.SetCustomEnabled(state)
    _customEnabled = state and true or false
end

function EmoteAPI.IsCustomEnabled()
    return _customEnabled
end

-- Подгружает ДОПОЛНИТЕЛЬНЫЙ список эмоций из JSON по URL.
-- ВАЖНО: это чисто данные (HttpService:JSONDecode), никакого loadstring,
-- никакого выполнения кода — максимум "плохой ID", не бэкдор.
-- Если url не передан (nil/пустая строка) — используется DEFAULT_CUSTOM_DB_URL.
-- Вызывать один раз при старте/при включении тумблера "Кастомные анимации".
-- Возвращает: ok (bool), count или текст ошибки
function EmoteAPI.LoadCustomDatabase(url)
    if not url or url == "" then
        url = EmoteAPI.DEFAULT_CUSTOM_DB_URL
    end

    local HttpService = game:GetService("HttpService")
    local ok, result = pcall(function()
        local raw = game:HttpGet(url)
        local decoded = HttpService:JSONDecode(raw)
        -- Разные источники по-разному оборачивают массив: либо сам массив,
        -- либо {data=[...]}, либо {emotes=[...]}, либо {items=[...]}
        if type(decoded) == "table" then
            if decoded.data then return decoded.data end
            if decoded.emotes then return decoded.emotes end
            if decoded.items then return decoded.items end
            return decoded
        end
        return decoded
    end)
    if not ok or type(result) ~= "table" then
        warn("[EmoteAPI] Failed to load custom database from " .. tostring(url) .. ": " .. tostring(result))
        return false, tostring(result)
    end

    local loaded = {}
    for _, item in ipairs(result) do
        if type(item) == "table" then
            -- Разные источники называют поля по-разному — проверяем варианты
            local id = item.id or item.Id or item.ID or item.assetId or item.AssetId
            local name = item.name or item.Name or item.title or item.Title or item.emoteName or item.EmoteName
            id = tonumber(id)
            if id and id > 0 and type(name) == "string" and name ~= "" then
                table.insert(loaded, { id = id, name = name })
            end
        end
    end

    if #loaded == 0 then
        warn("[EmoteAPI] Custom database at " .. tostring(url) .. " loaded but contained 0 valid entries — проверь формат JSON (ожидались поля id/name).")
        return false, "0 valid entries after parsing"
    end

    CUSTOM_EMOTES = loaded
    return true, #loaded
end

-- ==========================================================
-- 2. ПОИСК (полностью локальный, без сети)
-- ==========================================================

-- Простой пословный поиск: каждое слово из запроса должно
-- встречаться в названии эмоции. Регистр не важен.
local function smartMatch(name, query)
    name = name:lower()
    query = query:lower()
    for word in query:gmatch("%S+") do
        if not name:find(word, 1, true) then
            return false
        end
    end
    return true
end

-- Возвращает отсортированный список совпадений: {id, name}
-- Приоритет: точное совпадение > совпадение в начале > обычное вхождение
-- limit по умолчанию 8 — ИИ не нужно видеть сотни результатов, только топ.
function EmoteAPI.Search(query, limit)
    if not query or query == "" then return {} end
    limit = limit or 8
    query = query:lower()

    local pool = EMOTES
    if _customEnabled and #CUSTOM_EMOTES > 0 then
        pool = {}
        for _, e in ipairs(EMOTES) do table.insert(pool, e) end
        for _, e in ipairs(CUSTOM_EMOTES) do table.insert(pool, e) end
    end

    local exact, startsWith, contains = {}, {}, {}

    for _, e in ipairs(pool) do
        local lname = e.name:lower()
        if lname == query then
            table.insert(exact, e)
        elseif lname:find("^" .. query) then
            table.insert(startsWith, e)
        elseif smartMatch(e.name, query) then
            table.insert(contains, e)
        end
    end

    local result = {}
    for _, e in ipairs(exact) do table.insert(result, e) end
    for _, e in ipairs(startsWith) do table.insert(result, e) end
    for _, e in ipairs(contains) do table.insert(result, e) end

    -- обрезаем до limit
    local trimmed = {}
    for i = 1, math.min(limit, #result) do
        trimmed[i] = result[i]
    end
    return trimmed
end

-- Форматирует результаты поиска в компактную строку для промпта ИИ.
-- Пример вывода:
--   1. Sit (builtin:sit)
--   2. Stadium (id:3360686498)
--   3. Tired (id:2506281703)
function EmoteAPI.FormatResults(results)
    if #results == 0 then
        return "No animations found for that query."
    end
    local lines = {}
    for i, e in ipairs(results) do
        local ref = e.builtin and ("builtin:" .. tostring(e.id)) or ("id:" .. tostring(e.id))
        table.insert(lines, i .. ". " .. e.name .. " (" .. ref .. ")")
    end
    return table.concat(lines, "\n")
end

-- ==========================================================
-- 3. ПРОИГРЫВАНИЕ
-- ==========================================================
local _activeTrack   = nil
local _activeThread  = nil

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Возврат в idle через встроенный Animate-скрипт (R6/R15 совместимо)
local function restoreIdle()
    pcall(function()
        local char = player.Character
        local animate = char and char:FindFirstChild("Animate")
        local fn = animate and animate:FindFirstChild("PlayEmote")
        if fn then fn:Invoke("idle") end
    end)
end

function EmoteAPI.Stop()
    if _activeThread then
        pcall(task.cancel, _activeThread)
        _activeThread = nil
    end
    if _activeTrack then
        pcall(function() _activeTrack:Stop(0.3) end)
        _activeTrack = nil
    end
    restoreIdle()
end

-- Проиграть по конкретному ID (число) — грузится напрямую через Animator,
-- никакого ApplyDescription, работает в любом executor-окружении.
function EmoteAPI.PlayById(animId, seconds)
    seconds = seconds or 30
    local humanoid = getHumanoid()
    if not humanoid then return false end

    EmoteAPI.Stop()

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(animId)

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if not ok or not track then return false end

    track.Priority = Enum.AnimationPriority.Action
    track:Play(0, 1, 1)
    _activeTrack = track

    _activeThread = task.delay(seconds, function()
        pcall(function() track:Stop(0.3) end)
        _activeTrack = nil
        _activeThread = nil
        restoreIdle()
    end)

    return true
end

-- Проиграть встроенную /e эмоцию (wave, dance и т.д.) через штатный PlayEmote
function EmoteAPI.PlayBuiltin(name, seconds)
    seconds = seconds or 30
    local humanoid = getHumanoid()
    if not humanoid then return false end

    EmoteAPI.Stop()

    local ok, track = pcall(function()
        return humanoid:PlayEmote(name)
    end)
    if not ok or not track then return false end

    _activeTrack = track
    _activeThread = task.delay(seconds, function()
        pcall(function() track:Stop(0.3) end)
        _activeTrack = nil
        _activeThread = nil
        restoreIdle()
    end)

    return true
end

-- ==========================================================
-- 4. ГЛАВНАЯ ФУНКЦИЯ ДЛЯ ИИ:
--    ИИ передаёт свободный текст ("sit", "танцуй", "shrug") —
--    функция сама находит лучшее совпадение и проигрывает его.
-- ==========================================================
function EmoteAPI.PlayByQuery(query, seconds)
    local results = EmoteAPI.Search(query, 1)
    if #results == 0 then return false, "not_found" end

    local best = results[1]
    if best.builtin then
        return EmoteAPI.PlayBuiltin(best.id, seconds), best.name
    else
        return EmoteAPI.PlayById(best.id, seconds), best.name
    end
end

-- Проигрывает по ссылке, которую ИИ скопировал из результатов поиска,
-- например "builtin:sit" или "id:3360686498". Это то, что должно
-- приходить во втором тег-сообщении [DO:playanim <ref>].
function EmoteAPI.PlayByRef(ref, seconds)
    if type(ref) ~= "string" then return false end
    local kind, value = ref:match("^(%a+):(.+)$")
    if kind == "builtin" then
        return EmoteAPI.PlayBuiltin(value, seconds)
    elseif kind == "id" then
        return EmoteAPI.PlayById(tonumber(value), seconds)
    end
    return false
end

return EmoteAPI
