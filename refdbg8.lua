-- [Rocky][REFDBG8] Dump paket MASUK/KELUAR world versi game sekarang (Net.CALLS/EVENTS)
-- Cara pakai: di dalam world Growblox -> eksekusi -> tunggu 'selesai' -> paste hasil.
-- HANYA MEMBACA — tidak mengirim paket apa pun ke server, tidak mengubah tile.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg8.lua", text)
	pcall(writefile, "Rocky_refdbg8.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG8] " .. tostring(s)
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
	for i = 1, 24 do
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
			end
		end
	end
end

local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then say("STOP: getgc tidak ada") return end

---------------------------------------------------------------------
-- A) World + Net (jalur sama dgn refdbg7)
---------------------------------------------------------------------
say("=== A) world & net ===")
local world, net
local i = 0
for _, v in pairs(gc) do
	i += 1
	if i % 400 == 0 then task.wait() end
	if type(v) == "table" then
		local fg, bg, w, h = rawget(v, "fg"), rawget(v, "bg"), rawget(v, "w"), rawget(v, "h")
		if world == nil and type(fg) == "table" and type(bg) == "table"
			and type(w) == "number" and w > 0 and type(h) == "number" and h > 0
			and rawget(v, "spawn") ~= nil then
			world = v
		end
	end
end
if world then
	local fg = rawget(world, "fg")
	local n = 0
	for _ in pairs(fg) do n += 1 end
	say("World: name=" .. tostring(rawget(world, "name")) .. " | fg isi=" .. n)
	dumpFn("World.goTo", rawget(world, "goTo"))
	dumpFn("World.enter", rawget(world, "enter"))
	local wcall = rawget(world, "call")
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
say("Net: " .. (type(net) == "table" and "KETEMU" or "TIDAK"))
if type(net) ~= "table" then return end

---------------------------------------------------------------------
-- B) CALLS & EVENTS: daftar nama paket yang bisa dipanggil / didengar
---------------------------------------------------------------------
say("=== B) CALLS & EVENTS ===")
local calls = rawget(net, "CALLS")
say("Net.CALLS: " .. (type(calls) == "table" and ("keys(" .. (function()
	local n = 0
	for _ in pairs(calls) do n += 1 end
	return n
end)() .. ") " .. tableKeys(calls, 90)) or tostring(type(calls))))
if type(calls) == "table" then
	local seen, n = 0, 0
	for name, v in pairs(calls) do
		seen += 1
		if seen > 5 or n > 8 then break end
		if type(v) == "function" then
			say(("CALLS[%s] fn consts %s"):format(tostring(name), constFull(consts(v), 44)))
			n += 1
		elseif type(v) == "table" then
			say(("CALLS[%s] tbl keys: %s"):format(tostring(name), tableKeys(v, 16)))
			n += 1
		end
	end
end
local ev = rawget(net, "EVENTS")
say("Net.EVENTS: " .. (type(ev) == "table" and tableKeys(ev, 90) or tostring(type(ev))))

---------------------------------------------------------------------
-- C) Net.on: cara mendengarkan + channel terkait world
---------------------------------------------------------------------
say("=== C) Net.on & channel world ===")
dumpFn("Net.on", rawget(net, "on"))
for _, name in ipairs({ "worldClosed", "worldTag", "worldsAnswer", "leave", "left", "doorPass", "call", "ask", "busy" }) do
	local c = rawget(net, name)
	if type(c) == "table" then
		say(("Net.%s keys: %s"):format(name, tableKeys(c, 20)))
		for k, v in pairs(c) do
			if type(v) == "function" and (islc == nil or islc(v)) then
				say(("Net.%s.%s consts %s"):format(name, tostring(k), constFull(consts(v), 48)))
			end
		end
	else
		say("Net." .. name .. ": " .. type(c))
	end
end

---------------------------------------------------------------------
-- D) Fungsi game yang mengirim enter/leave world (cari di GC)
---------------------------------------------------------------------
say("=== D) pemanggil enter/leave world ===")
local found, i2 = 0, 0
for _, v in pairs(gc) do
	i2 += 1
	if i2 % 400 == 0 then task.wait() end
	if found >= 6 then break end
	if type(v) == "function" and (islc == nil or islc(v)) then
		local c = consts(v)
		if c then
			for _, k in ipairs(c) do
				if type(k) == "string" then
					local lk = string.lower(k)
					if string.find(lk, "enterworld", 1, true) or string.find(lk, "joinworld", 1, true)
						or string.find(lk, "leaveworld", 1, true) or string.find(lk, "worldclosed", 1, true) then
						dumpFn("GCfn(" .. k .. ")", v)
						found += 1
						break
					end
				end
			end
		end
	end
end
say("fungsi ketemu: " .. found)

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
say("File: Rocky_refdbg8.lua & Rocky_refdbg8.txt (folder workspace executor)")
print(text)
