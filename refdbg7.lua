-- [Rocky][REFDBG7] Dump jalur MASUK WORLD + event WorldClosed versi game sekarang
-- Cara pakai:
--   1) Masuk world Growblox -> eksekusi -> tunggu 'selesai' -> paste hasil.
--   2) Keluar world (layar pilih world) -> eksekusi LAGI -> paste hasil.
-- HANYA MEMBACA — tidak mengirim paket apa pun ke server, tidak mengubah tile.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg7.lua", text)
	pcall(writefile, "Rocky_refdbg7.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG7] " .. tostring(s)
	out[#out + 1] = s
	nPrint += 1
	print(s)
	if nPrint % 10 == 0 then savePartial(); task.wait() end
end

local getconsts = (debug and debug.getconstants) or getconstants
local islc = islclosure
local function consts(fn)
	if getconsts == nil or type(fn) ~= "function" then return nil end
	local ok, c = pcall(getconsts, fn)
	if not ok or type(c) ~= "table" then return nil end
	return c
end
local function constFull(c, cap)
	if not c then return "-" end
	local parts = {}
	for i = 1, #c do
		local v = c[i]
		if type(v) == "string" then
			local m = cap or 60
			local s = #v > m and (string.sub(v, 1, m) .. "...") or v
			parts[i] = string.format("%q", s)
		else
			parts[i] = tostring(v)
		end
	end
	return "[" .. #c .. "] " .. table.concat(parts, ", ")
end
local function upvals(fn)
	if debug and debug.getupvalues then
		local ok, ups = pcall(debug.getupvalues, fn)
		if ok and type(ups) == "table" then return ups end
	end
	local gu = (debug and debug.getupvalue) or getupvalue
	if not gu then return nil end
	local o = {}
	for i = 1, 40 do
		local ok, name, v = pcall(gu, fn, i)
		if not ok then break end
		o[i] = v
	end
	return o
end
local function tableKeys(t, cap)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = tostring(k)
		if #keys >= (cap or 40) then keys[#keys + 1] = "..."; break end
	end
	table.sort(keys)
	return table.concat(keys, " ")
end
local function dumpFn(label, fn)
	if type(fn) ~= "function" then return end
	local okI, info = pcall(debug.getinfo, fn, "s")
	say(label .. " source: " .. (okI and info and tostring(info.source) or "-"))
	say(label .. " consts: " .. constFull(consts(fn)))
	local ups = upvals(fn)
	if ups then
		for k, v in pairs(ups) do
			if type(v) == "table" then
				say((label .. " up[%s] tbl keys: %s"):format(tostring(k), tableKeys(v, 24)))
			elseif type(v) == "function" and (islc == nil or islc(v)) then
				say((label .. " up[%s] fn consts %s"):format(tostring(k), constFull(consts(v), 40)))
			elseif type(v) == "Instance" then
				say((label .. " up[%s] Instance: %s (%s)"):format(tostring(k), v.Name, v.ClassName))
			end
		end
	end
end
local function instKeys(inst, cap)
	if typeof and typeof(inst) == "Instance" or type(inst) == "userdata" then
		local names = {}
		for _, ch in pairs(inst:GetChildren()) do
			names[#names + 1] = ch.Name .. ":" .. ch.ClassName
			if #names >= (cap or 30) then names[#names + 1] = "..."; break end
		end
		table.sort(names)
		return table.concat(names, " ")
	end
	return "(bukan Instance)"
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then say("STOP: getgc tidak ada") return end

---------------------------------------------------------------------
-- A) WORLD: masih ada tabel world di GC? (validator fg/bg/w/h/spawn)
---------------------------------------------------------------------
say("=== A) state world ===")
local world
local i = 0
for _, v in pairs(gc) do
	i += 1
	if i % 400 == 0 then task.wait() end
	if type(v) == "table" then
		local fg, bg, w, h = rawget(v, "fg"), rawget(v, "bg"), rawget(v, "w"), rawget(v, "h")
		if type(fg) == "table" and type(bg) == "table" and type(w) == "number" and w > 0
			and type(h) == "number" and h > 0 and rawget(v, "spawn") ~= nil then
			world = v
			break
		end
	end
end
if world then
	local name = rawget(world, "name")
	say("World: KETEMU, name=" .. tostring(name) .. ", w=" .. tostring(rawget(world, "w")) .. ", h=" .. tostring(rawget(world, "h")))
	say("World keys: " .. tableKeys(world, 50))
else
	say("World: TIDAK ketemu (kemungkinan DI LUAR world / layar pilih world)")
end

---------------------------------------------------------------------
-- B) Net via world.call upvalue (jalur terbukti probe lama)
---------------------------------------------------------------------
local net
if world then
	say("=== B) Net via World.call ===")
	local wcall = rawget(world, "call")
	dumpFn("World.call", wcall)
	if type(wcall) == "function" then
		local ups = upvals(wcall)
		if ups then
			for _, v in pairs(ups) do
				if type(v) == "table" then
					local cand = v.j1PKXTgzz or v.Net
					if cand ~= nil then
						local okR, m = pcall(require, cand)
						if okR and type(m) == "table" then net = m end
					end
					if net == nil and type(v.tile) == "table" then net = v end
				end
			end
		end
	end
end
if type(net) == "table" then
	say("Net: KETEMU via world.call")
	say("Net channels: " .. tableKeys(net, 60))
	say("Net.on ada? " .. tostring(type(rawget(net, "on"))))
	say("Net.EVENTS ada? " .. tostring(type(rawget(net, "EVENTS"))))
	local wc = rawget(net, "WorldClosed")
	if wc ~= nil then
		say("Net.WorldClosed = " .. type(wc) .. (type(wc) == "table" and (" keys: " .. tableKeys(wc, 20)) or ""))
		if type(wc) == "table" then
			for k, v in pairs(wc) do
				if type(v) == "function" then dumpFn("Net.WorldClosed." .. tostring(k), v) end
			end
		end
	else
		say("Net.WorldClosed: TIDAK ADA")
	end
	for _, name in ipairs({ "world", "enter", "join", "travel", "door", "warp" }) do
		local c = rawget(net, name)
		if type(c) == "table" then
			say(("Net.%s keys: %s"):format(name, tableKeys(c, 20)))
			if type(rawget(c, "send")) == "function" then dumpFn("Net." .. name .. ".send", rawget(c, "send")) end
		end
	end
else
	say("=== B) Net via world.call: dilewati (world/Net tidak ketemu) ===")
end

---------------------------------------------------------------------
-- C) Registry module (alias) — deteksi alias ganti versi baru
---------------------------------------------------------------------
say("=== C) registry module ===")
local shared = ReplicatedStorage:FindFirstChild("Shared")
local regMode = "ReplicatedStorage.Shared"
if not shared then
	local okEnv, gameEnv = pcall(function() return getrenv and getrenv() end)
	local moduleKey = ReplicatedStorage:GetAttribute("Qz")
	local gameShared = okEnv and type(gameEnv) == "table" and gameEnv.shared or nil
	shared = moduleKey and type(gameShared) == "table" and gameShared[moduleKey] or nil
	regMode = "Qz registry"
end
say("registry: " .. regMode .. " | type=" .. type(shared))
if shared ~= nil then
	local n = 0
	for _ in pairs(shared) do n += 1 end
	say("registry pairs count: " .. n)
	if n == 0 then
		local mt = getmetatable(shared)
		say("registry proxy? metatable keys: " .. (type(mt) == "table" and tableKeys(mt, 20) or "-"))
	end
	local function tryReq(alias)
		local okR, m = pcall(function() return require(shared[alias]) end)
		if okR and type(m) == "table" then
			say("registry[" .. alias .. "] -> keys: " .. tableKeys(m, 40))
			return m
		end
		return nil
	end
	for _, alias in ipairs({ "j1PKXTgzz", "Net", "xGd5Vdk03obV", "WorldMenu", "Input", "Menu" }) do
		local has = shared[alias] ~= nil
		if has then tryReq(alias) end
	end
	local ui = shared.Ui or (type(rawget(shared, "Ui")) == "table" and rawget(shared, "Ui")) or nil
	if type(ui) == "table" then
		say("registry.Ui keys: " .. tableKeys(ui, 40))
		local m = ui["xGd5Vdk03obV"]
		if m ~= nil then
			local okR, mod = pcall(require, m)
			if okR and type(mod) == "table" then
				say("Ui[xGd5Vdk03obV] (WorldMenu) keys: " .. tableKeys(mod, 40))
				dumpFn("WorldMenu.enter", rawget(mod, "enter"))
				dumpFn("WorldMenu.openPicker", rawget(mod, "openPicker"))
			end
		end
	elseif ui ~= nil then
		say("registry.Ui: " .. instKeys(ui, 30))
	end
end

---------------------------------------------------------------------
-- D) Menu ref di GC (tabel openBackpack + ui) + fungsi enter-nya
---------------------------------------------------------------------
say("=== D) Menu (openBackpack) ===")
local menu
i = 0
for _, v in pairs(gc) do
	i += 1
	if i % 400 == 0 then task.wait() end
	if type(v) == "table" and type(rawget(v, "openBackpack")) == "function" and type(rawget(v, "ui")) == "table" then
		menu = v
		break
	end
end
if menu then
	say("Menu: KETEMU, keys: " .. tableKeys(menu, 50))
	dumpFn("Menu.enter", rawget(menu, "enter"))
	dumpFn("Menu.openPicker", rawget(menu, "openPicker"))
else
	say("Menu (openBackpack+ui): TIDAK ketemu di GC")
end

---------------------------------------------------------------------
-- E) GameGui + WorldRemotes: module & remote yang masih ada
---------------------------------------------------------------------
say("=== E) GameGui & WorldRemotes ===")
local gameGui = PlayerGui:FindFirstChild("GameGui")
say("GameGui: " .. (gameGui and instKeys(gameGui, 30) or "TIDAK ADA"))
local wm = gameGui and gameGui:FindFirstChild("WorldMenu")
if wm then
	local okR, mod = pcall(require, wm)
	if okR and type(mod) == "table" then
		say("GameGui.WorldMenu keys: " .. tableKeys(mod, 40))
		dumpFn("GameGui.WorldMenu.enter", rawget(mod, "enter"))
	end
else
	say("GameGui.WorldMenu (legacy): TIDAK ADA")
end
local wr = ReplicatedStorage:FindFirstChild("WorldRemotes")
say("WorldRemotes: " .. (wr and instKeys(wr, 30) or "TIDAK ADA"))

say("selesai (" .. nPrint .. " baris).")

local text = table.concat(out, "\n")
local copied = false
if type(setclipboard) == "function" then
	copied = pcall(setclipboard, text)
elseif type(toclipboard) == "function" then
	copied = pcall(toclipboard, text)
end
if copied then say("SEMUA output sudah di CLIPBOARD — tinggal paste ke chat.") end
savePartial()
say("File: Rocky_refdbg7.lua & Rocky_refdbg7.txt (folder workspace executor)")
print(text)
