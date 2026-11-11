-- [Rocky][REFDBG6] Dump renderer tangan game: kosakata pose (kind) + isi tabel aksi
-- Cara pakai: masuk world Growblox -> eksekusi -> tunggu 'selesai' -> paste hasil.
-- HANYA MEMBACA.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg6.lua", text)
	pcall(writefile, "Rocky_refdbg6.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG6] " .. tostring(s)
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
local function constFull(c)
	if not c then return "-" end
	local parts = {}
	for i = 1, #c do
		local v = c[i]
		if type(v) == "string" then
			local s = #v > 60 and (string.sub(v, 1, 60) .. "...") or v
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
	for i = 1, 24 do
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
		if #keys >= (cap or 30) then keys[#keys + 1] = "..."; break end
	end
	table.sort(keys)
	return table.concat(keys, " ")
end
local function isArmFn(fn)
	local c = consts(fn)
	if not c then return false end
	local a, b, d = false, false, false
	for _, k in pairs(c) do
		if k == "forearm" then a = true
		elseif k == "heldReach" then b = true
		elseif k == "punchReach" then d = true end
	end
	return a and b and d
end

-- 1) Cari fungsi tangan game di koneksi RunService (cara sama dgn script)
say("--- cari renderer tangan ---")
local RunService = game:GetService("RunService")
local arms, seen = {}, {}
local function addFn(fn)
	if type(fn) == "function" and not seen[fn] and (islc == nil or islc(fn)) and isArmFn(fn) then
		seen[fn] = true
		arms[#arms + 1] = fn
	end
end
for _, name in ipairs({ "RenderStepped", "Heartbeat", "PreRender", "Stepped" }) do
	local okS, sig = pcall(function() return RunService[name] end)
	if okS and sig then
		local okC, conns = pcall(getconnections, sig)
		if okC and type(conns) == "table" then
			for _, cn in ipairs(conns) do
				local okf, fn = pcall(function() return cn.Function end)
				if okf then
					addFn(fn)
					local ups = upvals(fn)
					if ups then
						for _, u in pairs(ups) do
							if type(u) == "function" then addFn(u) end
						end
					end
				end
			end
		end
	end
end
say("renderer tangan ketemu: " .. #arms)
if #arms == 0 then
	say("TIDAK ketemu via koneksi — coba getgc")
	local okGc, gc = pcall(getgc, true)
	if okGc and type(gc) == "table" then
		for _, v in pairs(gc) do
			if type(v) == "function" and (islc == nil or islc(v)) and isArmFn(v) then
				arms[#arms + 1] = v
				if #arms >= 4 then break end
			end
		end
		say("via getgc: " .. #arms)
	end
end

-- 2) Dump konstanta penuh + tabel aksi
for ai, fn in ipairs(arms) do
	say(("arm#%d consts %s"):format(ai, constFull(consts(fn))))
	local ups = upvals(fn)
	if ups then
		for k, v in pairs(ups) do
			if type(v) == "table" then
				say(("arm#%d up[%s] tbl: %s"):format(ai, tostring(k), tableKeys(v)))
				-- isi nilai sederhana tabel aksi
				local parts = 0
				for k2, v2 in pairs(v) do
					parts += 1
					if parts <= 10 and type(v2) ~= "table" then
						say(("  up[%s].%s = %s"):format(tostring(k), tostring(k2), tostring(v2)))
					elseif parts <= 10 and type(v2) == "table" then
						say(("  up[%s].%s = table{%s}"):format(tostring(k), tostring(k2), tableKeys(v2, 12)))
					end
				end
			elseif type(v) == "function" then
				local c2 = consts(v)
				if c2 and #c2 > 0 then
					say(("arm#%d up[%s] fn consts %s"):format(ai, tostring(k), constFull(c2)))
				end
			end
		end
	end
end

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
say("File: Rocky_refdbg6.lua & Rocky_refdbg6.txt (folder workspace executor)")
print(text)
