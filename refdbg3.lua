-- [Rocky][REFDBG3] Probe v3: daftar lengkap field World + Net via World.call
-- Cara pakai:
--   1. Masuk ke dalam world Growblox dulu (bukan lobby/menu).
--   2. Eksekusi file ini (biarkan sampai 'selesai', 1-3 menit di HP).
--   3. Hasil otomatis di-CLIPBOARD + file Rocky_refdbg3.lua/.txt + 1 pesan konsol utuh.
-- HANYA MEMBACA — tidak mengirim paket, tidak mengubah tile.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg3.lua", text)
	pcall(writefile, "Rocky_refdbg3.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG3] " .. tostring(s)
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
local function constStr(c, n)
	local parts = {}
	for i = 1, math.min(#c, n or 14) do
		local v = c[i]
		parts[i] = (type(v) == "string") and string.format("%q", v) or tostring(v)
	end
	return table.concat(parts, ", ")
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
local function upSummary(ups)
	if not ups then return "-" end
	local parts, n = {}, 0
	for k, v in pairs(ups) do
		n += 1
		if n <= 10 then parts[#parts + 1] = tostring(k) .. "=" .. type(v) end
	end
	return tostring(n) .. " [" .. table.concat(parts, " ") .. "]"
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

-- World via struktur (pairs: tahan lubang array getgc)
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

---------------------------------------------------------------------
-- B1) Daftar LENGKAP field World (nama=type), padat 10 per baris
---------------------------------------------------------------------
say("--- B1) semua field World ---")
local names, types = {}, {}
for k, v in pairs(world) do
	names[#names + 1] = tostring(k)
	types[tostring(k)] = type(v)
end
table.sort(names)
local chunk = {}
for idx, nm in ipairs(names) do
	chunk[#chunk + 1] = nm .. "=" .. types[nm]
	if #chunk == 10 then
		say(table.concat(chunk, " "))
		chunk = {}
	end
end
if #chunk > 0 then say(table.concat(chunk, " ")) end
say("total field World: " .. #names)

---------------------------------------------------------------------
-- B2) Konstanta SETIAP method World (per nama, bukan dedupe bentuk)
---------------------------------------------------------------------
say("--- B2) method World + konstanta ---")
local nM = 0
for _, nm in ipairs(names) do
	local v = rawget(world, nm)
	if type(v) == "function" and (islc == nil or islc(v)) then
		nM += 1
		local c = consts(v)
		say(("World.%s ups=%s consts[%d]: %s")
			:format(nm, upSummary(upvals(v)), c and #c or -1, c and constStr(c, 14) or "-"))
		if nM >= 120 then
			say("... cap 120 method")
			break
		end
	end
end

---------------------------------------------------------------------
-- C) Net module via World.call / World.ask (upvalue tabel = registry/Net)
---------------------------------------------------------------------
say("--- C) Net via World.call ---")
local wcall = rawget(world, "call")
local net = nil
if type(wcall) == "function" then
	local ups = upvals(wcall)
	say("World.call ups: " .. upSummary(ups))
	if ups then
		for k, v in pairs(ups) do
			if type(v) == "table" then
				say("upvalue[" .. tostring(k) .. "] keys: " .. tableKeys(v))
				-- upvalue bisa registry (alias->ModuleScript) atau Net langsung
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
if type(net) ~= "table" then
	say("Net belum ketemu dari World.call — coba require registry manual")
	local okEnv, gameEnv = pcall(function() return getrenv and getrenv() end)
	local moduleKey = game:GetService("ReplicatedStorage"):GetAttribute("Qz")
	local gameShared = okEnv and type(gameEnv) == "table" and gameEnv.shared or nil
	local reg = moduleKey and type(gameShared) == "table" and gameShared[moduleKey] or nil
	if type(reg) == "table" then
		local okR, m = pcall(require, reg.j1PKXTgzz)
		if okR and type(m) == "table" then net = m end
	end
end
if type(net) ~= "table" then
	say("Net: TIDAK KETEMU")
else
	local ch = {}
	for k in pairs(net) do ch[#ch + 1] = tostring(k) end
	table.sort(ch)
	say("Net channels (" .. #ch .. "): " .. table.concat(ch, " "))
	for _, name in ipairs({ "tile", "act", "call", "ask", "seq", "waits", "listen" }) do
		local c = net[name]
		if type(c) == "table" and type(c.send) == "function" then
			local cc = consts(c.send)
			say(("Net.%s.send consts[%d]: %s"):format(name, cc and #cc or -1, cc and constStr(cc) or "-"))
			local ups = upvals(c.send)
			say(("Net.%s.send upvalues: %s"):format(name, upSummary(ups)))
			if ups then
				for k, v in pairs(ups) do
					if type(v) == "table" then
						say(("Net.%s.send upvalue[%s] keys: %s"):format(name, tostring(k), tableKeys(v)))
					end
				end
			end
		elseif c ~= nil then
			say("Net." .. name .. " = " .. type(c))
		end
	end
end

---------------------------------------------------------------------
-- D) Keyword scan (pairs, tahan lubang): fungsi pengirim tile/act
---------------------------------------------------------------------
say("--- D) keyword constants ---")
local KW = { "j1PKXTgzz", "placedAt", "flips", "newCrack", "punch", "setTile", "tile" }
local seenK, m, i2 = {}, 0, 0
for _, v in pairs(gc) do
	i2 += 1
	if i2 % 500 == 0 then task.wait() end
	if type(v) == "function" and not seenK[v] and (islc == nil or islc(v)) then
		seenK[v] = true
		local c = consts(v)
		if c then
			local hit = {}
			for _, k in ipairs(c) do
				if type(k) == "string" then
					for _, kw in ipairs(KW) do
						if string.find(k, kw, 1, true) then
							hit[#hit + 1] = k
							break
						end
					end
				end
			end
			if #hit > 0 then
				m += 1
				-- apakah fungsi ini memegang World?
				local hasW = false
				local ups = upvals(v)
				if ups then
					for _, u in pairs(ups) do
						if u == world then hasW = true break end
					end
				end
				say(("kw#%d world=%s hit=[%s] consts[%d]: %s")
					:format(m, hasW and "YA" or "no", table.concat(hit, "|"), #c, constStr(c, 12)))
				if m >= 40 then
					say("... cap 40")
					break
				end
			end
		end
	end
end
if m == 0 then say("TIDAK ada keyword sama sekali") end

---------------------------------------------------------------------
-- E) Kamus string konstanta (top 60) — pairs, tahan lubang
---------------------------------------------------------------------
say("--- E) string constants terbanyak ---")
local freq, nFn = {}, 0
local i3 = 0
for _, v in pairs(gc) do
	i3 += 1
	if i3 % 500 == 0 then task.wait() end
	if type(v) == "function" and (islc == nil or islc(v)) then
		nFn += 1
		local c = consts(v)
		if c then
			for _, k in ipairs(c) do
				if type(k) == "string" and #k >= 3 and #k <= 40 then
					freq[k] = (freq[k] or 0) + 1
				end
			end
		end
	end
end
say("fungsi discan: " .. nFn)
local list = {}
for s, n in pairs(freq) do list[#list + 1] = { s = s, n = n } end
table.sort(list, function(a, b) return a.n > b.n end)
for i4 = 1, math.min(#list, 60) do
	say(("str x%d %q"):format(list[i4].n, list[i4].s))
end
if #list == 0 then say("TIDAK ada string konstanta") end

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
say("File: Rocky_refdbg3.lua & Rocky_refdbg3.txt (folder workspace executor)")
print(text)
