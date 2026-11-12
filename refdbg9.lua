-- [Rocky][REFDBG9] UJI masuk world: apakah World.enter masih jalan & bagaimana deteksi suksesnya
-- Cara pakai: KELUAR world dulu (layar pilih world) -> eksekusi -> paste hasil.
-- Aksi: memanggil World.enter 1x untuk world di bawah (sama seperti tombol masuk world game).

local WORLD = "GGGE" -- ganti kalau mau tes world lain

local nPrint = 0
local out = {}
local function savePartial()
	if type(writefile) ~= "function" then return end
	local text = table.concat(out, "\n")
	pcall(writefile, "Rocky_refdbg9.lua", text)
	pcall(writefile, "Rocky_refdbg9.txt", text)
end
local function say(s)
	s = "[Rocky][REFDBG9] " .. tostring(s)
	out[#out + 1] = s
	nPrint += 1
	print(s)
	if nPrint % 10 == 0 then savePartial(); task.wait() end
end

local function fgMark(fg)
	local n, mark = 0, {}
	for k, v in pairs(fg) do
		n += 1
		if n <= 3 then mark[#mark + 1] = tostring(k) .. "=" .. tostring(v) end
		if n >= 3 then break end
	end
	return n, table.concat(mark, ",")
end

say("=== A) cari world ===")
local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then say("STOP: getgc tidak ada") return end
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
if not world then say("World: TIDAK ketemu di GC") return end
local oldFg = rawget(world, "fg")
local oldN, oldMark = fgMark(oldFg)
say(("sebelum: name=%s fgTabelSama=%s fgIsi=%d mark=[%s]"):format(
	tostring(rawget(world, "name")), tostring(oldFg), oldN, oldMark))

local enter = rawget(world, "enter")
say("World.enter: " .. type(enter))
if type(enter) ~= "function" then return end

---------------------------------------------------------------------
-- B) panggil World.enter 1x (sama seperti game masuk world)
---------------------------------------------------------------------
say("=== B) panggil World.enter(" .. WORLD .. ") ===")
local t0 = os.clock()
local ok, res, msg = pcall(enter, WORLD)
say(("pcall ok=%s res=%s msg=%s (%.1fs)"):format(tostring(ok), tostring(res), tostring(msg), os.clock() - t0))

say("=== C) pantau 12 detik ===")
local last = ""
for s = 1, 12 do
	task.wait(1)
	local n, mark = fgMark(rawget(world, "fg"))
	local line = ("t+%d name=%s fgBaru=%s isi=%d mark=[%s]"):format(
		s, tostring(rawget(world, "name")), tostring(rawget(world, "fg") ~= oldFg), n, mark)
	if line ~= last then
		say(line)
		last = line
	end
end
local nowFg = rawget(world, "fg")
local nowN, nowMark = fgMark(nowFg)
local masuk = (nowFg ~= oldFg) or (nowN ~= oldN) or (nowMark ~= oldMark)
say("HASIL: " .. (masuk and "MASUK (data world berubah)" or "TIDAK MASUK (data tidak berubah)"))

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
say("File: Rocky_refdbg9.lua & Rocky_refdbg9.txt (folder workspace executor)")
print(text)
