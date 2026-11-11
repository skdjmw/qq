-- [Rocky][REFDBG5] Dump terakhir: schema ByteNet + konvensi sender punch game
-- Cara pakai: masuk world Growblox -> eksekusi -> tunggu 'selesai' -> paste hasil.
-- HANYA MEMBACA — tidak mengirim paket, tidak mengubah tile.

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg5.lua", text)
	pcall(writefile, "Rocky_refdbg5.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG5] " .. tostring(s)
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
			local s = #v > 48 and (string.sub(v, 1, 48) .. "...") or v
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
	for i = 1, 40 do
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
		if #keys >= (cap or 40) then keys[#keys + 1] = "..."; break end
	end
	table.sort(keys)
	return table.concat(keys, " ")
end

local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then say("STOP: getgc tidak ada") return end

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
say("World: " .. (world and "ketemu" or "TIDAK"))
if not world then return end

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
say("Net: " .. (type(net) == "table" and "ketemu" or "TIDAK"))
if type(net) ~= "table" then return end

---------------------------------------------------------------------
-- B) SCHEMA serializer: upvalues dari upvalue[1] Net.<ch>.send
---------------------------------------------------------------------
say("--- B) schema serializer ---")
for _, name in ipairs({ "tile", "act", "punch", "harvest", "take", "drop" }) do
	local c = net[name]
	if type(c) == "table" and type(c.send) == "function" then
		local ups = upvals(c.send)
		local ser = ups and ups[1]
		if type(ser) == "function" then
			local sups = upvals(ser)
			say(("Net.%s serializer ups=%s"):format(name, sups and (function()
				local parts, n = {}, 0
				for k, v in pairs(sups) do
					n += 1
					if n <= 12 then parts[#parts + 1] = tostring(k) .. "=" .. type(v) end
				end
				return tostring(n) .. "[" .. table.concat(parts, " ") .. "]"
			end)() or "-"))
			if sups then
				for k, v in pairs(sups) do
					if type(v) == "table" then
						-- schema: keys = nama field payload
						say(("Net.%s ser.up[%s] keys: %s"):format(name, tostring(k), tableKeys(v, 40)))
						-- 1 level dalam: sub-tabel (mis. field list)
						local n2 = 0
						for k2, v2 in pairs(v) do
							if type(v2) == "table" and n2 < 4 then
								n2 += 1
								say(("Net.%s ser.up[%s].%s keys: %s"):format(name, tostring(k), tostring(k2), tableKeys(v2, 24)))
							end
						end
					elseif type(v) == "function" then
						say(("Net.%s ser.up[%s] fn consts %s"):format(name, tostring(k), constFull(consts(v))))
					elseif type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
						say(("Net.%s ser.up[%s] = %s"):format(name, tostring(k), tostring(v)))
					end
				end
			end
		else
			say("Net." .. name .. ": serializer bukan function (ups=" .. tostring(ups) .. ")")
		end
	end
end

---------------------------------------------------------------------
-- C) inputPunchHandler: upvalue function (sendHit dll) + asal module
---------------------------------------------------------------------
say("--- C) inputPunchHandler ---")
local handler
local i = 0
for _, v in pairs(gc) do
	i += 1
	if i % 400 == 0 then task.wait() end
	if type(v) == "function" and (islc == nil or islc(v)) then
		local c = consts(v)
		if c and #c > 100 then
			local hasPM, hasPE = false, false
			for _, k in ipairs(c) do
				if k == "punch_miss" then hasPM = true
				elseif k == "punchEvent" then hasPE = true end
			end
			if hasPM and hasPE then handler = v break end
		end
	end
end
if type(handler) ~= "function" then
	say("inputPunchHandler TIDAK ketemu")
else
	local okI, info = pcall(debug.getinfo, handler, "s")
	say("source: " .. (okI and info and tostring(info.source) or "-"))
	local ups = upvals(handler)
	if ups then
		for k, v in pairs(ups) do
			if type(v) == "function" and (islc == nil or islc(v)) then
				say(("up[%s] fn consts %s"):format(tostring(k), constFull(consts(v))))
				-- upvalue milik fungsi ini: cari Net/channel
				local vups = upvals(v)
				if vups then
					for k2, v2 in pairs(vups) do
						if type(v2) == "table" then
							say(("up[%s].up[%s] tbl keys: %s"):format(tostring(k), tostring(k2), tableKeys(v2, 24)))
						elseif type(v2) == "function" and (islc == nil or islc(v2)) then
							local c3 = consts(v2)
							if c3 and #c3 > 0 and #c3 <= 30 then
								say(("up[%s].up[%s] fn consts %s"):format(tostring(k), tostring(k2), constFull(c3)))
							end
						end
					end
				end
			elseif type(v) == "table" then
				say(("up[%s] tbl keys: %s"):format(tostring(k), tableKeys(v, 20)))
			end
		end
	end
end

say("selesai (" .. nPrint .. " baris).")

---------------------------------------------------------------------
-- D) clipboard + file + 1 pesan utuh
---------------------------------------------------------------------
local text = table.concat(out, "\n")
local copied = false
if type(setclipboard) == "function" then
	copied = pcall(setclipboard, text)
elseif type(toclipboard) == "function" then
	copied = pcall(toclipboard, text)
end
if copied then say("SEMUA output sudah di CLIPBOARD — tinggal paste ke chat.") end
savePartial()
say("File: Rocky_refdbg5.lua & Rocky_refdbg5.txt (folder workspace executor)")
print(text)
