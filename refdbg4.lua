-- [Rocky][REFDBG4] Probe v4 FINAL: schema payload tile/act/punch versi game sekarang
-- Cara pakai:
--   1. Masuk ke dalam world Growblox dulu (bukan lobby/menu).
--   2. Eksekusi file ini (biarkan sampai 'selesai', 1-3 menit di HP).
--   3. Hasil otomatis di-CLIPBOARD + file Rocky_refdbg4.lua/.txt + 1 pesan konsol utuh.
-- HANYA MEMBACA — tidak mengirim paket, tidak mengubah tile.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg4.lua", text)
	pcall(writefile, "Rocky_refdbg4.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG4] " .. tostring(s)
	out[#out + 1] = s
	nPrint += 1
	print(s)
	if nPrint % 10 == 0 then savePartial(); task.wait() end
end

local exName = "-"
if type(identifyexecutor) == "function" then
	local okEx, nameEx = pcall(identifyexecutor)
	if okEx and type(nameEx) == "string" then exName = nameEx end
end
say("mulai | executor: " .. exName .. " — biarkan sampai 'selesai'")

local getconsts = (debug and debug.getconstants) or getconstants
local islc = islclosure
local function consts(fn)
	if getconsts == nil or type(fn) ~= "function" then return nil end
	local ok, c = pcall(getconsts, fn)
	if not ok or type(c) ~= "table" then return nil end
	return c
end
-- FULL: semua konstanta, string dipotong 48 char
local function constFull(c)
	if not c then return "-" end
	local parts = {}
	for i = 1, #c do
		local v = c[i]
		if type(v) == "string" then
			local s = v
			if #s > 48 then s = string.sub(s, 1, 48) .. "..." end
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
	local outU = {}
	for i = 1, 30 do
		local ok, name, v = pcall(gu, fn, i)
		if not ok then break end
		outU[i] = v
	end
	return outU
end
local function tableKeys(t, cap)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = tostring(k)
		if #keys >= (cap or 24) then keys[#keys + 1] = "..."; break end
	end
	table.sort(keys)
	return table.concat(keys, " ")
end

local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then
	say("STOP: getgc tidak tersedia")
	return
end

-- World via struktur (pairs: tahan lubang)
local world
for _, v in pairs(gc) do
	if type(v) == "table" then
		local fg, bg, w, h = rawget(v, "fg"), rawget(v, "bg"), rawget(v, "w"), rawget(v, "h")
		if type(fg) == "table" and type(bg) == "table" and type(w) == "number" and w > 0
			and type(h) == "number" and h > 0 and rawget(v, "spawn") ~= nil then
			world = v
			break
		end
	end
end
say("World: " .. (world and "ketemu" or "TIDAK ketemu"))
if not world then return end

-- Net via upvalue tabel World.call -> alias j1PKXTgzz
local net
do
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
say("Net: " .. (type(net) == "table" and "ketemu" or "TIDAK ketemu"))
if type(net) ~= "table" then return end

---------------------------------------------------------------------
-- B) SERIALIZER tiap channel penting: upvalue[1] = fungsi pembaca payload
---------------------------------------------------------------------
say("--- B) serializer channel (field payload) ---")
for _, name in ipairs({ "tile", "act", "punch", "harvest", "take", "drop", "move", "look", "call", "ask" }) do
	local c = net[name]
	if type(c) == "table" and type(c.send) == "function" then
		local ups = upvals(c.send)
		if ups then
			for k, v in pairs(ups) do
				if type(v) == "function" and (islc == nil or islc(v)) then
					say(("Net.%s.send upfn[%s] consts %s"):format(name, tostring(k), constFull(consts(v))))
				elseif type(v) == "table" then
					say(("Net.%s.send uptbl[%s] keys: %s"):format(name, tostring(k), tableKeys(v, 40)))
				elseif type(v) == "number" then
					say(("Net.%s.send upnum[%s] = %s"):format(name, tostring(k), tostring(v)))
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- C) CALLS: handler pesan MASUK (schema decode server)
---------------------------------------------------------------------
say("--- C) CALLS handler masuk ---")
do
	-- cari tabel CALLS: upvalue[3] Net.tile.send (dari v3) atau net.CALLS
	local calls = (type(net.CALLS) == "table") and net.CALLS or nil
	if not calls then
		local ts = net.tile
		if type(ts) == "table" and type(ts.send) == "function" then
			local ups = upvals(ts.send)
			if ups then
				for _, v in pairs(ups) do
					if type(v) == "table" and v.tile ~= nil then calls = v break end
				end
			end
		end
	end
	if type(calls) ~= "table" then
		say("CALLS tidak ketemu")
	else
		say("CALLS keys (" .. (function() local n = 0 for _ in pairs(calls) do n += 1 end return n end)() .. "): " .. tableKeys(calls, 100))
		for _, name in ipairs({ "tile", "tileChanged", "acted", "punch", "harvest", "take", "acted2" }) do
			local h = calls[name]
			if type(h) == "function" and (islc == nil or islc(h)) then
				say(("CALLS.%s consts %s"):format(name, constFull(consts(h))))
			elseif type(h) == "table" and type(h[1] or h.fire or h.connect) ~= nil then
				say("CALLS." .. name .. " = table keys: " .. tableKeys(h, 12))
			end
		end
	end
end

---------------------------------------------------------------------
-- D) Fungsi kunci game: FULL constants
---------------------------------------------------------------------
say("--- D) fungsi kunci ---")
local function dumpFn(label, fn)
	if type(fn) ~= "function" then
		say(label .. " = " .. type(fn))
		return
	end
	say(label .. " ups=" .. (function()
		local ups = upvals(fn)
		if not ups then return "-" end
		local parts, n = {}, 0
		for k, v in pairs(ups) do
			n += 1
			if n <= 10 then parts[#parts + 1] = tostring(k) .. "=" .. type(v) end
		end
		return tostring(n) .. "[" .. table.concat(parts, " ") .. "]"
	end)() .. " consts " .. constFull(consts(fn)))
end
dumpFn("World.remoteHit", rawget(world, "remoteHit"))
dumpFn("World.punchEvent", rawget(world, "punchEvent"))
dumpFn("World.tileChanged", rawget(world, "tileChanged"))
dumpFn("World.spliceSeed", rawget(world, "spliceSeed"))
dumpFn("Net.call(fn)", type(net.call) == "function" and net.call or nil)
-- handler input punch: consts memuat "punch_miss" DAN "punchEvent"
-- penerima tile: consts memuat "worldTag" DAN "tileChanged"
local i = 0
local doneFn = {}
for _, v in pairs(gc) do
	i += 1
	if i % 400 == 0 then task.wait() end
	if type(v) == "function" and not doneFn[v] and (islc == nil or islc(v)) then
		doneFn[v] = true
		local c = consts(v)
		if c then
			local hasPM, hasPE, hasWT, hasTC = false, false, false, false
			for _, k in ipairs(c) do
				if k == "punch_miss" then hasPM = true
				elseif k == "punchEvent" then hasPE = true
				elseif k == "worldTag" then hasWT = true
				elseif k == "tileChanged" then hasTC = true end
			end
			if hasPM and hasPE then
				dumpFn("inputPunchHandler", v)
			end
			if hasWT and hasTC then
				dumpFn("tileApplyHandler", v)
			end
		end
	end
end

---------------------------------------------------------------------
-- E) Isi placedAt / flips (format catatan place)
---------------------------------------------------------------------
say("--- E) World.placedAt / flips ---")
for _, fname in ipairs({ "placedAt", "flips" }) do
	local t = rawget(world, fname)
	if type(t) ~= "table" then
		say(fname .. " = " .. type(t))
	else
		local n = 0
		for k, v in pairs(t) do
			n += 1
			if n <= 3 then
				say(("%s[%s] = %s (%s)"):format(fname, tostring(k), tostring(v), type(v)))
			end
		end
		say(fname .. ": " .. n .. " entri")
	end
end

say("selesai (" .. nPrint .. " baris).")

---------------------------------------------------------------------
-- F) clipboard + file + 1 pesan utuh
---------------------------------------------------------------------
local text = table.concat(out, "\n")
local copied = false
if type(setclipboard) == "function" then
	copied = pcall(setclipboard, text)
elseif type(toclipboard) == "function" then
	copied = pcall(toclipboard, text)
end
if copied then
	say("SEMUA output sudah di CLIPBOARD — tinggal paste ke chat.")
else
	say("Executor tidak punya setclipboard — salin manual dari konsol.")
end
savePartial()
say("File: Rocky_refdbg4.lua & Rocky_refdbg4.txt (folder workspace executor)")
print(text)
