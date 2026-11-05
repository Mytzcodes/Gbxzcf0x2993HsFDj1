--[[
    StructScope v3.0  -  ByteNet Debugger + Struct Table + Docs Generator (SCRIPT HUB UI)
    PASIF: hanya membaca / merekam. Debugger tidak mengirim, mengubah, atau memutar ulang packet.

    BARU di v3.0
      * SUB-PACKET: satu packet ByteNet bisa membawa banyak jenis pesan (mis. packet.packet = "message").
        Debugger mendeteksi field pembeda (packet/type/action/message/cmd/...) lalu mencatat
        struct, hitungan, dan sampel PER sub-packet. Log bisa difilter per packet / sub / isi data.
      * TABEL STRUCT dari packet: declared (definisi ByteNet) atau observed (data nyata), plus per sub-packet.
      * LOG scroll: panel log sendiri di tab Log (banyak baris, auto-scroll ke data baru).
      * RESPONSIVE: ukuran awal menyesuaikan layar, mode kompak untuk mobile (sidebar ikon, satu kolom),
        tarik bar paling bawah menu untuk ubah ukuran, tombol cepat "SS" untuk buka/tutup menu.
      * SAVE DOCS: satu klik menyimpan folder rapi berformat Markdown (README, overview, coverage,
        structs, subpackets, packets, categories, logs, lua). Ada auto-save berkala.

    API (getgenv().StructScope):
      StructScope.Packets.get(namaAtauId)   -> objek ByteNet asli (listen / send)
      StructScope.Packets.info(namaAtauId)  -> { id, name, channel, source, struct, schema, counts, subs, ... }
      StructScope.Packets.subs(namaAtauId)  -> { [sub] = { n, inN, outN, schema, samples } }
      StructScope.Packets.list()            -> daftar nama packet
      StructScope.Subscribe(function(name, dir, chan, data, entry, sub) end) -> fungsi unsubscribe
      StructScope.Log / StructScope.Chat    -> tabel log
      StructScope.Stats()                   -> { inR, inU, outR, outU, ... }
      StructScope.Export.framework() / .docs() / .report() / .structs() -> string
      StructScope.SaveDocs(snapshot?)       -> simpan folder docs
]]

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
local VERSION = "3.0"
local CFG = {
	MaxSamples = 12,     -- sampel terakhir per packet
	SubSamples = 5,      -- sampel terakhir per sub-packet
	SubCap     = 120,    -- maks jenis sub-packet per packet
	LearnLimit = 300,    -- data per packet yang dipelajari penuh (sisanya 1 dari 20)
	FeedMax    = 250,
	LogMax     = 2000,   -- entri log keseluruhan
	MoveCap    = 6,      -- maks packet movement dicatat per detik (0 = tanpa batas)
	TextLimit  = 20000,  -- batas karakter di viewer (Copy/Save tetap penuh)
	LogLimit   = 28000,  -- batas karakter panel log
	Ascii      = true,   -- non-ASCII jadi '?'
	MenuKey    = "RightShift",
	AutoScanEvery = 20,
	AutoSaveMin = 5,     -- menit, bila Auto-save docs dinyalakan
}

------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

if getgenv and getgenv().__StructScopeUnload then
	pcall(getgenv().__StructScopeUnload)
end

------------------------------------------------------------------
-- SCRIPT HUB UI (library custom, tanpa dependensi luar, ikon digambar dari Frame)
------------------------------------------------------------------
local function buildHubUI()
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")

	local L = {
		MainColor = Color3.fromRGB(14, 32, 80),
		BackgroundColor = Color3.fromRGB(8, 18, 48),
		AccentColor = Color3.fromRGB(47, 107, 255),
		OutlineColor = Color3.fromRGB(31, 58, 133),
		FontColor = Color3.fromRGB(234, 241, 255),
		Toggled = true,
		Options = {}, Toggles = {},
		MenuKey = Enum.KeyCode.RightShift,
		_conns = {}, _unload = {}, _reg = {}, _resize = {},
	}
	L.AccentColorDark = L.AccentColor:Lerp(Color3.new(0, 0, 0), 0.4)

	local function conn(c) L._conns[#L._conns + 1] = c return c end
	local function lighten(c, t) return c:Lerp(Color3.new(1, 1, 1), t) end
	local function darken(c, t) return c:Lerp(Color3.new(0, 0, 0), t) end
	function L:GetDarkerColor(c) return darken(c, 0.4) end

	local function bind(inst, prop, fn)
		L._reg[#L._reg + 1] = { inst, prop, fn }
		inst[prop] = fn()
	end
	function L:UpdateColorsUsingRegistry()
		local keep = {}
		for _, r in ipairs(L._reg) do
			if r[1].Parent ~= nil then
				keep[#keep + 1] = r
				pcall(function() r[1][r[2]] = r[3]() end)
			end
		end
		L._reg = keep
	end

	local function new(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		if parent then o.Parent = parent end
		return o
	end
	local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
	local function stroke(o, fn, th)
		local s = new("UIStroke", { Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
		bind(s, "Color", fn)
		return s
	end
	local function padding(o, l, t, r, b)
		return new("UIPadding", {
			PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
			PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
		}, o)
	end
	local function vlist(o, gap)
		return new("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder }, o)
	end

	local cMain = function() return L.MainColor end
	local cBg = function() return L.BackgroundColor end
	local cOutline = function() return L.OutlineColor end
	local cAccent = function() return L.AccentColor end
	local cFont = function() return L.FontColor end
	local cDim = function() return L.FontColor:Lerp(L.BackgroundColor, 0.32) end
	local cCtrl = function() return lighten(L.MainColor, 0.07) end
	local cField = function() return darken(L.MainColor, 0.38) end
	local cSide = function() return darken(L.BackgroundColor, 0.28) end
	local cSoft = function() return lighten(L.AccentColor, 0.38) end

	local function txt(parent, props, colorFn)
		local base = {
			BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
		}
		for k, v in pairs(props) do base[k] = v end
		local t = new("TextLabel", base, parent)
		bind(t, "TextColor3", colorFn or cFont)
		return t
	end

	local function safe(cb, ...)
		if type(cb) ~= "function" then return end
		local ok, err = pcall(cb, ...)
		if not ok then warn("[StructScope UI] " .. tostring(err)) end
	end

	-- ---------- ScreenGui ----------
	local gui = Instance.new("ScreenGui")
	gui.Name = "StructScopeHub"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999
	local parented = false
	pcall(function()
		if gethui then gui.Parent = gethui() parented = true end
	end)
	if not parented then
		parented = pcall(function() gui.Parent = game:GetService("CoreGui") end)
	end
	if not parented or not gui.Parent then
		gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	end
	L.ScreenGui = gui

	local function screenSize()
		local s = gui.AbsoluteSize
		if s.X < 100 or s.Y < 100 then
			local cam = workspace.CurrentCamera
			if cam then s = cam.ViewportSize end
		end
		return s
	end

	local overlay = new("Frame", {
		Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50,
	}, gui)
	local toastHolder = new("Frame", {
		Name = "Toasts", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 270, 1, -24), BackgroundTransparency = 1, ZIndex = 60,
	}, gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, toastHolder)

	-- ---------- tooltip ----------
	local tip = new("TextLabel", {
		Visible = false, ZIndex = 70, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 12,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
	}, overlay)
	bind(tip, "BackgroundColor3", cField)
	bind(tip, "TextColor3", cFont)
	corner(tip, 6)
	stroke(tip, cOutline)
	padding(tip, 8, 5, 8, 5)
	new("UISizeConstraint", { MaxSize = Vector2.new(260, 400) }, tip)

	local function attachTip(obj, text)
		if not text or text == "" then return end
		conn(obj.MouseEnter:Connect(function() tip.Text = text tip.Visible = true end))
		conn(obj.MouseLeave:Connect(function() tip.Visible = false end))
		conn(obj.MouseMoved:Connect(function(x, y) tip.Position = UDim2.fromOffset(x + 14, y + 16) end))
	end

	-- ---------- notify ----------
	local toastN = 0
	function L:Notify(text, t)
		toastN += 1
		local card = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0, LayoutOrder = toastN, ZIndex = 60,
		}, toastHolder)
		bind(card, "BackgroundColor3", cCtrl)
		corner(card, 10)
		local st = stroke(card, cAccent, 1)
		padding(card, 12, 9, 12, 9)
		local lb = new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 13, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(text), ZIndex = 61,
		}, card)
		bind(lb, "TextColor3", cFont)
		task.delay(t or 3, function()
			pcall(function()
				local info = TweenInfo.new(0.25)
				TS:Create(card, info, { BackgroundTransparency = 1 }):Play()
				TS:Create(lb, info, { TextTransparency = 1 }):Play()
				TS:Create(st, info, { Transparency = 1 }):Play()
				task.wait(0.3)
				card:Destroy()
			end)
		end)
	end

	-- ---------- icons ----------
	local function iconFrame(parent, kind)
		local box = new("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1 }, parent)
		local parts = {}
		local function fill(size, pos, round, anchor)
			local f = new("Frame", {
				Size = size, Position = pos, BorderSizePixel = 0, AnchorPoint = anchor or Vector2.new(0, 0),
			}, box)
			if round then corner(f, round) end
			parts[#parts + 1] = { f, "BackgroundColor3" }
			return f
		end
		local function ring(size, pos, round, th, rot)
			local f = new("Frame", {
				Size = size, Position = pos, BackgroundTransparency = 1, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rot or 0,
			}, box)
			if round then corner(f, round) end
			local s = new("UIStroke", { Thickness = th or 2 }, f)
			parts[#parts + 1] = { s, "Color" }
			return f
		end
		local c = UDim2.fromOffset(11, 11)
		if kind == "home" then
			ring(UDim2.fromOffset(13, 13), c, 2, 2, 45)
			fill(UDim2.fromOffset(4, 4), c, 1, Vector2.new(0.5, 0.5))
		elseif kind == "eye" then
			ring(UDim2.fromOffset(20, 12), c, 6, 2)
			fill(UDim2.fromOffset(6, 6), c, 3, Vector2.new(0.5, 0.5))
		elseif kind == "bars" then
			fill(UDim2.fromOffset(18, 3), UDim2.fromOffset(2, 3), 1)
			fill(UDim2.fromOffset(12, 3), UDim2.fromOffset(2, 9), 1)
			fill(UDim2.fromOffset(16, 3), UDim2.fromOffset(2, 15), 1)
		elseif kind == "copy" then
			ring(UDim2.fromOffset(12, 12), UDim2.fromOffset(8, 8), 3, 2)
			ring(UDim2.fromOffset(12, 12), UDim2.fromOffset(14, 14), 3, 2)
		elseif kind == "cube" then
			ring(UDim2.fromOffset(17, 17), c, 4, 2)
			fill(UDim2.fromOffset(6, 6), c, 2, Vector2.new(0.5, 0.5))
		elseif kind == "palette" then
			ring(UDim2.fromOffset(19, 19), c, 10, 2)
			fill(UDim2.fromOffset(8, 8), UDim2.fromOffset(11, 8), 4, Vector2.new(0.5, 0))
		else
			ring(UDim2.fromOffset(19, 19), c, 10, 2)
			fill(UDim2.fromOffset(3, 3), UDim2.fromOffset(11, 6), 2, Vector2.new(0.5, 0))
			fill(UDim2.fromOffset(3, 7), UDim2.fromOffset(11, 10), 1, Vector2.new(0.5, 0))
		end
		local function setColor(col)
			for _, p in ipairs(parts) do p[1][p[2]] = col end
		end
		return box, setColor
	end

	local ICON_BY_TAB = {
		Utama = "home", Viewer = "eye", Log = "bars", Struct = "cube",
		Simpan = "copy", Tema = "palette", Info = "info",
	}

	-- ---------- groupbox ----------
	local function makeGroupbox(scroll, title, order)
		local gb = {}
		local card = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0, LayoutOrder = order,
		}, scroll)
		bind(card, "BackgroundColor3", cMain)
		corner(card, 12)
		stroke(card, cOutline)
		vlist(card, 8)
		padding(card, 12, 10, 12, 12)

		local head = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 0 }, card)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, head)
		local bolt = new("Frame", { Size = UDim2.fromOffset(4, 16), BorderSizePixel = 0, LayoutOrder = 1 }, head)
		bind(bolt, "BackgroundColor3", cSoft)
		corner(bolt, 2)
		txt(head, {
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamBold, TextSize = 15, Text = title, LayoutOrder = 2,
		})
		local rule = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = 1 }, card)
		bind(rule, "BackgroundColor3", cOutline)

		local cont = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = 2,
		}, card)
		vlist(cont, 8)
		gb.Container = cont
		gb.Frame = card
		local n = 0
		local function nxt() n += 1 return n end
		function gb:Resize() end

		function gb:AddLabel(text, wrap)
			local lbl = txt(cont, {
				Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(text),
				TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = nxt(),
			}, cDim)
			local obj = { Label = lbl }
			function obj:SetText(t) lbl.Text = tostring(t) end
			function obj:AddKeyPicker(id, o)
				o = o or {}
				lbl.Size = UDim2.new(1, 0, 0, 28)
				lbl.TextYAlignment = Enum.TextYAlignment.Center
				local kp = { Value = o.Default or "RightShift" }
				local b = new("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(96, 24), AutoButtonColor = false, BorderSizePixel = 0,
					Font = Enum.Font.GothamSemibold, TextSize = 12, Text = kp.Value,
				}, lbl)
				bind(b, "BackgroundColor3", cField)
				bind(b, "TextColor3", cSoft)
				corner(b, 7)
				stroke(b, cOutline)
				local waiting = false
				pcall(function() L.MenuKey = Enum.KeyCode[kp.Value] or L.MenuKey end)
				conn(b.MouseButton1Click:Connect(function()
					waiting = true
					L._rebinding = true
					b.Text = "tekan tombol..."
				end))
				conn(UIS.InputBegan:Connect(function(input)
					if not waiting then return end
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					waiting = false
					L._rebinding = false
					if input.KeyCode ~= Enum.KeyCode.Escape then
						kp.Value = input.KeyCode.Name
						L.MenuKey = input.KeyCode
					end
					b.Text = kp.Value
				end))
				function kp:SetValue(v)
					kp.Value = tostring(v)
					b.Text = kp.Value
					pcall(function() L.MenuKey = Enum.KeyCode[kp.Value] or L.MenuKey end)
				end
				L.Options[id] = kp
				return kp
			end
			return obj
		end

		function gb:AddToggle(id, o)
			o = o or {}
			local value = o.Default and true or false
			local row = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "",
				AutoButtonColor = false, LayoutOrder = nxt(),
			}, cont)
			txt(row, { Size = UDim2.new(1, -52, 1, 0), Text = o.Text or id, TextTruncate = Enum.TextTruncate.AtEnd })
			local track = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(40, 22), BorderSizePixel = 0,
			}, row)
			corner(track, 11)
			stroke(track, cOutline)
			local knob = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0,
				Position = UDim2.new(0, value and 21 or 3, 0.5, 0),
			}, track)
			corner(knob, 8)
			bind(knob, "BackgroundColor3", function() return value and Color3.new(1, 1, 1) or L.FontColor:Lerp(L.BackgroundColor, 0.4) end)
			bind(track, "BackgroundColor3", function() return value and L.AccentColor or cField() end)
			local t = { Value = value }
			local function paint()
				t.Value = value
				track.BackgroundColor3 = value and L.AccentColor or cField()
				knob.BackgroundColor3 = value and Color3.new(1, 1, 1) or L.FontColor:Lerp(L.BackgroundColor, 0.4)
				TS:Create(knob, TweenInfo.new(0.12), { Position = UDim2.new(0, value and 21 or 3, 0.5, 0) }):Play()
			end
			function t:SetValue(v, silent)
				v = v and true or false
				if v == value then return end
				value = v
				paint()
				if not silent then safe(o.Callback, value) end
			end
			conn(row.MouseButton1Click:Connect(function() t:SetValue(not value) end))
			attachTip(row, o.Tooltip)
			L.Toggles[id] = t
			L.Options[id] = t
			return t
		end

		function gb:AddButton(o, func)
			if type(o) == "string" then o = { Text = o, Func = func } end
			local hover = false
			local b = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 34), AutoButtonColor = false, BorderSizePixel = 0,
				Font = Enum.Font.GothamSemibold, TextSize = 13, Text = o.Text or "Button",
				TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = nxt(),
			}, cont)
			bind(b, "BackgroundColor3", function() return hover and lighten(L.MainColor, 0.16) or cCtrl() end)
			bind(b, "TextColor3", cFont)
			corner(b, 10)
			local st = stroke(b, function() return hover and L.AccentColor or L.OutlineColor end)
			conn(b.MouseEnter:Connect(function()
				hover = true
				b.BackgroundColor3 = lighten(L.MainColor, 0.16)
				st.Color = L.AccentColor
			end))
			conn(b.MouseLeave:Connect(function()
				hover = false
				b.BackgroundColor3 = cCtrl()
				st.Color = L.OutlineColor
			end))
			conn(b.MouseButton1Click:Connect(function()
				b.BackgroundColor3 = L.AccentColor
				task.delay(0.12, function()
					pcall(function() b.BackgroundColor3 = hover and lighten(L.MainColor, 0.16) or cCtrl() end)
				end)
				safe(o.Func or o.Callback)
			end))
			attachTip(b, o.Tooltip)
			return { Button = b }
		end

		function gb:AddInput(id, o)
			o = o or {}
			local wrap = new("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1, LayoutOrder = nxt(),
			}, cont)
			vlist(wrap, 5)
			if o.Text then
				txt(wrap, { Size = UDim2.new(1, 0, 0, 16), Text = o.Text, LayoutOrder = 1, TextSize = 12 }, cDim)
			end
			local box = new("TextBox", {
				Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, LayoutOrder = 2,
				Font = Enum.Font.Gotham, TextSize = 13, Text = o.Default or "", ClearTextOnFocus = false,
				PlaceholderText = o.Placeholder or "", TextXAlignment = Enum.TextXAlignment.Left,
			}, wrap)
			bind(box, "BackgroundColor3", cField)
			bind(box, "TextColor3", cFont)
			bind(box, "PlaceholderColor3", cDim)
			corner(box, 9)
			local st = stroke(box, cOutline)
			padding(box, 10, 0, 10, 0)
			local t = { Value = box.Text }
			conn(box.Focused:Connect(function() st.Color = L.AccentColor end))
			conn(box.FocusLost:Connect(function()
				st.Color = L.OutlineColor
				t.Value = box.Text
				if o.Finished then safe(o.Callback, box.Text) end
			end))
			conn(box:GetPropertyChangedSignal("Text"):Connect(function()
				t.Value = box.Text
				if not o.Finished then safe(o.Callback, box.Text) end
			end))
			function t:SetValue(v) box.Text = tostring(v) end
			L.Options[id] = t
			return t
		end

		function gb:AddSlider(id, o)
			o = o or {}
			local min, max = o.Min or 0, o.Max or 100
			local dec = o.Rounding or 0
			local function round(v)
				local m = 10 ^ dec
				return math.floor(v * m + 0.5) / m
			end
			local value = math.clamp(o.Default or min, min, max)
			local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = nxt() }, cont)
			txt(wrap, { Size = UDim2.new(1, -50, 0, 18), Text = o.Text or id, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd }, cDim)
			local vl = txt(wrap, {
				Size = UDim2.new(0, 46, 0, 18), Position = UDim2.new(1, -46, 0, 0), Text = tostring(value),
				TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 12,
			}, cSoft)
			local hit = new("TextButton", {
				Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			}, wrap)
			local track = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0,
			}, hit)
			bind(track, "BackgroundColor3", cField)
			corner(track, 4)
			stroke(track, cOutline)
			local fillF = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, track)
			bind(fillF, "BackgroundColor3", cAccent)
			corner(fillF, 4)
			local knob = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0,
			}, track)
			knob.BackgroundColor3 = Color3.new(1, 1, 1)
			corner(knob, 8)
			local t = { Value = value }
			local function visual()
				local a = (max > min) and (value - min) / (max - min) or 0
				fillF.Size = UDim2.new(a, 0, 1, 0)
				knob.Position = UDim2.new(a, 0, 0.5, 0)
				vl.Text = tostring(value)
			end
			visual()
			local dragging = false
			local function setFromX(x)
				local w = track.AbsoluteSize.X
				if w <= 0 then return end
				local a = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
				local v = round(min + a * (max - min))
				if v ~= value then
					value = v
					t.Value = v
					visual()
					safe(o.Callback, v)
				end
			end
			conn(hit.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					setFromX(input.Position.X)
				end
			end))
			conn(UIS.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					setFromX(input.Position.X)
				end
			end))
			conn(UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end))
			function t:SetValue(v)
				value = math.clamp(round(v), min, max)
				t.Value = value
				visual()
				safe(o.Callback, value)
			end
			L.Options[id] = t
			return t
		end

		function gb:AddDropdown(id, o)
			o = o or {}
			local values = o.Values or {}
			local multi = o.Multi and true or false
			local value
			if multi then
				value = {}
			else
				if type(o.Default) == "number" then value = values[o.Default]
				elseif type(o.Default) == "string" then value = o.Default end
				if value == nil and not o.AllowNull then value = values[1] end
			end
			local wrap = new("Frame", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1, LayoutOrder = nxt(),
			}, cont)
			vlist(wrap, 5)
			if o.Text then
				txt(wrap, { Size = UDim2.new(1, 0, 0, 16), Text = o.Text, LayoutOrder = 1, TextSize = 12 }, cDim)
			end
			local btn = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 32), AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = 2,
				Font = Enum.Font.GothamMedium, TextSize = 13, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
			}, wrap)
			bind(btn, "BackgroundColor3", cField)
			bind(btn, "TextColor3", cFont)
			corner(btn, 9)
			local st = stroke(btn, cOutline)
			local face = txt(btn, {
				Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -36, 1, 0), Text = "-",
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local chev = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(12, 8), BackgroundTransparency = 1,
			}, btn)
			for _, rot in ipairs({ 40, -40 }) do
				local bar = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 2), BorderSizePixel = 0,
					Position = UDim2.new(rot > 0 and 0.28 or 0.72, 0, 0.5, 0), Rotation = rot,
				}, chev)
				bind(bar, "BackgroundColor3", cSoft)
				corner(bar, 1)
			end

			local t = { Value = value, Values = values }
			local function labelText()
				if multi then
					local names = {}
					for _, v in ipairs(values) do if value[v] then names[#names + 1] = v end end
					if #names == 0 then return "-" end
					if #names <= 2 then return table.concat(names, ", ") end
					return #names .. " dipilih"
				end
				return value ~= nil and tostring(value) or "-"
			end
			local function refresh() face.Text = labelText() t.Value = value end
			refresh()

			local popup
			local function close()
				if popup then
					pcall(function() popup:Destroy() end)
					popup = nil
				end
				st.Color = L.OutlineColor
			end
			local function open()
				close()
				st.Color = L.AccentColor
				popup = new("TextButton", {
					Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 51,
				}, overlay)
				conn(popup.MouseButton1Click:Connect(close))
				local count = math.max(#values, 1)
				local h = math.min(count * 30 + 10, 190)
				local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
				local y = pos.Y + size.Y + 4
				if y + h > gui.AbsoluteSize.Y - 8 then y = math.max(8, pos.Y - h - 4) end
				local list = new("ScrollingFrame", {
					Position = UDim2.fromOffset(pos.X, y), Size = UDim2.fromOffset(size.X, h),
					BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 52,
				}, popup)
				bind(list, "BackgroundColor3", function() return lighten(L.MainColor, 0.05) end)
				bind(list, "ScrollBarImageColor3", cAccent)
				corner(list, 10)
				stroke(list, cAccent)
				padding(list, 5, 5, 5, 5)
				vlist(list, 2)
				if #values == 0 then
					txt(list, { Size = UDim2.new(1, 0, 0, 26), Text = "(kosong)", ZIndex = 53 }, cDim)
				end
				for i, v in ipairs(values) do
					local on = multi and value[v] or (not multi and value == v)
					local it = new("TextButton", {
						Size = UDim2.new(1, -6, 0, 28), AutoButtonColor = false, BorderSizePixel = 0,
						Font = Enum.Font.GothamMedium, TextSize = 13, Text = "", LayoutOrder = i, ZIndex = 53,
					}, list)
					bind(it, "BackgroundColor3", function() return on and L.AccentColor or lighten(L.MainColor, 0.05) end)
					it.BackgroundTransparency = on and 0.15 or 1
					corner(it, 7)
					if multi then
						local cb = new("Frame", {
							AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
							Size = UDim2.fromOffset(14, 14), ZIndex = 54, BorderSizePixel = 0,
							BackgroundTransparency = on and 0 or 1,
						}, it)
						bind(cb, "BackgroundColor3", cSoft)
						corner(cb, 4)
						stroke(cb, cSoft, 1.5)
					end
					txt(it, {
						Position = UDim2.fromOffset(multi and 30 or 10, 0), Size = UDim2.new(1, multi and -36 or -16, 1, 0),
						Text = tostring(v), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 54,
					})
					conn(it.MouseEnter:Connect(function() if not on then it.BackgroundTransparency = 0.6 it.BackgroundColor3 = L.AccentColor end end))
					conn(it.MouseLeave:Connect(function() if not on then it.BackgroundTransparency = 1 end end))
					conn(it.MouseButton1Click:Connect(function()
						if multi then
							local cp = list.CanvasPosition
							value[v] = (not value[v]) or nil
							refresh()
							safe(o.Callback, value)
							open()
							task.defer(function()
								local nl = popup and popup:FindFirstChildOfClass("ScrollingFrame")
								if nl then nl.CanvasPosition = cp end
							end)
						else
							value = v
							refresh()
							close()
							safe(o.Callback, value)
						end
					end))
				end
			end
			conn(btn.MouseButton1Click:Connect(function()
				if popup then close() else open() end
			end))
			attachTip(btn, o.Tooltip)

			function t:SetValues(list)
				values = list or {}
				t.Values = values
				if multi then
					for k in pairs(value) do
						if not table.find(values, k) then value[k] = nil end
					end
				else
					if value ~= nil and not table.find(values, value) then
						value = (not o.AllowNull) and values[1] or nil
					elseif value == nil and not o.AllowNull then
						value = values[1]
					end
				end
				refresh()
				if popup then close() end
			end
			function t:SetValue(v)
				if multi then
					value = {}
					if type(v) == "table" then
						for k, on in pairs(v) do if on then value[k] = true end end
					end
				else
					value = v
				end
				refresh()
				safe(o.Callback, value)
			end
			L.Options[id] = t
			return t
		end

		return gb
	end

	-- ---------- window (responsive + bisa di-resize) ----------
	function L:CreateWindow(cfg)
		cfg = cfg or {}
		local W = { Tabs = {}, Active = nil, Compact = false }
		local MIN_W, MIN_H, BOT_H = 300, 230, 16
		local TITLE_H, SIDE_W = 54, 158
		local minimized, maxed, pre = false, false, nil
		local want = cfg.Size or UDim2.fromOffset(780, 470)
		local ss = screenSize()
		local cw = math.clamp(math.min(want.X.Offset, ss.X * 0.96), MIN_W, math.max(MIN_W, ss.X - 12))
		local ch = math.clamp(math.min(want.Y.Offset, ss.Y * 0.86), MIN_H, math.max(MIN_H, ss.Y - 12))
		if cfg.ToggleKey then
			pcall(function() L.MenuKey = Enum.KeyCode[cfg.ToggleKey] or L.MenuKey end)
		end

		local holder = new("Frame", {
			Name = "Holder", Position = UDim2.fromOffset(math.floor((ss.X - cw) / 2), math.floor((ss.Y - ch) / 2)),
			Size = UDim2.fromOffset(cw, ch), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2,
		}, gui)
		bind(holder, "BackgroundColor3", cBg)
		corner(holder, 16)
		stroke(holder, function() return L.OutlineColor:Lerp(L.AccentColor, 0.55) end, 1.5)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 200, 214)),
		}, holder)
		W.Holder = holder

		-- title bar
		local bar = new("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE_H), BorderSizePixel = 0 }, holder)
		bind(bar, "BackgroundColor3", cMain)
		local barRule = new("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
		}, bar)
		bind(barRule, "BackgroundColor3", cOutline)

		local leftF = new("Frame", { Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1 }, bar)
		padding(leftF, 14, 0, 0, 0)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
		}, leftF)
		local logo = new("Frame", { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, leftF)
		local d1 = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(19, 19),
			BackgroundTransparency = 1, Rotation = 45,
		}, logo)
		corner(d1, 4)
		bind(new("UIStroke", { Thickness = 2.5 }, d1), "Color", cSoft)
		local d2 = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
			BorderSizePixel = 0, Rotation = 45,
		}, logo)
		bind(d2, "BackgroundColor3", cSoft)
		corner(d2, 2)
		local titleLbl = txt(leftF, {
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = cfg.Title or "Script Hub",
			Font = Enum.Font.GothamBold, TextSize = 20, LayoutOrder = 2,
		})
		local sep = new("Frame", { Size = UDim2.fromOffset(1, 26), BorderSizePixel = 0, LayoutOrder = 3 }, leftF)
		bind(sep, "BackgroundColor3", cOutline)
		local subLbl = txt(leftF, {
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			Text = cfg.Subtitle or "", TextSize = 13, LayoutOrder = 4, TextTruncate = Enum.TextTruncate.AtEnd,
		}, cDim)

		-- drag title bar
		local dragging, dragStart, startPos = false, nil, nil
		conn(bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, dragStart, startPos = true, input.Position, holder.Position
			end
		end))
		conn(UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = input.Position - dragStart
				local s = screenSize()
				local x = math.clamp(startPos.X.Offset + d.X, -(cw - 90), math.max(0, s.X - 90))
				local y = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, s.Y - TITLE_H))
				holder.Position = UDim2.fromOffset(x, y)
			end
		end))
		conn(UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))

		-- window buttons
		local ctrls = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(124, 34), BackgroundTransparency = 1,
		}, bar)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, ctrls)
		local function winBtn(label, order, draw, cb)
			local b = new("TextButton", {
				Name = label, Size = UDim2.fromOffset(34, 34), AutoButtonColor = false, Text = "",
				BorderSizePixel = 0, LayoutOrder = order,
			}, ctrls)
			bind(b, "BackgroundColor3", cCtrl)
			corner(b, 10)
			stroke(b, function() return L.OutlineColor:Lerp(L.AccentColor, 0.35) end)
			draw(b)
			conn(b.MouseEnter:Connect(function() b.BackgroundColor3 = lighten(L.MainColor, 0.18) end))
			conn(b.MouseLeave:Connect(function() b.BackgroundColor3 = cCtrl() end))
			conn(b.MouseButton1Click:Connect(cb))
			return b
		end
		local function barShape(parent, w, h, rot)
			local f = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(w, h), BorderSizePixel = 0, Rotation = rot or 0,
			}, parent)
			bind(f, "BackgroundColor3", cFont)
			corner(f, 1)
			return f
		end

		local body = new("Frame", {
			Name = "Body", Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 1, -TITLE_H - BOT_H),
			BackgroundTransparency = 1,
		}, holder)

		-- sidebar
		local side = new("Frame", { Name = "Sidebar", Size = UDim2.new(0, SIDE_W, 1, 0), BorderSizePixel = 0 }, body)
		bind(side, "BackgroundColor3", cSide)
		local sideRule = new("Frame", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0,
		}, side)
		bind(sideRule, "BackgroundColor3", cOutline)
		local tabList = new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 1, -70), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		}, side)
		local tabPad = padding(tabList, 10, 12, 10, 8)
		vlist(tabList, 4)

		local status = new("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 48),
			BorderSizePixel = 0,
		}, side)
		bind(status, "BackgroundColor3", cMain)
		corner(status, 11)
		stroke(status, cOutline)
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0,
		}, status)
		corner(dot, 5)
		local stText = txt(status, {
			Position = UDim2.fromOffset(32, 7), Size = UDim2.new(1, -38, 0, 18), Text = "Siap",
			Font = Enum.Font.GothamBold, TextSize = 13,
		}, cSoft)
		txt(status, {
			Position = UDim2.fromOffset(32, 25), Size = UDim2.new(1, -38, 0, 16), Text = "v" .. tostring(cfg.Version or "1.0"), TextSize = 11,
		}, cDim)
		local statusOn = false
		bind(dot, "BackgroundColor3", function() return statusOn and Color3.fromRGB(80, 220, 140) or L.AccentColor end)
		function L:SetStatus(text, on)
			statusOn = on and true or false
			stText.Text = tostring(text)
			dot.BackgroundColor3 = statusOn and Color3.fromRGB(80, 220, 140) or L.AccentColor
		end

		local content = new("Frame", {
			Name = "Content", Position = UDim2.fromOffset(SIDE_W, 0), Size = UDim2.new(1, -SIDE_W, 1, 0),
			BackgroundTransparency = 1,
		}, body)

		-- grip resize (bar paling bawah)
		local grip = new("TextButton", {
			Name = "Grip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, BOT_H), BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 10,
		}, holder)
		bind(grip, "BackgroundColor3", cMain)
		local gRule = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 11 }, grip)
		bind(gRule, "BackgroundColor3", cOutline)
		local gPill = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(46, 4),
			BorderSizePixel = 0, ZIndex = 11,
		}, grip)
		bind(gPill, "BackgroundColor3", cSoft)
		corner(gPill, 2)
		local gCorner = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.55, 0), Size = UDim2.fromOffset(10, 4),
			BorderSizePixel = 0, ZIndex = 11, Rotation = -35,
		}, grip)
		bind(gCorner, "BackgroundColor3", cSoft)
		corner(gCorner, 2)
		attachTip(grip, "Tarik untuk mengubah ukuran menu")

		-- ---------- layout responsive ----------
		function W:Layout()
			local compact = cw < 620
			TITLE_H = compact and 42 or 54
			SIDE_W = compact and 54 or 158
			bar.Size = UDim2.new(1, 0, 0, TITLE_H)
			body.Position = UDim2.fromOffset(0, TITLE_H)
			body.Size = UDim2.new(1, 0, 1, -TITLE_H - BOT_H)
			side.Size = UDim2.new(0, SIDE_W, 1, 0)
			content.Position = UDim2.fromOffset(SIDE_W, 0)
			content.Size = UDim2.new(1, -SIDE_W, 1, 0)
			tabList.Size = UDim2.new(1, 0, 1, compact and 0 or -70)
			tabPad.PaddingLeft = UDim.new(0, compact and 6 or 10)
			tabPad.PaddingRight = UDim.new(0, compact and 6 or 10)
			status.Visible = not compact
			subLbl.Visible = not compact
			titleLbl.TextSize = compact and 17 or 20
			leftF.Size = UDim2.new(1, compact and -128 or -150, 1, 0)
			if compact ~= W._lc then
				W._lc = compact
				W.Compact = compact
				for _, t in ipairs(W.Tabs) do t:_layout(compact) end
			end
			local bw, bh = cw - SIDE_W, ch - TITLE_H - BOT_H
			for _, f in ipairs(L._resize) do safe(f, bw, bh, compact) end
		end

		function W:SetSize(w, h)
			local s = screenSize()
			local px, py = math.max(holder.Position.X.Offset, 0), math.max(holder.Position.Y.Offset, 0)
			cw = math.clamp(w, MIN_W, math.max(MIN_W, s.X - px - 2))
			ch = math.clamp(h, MIN_H, math.max(MIN_H, s.Y - py - 2))
			holder.Size = minimized and UDim2.fromOffset(cw, TITLE_H) or UDim2.fromOffset(cw, ch)
			W:Layout()
		end

		local rs, rsStart, rsSize = false, nil, nil
		conn(grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				rs, rsStart, rsSize = true, input.Position, Vector2.new(cw, ch)
			end
		end))
		conn(UIS.InputChanged:Connect(function(input)
			if rs and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = input.Position - rsStart
				if not maxed then W:SetSize(rsSize.X + d.X, rsSize.Y + d.Y) end
			end
		end))
		conn(UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				rs = false
			end
		end))
		conn(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local s = screenSize()
			if maxed then
				cw, ch = s.X - 12, s.Y - 12
				holder.Position = UDim2.fromOffset(6, 6)
			else
				local x = math.clamp(holder.Position.X.Offset, -(cw - 90), math.max(0, s.X - 90))
				local y = math.clamp(holder.Position.Y.Offset, 0, math.max(0, s.Y - TITLE_H))
				holder.Position = UDim2.fromOffset(x, y)
			end
			W:SetSize(cw, ch)
		end))

		function W:SetMinimized(v)
			minimized = v and true or false
			body.Visible = not minimized
			grip.Visible = not minimized
			holder.Size = minimized and UDim2.fromOffset(cw, TITLE_H) or UDim2.fromOffset(cw, ch)
			if W.OnMinimized then safe(W.OnMinimized, minimized) end
		end
		function W:SetMaximized(v)
			v = v and true or false
			if v == maxed then return end
			maxed = v
			local s = screenSize()
			if v then
				pre = { cw, ch, holder.Position }
				holder.Position = UDim2.fromOffset(6, 6)
				cw, ch = s.X - 12, s.Y - 12
			else
				if pre then cw, ch, holder.Position = pre[1], pre[2], pre[3] end
			end
			holder.Size = minimized and UDim2.fromOffset(cw, TITLE_H) or UDim2.fromOffset(cw, ch)
			W:Layout()
		end

		winBtn("Minimize", 1, function(b) barShape(b, 12, 2.5) end, function() W:SetMinimized(not minimized) end)
		winBtn("Maximize", 2, function(b)
			local f = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
			}, b)
			corner(f, 2)
			bind(new("UIStroke", { Thickness = 2.2 }, f), "Color", cFont)
		end, function()
			if minimized then W:SetMinimized(false) end
			W:SetMaximized(not maxed)
		end)
		W.CloseButton = winBtn("Close", 3, function(b)
			barShape(b, 15, 2.5, 45)
			barShape(b, 15, 2.5, -45)
		end, function()
			if W.OnClose then safe(W.OnClose) else L:Unload() end
		end)

		-- ---------- tabs ----------
		function W:AddTab(name, topts)
			local tab = { Name = name }
			local split = (topts and topts.Split) or 0.5
			local order = #W.Tabs + 1

			local tb = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 40), AutoButtonColor = false, BorderSizePixel = 0, Text = "",
				LayoutOrder = order, BackgroundTransparency = 1,
			}, tabList)
			bind(tb, "BackgroundColor3", cAccent)
			corner(tb, 12)
			local grad = new("UIGradient", { Enabled = false, Rotation = 0 }, tb)
			bind(grad, "Color", function() return ColorSequence.new(L.AccentColor, lighten(L.AccentColor, 0.22)) end)
			local tbStroke = new("UIStroke", { Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tb)
			bind(tbStroke, "Color", cSoft)
			local ic, setIcon = iconFrame(tb, ICON_BY_TAB[name] or "info")
			ic.Position = UDim2.fromOffset(12, 9)
			local tl = txt(tb, {
				Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -50, 1, 0), Text = name,
				Font = Enum.Font.GothamSemibold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			}, cSoft)

			local container = new("Frame", {
				Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
			}, content)
			tab.Container = container

			local function column()
				local sc = new("ScrollingFrame", {
					Size = UDim2.new(0.5, -17, 1, -24), BackgroundTransparency = 1, BorderSizePixel = 0,
					ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
				}, container)
				bind(sc, "ScrollBarImageColor3", cAccent)
				padding(sc, 0, 0, 8, 0)
				vlist(sc, 12)
				return sc
			end
			local colL, colR = column(), column()
			local gbs, nL, nR = {}, 0, 0

			function tab:_layout(compact)
				tb.Size = UDim2.new(1, 0, 0, compact and 38 or 40)
				ic.Position = UDim2.fromOffset(compact and 10 or 12, compact and 8 or 9)
				tl.Visible = not compact
				if compact then
					colR.Visible = false
					colL.Position = UDim2.new(0, 6, 0, 8)
					colL.Size = UDim2.new(1, -8, 1, -16)
					for _, g in ipairs(gbs) do
						g[1].Parent = colL
						g[1].LayoutOrder = (g[2] == "L") and g[3] or (1000 + g[3])
					end
				else
					colR.Visible = true
					colL.Position = UDim2.new(0, 12, 0, 12)
					colL.Size = UDim2.new(split, -17, 1, -24)
					colR.Position = UDim2.new(split, 5, 0, 12)
					colR.Size = UDim2.new(1 - split, -17, 1, -24)
					for _, g in ipairs(gbs) do
						g[1].Parent = (g[2] == "L") and colL or colR
						g[1].LayoutOrder = g[3]
					end
				end
			end
			function tab:AddLeftGroupbox(title)
				nL += 1
				local g = makeGroupbox(colL, title, nL)
				gbs[#gbs + 1] = { g.Frame, "L", nL }
				tab:_layout(W.Compact)
				return g
			end
			function tab:AddRightGroupbox(title)
				nR += 1
				local g = makeGroupbox(colR, title, nR)
				gbs[#gbs + 1] = { g.Frame, "R", nR }
				tab:_layout(W.Compact)
				return g
			end

			function tab:SetActive(on)
				container.Visible = on
				tb.BackgroundTransparency = on and 0 or 1
				grad.Enabled = on
				tbStroke.Transparency = on and 0.35 or 1
				local col = on and Color3.new(1, 1, 1) or lighten(L.AccentColor, 0.38)
				tl.TextColor3 = col
				setIcon(col)
				tab._active = on
			end
			function tab:ShowTab()
				for _, t in ipairs(W.Tabs) do t:SetActive(t == tab) end
				W.Active = tab
			end
			L._reg[#L._reg + 1] = { tl, "TextColor3", function()
				return tab._active and Color3.new(1, 1, 1) or lighten(L.AccentColor, 0.38)
			end }
			L._reg[#L._reg + 1] = { ic, "Name", function()
				setIcon(tab._active and Color3.new(1, 1, 1) or lighten(L.AccentColor, 0.38))
				return ic.Name
			end }

			conn(tb.MouseButton1Click:Connect(function() tab:ShowTab() end))
			conn(tb.MouseEnter:Connect(function() if not tab._active then tb.BackgroundTransparency = 0.85 end end))
			conn(tb.MouseLeave:Connect(function() if not tab._active then tb.BackgroundTransparency = 1 end end))

			W.Tabs[#W.Tabs + 1] = tab
			tab:SetActive(false)
			tab:_layout(W.Compact)
			if #W.Tabs == 1 then tab:ShowTab() end
			return tab
		end

		function W:Toggle(v)
			if v == nil then v = not L.Toggled end
			L.Toggled = v
			holder.Visible = v
			if not v then tip.Visible = false end
		end
		L._window = W
		conn(UIS.InputBegan:Connect(function(input, gp)
			if gp or L._rebinding then return end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == L.MenuKey then
				W:Toggle()
			end
		end))

		-- tombol cepat buka/tutup menu (berguna di mobile)
		local fab = new("TextButton", {
			Name = "Fab", Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(10, 96), AutoButtonColor = false,
			Text = "SS", Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0, BackgroundTransparency = 0.12, ZIndex = 40,
		}, gui)
		bind(fab, "BackgroundColor3", cAccent)
		fab.TextColor3 = Color3.new(1, 1, 1)
		corner(fab, 18)
		stroke(fab, cOutline)
		conn(fab.MouseButton1Click:Connect(function() W:Toggle() end))
		L.Fab = fab

		holder.Visible = cfg.AutoShow ~= false
		L.Toggled = holder.Visible
		W:Layout()
		return W
	end

	function L:Toggle(v)
		if L._window then L._window:Toggle(v) end
	end
	function L:OnResize(fn) L._resize[#L._resize + 1] = fn end
	function L:OnUnload(fn) L._unload[#L._unload + 1] = fn end
	function L:Unload()
		if L.Unloaded then return end
		L.Unloaded = true
		for _, f in ipairs(L._unload) do pcall(f) end
		for _, c in ipairs(L._conns) do pcall(function() c:Disconnect() end) end
		pcall(function() L.ScreenGui:Destroy() end)
	end
	function L:SetStatus() end -- diganti saat window dibuat

	return L
end

local Library = buildHubUI()

if type(Library) ~= "table" then
	warn("[StructScope] UI gagal dibuat")
	return
end

------------------------------------------------------------------
-- UTIL
------------------------------------------------------------------
local conns, running = {}, true
local function track(c) conns[#conns + 1] = c return c end

local function notify(text, t)
	pcall(function() Library:Notify(text, t or 3) end)
end

local function clip(text)
	local fn = setclipboard or toclipboard
	if fn then return (pcall(fn, text)) end
	return false
end

local function ascii(s) return (tostring(s):gsub("[\128-\255]", "?")) end

local function pad(s, n)
	s = tostring(s)
	if #s >= n then return s end
	return s .. string.rep(" ", n - #s)
end

local function fnum(n)
	if n ~= n then return "nan" end
	if n == math.huge then return "inf" end
	if n == -math.huge then return "-inf" end
	if n % 1 == 0 and math.abs(n) < 1e15 then return string.format("%d", n) end
	return string.format("%.7g", n)
end

local RESERVED = {}
for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while continue export type"):gmatch("%S+") do
	RESERVED[w] = true
end
local IDENT = "^[%a_][%w_]*$"

local function isArray(v)
	local n = #v
	if n == 0 then return false end
	for k in pairs(v) do
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then return false end
	end
	return true
end

local function sortedKeys(t)
	local keys = {}
	for k in next, t do keys[#keys + 1] = k end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta == tb and (ta == "number" or ta == "string") then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function identOf(s)
	s = (tostring(s):gsub("[^%w_]", "_"))
	if s == "" then s = "_" end
	if s:match("^%d") or RESERVED[s] then s = "_" .. s end
	return s
end

local function lit(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "nil" then return "nil"
	elseif t == "boolean" then return tostring(v)
	elseif t == "number" then return fnum(v)
	elseif t == "string" then
		local s = v
		if #s > 80 then s = s:sub(1, 77) .. "..." end
		return string.format("%q", s)
	elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(fnum(v.X), fnum(v.Y), fnum(v.Z))
	elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(fnum(v.X), fnum(v.Y))
	elseif t == "CFrame" then
		local p = v.Position
		return ("CFrame.new(%s, %s, %s)"):format(fnum(p.X), fnum(p.Y), fnum(p.Z))
	elseif t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(fnum(v.R), fnum(v.G), fnum(v.B))
	elseif t == "EnumItem" then return tostring(v)
	elseif t == "Instance" then
		local ok, name = pcall(function() return v:GetFullName() end)
		return string.format("%q", "@" .. (ok and name or "?"))
	elseif t == "buffer" then return "buffer(len=" .. buffer.len(v) .. ")"
	elseif t == "table" then
		if depth >= 4 then return "{...}" end
		local parts = {}
		if isArray(v) then
			for i = 1, math.min(#v, 8) do parts[#parts + 1] = lit(v[i], depth + 1) end
			if #v > 8 then parts[#parts + 1] = "...(+" .. (#v - 8) .. ")" end
		else
			local n = 0
			for _, k in ipairs(sortedKeys(v)) do
				n += 1
				if n > 12 then parts[#parts + 1] = "..." break end
				local ks = (type(k) == "string" and k:match(IDENT)) and k or ("[" .. lit(k, depth + 1) .. "]")
				parts[#parts + 1] = ks .. " = " .. lit(v[k], depth + 1)
			end
		end
		if #parts == 0 then return "{}" end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return "<" .. t .. ">"
end

local function luaSrc(v, indent, depth, seen)
	local t = typeof(v)
	if t == "table" then
		if seen[v] then return "nil --[[siklik]]" end
		if depth >= 10 then return "nil --[[terlalu dalam]]" end
		seen[v] = true
		local p1, parts = string.rep("\t", indent + 1), {}
		if isArray(v) then
			for i = 1, #v do parts[#parts + 1] = p1 .. luaSrc(v[i], indent + 1, depth + 1, seen) end
		else
			for _, k in ipairs(sortedKeys(v)) do
				local ks = (type(k) == "string" and k:match(IDENT) and not RESERVED[k]) and k
					or ("[" .. luaSrc(k, indent + 1, depth + 1, seen) .. "]")
				parts[#parts + 1] = p1 .. ks .. " = " .. luaSrc(v[k], indent + 1, depth + 1, seen)
			end
		end
		seen[v] = nil
		if #parts == 0 then return "{}" end
		return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. string.rep("\t", indent) .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "buffer" then
		local ok, s = pcall(buffer.tostring, v)
		if not ok then return "nil" end
		if #s > 128 then s = s:sub(1, 128) end
		local hex = s:gsub(".", function(c) return ("\\x%02X"):format(c:byte()) end)
		return 'buffer.fromstring("' .. hex .. '")'
	end
	return lit(v)
end

local function deepCopy(v, depth, seen)
	depth = depth or 0
	if typeof(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] or depth >= 8 then return nil end
	seen[v] = true
	local out, n = {}, 0
	for k, val in next, v do
		n += 1
		if n > 300 then break end
		out[type(k) == "table" and tostring(k) or k] = deepCopy(val, depth + 1, seen)
	end
	seen[v] = nil
	return out
end

local function tree(v, name, ind, out, depth)
	local p = string.rep("  ", ind)
	local t = typeof(v)
	if t == "table" then
		local arr = isArray(v)
		local cnt = 0
		for _ in next, v do cnt += 1 end
		out[#out + 1] = ("%s%s: %s (%d)"):format(p, name, arr and "array" or "object", cnt)
		if depth >= 8 then out[#out + 1] = p .. "  ..." return end
		local keys = sortedKeys(v)
		for i, k in ipairs(keys) do
			if i > 40 then out[#out + 1] = ("%s  ... +%d lainnya"):format(p, #keys - 40) break end
			tree(v[k], arr and ("[" .. tostring(k) .. "]") or tostring(k), ind + 1, out, depth + 1)
		end
	elseif t == "buffer" then
		out[#out + 1] = ("%s%s: buffer (len=%d)"):format(p, name, buffer.len(v))
	else
		out[#out + 1] = ("%s%s: %s = %s"):format(p, name, t, lit(v))
	end
end

local function safeName(s)
	return (ascii(s ~= "" and s or "view"):gsub("[^%w_%-]", "_"))
end

local function mdEscape(s) return (tostring(s):gsub("|", "\\|"):gsub("\n", " ")) end

local function clipLine(s, n)
	if #s > n then return s:sub(1, n - 3) .. "..." end
	return s
end

------------------------------------------------------------------
-- LEARN: skema dari data nyata
------------------------------------------------------------------
local function newNode() return { n = 0, types = {} } end

local function addVal(node, key, v)
	node.vals = node.vals or {}
	node.valSet = node.valSet or {}
	if node.valSet[key] then return end
	if #node.vals >= 8 then node.valOver = true return end
	node.valSet[key] = true
	node.vals[#node.vals + 1] = v
end

local function learn(node, v, depth)
	depth = depth or 0
	node = node or newNode()
	node.n += 1
	local t = typeof(v)
	if t == "table" then
		if depth >= 8 then node.types.object = true return node end
		if next(v) == nil then
			node.types.array = true
			node.len = node.len or { min = 0, max = 0 }
			node.len.min = 0
		elseif isArray(v) then
			node.types.array = true
			local n = #v
			node.len = node.len or { min = n, max = n }
			node.len.min = math.min(node.len.min, n)
			node.len.max = math.max(node.len.max, n)
			for i = 1, math.min(n, 30) do node.item = learn(node.item, v[i], depth + 1) end
		else
			node.types.object = true
			node.objN = (node.objN or 0) + 1
			node.fields = node.fields or {}
			for k, val in next, v do
				local key = tostring(k)
				node.fields[key] = learn(node.fields[key], val, depth + 1)
			end
		end
	elseif t == "number" then
		node.types.number = true
		if v == v then
			local s = node.num
			if not s then s = { min = v, max = v, int = true, f32 = true } node.num = s end
			if v < s.min then s.min = v end
			if v > s.max then s.max = v end
			if v % 1 ~= 0 or v == math.huge or v == -math.huge then s.int = false end
			if s.f32 then
				local ok, back = pcall(function() return string.unpack("<f", string.pack("<f", v)) end)
				if not ok or back ~= v then s.f32 = false end
			end
			addVal(node, v, v)
		end
	elseif t == "string" then
		node.types.string = true
		local s = node.str or { min = #v, max = #v }
		node.str = s
		s.min, s.max = math.min(s.min, #v), math.max(s.max, #v)
		if #v <= 40 then addVal(node, v, v) end
	elseif t == "boolean" then
		node.types.boolean = true
		addVal(node, v, v)
	elseif t == "buffer" then
		node.types.buffer = true
		local l = buffer.len(v)
		local s = node.blen or { min = l, max = l }
		node.blen = s
		s.min, s.max = math.min(s.min, l), math.max(s.max, l)
	else
		node.types[t] = true
	end
	return node
end

local function typeLabel(node)
	local ks = {}
	for k in pairs(node.types) do
		if k == "number" and node.num then ks[#ks + 1] = node.num.int and "int" or "float"
		else ks[#ks + 1] = k end
	end
	table.sort(ks)
	return #ks > 0 and table.concat(ks, "|") or "any"
end

local function detail(node)
	local parts, t = {}, node.types
	if t.number and node.num then
		local s = node.num
		local d = ("%s..%s"):format(fnum(s.min), fnum(s.max))
		if not s.int then d = d .. (s.f32 and " (muat f32)" or " (butuh f64)") end
		parts[#parts + 1] = d
	end
	if t.string and node.str then parts[#parts + 1] = ("len %d..%d"):format(node.str.min, node.str.max) end
	if t.array and node.len then parts[#parts + 1] = ("panjang %d..%d"):format(node.len.min, node.len.max) end
	if t.buffer and node.blen then parts[#parts + 1] = ("byte %d..%d"):format(node.blen.min, node.blen.max) end
	if node.vals and #node.vals > 0 then
		local vs = {}
		for i = 1, math.min(#node.vals, 6) do vs[i] = lit(node.vals[i]) end
		local label = node.valOver and "contoh: " or ((node.n >= 5) and "nilai (enum?): " or "nilai: ")
		parts[#parts + 1] = label .. table.concat(vs, ", ") .. (node.valOver and ", ..." or "")
	end
	return table.concat(parts, " | ")
end

local function flatten(node, path, rows, optional)
	rows[#rows + 1] = { path = path == "" and "(root)" or path, node = node, opt = optional }
	if node.fields then
		for _, k in ipairs(sortedKeys(node.fields)) do
			local f = node.fields[k]
			flatten(f, path == "" and k or (path .. "." .. k), rows, f.n < (node.objN or f.n))
		end
	end
	if node.item then flatten(node.item, path .. "[]", rows, false) end
end

local function numExpr(node)
	local s = node.num
	if not s then return "ByteNet.float64" end
	if s.int then
		if s.min >= 0 then
			if s.max <= 255 then return "ByteNet.uint8"
			elseif s.max <= 65535 then return "ByteNet.uint16"
			elseif s.max <= 4294967295 then return "ByteNet.uint32" end
		else
			if s.min >= -128 and s.max <= 127 then return "ByteNet.int8"
			elseif s.min >= -32768 and s.max <= 32767 then return "ByteNet.int16"
			elseif s.min >= -2147483648 and s.max <= 2147483647 then return "ByteNet.int32" end
		end
		return "ByteNet.float64"
	end
	return s.f32 and "ByteNet.float32" or "ByteNet.float64"
end

local function nodeExpr(node, ind)
	local p = string.rep("\t", ind)
	local kinds = {}
	for k in pairs(node.types) do kinds[#kinds + 1] = k end
	table.sort(kinds)
	if #kinds == 0 then return "ByteNet.unknown" end
	if #kinds > 1 then return "ByteNet.unknown --[[campuran: " .. table.concat(kinds, "|") .. "]]" end
	local k = kinds[1]
	if k == "number" then return numExpr(node)
	elseif k == "boolean" then return "ByteNet.bool"
	elseif k == "string" then return "ByteNet.string"
	elseif k == "Vector3" then return "ByteNet.vec3"
	elseif k == "Vector2" then return "ByteNet.vec2"
	elseif k == "CFrame" then return "ByteNet.cframe"
	elseif k == "Instance" then return "ByteNet.inst"
	elseif k == "buffer" then return "ByteNet.buff"
	elseif k == "array" then
		return "ByteNet.array(" .. (node.item and nodeExpr(node.item, ind) or "ByteNet.unknown") .. ")"
	elseif k == "object" then
		local lines = {}
		for _, key in ipairs(sortedKeys(node.fields or {})) do
			local f = node.fields[key]
			local e = nodeExpr(f, ind + 1)
			if f.n < (node.objN or f.n) then e = "ByteNet.optional(" .. e .. ")" end
			local ks = (key:match(IDENT) and not RESERVED[key]) and key or ("[" .. string.format("%q", key) .. "]")
			lines[#lines + 1] = p .. "\t" .. ks .. " = " .. e .. ","
		end
		if #lines == 0 then return "ByteNet.struct({})" end
		return "ByteNet.struct({\n" .. table.concat(lines, "\n") .. "\n" .. p .. "})"
	end
	return "ByteNet.unknown --[[" .. k .. "]]"
end

------------------------------------------------------------------
-- STATE & REGISTRY
------------------------------------------------------------------
local state = {
	active = false, dirty = true, logDirty = true, listDirty = true, view = "full",
	selected = nil, selectedSub = nil, filter = "", auto = true, logLines = 120,
	logDetail = false, autoScan = false, autoSave = false, t0 = nil, lastScan = 0, lastSave = 0,
}
local function markDirty() state.dirty = true state.logDirty = true end

local muted = {}
local entries, byObj, byId, byName = {}, {}, {}, {}
local Store = { feed = {}, log = {}, chat = {} }
local Raw = { reliable = { n = 0, bytes = 0 }, unreliable = { n = 0, bytes = 0 } }
local Subs = {}
local chatConn
local remoteConns = {}
local remoteList = {}
local remotesFound = 0

local logCfg = {
	dir = "Semua", cat = "Semua", chan = "Semua", pkt = "Semua", sub = "Semua", name = "", text = "",
	seq = 0, dropped = 0, moveT = 0, moveN = 0,
	chatKeys = { "chat", "msg", "message", "say", "talk", "whisper", "emote", "shout", "speak" },
	moveKeys = { "move", "walk", "cframe", "velocity", "jump", "teleport", "dash", "sprint", "position" },
}

local function matchAny(s, keys)
	for _, k in ipairs(keys) do
		if k ~= "" and s:find(k, 1, true) then return true end
	end
	return false
end

local function classify(name, data, sub)
	local lname = (tostring(name or "") .. " " .. tostring(sub or "")):lower()
	if lname ~= " " then
		if matchAny(lname, logCfg.chatKeys) then return "chat" end
		if matchAny(lname, logCfg.moveKeys) then return "movement" end
	end
	local t = typeof(data)
	if t == "Vector3" or t == "Vector2" or t == "CFrame" then return "movement" end
	if t == "table" then
		local n = 0
		for k, v in next, data do
			n += 1
			if n > 20 then break end
			local lk = tostring(k):lower()
			local vt = typeof(v)
			if vt == "string" and matchAny(lk, logCfg.chatKeys) then return "chat" end
			if vt == "Vector3" or vt == "Vector2" or vt == "CFrame" then return "movement" end
		end
	end
	return "other"
end

local function extractChat(data)
	if type(data) == "string" then return nil, data end
	if type(data) ~= "table" then return nil, nil end
	local who, msg
	for k, v in next, data do
		local lk = tostring(k):lower()
		local vt = typeof(v)
		if vt == "string" then
			if lk:find("msg") or lk:find("message") or lk:find("text") or lk:find("chat") or lk:find("content") then
				msg = msg or v
			elseif lk:find("name") or lk:find("player") or lk:find("user") or lk:find("sender") or lk:find("from") then
				who = who or v
			end
		elseif vt == "Instance" and v:IsA("Player") then
			who = who or v.Name
		elseif vt == "number" and (lk:find("userid") or lk:find("player") or lk:find("sender")) then
			local p = Players:GetPlayerByUserId(v)
			who = who or (p and p.Name) or tostring(v)
		end
	end
	if not msg then
		for _, v in next, data do
			if type(v) == "string" and (not msg or #v > #msg) then msg = v end
		end
	end
	return who, msg
end

------------------------------------------------------------------
-- SUB-PACKET: satu packet ByteNet membawa banyak jenis pesan
-- (mis. { packet = "message", ... } atau { "Move", ... }).
-- Field pembeda dicari dari daftar kunci umum (urutan = prioritas).
------------------------------------------------------------------
local DISC_ORDER = {
	"packet", "type", "action", "act", "event", "evt", "cmd", "command", "request", "req",
	"kind", "op", "opcode", "method", "name", "message", "msg", "id", "t", "a", "k",
}
local DISC_RANK = {}
for i, k in ipairs(DISC_ORDER) do DISC_RANK[k] = i end

local function subOf(data)
	if type(data) ~= "table" then return nil, nil end
	local bestRank, bestVal, bestKey
	for k, v in next, data do
		if type(k) == "string" then
			local rank = DISC_RANK[k:lower()]
			if rank and (not bestRank or rank < bestRank) then
				local tv, val = type(v), nil
				if tv == "string" then
					if #v > 0 and #v <= 40 and v:match("^[%w_%.%-:/]+$") then val = v end
				elseif tv == "number" then
					if v % 1 == 0 and v >= 0 and v <= 65535 then val = fnum(v) end
				end
				if val then bestRank, bestVal, bestKey = rank, val, k end
			end
		end
	end
	if bestVal then return bestVal, bestKey end
	local first = rawget(data, 1)
	if type(first) == "string" and #first > 0 and #first <= 40 and first:match("^[%a_][%w_%.%-:/]*$") then
		return first, "[1]"
	end
	return nil, nil
end

local function sortedSubNames(e)
	local names = {}
	for n in pairs(e.subs) do names[#names + 1] = n end
	table.sort(names, function(a, b)
		local na, nb = e.subs[a].n, e.subs[b].n
		if na ~= nb then return na > nb end
		return a < b
	end)
	return names
end

local function recordSub(e, sub, skey, dir, ch, data, cat)
	e.discKey = e.discKey or skey
	local s = e.subs[sub]
	if not s then
		if e.subCount >= CFG.SubCap then e.subOver = (e.subOver or 0) + 1 return end
		s = { name = sub, n = 0, inN = 0, outN = 0, R = 0, U = 0, learned = 0, samples = {}, first = os.date("%H:%M:%S"), cat = cat }
		e.subs[sub] = s
		e.subCount += 1
	end
	s.n += 1
	if dir == "IN" then s.inN += 1 else s.outN += 1 end
	if ch == "reliable" then s.R += 1 elseif ch == "unreliable" then s.U += 1 end
	s.last = os.date("%H:%M:%S")
	s.learned += 1
	if s.learned <= 150 or s.learned % 20 == 0 then s.schema = learn(s.schema, data) end
	local now = os.clock()
	if #s.samples < 3 or now - (s.lastSample or 0) >= 0.5 then
		s.lastSample = now
		s.samples[#s.samples + 1] = { dir = dir, chan = ch, time = os.date("%H:%M:%S"), data = deepCopy(data) }
		while #s.samples > CFG.SubSamples do table.remove(s.samples, 1) end
	end
end

------------------------------------------------------------------
-- CHANNEL (reliable / unreliable)
------------------------------------------------------------------
local Chan = { last = nil, t = 0, fresh = false, pending = {} }

local function chanInfo(e)
	if e.chan then return e.chan, "declared" end
	local r, u = e.outR, e.outU
	if r + u > 0 then return (r >= u) and "reliable" or "unreliable", "observed" end
	r, u = e.vR, e.vU
	if r + u > 0 then return (r >= u) and "reliable" or "unreliable", "heuristic" end
	return nil, nil
end

local function chanTag(e)
	local c, src = chanInfo(e)
	if not c then return "?" end
	local t = c == "reliable" and "R" or "U"
	if src == "heuristic" then t = t .. "~" end
	return t
end

local function chanText(e)
	local c, src = chanInfo(e)
	if not c then return "tidak diketahui" end
	return c:upper() .. " (" .. src .. ")"
end

local function recordLog(e, dir, data, ch, sub, cat)
	local now = os.clock()
	if cat == "movement" and CFG.MoveCap > 0 then
		if now - logCfg.moveT >= 1 then logCfg.moveT, logCfg.moveN = now, 0 end
		if logCfg.moveN >= CFG.MoveCap then logCfg.dropped += 1 return nil end
		logCfg.moveN += 1
	end
	logCfg.seq += 1
	local rec = {
		n = logCfg.seq, time = os.date("%H:%M:%S"), dir = dir, name = e.short, id = e.id,
		chan = ch, cat = cat, sub = sub, data = deepCopy(data),
	}
	local L = Store.log
	L[#L + 1] = rec
	while #L > CFG.LogMax do table.remove(L, 1) end
	if cat == "chat" then
		local who, msg = extractChat(rec.data)
		if msg then
			if not who and dir == "OUT" then who = LocalPlayer.Name end
			local C = Store.chat
			C[#C + 1] = { n = rec.n, time = rec.time, dir = dir, player = who or "?", message = msg, packet = e.short }
			while #C > CFG.LogMax do table.remove(C, 1) end
		end
	end
	return rec
end

local function connectChatService()
	if chatConn then return end
	pcall(function()
		local TCS = game:GetService("TextChatService")
		chatConn = TCS.MessageReceived:Connect(function(m)
			if not state.active then return end
			local src = m.TextSource
			local C = Store.chat
			C[#C + 1] = { n = 0, time = os.date("%H:%M:%S"), dir = "IN", player = src and src.Name or "?", message = tostring(m.Text), packet = "TextChatService" }
			while #C > CFG.LogMax do table.remove(C, 1) end
			markDirty()
		end)
	end)
end

local function getUps(f)
	local fn = getupvalues or (debug and debug.getupvalues)
	if not fn then return nil end
	local ok, res = pcall(fn, f)
	return (ok and type(res) == "table") and res or nil
end

local function upList(f)
	local ups = getUps(f)
	if not ups then return {} end
	local idx = {}
	for i in pairs(ups) do idx[#idx + 1] = i end
	table.sort(idx, function(a, b)
		if type(a) == "number" and type(b) == "number" then return a < b end
		return tostring(a) < tostring(b)
	end)
	local out = {}
	for _, i in ipairs(idx) do out[#out + 1] = ups[i] end
	return out
end

local function srcOf(f)
	local ok, s = pcall(function() return debug.info(f, "s") end)
	if ok and type(s) == "string" and s ~= "" then return s end
	if debug and debug.getinfo then
		local ok2, info = pcall(debug.getinfo, f)
		if ok2 and type(info) == "table" then return tostring(info.source or info.short_src or "") end
	end
	return nil
end

local function isPacketObj(t)
	if type(t) ~= "table" then return false end
	local ok, res = pcall(function()
		return type(rawget(t, "reader")) == "function"
			and type(rawget(t, "listen")) == "function"
			and type(rawget(t, "getListeners")) == "function"
	end)
	return ok and res
end

local SEND_KEYS = { "send", "sendTo", "sendToAll" }

local function findPacketId(obj)
	for _, key in ipairs(SEND_KEYS) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			for _, v in ipairs(upList(f)) do
				if type(v) == "number" and v % 1 == 0 and v >= 0 and v < 65536 then return v end
			end
		end
	end
	return nil
end

local function detectChannel(obj)
	for _, key in ipairs(SEND_KEYS) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			for _, v in ipairs(upList(f)) do
				if type(v) == "string" then
					local l = v:lower()
					if l == "reliable" or l == "unreliable" then return l end
				end
			end
		end
	end
	return nil
end

local function resetEntry(e)
	e.schema, e.samples, e.cIn, e.cOut, e.learned = nil, {}, 0, 0, 0
	e.inR, e.inU, e.inX, e.outR, e.outU, e.outX, e.vR, e.vU = 0, 0, 0, 0, 0, 0, 0, 0
	e.subs, e.subCount, e.discKey, e.subOver, e.cats = {}, 0, nil, nil, {}
end

local function indexEntry(e)
	local short = e.name:match("([^%.]+)$") or e.name
	e.short = short
	local k = short:lower()
	if not byName[k] then byName[k] = e end
	byName[e.name:lower()] = e
	if e.id and not byId[e.id] then byId[e.id] = e end
	state.listDirty = true
end

local function makeEntry(obj, id, name)
	local e = {
		obj = obj, id = id, auto = name == nil,
		name = name or (id and ("pkt_" .. id)) or ("pkt_" .. (#entries + 1)),
	}
	resetEntry(e)
	entries[#entries + 1] = e
	if obj then byObj[obj] = e end
	indexEntry(e)
	return e
end

local function publish(e, dir, ch, data, sub)
	for i = 1, #Subs do
		local cb = Subs[i]
		if cb then pcall(cb, e.short, dir, ch, data, e, sub) end
	end
end

local function observe(e, dir, data, chan)
	if dir == "IN" then e.cIn += 1 else e.cOut += 1 end

	local ch, pending = chan, false
	if dir == "OUT" then
		ch = chan or e.chan
		if ch == "reliable" then e.outR += 1 elseif ch == "unreliable" then e.outU += 1 else e.outX += 1 end
	else
		ch = e.chan
		if not ch and Chan.fresh then
			ch = Chan.last
			if ch == "reliable" then e.vR += 1 elseif ch then e.vU += 1 end
		end
		if ch == "reliable" then e.inR += 1
		elseif ch == "unreliable" then e.inU += 1
		else e.inX += 1 pending = true end
	end

	if muted[e.short] then return end

	local sub, skey = subOf(data)
	local cat = classify(e.short, data, sub)
	e.cats[cat] = (e.cats[cat] or 0) + 1

	local rec = select(2, pcall(recordLog, e, dir, data, ch, sub, cat))
	if type(rec) ~= "table" then rec = nil end
	if pending and remotesFound > 0 then
		local P = Chan.pending
		P[#P + 1] = { e = e, t = os.clock(), rec = rec }
		while #P > 200 do table.remove(P, 1) end
	end

	local now = os.clock()
	e.learned += 1
	if e.learned <= CFG.LearnLimit or e.learned % 20 == 0 then
		e.schema = learn(e.schema, data)
	end
	if sub then pcall(recordSub, e, sub, skey, dir, ch, data, cat) end
	if now - (e.lastSample or 0) >= 0.1 or #e.samples < 3 then
		e.lastSample = now
		e.samples[#e.samples + 1] = { dir = dir, chan = ch, sub = sub, time = os.date("%H:%M:%S"), data = deepCopy(data) }
		while #e.samples > CFG.MaxSamples do table.remove(e.samples, 1) end
	end
	if now - (e.lastFeed or 0) >= 0.15 then
		e.lastFeed = now
		local tag = ch and (ch == "reliable" and "R" or "U") or "?"
		local line = ("[%s] %-3s %s %s%s %s"):format(os.date("%H:%M:%S"), dir, tag, e.short, sub and ("[" .. sub .. "]") or "", lit(data))
		if #line > 220 then line = line:sub(1, 217) .. "..." end
		local f = Store.feed
		f[#f + 1] = line
		while #f > CFG.FeedMax do table.remove(f, 1) end
	end
	publish(e, dir, ch, data, sub)
	markDirty()
end

local function resolvePending(chan)
	local now = os.clock()
	local P = Chan.pending
	for i = #P, 1, -1 do
		local p = P[i]
		if now - p.t <= 0.1 then
			local e = p.e
			if e.inX > 0 then e.inX -= 1 end
			if chan == "reliable" then e.inR += 1 e.vR += 1 else e.inU += 1 e.vU += 1 end
			if p.rec and not p.rec.chan then p.rec.chan = chan end
		end
		table.remove(P, i)
	end
end

local function onRemote(chan, ...)
	if not state.active then return end
	Chan.last, Chan.t, Chan.fresh = chan, os.clock(), true
	task.defer(function() Chan.fresh = false end)
	local a = ...
	local R = Raw[chan]
	R.n += 1
	if typeof(a) == "buffer" then R.bytes += buffer.len(a) end
	resolvePending(chan)
	state.dirty = true
end

local function connectRemotes()
	if #remoteConns > 0 then return #remoteConns end
	local okD, desc = pcall(function() return ReplicatedStorage:GetDescendants() end)
	if not okD then return 0 end
	table.clear(remoteList)
	for _, inst in ipairs(desc) do
		local isEvent = inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent")
		local isRemote = isEvent or inst:IsA("RemoteFunction")
		if isRemote then
			local lname = inst.Name:lower()
			local inBN = lname:find("bytenet", 1, true) or inst:FindFirstAncestor("ByteNet") ~= nil
			local chan = (inst:IsA("UnreliableRemoteEvent") or lname:find("unreliable", 1, true)) and "unreliable" or "reliable"
			local okP, path = pcall(function() return inst:GetFullName() end)
			remoteList[#remoteList + 1] = { path = okP and path or inst.Name, class = inst.ClassName, bytenet = inBN and true or false, chan = chan }
			if isEvent and inBN then
				local ok, c = pcall(function()
					return inst.OnClientEvent:Connect(function(...) onRemote(chan, ...) end)
				end)
				if ok and c then remoteConns[#remoteConns + 1] = c end
			end
		end
	end
	remotesFound = #remoteConns
	return remotesFound
end

local function disconnectRemotes()
	for _, c in ipairs(remoteConns) do pcall(function() c:Disconnect() end) end
	table.clear(remoteConns)
	remotesFound = 0
	table.clear(Chan.pending)
end

local function attach(e)
	if e.attached or not e.listeners then return end
	e.master = function(data) pcall(observe, e, "IN", data) end
	table.insert(e.listeners, e.master)
	e.attached = true
end

local function detach(e)
	if e.attached and e.listeners and e.master then
		local i = table.find(e.listeners, e.master)
		if i then table.remove(e.listeners, i) end
	end
	e.attached = false
	if e.origSend and e.obj then
		pcall(rawset, e.obj, "send", e.origSend)
		e.origSend = nil
	end
end

local function register(obj, name)
	local e = byObj[obj]
	if e then
		if name and e.auto then e.name, e.auto = name, false indexEntry(e) end
		return e
	end
	local id = findPacketId(obj)
	local existing = id and byId[id]
	if existing and not existing.obj then
		e = existing
		e.obj = obj
		byObj[obj] = e
		if name then e.name, e.auto = name, false indexEntry(e) end
		e.declTried = nil
	else
		e = makeEntry(obj, id, name)
	end
	e.chan = e.chan or detectChannel(obj)
	local okL, ls = pcall(function() return rawget(obj, "getListeners")() end)
	if okL and type(ls) == "table" then e.listeners = ls end
	if state.active then attach(e) end
	state.listDirty = true
	return e
end

local function scanPackets()
	local before = #entries
	if getloadedmodules then
		local okM, mods = pcall(getloadedmodules)
		if okM and type(mods) == "table" then
			local visited = {}
			local function walk(t, prefix, depth)
				if visited[t] or depth > 4 then return end
				visited[t] = true
				pcall(function()
					local n = 0
					for k, v in next, t do
						n += 1
						if n > 400 then break end
						if type(v) == "table" then
							if isPacketObj(v) then register(v, prefix .. tostring(k))
							else walk(v, prefix .. tostring(k) .. ".", depth + 1) end
						end
					end
				end)
			end
			for i, m in ipairs(mods) do
				if typeof(m) == "Instance" and m:IsA("ModuleScript") then
					local okR, res = pcall(require, m)
					if okR and type(res) == "table" then
						if isPacketObj(res) then register(res, m.Name) else walk(res, "", 1) end
					end
				end
				if i % 40 == 0 then task.wait() end
			end
		end
	end
	if getgc then
		local okG, gc = pcall(getgc, true)
		if okG and type(gc) == "table" then
			for i = 1, #gc do
				local v = gc[i]
				if type(v) == "table" and not byObj[v] and isPacketObj(v) then register(v, nil) end
				if i % 4000 == 0 then task.wait() end
			end
		end
	end
	return #entries - before
end

local function onOut(id, chan, data)
	if not state.active then return end
	local e = byId[id]
	if not e then
		e = makeEntry(nil, id, "id_" .. tostring(id))
		e.auto = true
		byId[id] = e
	end
	observe(e, "OUT", data, chan)
end

local function installClientHook()
	if not hookfunction then return false, "hookfunction tidak tersedia" end
	local genv = getgenv and getgenv() or nil
	if genv then genv.__SS_out = onOut end
	if genv and genv.__SS_hooked then return true end
	local bn = ReplicatedStorage:FindFirstChild("ByteNet")
	local proc = bn and bn:FindFirstChild("process")
	local m = proc and proc:FindFirstChild("client")
	if not m then return false, "ReplicatedStorage.ByteNet.process.client tidak ditemukan" end
	local okR, client = pcall(require, m)
	if not okR or type(client) ~= "table" then return false, "require process.client gagal" end
	local hooked = 0
	for _, fname in ipairs({ "sendReliable", "sendUnreliable" }) do
		local f = rawget(client, fname)
		if type(f) == "function" then
			local chan = fname == "sendReliable" and "reliable" or "unreliable"
			local orig
			local ok = pcall(function()
				orig = hookfunction(f, function(id, writer, data, ...)
					local cb = getgenv and getgenv().__SS_out
					if cb then pcall(cb, id, chan, data) end
					return orig(id, writer, data, ...)
				end)
			end)
			if ok and orig then hooked += 1 end
		end
	end
	if hooked > 0 and genv then genv.__SS_hooked = true end
	return hooked > 0, hooked == 0 and "hook gagal (fungsi send tidak ditemukan)" or nil
end

local function wrapSendFallback(e)
	if e.origSend or not e.obj then return end
	local orig = rawget(e.obj, "send")
	if type(orig) ~= "function" then return end
	e.origSend = orig
	local ok = pcall(rawset, e.obj, "send", function(data, ...)
		if state.active then pcall(observe, e, "OUT", data, e.chan) end
		return orig(data, ...)
	end)
	if not ok then e.origSend = nil end
end

------------------------------------------------------------------
-- INTROSPEKSI DEFINISI BYTENET (DECLARED)
------------------------------------------------------------------
local function isDT(t)
	if type(t) ~= "table" then return false end
	local ok, res = pcall(function()
		return type(rawget(t, "read")) == "function" and type(rawget(t, "write")) == "function"
	end)
	return ok and res
end

local function dtName(dt)
	for _, k in ipairs({ "read", "write" }) do
		local f = rawget(dt, k)
		if type(f) == "function" then
			local s = srcOf(f)
			local n = s and s:match("dataTypes[%./\\]([%w_]+)")
			if n then return n end
		end
	end
	return nil
end

local function dtUps(dt)
	local f = rawget(dt, "read")
	if type(f) ~= "function" then f = rawget(dt, "write") end
	if type(f) ~= "function" then return {} end
	return upList(f)
end

local function describeDT(dt, depth, stack)
	depth = depth or 0
	stack = stack or {}
	local node = { kind = dtName(dt) or "?" }
	if depth > 10 or stack[dt] then node.cyclic = true return node end
	stack[dt] = true
	local k = node.kind
	if k == "struct" then
		for _, up in ipairs(dtUps(dt)) do
			if type(up) == "table" and not isDT(up) then
				local fields, count = {}, 0
				for fk, fv in pairs(up) do
					if type(fk) == "string" and isDT(fv) then
						fields[fk] = describeDT(fv, depth + 1, stack)
						count += 1
					end
				end
				if count > 0 then node.fields = fields break end
			end
		end
	elseif k == "array" or k == "optional" then
		local found = {}
		for _, up in ipairs(dtUps(dt)) do if isDT(up) then found[#found + 1] = up end end
		if found[1] then node.inner = describeDT(found[1], depth + 1, stack) end
		if #found > 1 then node.extra = #found - 1 end
	elseif k == "map" then
		local found = {}
		for _, up in ipairs(dtUps(dt)) do if isDT(up) then found[#found + 1] = up end end
		if found[1] then node.key = describeDT(found[1], depth + 1, stack) end
		if found[2] then node.value = describeDT(found[2], depth + 1, stack) end
	end
	stack[dt] = nil
	return node
end

local function declExpr(node, ind)
	local p = string.rep("\t", ind)
	local k = node.kind
	if node.cyclic then return "ByteNet.unknown --[[siklik]]" end
	if k == "struct" then
		if not node.fields then return "ByteNet.struct({ --[[field tidak terbaca dari upvalue]] })" end
		local lines = {}
		for _, key in ipairs(sortedKeys(node.fields)) do
			local ks = (key:match(IDENT) and not RESERVED[key]) and key or ("[" .. string.format("%q", key) .. "]")
			lines[#lines + 1] = p .. "\t" .. ks .. " = " .. declExpr(node.fields[key], ind + 1) .. ","
		end
		return "ByteNet.struct({\n" .. table.concat(lines, "\n") .. "\n" .. p .. "})"
	elseif k == "array" or k == "optional" then
		return ("ByteNet.%s(%s)"):format(k, node.inner and declExpr(node.inner, ind) or "?")
	elseif k == "map" then
		return ("ByteNet.map(%s, %s)"):format(node.key and declExpr(node.key, ind) or "?", node.value and declExpr(node.value, ind) or "?")
	elseif k == "?" then
		return "?"
	end
	return "ByteNet." .. k
end

local function introspect(e)
	if e.declTried then return e.declared end
	e.declTried = true
	e.declared = false
	local obj = e.obj
	if not obj then return false end
	local cands = {}
	for _, key in ipairs({ "reader", "writer" }) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			local s = srcOf(f)
			if s and s:find("dataTypes", 1, true) then cands[#cands + 1] = { read = f, write = f } end
		end
	end
	if #cands == 0 then
		for _, f in next, obj do
			if type(f) == "function" then
				for _, up in ipairs(upList(f)) do
					if isDT(up) then cands[#cands + 1] = up end
				end
			end
		end
	end
	if #cands == 0 then
		for _, f in next, obj do
			if type(f) == "function" then
				for _, up in ipairs(upList(f)) do
					if type(up) == "function" then
						for _, up2 in ipairs(upList(up)) do
							if isDT(up2) then cands[#cands + 1] = up2 end
						end
					end
				end
			end
		end
	end
	for _, dt in ipairs(cands) do
		local ok, node = pcall(describeDT, dt)
		if ok and node and node.kind ~= "?" then
			e.declared = node
			break
		end
	end
	return e.declared
end

------------------------------------------------------------------
-- LAPORAN / TABEL STRUCT
------------------------------------------------------------------
local function sortedEntries()
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		local ia, ib = a.id or 1e9, b.id or 1e9
		if ia ~= ib then return ia < ib end
		return (a.short or "") < (b.short or "")
	end)
	return list
end

local function headerOf(e)
	return ("%s  (id %s)"):format(e.short, tostring(e.id or "?"))
end

local function relLine(e)
	local c, src = chanInfo(e)
	if not c then return "" end
	return ("\n\treliabilityType = %q,%s"):format(c, src ~= "declared" and (" -- " .. src) or "")
end

local function declaredText(e)
	local d = introspect(e)
	if not d then
		return "(tidak terbaca: executor tanpa debug.info/getupvalues, atau struktur modul ByteNet berbeda)\nGunakan bagian OBSERVED di bawah."
	end
	return ("ByteNet.definePacket({\n\tvalue = %s,%s\n})"):format(declExpr(d, 1), relLine(e))
end

-- baris tabel struct (declared)
local function declRows(node, path, rows, opt)
	local p = path == "" and "(root)" or path
	local k = node.kind
	if node.cyclic then rows[#rows + 1] = { path = p, type = "(siklik)", opt = opt, detail = "" } return end
	if k == "struct" then
		rows[#rows + 1] = { path = p, type = "struct", opt = opt, detail = node.fields and "" or "field tidak terbaca" }
		if node.fields then
			for _, key in ipairs(sortedKeys(node.fields)) do
				declRows(node.fields[key], path == "" and key or (path .. "." .. key), rows, false)
			end
		end
	elseif k == "array" then
		rows[#rows + 1] = { path = p, type = "array", opt = opt, detail = "" }
		if node.inner then declRows(node.inner, path .. "[]", rows, false) end
	elseif k == "optional" then
		if node.inner then declRows(node.inner, path, rows, true)
		else rows[#rows + 1] = { path = p, type = "optional", opt = true, detail = "" } end
	elseif k == "map" then
		rows[#rows + 1] = { path = p, type = "map", opt = opt, detail = "" }
		if node.key then declRows(node.key, path .. "{key}", rows, false) end
		if node.value then declRows(node.value, path .. "{value}", rows, false) end
	else
		rows[#rows + 1] = { path = p, type = k, opt = opt, detail = "" }
	end
end

-- baris tabel struct (observed)
local function schemaRows(schema)
	local rows, out = {}, {}
	flatten(schema, "", rows, false)
	for _, r in ipairs(rows) do
		out[#out + 1] = { path = r.path, type = typeLabel(r.node), opt = r.opt, detail = detail(r.node) }
	end
	return out
end

local function structRows(e)
	local d = introspect(e)
	if d then
		local rows = {}
		declRows(d, "", rows, false)
		return "declared", rows
	end
	if e.schema then return "observed", schemaRows(e.schema) end
	return nil, {}
end

local function rowsText(rows, ind)
	ind = ind or ""
	if #rows == 0 then return { ind .. "(tidak ada field)" } end
	local w = 5
	for _, r in ipairs(rows) do w = math.max(w, #r.path) end
	w = math.min(w, 40)
	local out = { ind .. pad("FIELD", w) .. "  " .. pad("TIPE", 12) .. "  " .. pad("WAJIB", 8) .. "  DETAIL" }
	out[#out + 1] = ind .. string.rep("-", w + 30)
	for _, r in ipairs(rows) do
		out[#out + 1] = ind .. pad(r.path, w) .. "  " .. pad(r.type, 12) .. "  " .. pad(r.opt and "opsional" or "ya", 8) .. "  " .. (r.detail or "")
	end
	return out
end

local function mdRows(rows)
	local o = { "| Field | Tipe | Wajib | Detail |", "| --- | --- | --- | --- |" }
	for _, r in ipairs(rows) do
		o[#o + 1] = ("| `%s` | %s | %s | %s |"):format(mdEscape(r.path), mdEscape(r.type), r.opt and "opsional" or "ya", mdEscape(r.detail or ""))
	end
	return o
end

local function fieldsInline(schema)
	if not schema then return "?" end
	if schema.fields then
		local names = {}
		for i, k in ipairs(sortedKeys(schema.fields)) do
			if i > 8 then names[#names + 1] = "..." break end
			names[#names + 1] = k .. ":" .. typeLabel(schema.fields[k])
		end
		return "{" .. table.concat(names, ", ") .. "}"
	end
	return typeLabel(schema)
end

local function observedText(e)
	if not e.schema then
		return "(belum ada data. Aktifkan Rekam Packet lalu lakukan aksinya di game)"
	end
	local out = rowsText(schemaRows(e.schema), "")
	out[#out + 1] = ("(dipelajari dari %d data)"):format(e.schema.n)
	return table.concat(out, "\n")
end

local function guessText(e)
	if not e.schema then return "(belum ada data)" end
	return ("-- TEBAKAN minimal dari data nyata (tipe bisa lebih besar di definisi asli)\nByteNet.definePacket({\n\tvalue = %s,%s\n})"):format(nodeExpr(e.schema, 1), relLine(e))
end

local function lastSampleText(e)
	local s = e.samples[#e.samples]
	if not s then return "(belum ada sampel)" end
	local out = { ("Sampel terakhir [%s/%s]%s %s"):format(s.dir, s.chan or "?", s.sub and (" sub=" .. s.sub) or "", s.time) }
	tree(s.data, "data", 0, out, 0)
	out[#out + 1] = ""
	out[#out + 1] = "-- sebagai Lua:"
	out[#out + 1] = luaSrc(s.data, 0, 0, {})
	return table.concat(out, "\n")
end

local function samplesText(e)
	if #e.samples == 0 then return "(belum ada sampel)" end
	local list = {}
	for i, s in ipairs(e.samples) do list[i] = { dir = s.dir, chan = s.chan, sub = s.sub, time = s.time, data = s.data } end
	return ("-- %s : %d sampel terakhir\nreturn %s"):format(headerOf(e), #list, luaSrc(list, 0, 0, {}))
end

local function countsLine(e)
	return ("IN: R %d / U %d / ? %d | OUT: R %d / U %d / ? %d"):format(e.inR, e.inU, e.inX, e.outR, e.outU, e.outX)
end

local function topCat(e)
	local best, bn = "-", 0
	for c, n in pairs(e.cats) do if n > bn then best, bn = c, n end end
	return best
end

-- ringkasan sub-packet suatu packet
local function subsText(e)
	if e.subCount == 0 then
		return "(belum ada sub-packet terdeteksi. Sub-packet dikenali dari field pembeda seperti packet/type/action/message/cmd atau elemen pertama array berupa nama.)"
	end
	local o = {
		("SUB-PACKET %s | field pembeda: %s | %d jenis%s"):format(
			headerOf(e), tostring(e.discKey or "?"), e.subCount, e.subOver and (" (+" .. e.subOver .. " data jenis lain di luar batas)") or ""),
		"",
		("%s %s %s %s %s %s  %s"):format(pad("SUB", 24), pad("N", 6), pad("IN", 6), pad("OUT", 6), pad("CH", 3), pad("KAT", 9), "FIELD"),
		string.rep("-", 90),
	}
	for _, name in ipairs(sortedSubNames(e)) do
		local s = e.subs[name]
		local ch = (s.R > 0 and s.U == 0) and "R" or ((s.U > 0 and s.R == 0) and "U" or ((s.R + s.U) > 0 and "R/U" or "?"))
		o[#o + 1] = ("%s %s %s %s %s %s  %s"):format(pad(clipLine(name, 24), 24), pad(s.n, 6), pad(s.inN, 6), pad(s.outN, 6), pad(ch, 3), pad(s.cat or "-", 9), fieldsInline(s.schema))
	end
	return table.concat(o, "\n")
end

local function subDetailText(e, only)
	if e.subCount == 0 then return subsText(e) end
	local o = { subsText(e), "", string.rep("=", 70) }
	for _, name in ipairs(sortedSubNames(e)) do
		if not only or only == name then
			local s = e.subs[name]
			o[#o + 1] = ("[SUB] %s.%s = %s  | n=%d (IN %d / OUT %d) | kategori %s | terakhir %s"):format(e.short, tostring(e.discKey or "?"), name, s.n, s.inN, s.outN, s.cat or "-", s.last or "-")
			if s.schema then
				for _, l in ipairs(rowsText(schemaRows(s.schema), "  ")) do o[#o + 1] = l end
				o[#o + 1] = "  -- tebakan ByteNet:"
				for line in (nodeExpr(s.schema, 1) .. "\n"):gmatch("(.-)\n") do o[#o + 1] = "  -- " .. line end
			end
			local last = s.samples[#s.samples]
			if last then o[#o + 1] = "  contoh [" .. last.dir .. "]: " .. lit(last.data) end
			o[#o + 1] = ""
		end
	end
	return table.concat(o, "\n")
end

local function subsAllText()
	local o, any = { "SUB-PACKET SEMUA PACKET", string.rep("=", 70), "" }, false
	for _, e in ipairs(sortedEntries()) do
		if e.subCount > 0 then
			any = true
			o[#o + 1] = subsText(e)
			o[#o + 1] = ""
		end
	end
	if not any then return "(belum ada sub-packet terdeteksi. Rekam packet dan lakukan aksi di game)" end
	return table.concat(o, "\n")
end

local function packetStructBlock(e, withSubs)
	local src, rows = structRows(e)
	local o = { ("[%s] %s | CH %s | struct: %s | IN %d OUT %d"):format(tostring(e.id or "?"), e.short, chanTag(e), src or "belum ada data", e.cIn, e.cOut) }
	if src then
		for _, l in ipairs(rowsText(rows, "    ")) do o[#o + 1] = l end
	else
		o[#o + 1] = "    (belum ada struct. Rekam packet atau tunggu data)"
	end
	if withSubs and e.subCount > 0 then
		o[#o + 1] = ("    SUB-PACKET (key: %s, %d jenis):"):format(tostring(e.discKey or "?"), e.subCount)
		for _, name in ipairs(sortedSubNames(e)) do
			local s = e.subs[name]
			o[#o + 1] = ("      * %s  n=%d (IN %d / OUT %d)  %s"):format(name, s.n, s.inN, s.outN, fieldsInline(s.schema))
		end
	end
	return table.concat(o, "\n")
end

local function structTableText()
	local list = sortedEntries()
	if #list == 0 then return "(belum ada packet. Klik Scan atau aktifkan Rekam Packet)" end
	local o = { "TABEL STRUCT - semua packet (declared bila terbaca, jika tidak observed)", string.rep("=", 70), "" }
	for _, e in ipairs(list) do
		o[#o + 1] = packetStructBlock(e, true)
		o[#o + 1] = ""
	end
	return table.concat(o, "\n")
end

local function packetReport(e)
	local o = {}
	o[#o + 1] = "=================================================="
	o[#o + 1] = "PACKET " .. headerOf(e)
	o[#o + 1] = ("Nama lengkap: %s | sampel: %d | kategori: %s"):format(e.name, #e.samples, topCat(e))
	o[#o + 1] = ("Channel: %s | %s"):format(chanText(e), countsLine(e))
	if e.chan and (e.outR + e.outU) > 0 then
		local obs = e.outR >= e.outU and "reliable" or "unreliable"
		if obs ~= e.chan then o[#o + 1] = "PERINGATAN: channel declared (" .. e.chan .. ") berbeda dengan OUT teramati (" .. obs .. ")" end
	end
	o[#o + 1] = "=================================================="
	o[#o + 1] = ""
	o[#o + 1] = "[DECLARED] dibaca dari definisi ByteNet"
	o[#o + 1] = declaredText(e)
	o[#o + 1] = ""
	o[#o + 1] = "[OBSERVED] dipelajari dari data nyata"
	o[#o + 1] = observedText(e)
	if e.subCount > 0 then
		o[#o + 1] = ""
		o[#o + 1] = "[SUB-PACKET]"
		o[#o + 1] = subsText(e)
	end
	o[#o + 1] = ""
	o[#o + 1] = "[TEBAKAN]"
	o[#o + 1] = guessText(e)
	o[#o + 1] = ""
	o[#o + 1] = "[SAMPEL TERAKHIR]"
	o[#o + 1] = lastSampleText(e)
	return table.concat(o, "\n") .. "\n"
end

local function structSummary(e)
	local d = introspect(e)
	local desc = "?"
	if d then
		desc = d.kind
		if d.fields then
			local ks = sortedKeys(d.fields)
			local names = {}
			for i, k in ipairs(ks) do
				if i > 6 then names[#names + 1] = "..." break end
				names[#names + 1] = k .. ":" .. d.fields[k].kind
			end
			desc = "struct{" .. table.concat(names, ", ") .. "}"
		elseif d.inner then
			desc = d.kind .. "<" .. d.inner.kind .. ">"
		end
	elseif e.schema then
		desc = "(observed) " .. fieldsInline(e.schema)
	end
	return desc
end

local function summaryText()
	local list = sortedEntries()
	if #list == 0 then return "(belum ada packet. Klik Scan atau aktifkan Rekam Packet)" end
	local out = {
		("%s  %s  %s  %s  %s  %s  %s"):format(pad("ID", 5), pad("NAMA", 22), pad("CH", 3), pad("IN", 6), pad("OUT", 6), pad("SUB", 4), "STRUCT"),
		string.rep("-", 90),
		"CH: R=reliable U=unreliable ~=heuristik ?=belum diketahui | SUB = jumlah sub-packet",
	}
	for _, e in ipairs(list) do
		out[#out + 1] = ("%s  %s  %s  %s  %s  %s  %s"):format(pad(e.id or "?", 5), pad(e.short, 22), pad(chanTag(e), 3), pad(e.cIn, 6), pad(e.cOut, 6), pad(e.subCount, 4), structSummary(e))
	end
	return table.concat(out, "\n")
end

local function sumCounts()
	local s = { inR = 0, inU = 0, inX = 0, outR = 0, outU = 0, outX = 0 }
	for _, e in ipairs(entries) do
		for k in pairs(s) do s[k] += e[k] end
	end
	return s
end

local function channelStatsText()
	local s = sumCounts()
	local el = state.t0 and math.max(os.clock() - state.t0, 0.001) or nil
	local nR, nU, nX = 0, 0, 0
	for _, e in ipairs(entries) do
		local c = chanInfo(e)
		if c == "reliable" then nR += 1 elseif c == "unreliable" then nU += 1 else nX += 1 end
	end
	local o = {
		"STATISTIK CHANNEL",
		string.rep("-", 60),
		("Packet terdaftar : %d  (reliable %d | unreliable %d | belum diketahui %d)"):format(#entries, nR, nU, nX),
		("IN  reliable     : %d"):format(s.inR),
		("IN  unreliable   : %d"):format(s.inU),
		("IN  belum jelas  : %d"):format(s.inX),
		("OUT reliable     : %d"):format(s.outR),
		("OUT unreliable   : %d"):format(s.outU),
		("OUT belum jelas  : %d"):format(s.outX),
		"",
		("RemoteEvent ByteNet terhubung: %d"):format(remotesFound),
		("Raw IN reliable   : %d event, %d byte"):format(Raw.reliable.n, Raw.reliable.bytes),
		("Raw IN unreliable : %d event, %d byte"):format(Raw.unreliable.n, Raw.unreliable.bytes),
	}
	if el then
		o[#o + 1] = ("Durasi rekam      : %.1f detik"):format(el)
		o[#o + 1] = ("Rata-rata IN/OUT  : %.1f / %.1f packet per detik"):format((s.inR + s.inU + s.inX) / el, (s.outR + s.outU + s.outX) / el)
		o[#o + 1] = ("Raw byte IN/detik : reliable %.0f | unreliable %.0f"):format(Raw.reliable.bytes / el, Raw.unreliable.bytes / el)
	end
	o[#o + 1] = ""
	o[#o + 1] = "TOP PACKET (paling ramai)"
	o[#o + 1] = ("%s  %s  %s  %s  %s"):format(pad("NAMA", 22), pad("CH", 3), pad("IN", 7), pad("OUT", 7), "PER DETIK")
	local list = table.clone(entries)
	table.sort(list, function(a, b) return (a.cIn + a.cOut) > (b.cIn + b.cOut) end)
	for i = 1, math.min(15, #list) do
		local e = list[i]
		if e.cIn + e.cOut == 0 then break end
		o[#o + 1] = ("%s  %s  %s  %s  %s"):format(pad(e.short, 22), pad(chanTag(e), 3), pad(e.cIn, 7), pad(e.cOut, 7), el and ("%.1f"):format((e.cIn + e.cOut) / el) or "-")
	end
	return table.concat(o, "\n")
end

local function feedText()
	if #Store.feed == 0 then return "(belum ada packet. Aktifkan Rekam Packet)" end
	return table.concat(Store.feed, "\n")
end

local function allReport()
	local out = {
		"# StructScope - laporan semua packet",
		("PlaceId: %s | dibuat: %s | packet: %d\n"):format(tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S"), #entries),
		summaryText(), "", channelStatsText(), "", structTableText(), "",
	}
	for _, e in ipairs(sortedEntries()) do out[#out + 1] = packetReport(e) end
	return table.concat(out, "\n")
end

------------------------------------------------------------------
-- LOG (filter + format)
------------------------------------------------------------------
local function logPasses(r)
	if logCfg.dir ~= "Semua" and r.dir ~= logCfg.dir then return false end
	if logCfg.cat ~= "Semua" and r.cat ~= logCfg.cat then return false end
	if logCfg.chan ~= "Semua" and (r.chan or "?") ~= logCfg.chan then return false end
	if logCfg.pkt ~= "Semua" and r.name ~= logCfg.pkt then return false end
	if logCfg.sub ~= "Semua" and r.sub ~= logCfg.sub then return false end
	if logCfg.name ~= "" then
		local hay = (tostring(r.name) .. " " .. tostring(r.sub or "")):lower()
		if not (hay:find(logCfg.name, 1, true) or tostring(r.id):find(logCfg.name, 1, true)) then return false end
	end
	if logCfg.text ~= "" then
		if not r.search then r.search = lit(r.data):lower() end
		if not r.search:find(logCfg.text, 1, true) then return false end
	end
	return true
end

local function filteredLog()
	local out = {}
	for _, r in ipairs(Store.log) do
		if logPasses(r) then out[#out + 1] = r end
	end
	return out
end

local function recLine(r, detailed)
	local key = detailed and "lineD" or "line"
	if r[key] then return r[key] end
	local tag = r.chan and (r.chan == "reliable" and "R" or "U") or "?"
	local nm = r.name .. (r.sub and ("[" .. tostring(r.sub) .. "]") or "")
	local head = ("#%d %s %-3s %s [%s] %s (id %s)"):format(r.n, r.time, r.dir, tag, r.cat, nm, tostring(r.id or "?"))
	local s
	if detailed then
		local body = luaSrc(r.data, 1, 0, {})
		if #body > 700 then body = body:sub(1, 700) .. "..." end
		s = head .. "\n\t" .. body
	else
		s = clipLine(head .. " " .. lit(r.data), 230)
	end
	r[key] = s
	return s
end

local function logHeader(list)
	return ("Log: %d cocok filter dari %d total | tampil %d terakhir | movement dilewati %d | OUT=request IN=response/push"):format(
		#list, #Store.log, math.min(#list, state.logLines), logCfg.dropped)
end

local function logText()
	local list = filteredLog()
	local out = { logHeader(list), "" }
	if #list == 0 then
		out[#out + 1] = "(belum ada log yang cocok filter. Aktifkan Rekam Packet lalu lakukan aksi di game)"
		return table.concat(out, "\n"), 0
	end
	for i = math.max(1, #list - state.logLines + 1), #list do
		out[#out + 1] = recLine(list[i], state.logDetail)
	end
	return table.concat(out, "\n"), #list
end

local function chatText()
	local C = Store.chat
	if #C == 0 then return "(belum ada chat terdeteksi. Kirim / terima chat di game dengan Rekam Packet aktif)" end
	local out = { ("Chat log: %d pesan"):format(#C), "" }
	for i = math.max(1, #C - state.logLines + 1), #C do
		local c = C[i]
		out[#out + 1] = clipLine(("[%s] %-3s %s: %s  <%s>"):format(c.time, c.dir, tostring(c.player), tostring(c.message), c.packet), 180)
	end
	return table.concat(out, "\n")
end

local function logToLua(list, title)
	local plain = {}
	for i, r in ipairs(list) do
		plain[i] = { n = r.n, time = r.time, dir = r.dir, name = r.name, sub = r.sub, id = r.id, chan = r.chan, cat = r.cat, data = r.data }
	end
	return ("-- %s\n-- Dibuat: %s | Entri: %d | PlaceId: %s\nreturn %s\n"):format(
		title, os.date("%Y-%m-%d %H:%M:%S"), #plain, tostring(game.PlaceId), luaSrc(plain, 0, 0, {}))
end

local function chatToLua()
	return ("-- Chat log\n-- Dibuat: %s | Entri: %d | PlaceId: %s\nreturn %s\n"):format(
		os.date("%Y-%m-%d %H:%M:%S"), #Store.chat, tostring(game.PlaceId), luaSrc(Store.chat, 0, 0, {}))
end

local function registryLua()
	local list = {}
	for _, e in ipairs(sortedEntries()) do
		local d = introspect(e)
		local c, src = chanInfo(e)
		local subs = {}
		for n, s in pairs(e.subs) do subs[n] = s.n end
		list[#list + 1] = {
			id = e.id, name = e.short, fullName = e.name, channel = c, channelSource = src,
			countIn = e.cIn, countOut = e.cOut, category = topCat(e), discriminator = e.discKey, subs = subs,
			declared = d and declExpr(d, 0) or nil,
			observed = e.schema and typeLabel(e.schema) or nil,
		}
	end
	return ("-- Tabel packet\n-- Dibuat: %s | Packet: %d | PlaceId: %s\nreturn %s\n"):format(
		os.date("%Y-%m-%d %H:%M:%S"), #list, tostring(game.PlaceId), luaSrc(list, 0, 0, {}))
end

------------------------------------------------------------------
-- FRAMEWORK GENERATOR (modul, dokumentasi, template)
------------------------------------------------------------------
local function valueExpr(e, ind)
	local d = introspect(e)
	if d then return declExpr(d, ind), "declared" end
	if e.schema then return nodeExpr(e.schema, ind), "observed" end
	return "ByteNet.unknown", "unknown"
end

local function frameworkModule()
	local list = sortedEntries()
	local o = {
		("-- Packets.lua  (dibuat StructScope v%s)"):format(VERSION),
		("-- PlaceId: %s | dibuat: %s | packet: %d"):format(tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S"), #list),
		"-- Struct 'observed' hanya sebesar data yang pernah muncul. Periksa lagi sebelum dipakai.",
		"-- reliabilityType: reliable = RemoteEvent (terurut, pasti sampai), unreliable = UnreliableRemoteEvent.",
		"",
		"local ByteNet = require(game:GetService(\"ReplicatedStorage\"):WaitForChild(\"ByteNet\")) -- sesuaikan path",
		"",
		"return ByteNet.defineNamespace(\"app\", function()",
		"\treturn {",
		"\t\tpackets = {",
	}
	local used = {}
	for _, e in ipairs(list) do
		local key = identOf(e.short)
		if used[key] then key = key .. "_" .. tostring(e.id or #used) end
		used[key] = true
		local expr, src = valueExpr(e, 4)
		local c, csrc = chanInfo(e)
		o[#o + 1] = ("\t\t\t-- id %s | struct: %s | channel: %s"):format(tostring(e.id or "?"), src, c and (c .. " (" .. csrc .. ")") or "tidak diketahui")
		if e.subCount > 0 then
			local names = sortedSubNames(e)
			local shown = {}
			for i = 1, math.min(#names, 12) do shown[i] = names[i] end
			o[#o + 1] = ("\t\t\t-- sub-packet (%s): %s%s"):format(tostring(e.discKey or "?"), table.concat(shown, ", "), #names > 12 and ", ..." or "")
		end
		o[#o + 1] = ("\t\t\t%s = ByteNet.definePacket({"):format(key)
		o[#o + 1] = ("\t\t\t\tvalue = %s,"):format(expr)
		if c then o[#o + 1] = ("\t\t\t\treliabilityType = %q,"):format(c) end
		o[#o + 1] = "\t\t\t}),"
	end
	o[#o + 1] = "\t\t},"
	o[#o + 1] = "\t}"
	o[#o + 1] = "end)"
	return table.concat(o, "\n") .. "\n"
end

local function templateText(e)
	local c, src = chanInfo(e)
	local s = e.samples[#e.samples]
	local o = {
		("-- Template script: packet %s (id %s)"):format(e.short, tostring(e.id or "?")),
		("-- Channel: %s"):format(c and (c:upper() .. " (" .. src .. ")") or "tidak diketahui"),
		"",
		"local SS = getgenv().StructScope -- jalankan StructScope dulu",
		("local packet = SS.Packets.get(%q) -- objek ByteNet asli (listen / send)"):format(e.short),
		"",
		"-- 1) Pantau pasif lewat StructScope (IN dan OUT, tanpa mengubah apa pun)",
		"local unsubscribe = SS.Subscribe(function(name, dir, chan, data, entry, sub)",
		("\tif name ~= %q then return end"):format(e.short),
		"\t-- sub = nilai field pembeda (mis. nama pesan), nil bila packet tidak punya sub-packet",
		"\tprint(dir, chan, sub, data)",
		"end)",
		"-- unsubscribe() untuk berhenti",
		"",
		"-- 2) Listener langsung ke packet (IN dari server)",
		"if packet then",
		"\tpacket.listen(function(data)",
		"\t\tprint(\"diterima\", data)",
		"\tend)",
		"end",
		"",
	}
	if e.subCount > 0 then
		o[#o + 1] = ("-- Sub-packet yang terdeteksi (field pembeda: %s):"):format(tostring(e.discKey or "?"))
		for i, name in ipairs(sortedSubNames(e)) do
			if i > 20 then o[#o + 1] = "--   ..." break end
			o[#o + 1] = ("--   %s  %s"):format(name, fieldsInline(e.subs[name].schema))
		end
		o[#o + 1] = ""
	end
	o[#o + 1] = "-- 3) Mengirim ke server (AKTIF, bukan bagian debugger). Struct dari sampel terakhir:"
	if s then
		o[#o + 1] = "local sample = " .. luaSrc(s.data, 0, 0, {})
		o[#o + 1] = "-- packet.send(sample)"
	else
		o[#o + 1] = "-- (belum ada sampel; rekam dulu)"
		o[#o + 1] = "-- packet.send({ ... })"
	end
	o[#o + 1] = ""
	o[#o + 1] = "-- Struct:"
	local decl = declaredText(e)
	for line in (decl .. "\n"):gmatch("(.-)\n") do o[#o + 1] = "-- " .. line end
	return table.concat(o, "\n") .. "\n"
end

local DOC_INTRO = [==[
## Konsep ByteNet singkat

- **Packet** = definisi pesan dengan `id` unik, struct data, dan channel.
- **reliable** (default): lewat RemoteEvent. Urutan terjamin dan pasti sampai.
- **unreliable**: lewat UnreliableRemoteEvent. Bisa hilang atau tidak berurutan, ukuran dibatasi. Cocok untuk data sering seperti posisi.
- Arah **IN** = server ke client (response / push). Arah **OUT** = client ke server (request).
- **Sub-packet** = satu packet bisa membawa banyak jenis pesan, dibedakan lewat satu field (mis. `packet`, `type`, `action`, `message`).
- Data yang dilihat debugger adalah hasil decode (table), bukan buffer mentah.

## Cara mengambil data dari StructScope untuk script baru

```lua
local SS = getgenv().StructScope            -- StructScope harus sudah jalan

local packet = SS.Packets.get("NamaPacket") -- objek ByteNet asli
local info   = SS.Packets.info("NamaPacket")-- id, channel, struct, schema, counts, subs

-- pantau semua packet (pasif); sub = jenis pesan di dalam packet
local off = SS.Subscribe(function(name, dir, chan, data, entry, sub)
	print(name, sub, dir, chan, data)
end)
```

## Arti tanda channel

| Tanda | Arti |
| --- | --- |
| R / U | reliable / unreliable, pasti (declared atau OUT teramati) |
| R~ / U~ | tebakan dari RemoteEvent yang memicu packet |
| ? | belum diketahui |
]==]

local function docsMarkdown()
	local list = sortedEntries()
	local o = {
		"# Dokumentasi Packet ByteNet", "",
		("- PlaceId: `%s`"):format(tostring(game.PlaceId)),
		("- Dibuat: %s"):format(os.date("%Y-%m-%d %H:%M:%S")),
		("- Jumlah packet: %d"):format(#list),
		("- Dibuat oleh: StructScope v%s"):format(VERSION), "",
		"## Ringkasan packet", "",
		"| ID | Nama | Channel | Arah | IN | OUT | Sub | Struct |",
		"| --- | --- | --- | --- | --- | --- | --- | --- |",
	}
	for _, e in ipairs(list) do
		local dirs = (e.cIn > 0 and e.cOut > 0) and "IN/OUT" or (e.cIn > 0 and "IN" or (e.cOut > 0 and "OUT" or "-"))
		local c = chanInfo(e)
		o[#o + 1] = ("| %s | `%s` | %s | %s | %d | %d | %d | %s |"):format(
			tostring(e.id or "?"), e.short, c or "?", dirs, e.cIn, e.cOut, e.subCount, mdEscape(structSummary(e)))
	end
	o[#o + 1] = ""
	o[#o + 1] = DOC_INTRO
	o[#o + 1] = ""
	o[#o + 1] = "## Detail packet"
	for _, e in ipairs(list) do
		o[#o + 1] = ""
		o[#o + 1] = ("### %s (id %s)"):format(e.short, tostring(e.id or "?"))
		o[#o + 1] = ""
		o[#o + 1] = ("- Nama lengkap: `%s`"):format(e.name)
		o[#o + 1] = ("- Channel: **%s**"):format(chanText(e))
		o[#o + 1] = ("- %s"):format(countsLine(e))
		o[#o + 1] = ""
		local src, rows = structRows(e)
		if src then
			o[#o + 1] = ("**Struct** (%s)"):format(src)
			o[#o + 1] = ""
			for _, l in ipairs(mdRows(rows)) do o[#o + 1] = l end
			o[#o + 1] = ""
		end
		o[#o + 1] = "```lua"
		o[#o + 1] = declaredText(e)
		o[#o + 1] = "```"
	end
	return table.concat(o, "\n") .. "\n"
end

------------------------------------------------------------------
-- DOCS FOLDER (Markdown rapi, dipisah per kategori)
------------------------------------------------------------------
local function pktFile(e)
	return (e.id and string.format("%03d", e.id) or "xxx") .. "_" .. safeName(e.short)
end

local function mdLastSample(s)
	if not s then return {} end
	return { "", ("Contoh data (%s, %s):"):format(s.dir, s.chan or "?"), "", "```lua", "return " .. luaSrc(s.data, 0, 0, {}), "```" }
end

local function mdPacketDoc(e)
	local o = {
		("# %s (id %s)"):format(e.short, tostring(e.id or "?")), "",
		("[Kembali ke overview](../overview.md)"), "",
		("- Nama lengkap: `%s`"):format(e.name),
		("- Channel: **%s**"):format(chanText(e)),
		("- Kategori dominan: %s"):format(topCat(e)),
		("- %s"):format(countsLine(e)),
		("- Field pembeda sub-packet: %s | jumlah jenis: %d"):format(e.discKey and ("`" .. e.discKey .. "`") or "-", e.subCount), "",
	}
	local src, rows = structRows(e)
	o[#o + 1] = ("## Struct (%s)"):format(src or "belum ada data")
	o[#o + 1] = ""
	if src then for _, l in ipairs(mdRows(rows)) do o[#o + 1] = l end else o[#o + 1] = "_Belum ada data. Lakukan aksi terkait di game dengan Rekam Packet aktif._" end
	o[#o + 1] = ""
	o[#o + 1] = "## Definisi ByteNet (declared)"
	o[#o + 1] = ""
	o[#o + 1] = "```lua"
	o[#o + 1] = declaredText(e)
	o[#o + 1] = "```"
	if e.schema then
		o[#o + 1] = ""
		o[#o + 1] = "## Tebakan ByteNet (observed)"
		o[#o + 1] = ""
		o[#o + 1] = "```lua"
		o[#o + 1] = guessText(e)
		o[#o + 1] = "```"
	end
	if e.subCount > 0 then
		o[#o + 1] = ""
		o[#o + 1] = ("## Sub-packet (detail di [subpackets/%s.md](../subpackets/%s.md))"):format(pktFile(e), pktFile(e))
		o[#o + 1] = ""
		o[#o + 1] = "| Sub | N | IN | OUT | Kategori | Field |"
		o[#o + 1] = "| --- | --- | --- | --- | --- | --- |"
		for _, name in ipairs(sortedSubNames(e)) do
			local s = e.subs[name]
			o[#o + 1] = ("| `%s` | %d | %d | %d | %s | %s |"):format(mdEscape(name), s.n, s.inN, s.outN, s.cat or "-", mdEscape(fieldsInline(s.schema)))
		end
	end
	for _, l in ipairs(mdLastSample(e.samples[#e.samples])) do o[#o + 1] = l end
	return table.concat(o, "\n") .. "\n"
end

local function mdSubDoc(e)
	local o = {
		("# Sub-packet: %s (id %s)"):format(e.short, tostring(e.id or "?")), "",
		("[Packet](../packets/%s.md) | [Kembali ke overview](../overview.md)"):format(pktFile(e)), "",
		("Field pembeda: `%s` | %d jenis%s"):format(tostring(e.discKey or "?"), e.subCount, e.subOver and (" (+" .. e.subOver .. " data di luar batas)") or ""), "",
	}
	for _, name in ipairs(sortedSubNames(e)) do
		local s = e.subs[name]
		o[#o + 1] = ("## %s = `%s`"):format(tostring(e.discKey or "?"), name)
		o[#o + 1] = ""
		o[#o + 1] = ("- N: %d (IN %d / OUT %d) | channel R %d / U %d | kategori %s | pertama %s | terakhir %s"):format(s.n, s.inN, s.outN, s.R, s.U, s.cat or "-", s.first or "-", s.last or "-")
		o[#o + 1] = ""
		if s.schema then
			for _, l in ipairs(mdRows(schemaRows(s.schema))) do o[#o + 1] = l end
			o[#o + 1] = ""
			o[#o + 1] = "```lua"
			o[#o + 1] = nodeExpr(s.schema, 0)
			o[#o + 1] = "```"
		end
		for _, l in ipairs(mdLastSample(s.samples[#s.samples])) do o[#o + 1] = l end
		o[#o + 1] = ""
	end
	return table.concat(o, "\n") .. "\n"
end

local function mdOverview(list)
	local o = {
		"# Overview packet", "",
		"| ID | Nama | Channel | Arah | IN | OUT | Sub | Kategori | Struct | Dokumen |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	}
	for _, e in ipairs(list) do
		local dirs = (e.cIn > 0 and e.cOut > 0) and "IN/OUT" or (e.cIn > 0 and "IN" or (e.cOut > 0 and "OUT" or "-"))
		local c = chanInfo(e)
		o[#o + 1] = ("| %s | `%s` | %s | %s | %d | %d | %d | %s | %s | [packet](packets/%s.md) |"):format(
			tostring(e.id or "?"), e.short, c or "?", dirs, e.cIn, e.cOut, e.subCount, topCat(e), mdEscape(structSummary(e)), pktFile(e))
	end
	return table.concat(o, "\n") .. "\n"
end

local function mdStructIndex(list)
	local o = { "# Tabel struct semua packet", "", "Declared dipakai bila definisi ByteNet terbaca, jika tidak dipakai observed (dipelajari dari data nyata).", "" }
	for _, e in ipairs(list) do
		local src, rows = structRows(e)
		o[#o + 1] = ("## %s (id %s) - %s"):format(e.short, tostring(e.id or "?"), src or "belum ada data")
		o[#o + 1] = ""
		o[#o + 1] = ("Channel: %s | [dokumen](../packets/%s.md)"):format(chanText(e), pktFile(e))
		o[#o + 1] = ""
		if src then for _, l in ipairs(mdRows(rows)) do o[#o + 1] = l end else o[#o + 1] = "_belum ada data_" end
		o[#o + 1] = ""
	end
	return table.concat(o, "\n") .. "\n"
end

local function mdSubIndex(list)
	local o = {
		"# Sub-packet semua packet", "",
		"| Packet | Field pembeda | Sub | N | IN | OUT | Kategori | Field | Dokumen |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	}
	for _, e in ipairs(list) do
		for _, name in ipairs(sortedSubNames(e)) do
			local s = e.subs[name]
			o[#o + 1] = ("| `%s` | `%s` | `%s` | %d | %d | %d | %s | %s | [detail](%s.md) |"):format(
				e.short, tostring(e.discKey or "?"), mdEscape(name), s.n, s.inN, s.outN, s.cat or "-", mdEscape(fieldsInline(s.schema)), pktFile(e))
		end
	end
	if #o == 4 then o[#o + 1] = "| _belum ada sub-packet terdeteksi_ | | | | | | | | |" end
	return table.concat(o, "\n") .. "\n"
end

local function mdCategory(cat, list)
	local o = { ("# Kategori: %s"):format(cat), "", "| ID | Packet | Jumlah | Sub-packet kategori ini | Dokumen |", "| --- | --- | --- | --- | --- |" }
	local any = false
	for _, e in ipairs(list) do
		local n = e.cats[cat] or 0
		if n > 0 then
			any = true
			local subs = {}
			for _, name in ipairs(sortedSubNames(e)) do
				if e.subs[name].cat == cat then
					subs[#subs + 1] = name
					if #subs >= 15 then subs[#subs + 1] = "..." break end
				end
			end
			o[#o + 1] = ("| %s | `%s` | %d | %s | [packet](../packets/%s.md) |"):format(tostring(e.id or "?"), e.short, n, mdEscape(table.concat(subs, ", ")), pktFile(e))
		end
	end
	if not any then o[#o + 1] = "| _belum ada data_ | | | | |" end
	return table.concat(o, "\n") .. "\n"
end

local function mdCoverage(list)
	local noData, onlyIn, onlyOut, noChan, obsOnly, total = {}, {}, {}, {}, {}, #list
	local subTotal = 0
	for _, e in ipairs(list) do
		subTotal += e.subCount
		if e.cIn + e.cOut == 0 then noData[#noData + 1] = e.short
		elseif e.cOut == 0 then onlyIn[#onlyIn + 1] = e.short
		elseif e.cIn == 0 then onlyOut[#onlyOut + 1] = e.short end
		if not chanInfo(e) then noChan[#noChan + 1] = e.short end
		if not introspect(e) then obsOnly[#obsOnly + 1] = e.short end
	end
	local function block(title, items, hint)
		local o = { "## " .. title .. (" (%d)"):format(#items), "" }
		if hint then o[#o + 1] = "_" .. hint .. "_" o[#o + 1] = "" end
		if #items == 0 then o[#o + 1] = "- (tidak ada)" else
			for i, n in ipairs(items) do
				if i > 200 then o[#o + 1] = "- ..." break end
				o[#o + 1] = "- `" .. n .. "`"
			end
		end
		o[#o + 1] = ""
		return table.concat(o, "\n")
	end
	local s = sumCounts()
	local head = {
		"# Coverage debug", "",
		"Seberapa lengkap data yang sudah direkam. Lakukan lebih banyak aksi di game untuk menutup bagian yang kosong.", "",
		("- Packet terdaftar: %d"):format(total),
		("- Sudah ada data: %d (%.0f%%)"):format(total - #noData, total > 0 and (total - #noData) / total * 100 or 0),
		("- Total sub-packet terdeteksi: %d"):format(subTotal),
		("- Struct declared terbaca: %d | hanya observed: %d"):format(total - #obsOnly, #obsOnly),
		("- Total IN %d | OUT %d"):format(s.inR + s.inU + s.inX, s.outR + s.outU + s.outX),
		("- Log tersimpan: %d entri | chat: %d"):format(#Store.log, #Store.chat), "",
	}
	return table.concat(head, "\n") .. "\n"
		.. block("Packet tanpa data", noData, "Belum pernah muncul. Pancing lewat aksi di game.")
		.. block("Hanya IN (belum ada request OUT)", onlyIn, "Server push, atau aksi pengirim belum dilakukan.")
		.. block("Hanya OUT (belum ada response IN)", onlyOut)
		.. block("Channel belum diketahui", noChan)
		.. block("Struct hanya observed", obsOnly, "Definisi ByteNet tidak terbaca (executor tanpa getupvalues/debug.info?). Tipe bisa lebih kecil dari aslinya.")
end

local function mdRemotes()
	local o = { "# Remote di ReplicatedStorage", "", "| Path | Class | ByteNet | Channel |", "| --- | --- | --- | --- |" }
	for _, r in ipairs(remoteList) do
		o[#o + 1] = ("| `%s` | %s | %s | %s |"):format(mdEscape(r.path), r.class, r.bytenet and "ya" or "tidak", r.bytenet and r.chan or "-")
	end
	if #remoteList == 0 then o[#o + 1] = "| _belum discan. Nyalakan Rekam Packet_ | | | |" end
	return table.concat(o, "\n") .. "\n"
end

local function mdLogAll()
	local o = { "# Log packet", "", ("Total %d entri (terbaru di bawah). OUT = request, IN = response/push."):format(#Store.log), "", "```text" }
	for _, r in ipairs(Store.log) do o[#o + 1] = recLine(r, false) end
	o[#o + 1] = "```"
	return table.concat(o, "\n") .. "\n"
end

local function gameName()
	if state.gameName then return state.gameName end
	local name = "Game"
	pcall(function() name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
	state.gameName = name
	return name
end

local function gameFolder()
	return safeName(gameName()):sub(1, 40) .. "_" .. tostring(game.PlaceId)
end

local function buildDocFiles()
	local list = sortedEntries()
	local files = {}
	local function add(path, text) files[#files + 1] = { path, text } end

	local gname = gameName()
	add("README.md", table.concat({
		("# StructScope - %s"):format(gname), "",
		("- PlaceId: `%s`"):format(tostring(game.PlaceId)),
		("- Dibuat: %s oleh StructScope v%s"):format(os.date("%Y-%m-%d %H:%M:%S"), VERSION),
		("- Packet: %d | log: %d | chat: %d"):format(#list, #Store.log, #Store.chat), "",
		"## Daftar isi", "",
		"| File | Isi |", "| --- | --- |",
		"| [overview.md](overview.md) | Tabel ringkas semua packet, link ke dokumen per packet |",
		"| [coverage.md](coverage.md) | Kelengkapan data: packet kosong, hanya IN/OUT, struct observed |",
		"| [channels.md](channels.md) | Statistik reliable / unreliable dan packet teramai |",
		"| [remotes.md](remotes.md) | Daftar remote di ReplicatedStorage |",
		"| [structs/index.md](structs/index.md) | Tabel struct semua packet |",
		"| [subpackets/index.md](subpackets/index.md) | Semua sub-packet (jenis pesan di dalam packet) |",
		"| [categories/chat.md](categories/chat.md) | Packet kategori chat |",
		"| [categories/movement.md](categories/movement.md) | Packet kategori movement |",
		"| [categories/other.md](categories/other.md) | Packet kategori lain |",
		"| [logs/packet_log.md](logs/packet_log.md) | Log packet (teks) |",
		"| [logs/chat.md](logs/chat.md) | Chat log |",
		"| [lua/Packets.lua](lua/Packets.lua) | Modul definePacket hasil generate |",
		"| [lua/registry.lua](lua/registry.lua) | Tabel packet (Lua) |",
		"| `packets/` | Satu dokumen per packet |",
		"| `subpackets/` | Detail sub-packet per packet |",
		"| `lua/templates/` | Template script per packet |",
		"| `data/` | Log dan chat sebagai Lua table |", "",
	}, "\n"))
	add("overview.md", mdOverview(list))
	add("coverage.md", mdCoverage(list))
	add("channels.md", "# Statistik channel\n\n```text\n" .. channelStatsText() .. "\n```\n")
	add("remotes.md", mdRemotes())
	add("structs/index.md", mdStructIndex(list))
	add("subpackets/index.md", mdSubIndex(list))
	for _, cat in ipairs({ "chat", "movement", "other" }) do add("categories/" .. cat .. ".md", mdCategory(cat, list)) end
	add("logs/packet_log.md", mdLogAll())
	local chatLines = { "# Chat log", "", "```text" }
	for _, c in ipairs(Store.chat) do chatLines[#chatLines + 1] = ("[%s] %-3s %s: %s <%s>"):format(c.time, c.dir, tostring(c.player), tostring(c.message), c.packet) end
	chatLines[#chatLines + 1] = "```"
	add("logs/chat.md", table.concat(chatLines, "\n") .. "\n")
	add("lua/Packets.lua", frameworkModule())
	add("lua/registry.lua", registryLua())
	add("data/log.lua", logToLua(Store.log, "Packet log (semua)"))
	add("data/chat.lua", chatToLua())
	for i, e in ipairs(list) do
		local f = pktFile(e)
		add("packets/" .. f .. ".md", mdPacketDoc(e))
		if e.subCount > 0 then add("subpackets/" .. f .. ".md", mdSubDoc(e)) end
		add("lua/templates/" .. f .. ".lua", templateText(e))
		if i % 25 == 0 then task.wait() end
	end
	return files
end

------------------------------------------------------------------
-- RENDER (pilihan tampilan viewer)
------------------------------------------------------------------
local MODES = {
	{ key = "full",      label = "Struct lengkap",               needsPacket = true },
	{ key = "declared",  label = "Declared (definisi ByteNet)",  needsPacket = true },
	{ key = "observed",  label = "Observed (tabel field)",       needsPacket = true },
	{ key = "subs",      label = "Sub-packet (terpilih)",        needsPacket = true },
	{ key = "substruct", label = "Struct sub-packet (detail)",   needsPacket = true },
	{ key = "sample",    label = "Sample terakhir (tree)",       needsPacket = true },
	{ key = "samples",   label = "Semua sampel (Lua table)",     needsPacket = true },
	{ key = "template",  label = "Template script (terpilih)",   needsPacket = true },
	{ key = "structs",   label = "TABEL STRUCT (semua packet)" },
	{ key = "subs_all",  label = "Sub-packet (semua packet)" },
	{ key = "registry",  label = "Tabel packet (semua)" },
	{ key = "stats",     label = "Statistik channel (R/U)" },
	{ key = "log",       label = "Log packet (sesuai filter)" },
	{ key = "chat",      label = "Chat log" },
	{ key = "feed",      label = "Live feed ringkas" },
	{ key = "report",    label = "Laporan SEMUA packet" },
	{ key = "framework", label = "Modul Packets.lua (framework)" },
	{ key = "docs",      label = "Dokumentasi Markdown" },
}
local MODE_LABELS, MODE_BY_LABEL, MODE_BY_KEY = {}, {}, {}
for i, m in ipairs(MODES) do
	MODE_LABELS[i] = m.label
	MODE_BY_LABEL[m.label] = m
	MODE_BY_KEY[m.key] = m
end

local function render()
	local m, e = MODE_BY_KEY[state.view] or MODES[1], state.selected
	if m.needsPacket and not e then return "(pilih packet dulu di dropdown)", "-" end
	local k = m.key
	if k == "full" then return packetReport(e), headerOf(e)
	elseif k == "declared" then return declaredText(e), "Declared - " .. headerOf(e)
	elseif k == "observed" then return observedText(e) .. "\n\n" .. guessText(e), "Observed - " .. headerOf(e)
	elseif k == "subs" then return subsText(e), "Sub-packet - " .. headerOf(e)
	elseif k == "substruct" then return subDetailText(e, state.selectedSub), "Struct sub - " .. headerOf(e) .. (state.selectedSub and (" / " .. state.selectedSub) or "")
	elseif k == "sample" then return lastSampleText(e), "Sample - " .. headerOf(e)
	elseif k == "samples" then return samplesText(e), "Sampel - " .. headerOf(e)
	elseif k == "template" then return templateText(e), "Template - " .. headerOf(e)
	elseif k == "structs" then return structTableText(), "Tabel struct"
	elseif k == "subs_all" then return subsAllText(), "Sub-packet semua"
	elseif k == "registry" then return summaryText(), "Tabel packet"
	elseif k == "stats" then return channelStatsText(), "Statistik channel"
	elseif k == "log" then return (logText()), "Log packet"
	elseif k == "chat" then return chatText(), "Chat log"
	elseif k == "feed" then return feedText(), "Live feed"
	elseif k == "framework" then return frameworkModule(), "Packets.lua"
	elseif k == "docs" then return docsMarkdown(), "Dokumentasi"
	end
	return allReport(), "Laporan semua packet"
end

------------------------------------------------------------------
-- PANEL TEKS (viewer + log) dengan scroll dua arah
------------------------------------------------------------------
local Panels = {}

local function makePanel(gb, stick)
	local P = { full = "", stick = stick }
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 300)
	holder.BackgroundColor3 = Library.OutlineColor
	holder.BorderSizePixel = 0
	holder.Parent = gb.Container
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 8)
	hc.Parent = holder

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -2, 1, -2)
	scroll.Position = UDim2.fromOffset(1, 1)
	scroll.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.Parent = holder
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = scroll

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.XY
	box.Position = UDim2.fromOffset(4, 4)
	box.BackgroundTransparency = 1
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextEditable = false
	box.TextWrapped = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Font = Enum.Font.Code
	box.TextSize = 12
	box.TextColor3 = Color3.fromRGB(215, 222, 240)
	box.Text = ""
	box.Parent = scroll
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(200, 100)
	minSize.Parent = box

	P.holder, P.scroll, P.box = holder, scroll, box

	function P.set(text, limit)
		text = CFG.Ascii and ascii(text) or text
		P.full = text
		limit = limit or CFG.TextLimit
		local shown = text
		if #text > limit then
			if P.stick then
				shown = ("... [bagian awal dipotong, total %d karakter. Pakai Copy / Save untuk teks penuh]\n"):format(#text) .. text:sub(-limit)
			else
				shown = text:sub(1, limit) .. ("\n\n... [dipotong, total %d karakter. Pakai Copy / Save untuk teks penuh]"):format(#text)
			end
		end
		local atBottom = false
		if P.stick then
			atBottom = scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y >= scroll.AbsoluteCanvasSize.Y - 40
		end
		box.Text = shown
		if atBottom and state.logFollow ~= false then
			task.defer(function()
				pcall(function() scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, 1e7) end)
			end)
		end
	end
	Panels[#Panels + 1] = P
	return P
end

-- tinggi panel mengikuti tinggi menu
Library:OnResize(function(bw, bh, compact)
	local h = compact and math.max(170, bh - 90) or math.max(170, bh - 108)
	for _, P in ipairs(Panels) do
		pcall(function() P.holder.Size = UDim2.new(1, 0, 0, h) end)
	end
end)

local Viewer = { full = "", title = "" }

function Viewer.set(text, ttl)
	ttl = CFG.Ascii and ascii(ttl or "") or (ttl or "")
	Viewer.title = ttl
	if Viewer.panel then Viewer.panel.set(text) Viewer.full = Viewer.panel.full else Viewer.full = text end
	if Viewer.titleLabel then
		pcall(function() Viewer.titleLabel:SetText("Tampil: " .. ttl) end)
	end
end

local function tabVisible(tab)
	if Library.Toggled == false or state.minimized then return false end
	local ok, vis = pcall(function() return tab.Container.Visible end)
	return ok and vis == true
end

function Viewer.show()
	if Viewer.tab then pcall(function() Viewer.tab:ShowTab() end) end
end

------------------------------------------------------------------
-- FILE (single + docs folder)
------------------------------------------------------------------
local madeDirs = {}
local function ensureDirOnce(dir)
	if madeDirs[dir] then return end
	pcall(function()
		if makefolder and not (isfolder and isfolder(dir)) then makefolder(dir) end
	end)
	madeDirs[dir] = true
end

local function ensureParents(path)
	local acc
	for seg in path:gmatch("([^/]+)/") do
		acc = acc and (acc .. "/" .. seg) or seg
		ensureDirOnce(acc)
	end
end

local function writePath(path, text)
	if not writefile then return false end
	ensureParents(path)
	if CFG.Ascii then text = ascii(text) end
	return (pcall(writefile, path, text))
end

local function writeOut(prefix, text, ext)
	ext = ext or "txt"
	if not writefile then return nil, "writefile tidak didukung executor" end
	local path = ("StructScope/%s_%d.%s"):format(prefix, os.time(), ext)
	if not writePath(path, text) then
		path = ("%s_%d.%s"):format(prefix, os.time(), ext)
		if not pcall(writefile, path, CFG.Ascii and ascii(text) or text) then return nil, "gagal menulis file" end
	end
	return path
end

local saving = false
local function saveDocs(snapshot, quiet)
	if not writefile then notify("writefile tidak didukung executor.", 4) return end
	if #entries == 0 then notify("Belum ada packet. Scan / rekam dulu.", 3) return end
	if saving then notify("Penyimpanan docs masih berjalan.", 2) return end
	saving = true
	state.lastSave = os.clock()
	task.spawn(function()
		local root
		local ok, err = pcall(function()
			root = "StructScope/" .. gameFolder() .. "/" .. (snapshot and ("snapshot_" .. os.date("%Y%m%d_%H%M%S")) or "latest")
			local files = buildDocFiles()
			local okN = 0
			for i, f in ipairs(files) do
				if writePath(root .. "/" .. f[1], f[2]) then okN += 1 end
				if i % 10 == 0 then task.wait() end
			end
			if not quiet or okN < #files then
				notify(("Docs disimpan: %d/%d file di workspace/%s"):format(okN, #files, root), 7)
			end
		end)
		saving = false
		if not ok then notify("Simpan docs gagal: " .. tostring(err), 6) end
	end)
end

local function currentText()
	local text, title = render()
	return CFG.Ascii and ascii(text) or text, title
end

local function showView()
	local text, title = render()
	Viewer.set(text, title)
	Viewer.show()
	state.dirty = false
end

------------------------------------------------------------------
-- START / STOP
------------------------------------------------------------------
local labelMap = {}
local ddPacket, ddMute, ddSub, ddLogPkt, ddLogSub, statusLabel, statLabel, modeDD, logLabel, logPanel

local function labelOf(e) return ("%s (id %s)"):format(e.short, tostring(e.id or "?")) end

local function refreshSubDD()
	local list = { "(semua)" }
	local e = state.selected
	if e then
		for i, n in ipairs(sortedSubNames(e)) do
			if i > 150 then break end
			list[#list + 1] = n
		end
	end
	if ddSub then
		pcall(function()
			ddSub:SetValues(list)
			local v = ddSub.Value
			state.selectedSub = (v and v ~= "(semua)") and v or nil
		end)
	end
end

local function refreshLogSubDD()
	local names, set = {}, {}
	local function addE(e)
		for n in pairs(e.subs) do
			if not set[n] then set[n] = true names[#names + 1] = n end
		end
	end
	if logCfg.pkt ~= "Semua" then
		local e = byName[logCfg.pkt:lower()]
		if e then addE(e) end
	else
		for _, e in ipairs(entries) do addE(e) end
	end
	table.sort(names)
	local list = { "Semua" }
	for i, n in ipairs(names) do
		if i > 200 then break end
		list[#list + 1] = n
	end
	if ddLogSub then
		pcall(function()
			ddLogSub:SetValues(list)
			logCfg.sub = ddLogSub.Value or "Semua"
		end)
	end
end

local function refreshLists()
	state.listDirty = false
	labelMap = {}
	local labels, names, seenName = {}, {}, {}
	for _, e in ipairs(sortedEntries()) do
		local lab = labelOf(e)
		if labelMap[lab] then lab = lab .. " #" .. (#labels + 1) end
		if state.filter == "" or lab:lower():find(state.filter, 1, true) then
			labels[#labels + 1] = lab
			labelMap[lab] = e
		end
		if not seenName[e.short] then
			seenName[e.short] = true
			names[#names + 1] = e.short
		end
	end
	if #labels == 0 then labels = { "(tidak ada packet)" } end
	local muteNames = #names > 0 and names or { "(tidak ada packet)" }
	if ddPacket then pcall(function() ddPacket:SetValues(labels) end) end
	if ddMute then pcall(function() ddMute:SetValues(muteNames) end) end
	if ddLogPkt then
		local lp = { "Semua" }
		for _, n in ipairs(names) do lp[#lp + 1] = n end
		pcall(function()
			ddLogPkt:SetValues(lp)
			logCfg.pkt = ddLogPkt.Value or "Semua"
		end)
	end
	if not state.selected and labelMap[labels[1]] then
		state.selected = labelMap[labels[1]]
		if ddPacket then pcall(function() ddPacket:SetValue(labels[1]) end) end
	end
	refreshSubDD()
	refreshLogSubDD()
end

local starting = false
local function startSpy()
	if starting then return end
	starting = true
	state.active = true
	state.t0 = state.t0 or os.clock()
	notify("Scan packet ByteNet ...", 3)
	connectChatService()
	task.spawn(function()
		local added = scanPackets()
		for _, e in ipairs(entries) do attach(e) end
		local okC, errC = installClientHook()
		if not okC then
			for _, e in ipairs(entries) do wrapSendFallback(e) end
		end
		local nRem = connectRemotes()
		state.lastScan = os.clock()
		refreshLists()
		starting = false
		markDirty()
		notify(("Aktif: %d packet (%d baru), remote %d. OUT: %s"):format(
			#entries, added, nRem, okC and "hook process.client" or ("fallback obj.send (" .. tostring(errC) .. ")")), 6)
	end)
end

local function stopSpy()
	state.active = false
	for _, e in ipairs(entries) do detach(e) end
	disconnectRemotes()
	if chatConn then pcall(function() chatConn:Disconnect() end) chatConn = nil end
	markDirty()
end

local function clearAll()
	for _, e in ipairs(entries) do resetEntry(e) end
	table.clear(Store.feed)
	table.clear(Store.log)
	table.clear(Store.chat)
	table.clear(Chan.pending)
	Raw.reliable.n, Raw.reliable.bytes, Raw.unreliable.n, Raw.unreliable.bytes = 0, 0, 0, 0
	logCfg.seq, logCfg.dropped = 0, 0
	state.t0 = state.active and os.clock() or nil
	refreshSubDD()
	refreshLogSubDD()
	markDirty()
end

------------------------------------------------------------------
-- API UNTUK SCRIPT BARU: getgenv().StructScope
------------------------------------------------------------------
local function lookup(k)
	if type(k) == "number" then return byId[k] end
	if type(k) == "string" then return byName[k:lower()] end
	return nil
end

local API = {
	Version = VERSION,
	Packets = {
		get = function(k) local e = lookup(k) return e and e.obj or nil end,
		info = function(k)
			local e = lookup(k)
			if not e then return nil end
			local c, src = chanInfo(e)
			return {
				id = e.id, name = e.short, fullName = e.name, channel = c, source = src,
				struct = introspect(e), schema = e.schema, discriminator = e.discKey, subs = e.subs,
				counts = { inR = e.inR, inU = e.inU, inX = e.inX, outR = e.outR, outU = e.outU, outX = e.outX },
				samples = e.samples,
			}
		end,
		subs = function(k) local e = lookup(k) return e and e.subs or nil end,
		list = function()
			local out = {}
			for _, e in ipairs(sortedEntries()) do out[#out + 1] = e.short end
			return out
		end,
	},
	Subscribe = function(cb)
		if type(cb) ~= "function" then return function() end end
		Subs[#Subs + 1] = cb
		return function()
			local i = table.find(Subs, cb)
			if i then table.remove(Subs, i) end
		end
	end,
	Log = Store.log,
	Chat = Store.chat,
	Stats = function()
		local s = sumCounts()
		s.rawReliable, s.rawUnreliable = Raw.reliable, Raw.unreliable
		return s
	end,
	Export = { framework = frameworkModule, docs = docsMarkdown, report = allReport, structs = structTableText },
	SaveDocs = function(snapshot) saveDocs(snapshot and true or false, false) end,
}

------------------------------------------------------------------
-- SCRIPT HUB UI
------------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "StructScope",
	Subtitle = "Rekam - Struct - Docs",
	Version = VERSION,
	AutoShow = true,
	ToggleKey = CFG.MenuKey,
	Size = UDim2.fromOffset(820, 500),
})

local Tabs = {
	Main   = Window:AddTab("Utama"),
	View   = Window:AddTab("Viewer", { Split = 0.62 }),
	Log    = Window:AddTab("Log", { Split = 0.62 }),
	Struct = Window:AddTab("Struct"),
	Save   = Window:AddTab("Simpan"),
	Theme  = Window:AddTab("Tema"),
	Info   = Window:AddTab("Info"),
}
Viewer.tab = Tabs.View

local WinCtl = { minimized = false }
function WinCtl.toggle() Window:SetMinimized(not WinCtl.minimized) end
function WinCtl.unload()
	local fn = getgenv and getgenv().__StructScopeUnload
	if fn then fn() else pcall(function() Library:Unload() end) end
end
Window.OnMinimized = function(v)
	WinCtl.minimized = v
	state.minimized = v
	markDirty()
end
do
	local armed = false
	Window.OnClose = function()
		if not armed then
			armed = true
			notify("Klik X sekali lagi untuk menutup semua.", 3)
			task.delay(3, function() armed = false end)
			return
		end
		WinCtl.unload()
	end
end

local function doCopy(text, label)
	if CFG.Ascii then text = ascii(text) end
	notify(clip(text) and ("%s disalin (%d karakter)."):format(label, #text) or "setclipboard tidak didukung executor.", 3)
end

local function doSave(prefix, text, ext)
	local path, err = writeOut(prefix, text, ext)
	notify(path and ("Disimpan: " .. path) or tostring(err), 6)
	return path
end

local function packetDefText(e)
	return "-- DECLARED\n" .. declaredText(e) .. "\n\n-- TEBAKAN dari data observed\n" .. guessText(e)
end

local function logLua()
	local list = filteredLog()
	if #list == 0 then notify("Tidak ada log yang cocok filter.", 3) return nil end
	return logToLua(list, "Packet log (filter aktif)")
end

local function chatLua()
	if #Store.chat == 0 then notify("Belum ada chat terdeteksi.", 3) return nil end
	return chatToLua()
end

local function needSelected()
	if not state.selected then notify("Pilih packet dulu di tab Viewer.", 3) return nil end
	return state.selected
end

local function jumpView(key)
	state.view = key
	local m = MODE_BY_KEY[key]
	if m and modeDD then pcall(function() modeDD:SetValue(m.label) end) end
	state.view = key
	showView()
end

------------------------------------------------------------------
-- TAB UTAMA
------------------------------------------------------------------
local GBControl = Tabs.Main:AddLeftGroupbox("Kontrol")
GBControl:AddToggle("SS_Rec", {
	Text = "Rekam Packet (pasif)",
	Default = false,
	Tooltip = "Scan packet, pasang listener IN, hook OUT, dan pantau RemoteEvent. Hanya merekam.",
	Callback = function(v)
		if v then startSpy() else stopSpy() notify("Rekam dihentikan (data tetap tersimpan).", 3) end
	end,
})
GBControl:AddButton({
	Text = "Scan Ulang Packet",
	Func = function()
		task.spawn(function()
			local n = scanPackets()
			if state.active then
				for _, e in ipairs(entries) do attach(e) end
			end
			refreshLists()
			notify(("Scan selesai: %d packet baru, total %d."):format(n, #entries), 4)
		end)
	end,
})
GBControl:AddButton({ Text = "Buka Viewer", Func = showView })
GBControl:AddButton({ Text = "Kecilkan / Perbesar Menu", Func = function() WinCtl.toggle() end })
GBControl:AddButton({
	Text = "Clear Semua Data",
	Func = function() clearAll() notify("Data packet dibersihkan.", 2) end,
})
statusLabel = GBControl:AddLabel("Status: belum aktif", true)

local GBStat = Tabs.Main:AddRightGroupbox("Statistik Channel")
statLabel = GBStat:AddLabel("Belum ada data", true)
GBStat:AddButton({ Text = "Lihat Statistik di Viewer", Func = function() jumpView("stats") end })

local GBQuick = Tabs.Main:AddRightGroupbox("Jalan Pintas")
GBQuick:AddButton({ Text = "Simpan Docs Lengkap (folder rapi)", Func = function() saveDocs(false, false) end })
GBQuick:AddButton({ Text = "Tabel Struct semua packet", Func = function() jumpView("structs") end })
GBQuick:AddButton({ Text = "Tutup Semua (Unload)", Func = function() WinCtl.unload() end })

------------------------------------------------------------------
-- TAB VIEWER
------------------------------------------------------------------
local GBText = Tabs.View:AddLeftGroupbox("Isi Struct")
Viewer.titleLabel = GBText:AddLabel("Tampil: -")
Viewer.panel = makePanel(GBText, false)

local GBPick = Tabs.View:AddRightGroupbox("Lihat Struct")
GBPick:AddInput("SS_Filter", {
	Default = "", Finished = false, Text = "Filter nama / ID", Placeholder = "contoh: act atau 12",
	Callback = function(t) state.filter = (t or ""):lower() refreshLists() end,
})
ddPacket = GBPick:AddDropdown("SS_Packet", {
	Values = { "(scan dulu)" }, Default = 1, Multi = false, Text = "Packet",
	Callback = function(v)
		local e = labelMap[v]
		if e then
			state.selected = e
			refreshSubDD()
			markDirty()
		end
	end,
})
ddSub = GBPick:AddDropdown("SS_Sub", {
	Values = { "(semua)" }, Default = 1, Multi = false, Text = "Sub-packet (message / type di dalam packet)",
	Callback = function(v)
		state.selectedSub = (v and v ~= "(semua)") and v or nil
		markDirty()
	end,
})
modeDD = GBPick:AddDropdown("SS_Mode", {
	Values = MODE_LABELS, Default = 1, Multi = false, Text = "Tampilan",
	Callback = function(v)
		local m = MODE_BY_LABEL[v]
		if m then state.view = m.key end
		markDirty()
	end,
})
GBPick:AddToggle("SS_Auto", { Text = "Auto-refresh viewer", Default = true, Callback = function(v) state.auto = v end })
GBPick:AddButton({ Text = "Tampilkan / Refresh", Func = showView })
GBPick:AddButton({
	Text = "Copy Isi Viewer",
	Func = function()
		if Viewer.full == "" then return notify("Viewer kosong.", 2) end
		notify(clip(Viewer.full) and "Teks disalin." or "setclipboard tidak didukung.", 2)
	end,
})
GBPick:AddButton({
	Text = "Simpan Isi Viewer",
	Func = function()
		if Viewer.full == "" then return notify("Viewer kosong.", 2) end
		local path, err = writeOut(safeName(Viewer.title), Viewer.full)
		notify(path and ("Disimpan: " .. path) or tostring(err), 6)
	end,
})

------------------------------------------------------------------
-- TAB LOG
------------------------------------------------------------------
local GBLog = Tabs.Log:AddLeftGroupbox("Log Packet (scroll)")
logLabel = GBLog:AddLabel("Belum ada log. Nyalakan Rekam Packet.")
logPanel = makePanel(GBLog, true)

local GBFilter = Tabs.Log:AddRightGroupbox("Filter Log")
GBFilter:AddDropdown("SS_LogDir", {
	Values = { "Semua", "IN", "OUT" }, Default = 1, Multi = false,
	Text = "Arah (OUT = request, IN = response / push)",
	Callback = function(v) logCfg.dir = v markDirty() end,
})
ddLogPkt = GBFilter:AddDropdown("SS_LogPkt", {
	Values = { "Semua" }, Default = 1, Multi = false, Text = "Packet",
	Callback = function(v)
		logCfg.pkt = v or "Semua"
		refreshLogSubDD()
		markDirty()
	end,
})
ddLogSub = GBFilter:AddDropdown("SS_LogSub", {
	Values = { "Semua" }, Default = 1, Multi = false, Text = "Sub-packet / message di dalam packet",
	Callback = function(v) logCfg.sub = v or "Semua" markDirty() end,
})
GBFilter:AddDropdown("SS_LogChan", {
	Values = { "Semua", "reliable", "unreliable", "?" }, Default = 1, Multi = false, Text = "Channel",
	Callback = function(v) logCfg.chan = v markDirty() end,
})
GBFilter:AddDropdown("SS_LogCat", {
	Values = { "Semua", "chat", "movement", "other" }, Default = 1, Multi = false, Text = "Kategori",
	Callback = function(v) logCfg.cat = v markDirty() end,
})
GBFilter:AddInput("SS_LogName", {
	Default = "", Finished = false, Text = "Cari nama / ID / sub", Placeholder = "contoh: chat atau message",
	Callback = function(t) logCfg.name = (t or ""):lower() markDirty() end,
})
GBFilter:AddInput("SS_LogText", {
	Default = "", Finished = false, Text = "Cari isi data", Placeholder = "teks / angka di dalam data",
	Callback = function(t) logCfg.text = (t or ""):lower() markDirty() end,
})
GBFilter:AddSlider("SS_LogLines", {
	Text = "Baris tampil (scroll untuk lihat semua)", Default = state.logLines, Min = 20, Max = 400, Rounding = 0,
	Callback = function(v) state.logLines = v markDirty() end,
})
GBFilter:AddToggle("SS_LogDetail", {
	Text = "Detail data (multi-baris)", Default = false,
	Callback = function(v) state.logDetail = v markDirty() end,
})
GBFilter:AddToggle("SS_LogFollow", {
	Text = "Ikuti log baru (auto-scroll)", Default = true,
	Tooltip = "Hanya mengikuti bila posisi scroll sudah di paling bawah.",
	Callback = function(v) state.logFollow = v end,
})
GBFilter:AddButton({
	Text = "Reset Filter",
	Func = function()
		logCfg.dir, logCfg.cat, logCfg.chan, logCfg.pkt, logCfg.sub, logCfg.name, logCfg.text = "Semua", "Semua", "Semua", "Semua", "Semua", "", ""
		for _, id in ipairs({ "SS_LogDir", "SS_LogPkt", "SS_LogSub", "SS_LogChan", "SS_LogCat" }) do
			local o = Library.Options[id]
			if o then pcall(function() o:SetValue("Semua") end) end
		end
		for _, id in ipairs({ "SS_LogName", "SS_LogText" }) do
			local o = Library.Options[id]
			if o then pcall(function() o:SetValue("") end) end
		end
		markDirty()
	end,
})
GBFilter:AddButton({ Text = "Lihat Chat Log di Viewer", Func = function() jumpView("chat") end })
GBFilter:AddButton({ Text = "Lihat Live Feed di Viewer", Func = function() jumpView("feed") end })

local GBRec = Tabs.Log:AddRightGroupbox("Rekaman")
GBRec:AddSlider("SS_MoveCap", {
	Text = "Movement maks /detik (0 = semua)", Default = CFG.MoveCap, Min = 0, Max = 30, Rounding = 0,
	Callback = function(v) CFG.MoveCap = v end,
})
GBRec:AddSlider("SS_MaxSamples", {
	Text = "Maks sampel per packet", Default = CFG.MaxSamples, Min = 3, Max = 40, Rounding = 0,
	Callback = function(v) CFG.MaxSamples = v end,
})
ddMute = GBRec:AddDropdown("SS_Mute", {
	Values = { "(scan dulu)" }, Multi = true, AllowNull = true, Text = "Mute packet spam",
	Tooltip = "Packet yang dipilih tetap dihitung tapi tidak dicatat / dipelajari.",
	Callback = function(v)
		table.clear(muted)
		if type(v) == "table" then
			for name, on in pairs(v) do
				if on then muted[name] = true end
			end
		end
	end,
})
GBRec:AddToggle("SS_Ascii", {
	Text = "ASCII-safe (cegah huruf kotak)", Default = CFG.Ascii,
	Callback = function(v) CFG.Ascii = v markDirty() end,
})
GBRec:AddToggle("SS_AutoScan", {
	Text = "Auto-scan packet baru (20 detik)", Default = false,
	Tooltip = "getgc cukup berat. Nyalakan hanya jika packet baru sering didefinisikan.",
	Callback = function(v) state.autoScan = v end,
})
GBRec:AddButton({
	Text = "Hapus Log dan Chat Saja",
	Func = function()
		table.clear(Store.log)
		table.clear(Store.chat)
		logCfg.seq, logCfg.dropped = 0, 0
		markDirty()
		notify("Log dan chat dibersihkan.", 2)
	end,
})

------------------------------------------------------------------
-- TAB STRUCT (tabel struct, sub-packet, framework)
------------------------------------------------------------------
local GBStruct = Tabs.Struct:AddLeftGroupbox("Tabel Struct dari Packet")
GBStruct:AddLabel("Struct dibaca dari definisi ByteNet (declared) atau dipelajari dari data nyata (observed). Sub-packet = jenis pesan di dalam satu packet.", true)
GBStruct:AddButton({ Text = "Tabel Struct SEMUA di Viewer", Func = function() jumpView("structs") end })
GBStruct:AddButton({ Text = "Sub-packet SEMUA di Viewer", Func = function() jumpView("subs_all") end })
GBStruct:AddButton({
	Text = "Sub-packet packet terpilih",
	Func = function() if needSelected() then jumpView("subs") end end,
})
GBStruct:AddButton({
	Text = "Struct sub-packet terpilih (detail)",
	Func = function() if needSelected() then jumpView("substruct") end end,
})
GBStruct:AddButton({ Text = "Copy Tabel Struct (teks)", Func = function() doCopy(structTableText(), "Tabel struct") end })
GBStruct:AddButton({
	Text = "Copy Tabel Struct (Markdown)",
	Func = function() doCopy(mdStructIndex(sortedEntries()), "Tabel struct MD") end,
})
GBStruct:AddButton({
	Text = "Copy Sub-packet (Markdown)",
	Func = function() doCopy(mdSubIndex(sortedEntries()), "Sub-packet MD") end,
})

local GBGen = Tabs.Struct:AddRightGroupbox("Framework Generator")
GBGen:AddButton({ Text = "Lihat Packets.lua di Viewer", Func = function() jumpView("framework") end })
GBGen:AddButton({ Text = "Lihat Dokumentasi di Viewer", Func = function() jumpView("docs") end })
GBGen:AddButton({
	Text = "Lihat Template Script (terpilih)",
	Func = function() if needSelected() then jumpView("template") end end,
})
GBGen:AddButton({ Text = "Copy Packets.lua (ByteNet)", Func = function() doCopy(frameworkModule(), "Packets.lua") end })
GBGen:AddButton({ Text = "Copy Dokumentasi Markdown", Func = function() doCopy(docsMarkdown(), "Dokumentasi") end })
GBGen:AddButton({
	Text = "Copy Template Script (terpilih)",
	Func = function()
		local e = needSelected()
		if e then doCopy(templateText(e), "Template") end
	end,
})

------------------------------------------------------------------
-- TAB SIMPAN (docs folder rapi + copy)
------------------------------------------------------------------
local GBDocs = Tabs.Save:AddLeftGroupbox("Simpan Docs (folder rapi)")
GBDocs:AddLabel("Satu klik membuat folder Markdown terstruktur: README, overview, coverage, channels, remotes, structs, subpackets, packets, categories, logs, lua, data.", true)
GBDocs:AddButton({
	Text = "Simpan Docs Lengkap (latest)",
	Tooltip = "Menimpa folder 'latest' agar selalu mutakhir.",
	Func = function() saveDocs(false, false) end,
})
GBDocs:AddButton({
	Text = "Snapshot Docs (folder bertanggal)",
	Tooltip = "Folder baru berisi salinan lengkap, tidak menimpa 'latest'.",
	Func = function() saveDocs(true, false) end,
})
GBDocs:AddToggle("SS_AutoSave", {
	Text = "Auto-save docs berkala", Default = false,
	Tooltip = "Menyimpan ke folder 'latest' saat merekam.",
	Callback = function(v) state.autoSave = v state.lastSave = os.clock() end,
})
GBDocs:AddSlider("SS_AutoSaveMin", {
	Text = "Interval auto-save (menit)", Default = CFG.AutoSaveMin, Min = 1, Max = 30, Rounding = 0,
	Callback = function(v) CFG.AutoSaveMin = v end,
})
GBDocs:AddLabel("Lokasi: workspace/StructScope/<NamaGame>_<PlaceId>/latest", true)

local GBSave = Tabs.Save:AddRightGroupbox("Simpan File Tunggal")
GBSave:AddButton({
	Text = "Simpan Tampilan Viewer",
	Func = function()
		local text, title = currentText()
		doSave(safeName(title), text, "txt")
	end,
})
GBSave:AddButton({
	Text = "Simpan Table Log (.lua)",
	Func = function() local s = logLua() if s then doSave("packet_log", s, "lua") end end,
})
GBSave:AddButton({
	Text = "Simpan Table Chat (.lua)",
	Func = function() local s = chatLua() if s then doSave("chat_log", s, "lua") end end,
})
GBSave:AddButton({ Text = "Simpan Tabel Packet (.lua)", Func = function() doSave("packet_table", registryLua(), "lua") end })
GBSave:AddButton({ Text = "Simpan Packets.lua", Func = function() doSave("Packets", frameworkModule(), "lua") end })
GBSave:AddButton({
	Text = "Simpan Laporan SEMUA",
	Func = function() doSave("struct_report_" .. tostring(game.PlaceId), allReport(), "txt") end,
})
GBSave:AddButton({
	Text = "Simpan Template (terpilih)",
	Func = function()
		local e = needSelected()
		if e then doSave("template_" .. safeName(e.short), templateText(e), "lua") end
	end,
})

local GBCopy = Tabs.Save:AddRightGroupbox("Copy ke Clipboard")
GBCopy:AddButton({ Text = "Copy Tampilan Saat Ini", Func = function() doCopy(currentText(), "Tampilan") end })
GBCopy:AddButton({
	Text = "Copy Table Log (Lua, sesuai filter)",
	Func = function() local s = logLua() if s then doCopy(s, "Table log") end end,
})
GBCopy:AddButton({
	Text = "Copy Table Chat (Lua)",
	Func = function() local s = chatLua() if s then doCopy(s, "Table chat") end end,
})
GBCopy:AddButton({ Text = "Copy Tabel Packet (Lua)", Func = function() doCopy(registryLua(), "Tabel packet") end })
GBCopy:AddButton({
	Text = "Copy Definisi ByteNet (terpilih)",
	Func = function()
		local e = needSelected()
		if e then doCopy(packetDefText(e), "Definisi") end
	end,
})
GBCopy:AddButton({ Text = "Copy Statistik Channel", Func = function() doCopy(channelStatsText(), "Statistik") end })
GBCopy:AddButton({ Text = "Copy Laporan SEMUA Packet", Func = function() doCopy(allReport(), "Laporan") end })

------------------------------------------------------------------
-- TEMA
------------------------------------------------------------------
local THEME_ORDER = { "Script Hub", "Teal Gelap", "Midnight Biru", "Ungu Neon", "Hijau Terminal", "Abu Terang" }
local THEMES = {
	["Script Hub"] = {
		Main = Color3.fromRGB(14, 32, 80), Background = Color3.fromRGB(8, 18, 48), Accent = Color3.fromRGB(47, 107, 255),
		Outline = Color3.fromRGB(31, 58, 133), Font = Color3.fromRGB(234, 241, 255), View = Color3.fromRGB(6, 12, 32),
	},
	["Teal Gelap"] = {
		Main = Color3.fromRGB(24, 28, 34), Background = Color3.fromRGB(16, 19, 24), Accent = Color3.fromRGB(0, 170, 160),
		Outline = Color3.fromRGB(45, 52, 62), Font = Color3.fromRGB(230, 236, 240), View = Color3.fromRGB(12, 15, 20),
	},
	["Midnight Biru"] = {
		Main = Color3.fromRGB(22, 26, 40), Background = Color3.fromRGB(14, 17, 28), Accent = Color3.fromRGB(70, 130, 255),
		Outline = Color3.fromRGB(42, 50, 78), Font = Color3.fromRGB(225, 232, 250), View = Color3.fromRGB(10, 12, 22),
	},
	["Ungu Neon"] = {
		Main = Color3.fromRGB(30, 22, 40), Background = Color3.fromRGB(20, 14, 28), Accent = Color3.fromRGB(180, 90, 255),
		Outline = Color3.fromRGB(62, 46, 80), Font = Color3.fromRGB(238, 228, 250), View = Color3.fromRGB(14, 10, 20),
	},
	["Hijau Terminal"] = {
		Main = Color3.fromRGB(16, 24, 18), Background = Color3.fromRGB(10, 16, 12), Accent = Color3.fromRGB(60, 220, 110),
		Outline = Color3.fromRGB(34, 58, 40), Font = Color3.fromRGB(200, 245, 210), View = Color3.fromRGB(6, 12, 8),
	},
	["Abu Terang"] = {
		Main = Color3.fromRGB(235, 238, 242), Background = Color3.fromRGB(246, 248, 250), Accent = Color3.fromRGB(0, 120, 200),
		Outline = Color3.fromRGB(190, 196, 204), Font = Color3.fromRGB(30, 34, 40), View = Color3.fromRGB(255, 255, 255),
	},
}

local function applyTheme(name)
	local t = THEMES[name]
	if not t then return end
	Library.MainColor = t.Main
	Library.BackgroundColor = t.Background
	Library.AccentColor = t.Accent
	Library.OutlineColor = t.Outline
	Library.FontColor = t.Font
	pcall(function() Library.AccentColorDark = Library:GetDarkerColor(t.Accent) end)
	pcall(function() Library:UpdateColorsUsingRegistry() end)
	for _, P in ipairs(Panels) do
		pcall(function()
			P.holder.BackgroundColor3 = t.Outline
			P.scroll.BackgroundColor3 = t.View
			P.box.TextColor3 = t.Font
		end)
	end
end

local GBTheme = Tabs.Theme:AddLeftGroupbox("Tema")
GBTheme:AddDropdown("SS_Theme", {
	Values = THEME_ORDER, Default = 1, Multi = false, Text = "Pilih tema",
	Callback = function(v) applyTheme(v) end,
})
GBTheme:AddLabel("Tema berlaku untuk menu dan viewer.", true)

local GBMenu = Tabs.Theme:AddRightGroupbox("Menu")
GBMenu:AddToggle("SS_Fab", {
	Text = "Tombol cepat 'SS' di layar", Default = true,
	Tooltip = "Ketuk untuk buka / tutup menu (berguna di mobile).",
	Callback = function(v) if Library.Fab then Library.Fab.Visible = v end end,
})
GBMenu:AddButton({ Text = "Ukuran Default", Func = function() Window:SetMaximized(false) Window:SetSize(820, 500) end })
GBMenu:AddButton({ Text = "Tutup Semua (Unload)", Func = function() WinCtl.unload() end })
pcall(function()
	local lbl = GBMenu:AddLabel("Tombol buka/tutup menu")
	lbl:AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, Mode = "Toggle", NoUI = true, Text = "Menu keybind" })
end)

------------------------------------------------------------------
-- TAB INFO
------------------------------------------------------------------
local GBInfo = Tabs.Info:AddLeftGroupbox("Cara Pakai")
GBInfo:AddLabel(
	"1. Nyalakan Rekam Packet (tab Utama).\n" ..
	"2. Lakukan aksi di game: jalan, pukul, chat, buka menu, dll.\n" ..
	"3. Tab Viewer: pilih packet, sub-packet, dan Tampilan.\n" ..
	"4. Tab Log: scroll semua baris, filter arah / packet / sub / isi data.\n" ..
	"5. Tab Struct: tabel struct dan sub-packet semua packet.\n" ..
	"6. Tab Simpan: 'Simpan Docs Lengkap' membuat folder Markdown rapi.\n" ..
	"7. Tarik bar paling bawah menu untuk mengubah ukuran. Tarik title bar untuk memindah. Garis = kecilkan, kotak = perbesar, X = tutup (klik 2x).",
	true
)
local GBNote = Tabs.Info:AddRightGroupbox("Catatan")
GBNote:AddLabel(
	"OUT = request (client ke server), IN = response / push (server ke client). " ..
	"Channel OUT pasti dari hook sendReliable/sendUnreliable; IN dari definisi packet atau tebakan RemoteEvent (tanda ~). " ..
	"Sub-packet dikenali dari field pembeda (packet, type, action, message, cmd, ...) atau elemen pertama array. " ..
	"Declared butuh getupvalues dan debug.info. " ..
	"Script lain bisa memakai getgenv().StructScope.",
	true
)

applyTheme("Script Hub")
Window:Layout()

------------------------------------------------------------------
-- UNLOAD
------------------------------------------------------------------
local function cleanup()
	if not running then return end
	running = false
	state.active = false
	for _, e in ipairs(entries) do pcall(detach, e) end
	disconnectRemotes()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	if chatConn then pcall(function() chatConn:Disconnect() end) chatConn = nil end
	table.clear(Subs)
	if getgenv then
		pcall(function()
			getgenv().__SS_out = nil
			getgenv().__StructScopeUnload = nil
			getgenv().StructScope = nil
		end)
	end
end
pcall(function() Library:OnUnload(cleanup) end)
if getgenv then
	getgenv().__StructScopeUnload = function()
		cleanup()
		pcall(function() Library:Unload() end)
	end
	getgenv().StructScope = API
end

------------------------------------------------------------------
-- LOOP
------------------------------------------------------------------
task.spawn(function()
	local lastStatus, lastLog, lastSig = 0, 0, ""
	while running do
		local now = os.clock()
		if state.listDirty then pcall(refreshLists) end

		if state.autoScan and state.active and not starting and now - state.lastScan >= CFG.AutoScanEvery then
			state.lastScan = now
			task.spawn(function()
				local n = scanPackets()
				if n > 0 then
					for _, e in ipairs(entries) do attach(e) end
					refreshLists()
				end
			end)
		end

		if state.autoSave and state.active and not saving and #entries > 0 and now - state.lastSave >= CFG.AutoSaveMin * 60 then
			saveDocs(false, true)
		end

		if state.dirty and state.auto and tabVisible(Tabs.View) then
			state.dirty = false
			pcall(function()
				local text, title = render()
				Viewer.set(text, title)
			end)
		end
		if state.logDirty and now - lastLog >= 0.5 and tabVisible(Tabs.Log) then
			state.logDirty = false
			lastLog = now
			pcall(function()
				local text, count = logText()
				logPanel.set(text, CFG.LogLimit)
				logLabel:SetText(("%d log cocok filter | total %d | scroll untuk melihat semua"):format(count, #Store.log))
			end)
		end

		if now - lastStatus >= 1 then
			lastStatus = now
			local s = sumCounts()
			pcall(function() Library:SetStatus(state.active and "Merekam" or "Siap", state.active) end)
			pcall(function()
				statusLabel:SetText(("Status: %s | packet %d\nIN %d | OUT %d"):format(
					state.active and "REKAM" or "BERHENTI", #entries,
					s.inR + s.inU + s.inX, s.outR + s.outU + s.outX))
			end)
			pcall(function()
				statLabel:SetText(("Reliable   IN %d | OUT %d\nUnreliable IN %d | OUT %d\nBelum jelas IN %d | OUT %d\nRaw byte R %d | U %d"):format(
					s.inR, s.outR, s.inU, s.outU, s.inX, s.outX, Raw.reliable.bytes, Raw.unreliable.bytes))
			end)
			-- segarkan dropdown sub-packet bila ada jenis baru
			local total, selN = 0, state.selected and state.selected.subCount or 0
			for _, e in ipairs(entries) do total += e.subCount end
			local sig = total .. ":" .. selN .. ":" .. logCfg.pkt
			if sig ~= lastSig then
				lastSig = sig
				pcall(refreshSubDD)
				pcall(refreshLogSubDD)
			end
		end
		task.wait(0.3)
	end
end)

notify("StructScope v" .. VERSION .. " siap. Nyalakan 'Rekam Packet' untuk mulai.", 4)
