-- [Rocky][REFDBG2] Probe v2: cari signature place/punch versi game sekarang
-- Cara pakai:
--   1. Masuk ke dalam world Growblox dulu (bukan lobby/menu).
--   2. Eksekusi file ini di executor (biarkan sampai muncul 'selesai', 1-3 menit di HP).
--   3. Hasil otomatis di-CLIPBOARD + disimpan Rocky_refdbg2.lua/.txt + dicetak 1 pesan utuh.
-- Script ini HANYA MEMBACA (getgc, getconstants, getupvalues) — tidak mengirim paket.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg2.lua", text)
	pcall(writefile, "Rocky_refdbg2.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG2] " .. tostring(s)
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
local islc = islclosure -- boleh nil
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
local function constSig(c)
	local parts = {}
	for i = 1, #c do parts[i] = tostring(c[i]) end
	return table.concat(parts, "|")
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
		if n <= 8 then parts[#parts + 1] = tostring(k) .. "=" .. type(v) end
	end
	return tostring(n) .. " [" .. table.concat(parts, " ") .. "]"
end
local function tableKeys(t, cap)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = tostring(k)
		if #keys >= (cap or 20) then keys[#keys + 1] = "..."; break end
	end
	table.sort(keys)
	return table.concat(keys, " ")
end

---------------------------------------------------------------------
-- A) Sesi k .lua hidup: dump sender fallback yang DIPAKAI script sekarang
---------------------------------------------------------------------
say("--- A) Net dari sesi __KzoyzOpus ---")
local session = (getgenv and getgenv()) or _G
session = session.__KzoyzOpus
if type(session) ~= "table" or type(session.netSender) ~= "function" then
	say("Sesi k .lua tidak hidup / netSender tidak ada (eksekusi k .lua dulu)")
else
	say("Sesi hidup | ModuleMode: " .. tostring(session.ModuleMode))
	for _, name in ipairs({ "tile", "act" }) do
		local send = session.netSender(name)
		if type(send) ~= "function" then
			say("Net." .. name .. ".send: TIDAK ADA (channel hilang/berganti nama!)")
		else
			local c = consts(send)
			say(("Net.%s.send consts[%d]: %s"):format(name, c and #c or -1, c and constStr(c) or "-"))
			local ups = upvals(send)
			say(("Net.%s.send upvalues: %s"):format(name, upSummary(ups)))
			if ups then
				for k, v in pairs(ups) do
					if type(v) == "table" then
						say(("Net.%s.send upvalue[%s] keys: %s"):format(name, tostring(k), tableKeys(v)))
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- B) World table: semua field + konstanta tiap fungsinya (dedupe)
---------------------------------------------------------------------
local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then
	say("STOP: getgc tidak tersedia")
	return
end
local world
for _, v in ipairs(gc) do
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
if world then
	say("--- B) field World ---")
	local seenSig = {}
	local lines = 0
	for k, v in pairs(world) do
		if type(v) == "function" and (islc == nil or islc(v)) then
			local c = consts(v)
			local sig = c and constSig(c) or "-"
			if not seenSig[sig] then
				seenSig[sig] = true
				lines += 1
				say(("World.%s ups=%s consts[%d]: %s")
					:format(tostring(k), upSummary(upvals(v)), c and #c or -1, c and constStr(c, 14) or "-"))
				-- upvalue function milik fungsi World: 1 level (di situ handler asli sering sembunyi)
				local ups = upvals(v)
				if ups then
					for _, u in pairs(ups) do
						if type(u) == "function" and (islc == nil or islc(u)) then
							local cu = consts(u)
							local sigu = cu and constSig(cu) or "-"
							if not seenSig[sigu] then
								seenSig[sigu] = true
								lines += 1
								say(("World.%s -> upfn ups=%s consts[%d]: %s")
									:format(tostring(k), upSummary(upvals(u)), cu and #cu or -1, cu and constStr(cu, 14) or "-"))
							end
						end
					end
				end
				if lines >= 40 then
					say("... cap 40 bentuk fungsi")
					break
				end
			end
		else
			say("World." .. tostring(k) .. " = " .. type(v))
		end
	end
end

---------------------------------------------------------------------
-- C) Semua fungsi dg upvalue World — dedupe per BENTUK konstanta
---------------------------------------------------------------------
if world then
	say("--- C) fungsi dg upvalue World (dedupe bentuk) ---")
	local seenSig, counts = {}, {}
	local nShapes, total = 0, 0
	local i = 0
	for _, v in ipairs(gc) do
		i += 1
		if i % 500 == 0 then task.wait() end
		if type(v) == "function" and (islc == nil or islc(v)) then
			local ups = upvals(v)
			if ups then
				local hasW = false
				for _, u in pairs(ups) do
					if u == world then hasW = true break end
				end
				if hasW then
					total += 1
					local c = consts(v)
					local sig = c and constSig(c) or "-"
					if not seenSig[sig] then
						seenSig[sig] = true
						nShapes += 1
						counts[sig] = { n = 0, c = c, ups = ups }
					end
					counts[sig].n += 1
				end
			end
		end
	end
	say("total fungsi dg upvalue World: " .. total .. " | bentuk unik: " .. nShapes)
	for sig, e in pairs(counts) do
		say(("x%d ups=%s consts[%d]: %s")
			:format(e.n, upSummary(e.ups), e.c and #e.c or -1, e.c and constStr(e.c, 14) or "-"))
	end
end

---------------------------------------------------------------------
-- D) Kamus string konstanta game (frekuensi, top 60) — deteksi rename/obfuscation
---------------------------------------------------------------------
say("--- D) string constants terbanyak ---")
local freq, nFn, nWithC = {}, 0, 0
local i2 = 0
for _, v in ipairs(gc) do
	i2 += 1
	if i2 % 500 == 0 then task.wait() end
	if type(v) == "function" and (islc == nil or islc(v)) then
		nFn += 1
		local c = consts(v)
		if c then
			nWithC += 1
			for _, k in ipairs(c) do
				if type(k) == "string" and #k >= 3 and #k <= 40 then
					freq[k] = (freq[k] or 0) + 1
				end
			end
		end
	end
end
say("fungsi discan: " .. nFn .. " | punya konstanta: " .. nWithC)
local list = {}
for s, n in pairs(freq) do list[#list + 1] = { s = s, n = n } end
table.sort(list, function(a, b) return a.n > b.n end)
for i3 = 1, math.min(#list, 60) do
	say(("str x%d %q"):format(list[i3].n, list[i3].s))
end
if #list == 0 then say("TIDAK ada string konstanta sama sekali (string dienkripsi/dibangun runtime?)") end

---------------------------------------------------------------------
-- E) Kandidat Others/data pemain (sekunder)
---------------------------------------------------------------------
local o, i4 = 0, 0
for _, v in ipairs(gc) do
	i4 += 1
	if i4 % 500 == 0 then task.wait() end
	if type(v) == "table" and type(rawget(v, "list")) == "function" then
		o += 1
		say("oth#" .. o .. " keys: " .. tableKeys(v))
		if o >= 8 then break end
	end
end
if o == 0 then say("TIDAK ada tabel dengan fungsi list()") end

say("selesai (" .. nPrint .. " baris).")

---------------------------------------------------------------------
-- F) Salin hasil: clipboard + file + 1 pesan konsol utuh
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
	say("Executor tidak punya setclipboard/toclipboard — salin manual dari konsol.")
end
savePartial()
say("File: Rocky_refdbg2.lua & Rocky_refdbg2.txt (folder workspace executor)")
print(text)
