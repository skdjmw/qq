-- [Rocky][REFDBG] Probe signature place/punch versi game sekarang (standalone, tidak butuh k .lua)
-- Cara pakai:
--   1. Masuk ke dalam world Growblox dulu (bukan di lobby/menu).
--   2. Eksekusi file ini di executor.
--   3. Salin SELURUH baris [Rocky][REFDBG] yang muncul di konsol, kirim balik.
-- Script ini HANYA MEMBACA (getgc, getconstants, getupvalues) — tidak mengirim
-- paket dan tidak mengubah tile apapun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local nPrint = 0
local out = {} -- semua baris disimpan untuk clipboard/file di akhir
local function say(s)
	s = "[Rocky][REFDBG] " .. tostring(s)
	out[#out + 1] = s
	nPrint += 1
	print(s)
	if nPrint % 10 == 0 then task.wait() end
end

local exName = "-"
if type(identifyexecutor) == "function" then
	local okEx, nameEx = pcall(identifyexecutor)
	if okEx and type(nameEx) == "string" then exName = nameEx end
end
say("mulai | executor: " .. exName)

---------------------------------------------------------------------
-- 0) Registry module game (Shared)
---------------------------------------------------------------------
local shared = ReplicatedStorage:FindFirstChild("Shared")
local mode = "folder ReplicatedStorage.Shared"
if not shared then
	local okEnv, gameEnv = pcall(function() return getrenv and getrenv() end)
	local moduleKey = ReplicatedStorage:GetAttribute("Qz")
	local gameShared = okEnv and type(gameEnv) == "table" and gameEnv.shared or nil
	shared = moduleKey and type(gameShared) == "table" and gameShared[moduleKey] or nil
	mode = "Qz registry key=" .. tostring(moduleKey)
end
say("Shared: " .. mode .. " | type=" .. type(shared))
if type(shared) ~= "table" and typeof(shared) ~= "Instance" then
	say("STOP: registry module game tidak ketemu")
	return
end

-- Daftar semua key registry (cek apakah alias module masih sama dgn k .lua)
-- Registry bisa berupa tabel Lua (Qz) atau Folder Instance (mode lama).
local regKeys = {}
if type(shared) == "table" then
	for k in pairs(shared) do regKeys[#regKeys + 1] = tostring(k) end
else
	for _, c in ipairs(shared:GetChildren()) do regKeys[#regKeys + 1] = c.Name end
end
table.sort(regKeys)
say("Registry keys (" .. #regKeys .. "): " .. table.concat(regKeys, " "))

-- Nilai registry bisa tabel Lua atau ModuleScript; samakan dulu.
local function asModule(v)
	if type(v) == "table" then return v end
	if typeof(v) == "Instance" and v:IsA("ModuleScript") then
		local okM, m = pcall(require, v)
		if okM then return m end
	end
	return nil
end

---------------------------------------------------------------------
-- Helper konstanta & upvalue
---------------------------------------------------------------------
local getconsts = (debug and debug.getconstants) or getconstants
local islc = islclosure -- boleh nil
local function consts(fn)
	if getconsts == nil then return nil end
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
	local out = {}
	for i = 1, 30 do
		local ok, name, v = pcall(gu, fn, i) -- CATATAN: ambil (name, value)
		if not ok then break end
		out[i] = v
	end
	return out
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

---------------------------------------------------------------------
-- 1) Module Net: channel yang ada + konstanta send masing-masing
---------------------------------------------------------------------
local netRef, netKey = asModule(shared.Net), "Net"
if type(netRef) ~= "table" then
	if type(shared) == "table" then
		for k, v in pairs(shared) do
			local m = asModule(v)
			if type(m) == "table" and type(m.tile) == "table" and type(m.tile.send) == "function" then
				netRef, netKey = m, tostring(k)
				break
			end
		end
	end
end
if type(netRef) ~= "table" then
	say("Net: TIDAK ketemu di registry (nama module mungkin berganti!)")
else
	say("Net: ketemu via key '" .. netKey .. "'")
	local ch = {}
	for k in pairs(netRef) do ch[#ch + 1] = tostring(k) end
	table.sort(ch)
	say("Net channels (" .. #ch .. "): " .. table.concat(ch, " "))
	for _, name in ipairs({ "tile", "act", "Tile", "Act", "setTile", "move" }) do
		local c = netRef[name]
		if type(c) == "table" and type(c.send) == "function" then
			local cc = consts(c.send)
			say(("Net.%s.send consts[%d]: %s"):format(name, cc and #cc or -1, cc and constStr(cc) or "-"))
			say(("Net.%s.send upvalues: %s"):format(name, upSummary(upvals(c.send))))
		end
	end
end

---------------------------------------------------------------------
-- 2) World table via getgc
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
if not world then return end

---------------------------------------------------------------------
-- 3) Semua fungsi game yang memegang World sebagai upvalue
--    (di antaranya: handler place/punch yang baru)
---------------------------------------------------------------------
say("--- fungsi dg upvalue World ---")
local n, i = 0, 0
local done = {}
for _, v in ipairs(gc) do
	i += 1
	if i % 500 == 0 then task.wait() end
	if type(v) == "function" and not done[v] and (islc == nil or islc(v)) then
		local ups = upvals(v)
		if ups then
			local hasW = false
			for _, u in pairs(ups) do
				if u == world then hasW = true break end
			end
			if hasW then
				done[v] = true
				n += 1
				local c = consts(v)
				say(("fn#%d ups=%s consts[%d]: %s")
					:format(n, upSummary(ups), c and #c or -1, c and constStr(c, 12) or "-"))
				if n >= 30 then
					say("... cap 30 fungsi")
					break
				end
			end
		end
	end
end
if n == 0 then say("TIDAK ada fungsi yang memegang World sebagai upvalue (pola scan lama mati?)") end

---------------------------------------------------------------------
-- 4) Fungsi dg konstanta keyword terkait place/punch (deteksi rename)
---------------------------------------------------------------------
say("--- keyword constants ---")
local KW = { "placedAt", "flips", "newCrack", "HarvestProvider", "Vending", "SetTile", "tile" }
local seenK, m = {}, 0
for _, v in ipairs(gc) do
	i += 1
	if i % 500 == 0 then task.wait() end
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
				say(("kw#%d hit=[%s] consts[%d]: %s")
					:format(m, table.concat(hit, "|"), #c, constStr(c, 10)))
				if m >= 25 then
					say("... cap 25")
					break
				end
			end
		end
	end
end
if m == 0 then say("TIDAK ada konstanta keyword sama sekali (semua string diganti?)") end

---------------------------------------------------------------------
-- 5) Kandidat Others/data pemain (sekunder)
---------------------------------------------------------------------
local o = 0
for _, v in ipairs(gc) do
	i += 1
	if i % 500 == 0 then task.wait() end
	if type(v) == "table" and type(rawget(v, "list")) == "function" then
		o += 1
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		say(("oth#%d keys: %s"):format(o, table.concat(keys, " ")))
		if o >= 8 then break end
	end
end
if o == 0 then say("TIDAK ada tabel dengan fungsi list()") end

say("selesai (" .. nPrint .. " baris).")

---------------------------------------------------------------------
-- 6) Salin hasil: clipboard + file + 1 pesan konsol utuh
---------------------------------------------------------------------
local text = table.concat(out, "\n")
local copied = false
if type(setclipboard) == "function" then
	copied = pcall(setclipboard, text)
elseif type(toclipboard) == "function" then
	copied = pcall(toclipboard, text)
end
if copied then
	say("SEMUA output sudah di CLIPBOARD — tinggal Ctrl+V ke chat.")
else
	say("Executor tidak punya setclipboard/toclipboard — salin manual dari konsol.")
end
if type(writefile) == "function" then
	local okW, errW = pcall(writefile, "Rocky_refdbg.txt", text)
	if okW then
		say("Output juga disimpan ke file: Rocky_refdbg.txt (folder workspace executor)")
	else
		say("writefile gagal: " .. tostring(errW))
	end
end
-- Cetak sekali lagi sebagai SATU pesan konsol agar mudah di-select lalu copy.
print(text)
