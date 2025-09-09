-- Orion Library Universal Compatibility Update
-- Tüm executor'larda çalışacak şekilde optimize edilmiştir

--[[
Orion Library

MultiSelect Element Kullanımı:
    local MultiSelect = Tab:AddMultiSelect({
        Name = "MultiSelect Örneği",
        Options = {"Seçenek 1", "Seçenek 2", "Seçenek 3"},
        Default = {"Seçenek 1"}, -- Varsayılan seçili değerler (opsiyonel)
        Flag = "multiSelectFlag", -- Flag değeri (opsiyonel)
        Callback = function(Value)
            -- Value bir tablo olarak seçili değerleri içerir
            print("Seçili Değerler:", table.concat(Value, ", "))
        end    
    })

    -- Fonksiyonlar:
    MultiSelect:Refresh(Options, true) -- Seçenekleri günceller (true parametresi mevcut seçimleri temizler)
    MultiSelect:Set({"Seçenek 1", "Seçenek 3"}) -- Seçili değerleri ayarlar
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

-- UISizeConstraint güvenlik fonksiyonu - MaxSize < MinSize hatası için
local function SafeUISizeConstraint(parent, minX, minY, maxX, maxY)
    -- Minimum değerler her zaman maximum değerlerden küçük olmalı
    if maxX < minX then maxX = minX end
    if maxY < minY then maxY = minY end
    
    local constraint = Instance.new("UISizeConstraint")
    constraint.MinSize = Vector2.new(minX, minY)
    constraint.MaxSize = Vector2.new(maxX, maxY)
    constraint.Parent = parent
    return constraint
end

-- ImageButton için yardımcı fonksiyonlar
local function HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    
    i = i % 6
    
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- ImageButton oluşturma ve yapılandırma fonksiyonları
local function createImageButton(playerGui)
    local screenGui = Instance.new("ScreenGui")
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    local imageButton = Instance.new("ImageButton")
    imageButton.BorderSizePixel = 0
    imageButton.ScaleType = Enum.ScaleType.Fit
    imageButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    imageButton.Image = "rbxassetid://111073133971859"
    imageButton.Size = UDim2.new(0, 35, 0, 35)
    imageButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
    imageButton.Position = UDim2.new(0.35744, 0, 0.26145, 0)
    imageButton.Parent = screenGui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = imageButton
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = imageButton
    
    return imageButton, uiStroke
end

local function setupDragging(guiObject)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end
    
    local function onInputChanged(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            guiObject.Position = newPos
        end
    end
    
    guiObject.InputBegan:Connect(onInputBegan)
    UserInputService.InputChanged:Connect(onInputChanged)
end

local function setupRainbowStroke(uiStroke)
    local hue = 0
    local hueSpeed = 0.04
    local thicknessMin = 1
    local thicknessMax = 3.5
    local thicknessSpeed = 0.3
    local direction = 1
    
    task.spawn(function()
        while uiStroke.Parent do
            hue = (hue + hueSpeed) % 1
            local r, g, b = HSVtoRGB(hue, 1, 1)
            uiStroke.Color = Color3.fromRGB(r, g, b)
            
            uiStroke.Thickness = uiStroke.Thickness + (thicknessSpeed * direction)
            
            if uiStroke.Thickness >= thicknessMax then
                direction = -1
            elseif uiStroke.Thickness <= thicknessMin then
                direction = 1
            end
            
            task.wait(0.03)
        end
    end)
end

-- Ana kütüphane tanımlaması
local OrionLib = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(18, 18, 18),
			Second = Color3.fromRGB(25, 25, 25),
			Stroke = Color3.fromRGB(50, 50, 50),
			Divider = Color3.fromRGB(50, 50, 50),
			Text = Color3.fromRGB(240, 240, 240),
			TextDark = Color3.fromRGB(140, 140, 140)
		}
	},
	SelectedTheme = "Default",
	Folder = nil,
	SaveCfg = false
}

--[[ API/Executor Uyumluluk Katmanı ]]--

-- Executor tespiti ve API uyumluluğu
local EXECUTOR_CHECK = {}

EXECUTOR_CHECK.executor = (function()
    local success, result = pcall(function()
        return identifyexecutor and identifyexecutor() or "Unknown"
    end)
    return success and result or "Unknown"
end)()

EXECUTOR_CHECK.functions = {
    isfolder = isfolder or function(path) return false end,
    makefolder = makefolder or function(path) return end,
    isfile = isfile or function(path) return false end,
    writefile = writefile or function(path, content) return end,
    readfile = readfile or function(path) return "" end,
    httpget = game.HttpGet or function(self, url) return "" end
}

-- Core API güvenli erişim
local function GetCoreGui()
    local success, result = pcall(function()
        -- Sırayla farklı yöntemleri dener
        return game:GetService("CoreGui") or 
               gethui() or 
               game.CoreGui or
               game:GetService("Players").LocalPlayer.PlayerGui
    end)
    
    if success and result then 
        return result 
    else
        -- Son çare olarak PlayerGui'i döndür
        return game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end
end

-- getgenv evrensel erişim
getgenv = getgenv or function() return _G end

-- syn evrensel erişim
syn = syn or {}
syn.protect_gui = syn.protect_gui or function(gui) end
syn.unprotect_gui = syn.unprotect_gui or function(gui) end

-- Luraph desteği
if not pcall(function() return readfile end) then
    readfile = function() return "" end
    writefile = function() return end
    isfile = function() return false end
    isfolder = function() return false end
    makefolder = function() return end
end

--[[ Orion GUI Oluşturma ]]--
local Orion = Instance.new("ScreenGui")
Orion.Name = "KanistayLib"
Orion.ResetOnSpawn = false
Orion.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Orion.DisplayOrder = 999999999

-- Koruma ve parent ayarı
local function SafePlaceGui(gui)
    pcall(function()
        -- CoreGui ataması güvenlik katmanları ile
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = GetCoreGui()
        elseif gethui then
            gui.Parent = gethui()
        else
            gui.Parent = GetCoreGui()
        end
    end)
    
    -- GUI hala parent'a eklenmediyse PlayerGui'ye ekle
    if not gui.Parent then
        gui.Parent = LocalPlayer.PlayerGui
    end
    
    -- Versiyon kontrolü
    gui:GetPropertyChangedSignal("Parent"):Connect(function()
        if not gui.Parent then
            pcall(function() SafePlaceGui(gui) end)
        end
    end)
    
    -- Aynı isimli diğer GUI'leri temizle
    pcall(function()
        for _, Interface in ipairs(gui.Parent:GetChildren()) do
            if Interface.Name == gui.Name and Interface ~= gui then
                Interface:Destroy()
            end
        end
    end)
end

SafePlaceGui(Orion)

-- Orion çalışıyor mu kontrolü
function OrionLib:IsRunning()
    return Orion and Orion.Parent ~= nil
end

-- Güvenli bağlantı oluşturma
local function AddConnection(Signal, Function)
    if not OrionLib:IsRunning() then
        return
    end
    local Connection
    pcall(function()
        Connection = Signal:Connect(Function)
        table.insert(OrionLib.Connections, Connection)
    end)
    return Connection
end

-- Bağlantı temizleme
spawn(function()
    while true do
        if not OrionLib:IsRunning() then
            for _, Connection in next, OrionLib.Connections do
                pcall(function() Connection:Disconnect() end)
            end
            break
        end
        wait(1)
    end
end)

-- Config Okuma/Yazma Fonksiyonları (daha güvenli)
function SafeJsonEncode(data)
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    return success and result or "{}"
end

function SafeJsonDecode(json)
    local success, result = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    return success and result or {}
end

-- Güvenli config kaydetme
local function SaveCfg(id)
    if not OrionLib.SaveCfg or not OrionLib.Folder then return end
    
    pcall(function()
        -- Klasör kontrolü
        if not EXECUTOR_CHECK.functions.isfolder(OrionLib.Folder) then
            EXECUTOR_CHECK.functions.makefolder(OrionLib.Folder)
        end
        
        -- Flag verilerini topla
        local Data = {}
        for i, v in pairs(OrionLib.Flags) do
            if v.Save then
                if v.Type == "Colorpicker" then
                    Data[i] = {R = v.Value.R * 255, G = v.Value.G * 255, B = v.Value.B * 255}
                else
                    Data[i] = v.Value
                end
            end
        end
        
        -- Dosyaya yaz
        local json = SafeJsonEncode(Data)
        EXECUTOR_CHECK.functions.writefile(OrionLib.Folder .. "/" .. id .. ".txt", json)
    end)
end

-- Güvenli config yükleme
function LoadCfg(config)
	pcall(function()
		local Data = SafeJsonDecode(config)
		for a, b in pairs(Data) do
			if OrionLib.Flags[a] then
				spawn(function() 
					if OrionLib.Flags[a].Type == "Colorpicker" then
						OrionLib.Flags[a]:Set(Color3.fromRGB(b.R, b.G, b.B))
					else
						OrionLib.Flags[a]:Set(b)
					end    
				end)
			end
		end
	end)
end

-- Feather Icons kısmını kaldırma (isteğe bağlı)
local Icons = {}

-- GetIcon fonksiyonu - başa taşındı
local function GetIcon(IconName)
	-- Basitleştirilmiş versiyon
	return Icons[IconName] or nil
end

local WhitelistedMouse = {
    Enum.UserInputType.MouseButton1, 
    Enum.UserInputType.MouseButton2, 
    Enum.UserInputType.MouseButton3
}

local BlacklistedKeys = {
    Enum.KeyCode.Unknown,
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.Up,
    Enum.KeyCode.Left,
    Enum.KeyCode.Down,
    Enum.KeyCode.Right,
    Enum.KeyCode.Slash,
    Enum.KeyCode.Tab,
    Enum.KeyCode.Backspace,
    Enum.KeyCode.Escape
}

local function AddDraggingFunctionality(DragPoint, Main)
	-- Daha dayanıklı bir sürükleme sistemi
    local Dragging, DragInput, MousePos, FramePos = false, nil, nil, nil
    
    -- MouseButton1Down yerine InputBegan kullanarak daha geniş destek
    local function BeginDrag(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            MousePos = Input.Position
            FramePos = Main.Position
            
            -- Input durumunu takip et
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end
    
    -- Mouse/dokunmatik hareket takibi
    local function UpdateDrag(Input)
        if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
            DragInput = Input
            local Delta = Input.Position - MousePos
            Main.Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
        end
    end
    
    -- Hem DragPoint hem UserInputService üzerinden event bağlantıları
    pcall(function()
        DragPoint.InputBegan:Connect(BeginDrag)
        UserInputService.InputChanged:Connect(UpdateDrag)
    end)
end   

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do
		Object[i] = v
	end
	for i, v in next, Children or {} do
		v.Parent = Object
	end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	OrionLib.Elements[ElementName] = function(...)
		return ElementFunction(...)
	end
end

local function MakeElement(ElementName, ...)
	if ElementName == "Corner" then
		local Corner = Create("UICorner", {
			CornerRadius = UDim.new(0, 6) -- Daha yuvarlak köşeler (4'ten 6'ya)
		})
		return Corner
	elseif ElementName == "Stroke" then
		local Stroke = Create("UIStroke", {
			Thickness = 1
		})
		return Stroke
	elseif ElementName == "List" then
		local List = Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4)
		})
		return List
	elseif ElementName == "Padding" then
		local Padding = Create("UIPadding", {
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4)
		})
		if #{...} > 0 then
			Padding.PaddingTop = UDim.new(0, ({...})[1])
		end
		if #{...} > 1 then
			Padding.PaddingRight = UDim.new(0, ({...})[2])
		end
		if #{...} > 2 then
			Padding.PaddingBottom = UDim.new(0, ({...})[3])
		end
		if #{...} > 3 then
			Padding.PaddingLeft = UDim.new(0, ({...})[4])
		end
		return Padding
	elseif ElementName == "TFrame" then
		local Frame = Create("Frame", {
			BackgroundTransparency = 1
		})
		return Frame
	elseif ElementName == "Frame" then
		local Frame = Create("Frame")
		return Frame
	elseif ElementName == "RoundFrame" then
		local Frame = Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 0
		})
		local Corner = Create("UICorner", {
			CornerRadius = UDim.new(0, 12) -- Daha yumuşak köşeler (10'dan 12'ye çıkarıldı)
		})
		Corner.Parent = Frame
		
		-- UISizeConstraint güvenlik kontrolü ekle
		SafeUISizeConstraint(Frame, 0, 0, 10000, 10000)
		
		return Frame
	elseif ElementName == "Button" then
		local Button = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0
		})
		return Button
	elseif ElementName == "ScrollFrame" then
		local ScrollFrame = Create("ScrollingFrame", {
			BackgroundTransparency = 1,
			MidImage = "rbxassetid://7445543667",
			BottomImage = "rbxassetid://7445543667",
			TopImage = "rbxassetid://7445543667",
			ScrollBarImageColor3 = ({...})[1],
			BorderSizePixel = 0,
			ScrollBarThickness = ({...})[2],
			CanvasSize = UDim2.new(0, 0, 0, 0)
		})
		
		-- ScrollFrame için UISizeConstraint ekle
		SafeUISizeConstraint(ScrollFrame, 0, 0, 10000, 10000)
		
		return ScrollFrame
	elseif ElementName == "Image" then
		local ImageNew = Create("ImageLabel", {
			Image = ({...})[1],
			BackgroundTransparency = 1
		})

		if GetIcon(({...})[1]) ~= nil then
			ImageNew.Image = GetIcon(({...})[1])
		end	

		return ImageNew
	elseif ElementName == "ImageButton" then
		local Image = Create("ImageButton", {
			Image = ({...})[1],
			BackgroundTransparency = 1
		})
		return Image
	elseif ElementName == "Label" then
		local Label = Create("TextLabel", {
			Text = ({...})[1] or "",
			TextColor3 = Color3.fromRGB(240, 240, 240),
			TextTransparency = ({...})[3] or 0,
			TextSize = ({...})[2] or 15,
			Font = Enum.Font.Gotham,
			RichText = true,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left
		})
		
		-- Label için UISizeConstraint ekle
		SafeUISizeConstraint(Label, 0, 0, 10000, 10000)
		
		return Label
	else
		-- Fallback: Eğer element bulunamazsa, bir uyarı göster ve boş bir frame döndür
		warn("Element not found: " .. ElementName)
		return Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 0)
		})
	end
end

local function SetProps(Element, Props)
	table.foreach(Props, function(Property, Value)
		Element[Property] = Value
	end)
	return Element
end

local function SetChildren(Element, Children)
	table.foreach(Children, function(_, Child)
		Child.Parent = Element
	end)
	return Element
end

local function Round(Number, Factor)
	local Result = math.floor(Number/Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") then
		return "BackgroundColor3"
	end 
	if Object:IsA("ScrollingFrame") then
		return "ScrollBarImageColor3"
	end 
	if Object:IsA("UIStroke") then
		return "Color"
	end 
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then
		return "TextColor3"
	end   
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
		return "ImageColor3"
	end   
end

local function AddThemeObject(Object, Type)
	if not OrionLib.ThemeObjects[Type] then
		OrionLib.ThemeObjects[Type] = {}
	end    
	table.insert(OrionLib.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = OrionLib.Themes[OrionLib.SelectedTheme][Type]
	return Object
end    

local function SetTheme()
	for Name, Type in pairs(OrionLib.ThemeObjects) do
		for _, Object in pairs(Type) do
			Object[ReturnProperty(Object)] = OrionLib.Themes[OrionLib.SelectedTheme][Name]
		end    
	end    
end

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end    

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
	local Data = HttpService:JSONDecode(Config)
	table.foreach(Data, function(a,b)
		if OrionLib.Flags[a] then
			spawn(function() 
				if OrionLib.Flags[a].Type == "Colorpicker" then
					OrionLib.Flags[a]:Set(UnpackColor(b))
				else
					OrionLib.Flags[a]:Set(b)
				end    
			end)
		else
			warn("Orion Library Config Loader - Could not find ", a ,b)
		end
	end)
end

local function SaveCfg(Name)
	local Data = {}
	for i,v in pairs(OrionLib.Flags) do
		if v.Save then
			if v.Type == "Colorpicker" then
				Data[i] = PackColor(v.Value)
			else
				Data[i] = v.Value
			end
		end	
	end
	writefile(OrionLib.Folder .. "/" .. Name .. ".txt", tostring(HttpService:JSONEncode(Data)))
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3}
local BlacklistedKeys = {Enum.KeyCode.Unknown,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Left,Enum.KeyCode.Down,Enum.KeyCode.Right,Enum.KeyCode.Slash,Enum.KeyCode.Tab,Enum.KeyCode.Backspace,Enum.KeyCode.Escape}

-- Key kontrol fonksiyonu
local function CheckKey(Table, Key)
	for _, k in next, Table do
		if k == Key then
			return true
		end
	end
	return false
end



CreateElement("Corner", function(Scale, Offset)
	local Corner = Create("UICorner", {
		CornerRadius = UDim.new(Scale or 0, Offset or 10)
	})
	return Corner
end)

CreateElement("Stroke", function(Color, Thickness)
	local Stroke = Create("UIStroke", {
		Color = Color or Color3.fromRGB(255, 255, 255),
		Thickness = Thickness or 1
	})
	return Stroke
end)

CreateElement("List", function(Scale, Offset)
	local List = Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(Scale or 0, Offset or 0)
	})
	return List
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	local Padding = Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft = UDim.new(0, Left or 4),
		PaddingRight = UDim.new(0, Right or 4),
		PaddingTop = UDim.new(0, Top or 4)
	})
	return Padding
end)

CreateElement("TFrame", function()
	local TFrame = Create("Frame", {
		BackgroundTransparency = 1
	})
	return TFrame
end)

CreateElement("Frame", function(Color)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	})
	return Frame
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	}, {
		Create("UICorner", {
			CornerRadius = UDim.new(Scale, Offset)
		})
	})
	return Frame
end)

CreateElement("Button", function()
	local Button = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0
	})
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	local ScrollFrame = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color,
		BorderSizePixel = 0,
		ScrollBarThickness = Width,
		CanvasSize = UDim2.new(0, 0, 0, 0)
	})
	return ScrollFrame
end)

CreateElement("Image", function(ImageID)
	local ImageNew = Create("ImageLabel", {
		Image = ImageID,
		BackgroundTransparency = 1
	})

	if GetIcon(ImageID) ~= nil then
		ImageNew.Image = GetIcon(ImageID)
	end	

	return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
	local Image = Create("ImageButton", {
		Image = ImageID,
		BackgroundTransparency = 1
	})
	return Image
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	local Label = Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 15,
		Font = Enum.Font.Gotham,
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	return Label
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 5)
	})
}), {
	Position = UDim2.new(1, -25, 1, -25),
	Size = UDim2.new(0, 300, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent = Orion
})

function OrionLib:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name = NotificationConfig.Name or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4384403532"
		NotificationConfig.Time = NotificationConfig.Time or 15

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(25, 25, 25), 0, 10), {
			Parent = NotificationParent, 
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, -55, 0, 0),
			BackgroundTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", Color3.fromRGB(93, 93, 93), 1.2),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 20, 0, 20),
				ImageColor3 = Color3.fromRGB(240, 240, 240),
				Name = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
				Size = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 30, 0, 0),
				Font = Enum.Font.GothamBold,
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.GothamSemibold,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextWrapped = true
			})
		})

		TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play()

		wait(NotificationConfig.Time - 0.88)
		TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()
		wait(0.35)
		TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(1, 20, 0, 0)}):Play()
		wait(1.35)
		NotificationFrame:Destroy()
	end)
end    

function OrionLib:Init()
	if OrionLib.SaveCfg then	
		pcall(function()
			if EXECUTOR_CHECK.functions.isfile(OrionLib.Folder .. "/" .. game.GameId .. ".txt") then
				GlobalLoadCfg(EXECUTOR_CHECK.functions.readfile(OrionLib.Folder .. "/" .. game.GameId .. ".txt"))
				OrionLib:MakeNotification({
					Name = "Configuration",
					Content = "Auto-loaded configuration for the game " .. game.GameId .. ".",
					Time = 5
				})
			end
		end)		
	end	
end	

-- 1. NEON, TEK KATMANLI, KÜÇÜK VE SOLDA DOT
local function AddOnlineDot(WindowName, MainWindow)
    local TopBar = MainWindow:FindFirstChild("TopBar")
    if not TopBar then return end
    local OnlineDot = Instance.new("Frame")
    OnlineDot.Name = "OnlineDot"
    OnlineDot.Size = UDim2.new(0, 9, 0, 9)
    OnlineDot.Position = UDim2.new(0, 8, 0.4, 0) -- Yeni pozisyon
    OnlineDot.AnchorPoint = Vector2.new(0, 0.5)
    OnlineDot.BackgroundColor3 = Color3.fromRGB(25, 255, 19)
    OnlineDot.BorderSizePixel = 0
    OnlineDot.Parent = TopBar
    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = OnlineDot
    -- DotNeon UIStroke efekti, ApplyStrokeMode olmadan
    local DotNeon = Instance.new("UIStroke")
    DotNeon.Thickness = 1.5
    DotNeon.Transparency = 0.1
    DotNeon.Color = Color3.fromRGB(25, 255, 19)
    DotNeon.Parent = OnlineDot
    
    -- Dot artık animasyonsuz, sabit boyutta
    WindowName.Position = UDim2.new(0, 24, 0, -24)
end	

function OrionLib:CreateToggleButton()
    local player = game:GetService("Players").LocalPlayer
    local imageButton, uiStroke = createImageButton(player:WaitForChild("PlayerGui"))
    
    setupDragging(imageButton)
    setupRainbowStroke(uiStroke)
    
    -- KanistayLib'i açma/kapama işlevi
    imageButton.MouseButton1Click:Connect(function()
        if Orion then
            Orion.Enabled = true
        end
    end)
    
    -- Görünürlük kontrolü
    if Orion then
        local function updateVisibility()
            imageButton.Parent.Enabled = not Orion.Enabled
        end
        
        updateVisibility()
        Orion:GetPropertyChangedSignal("Enabled"):Connect(updateVisibility)
    end
    
    return imageButton
end

function OrionLib:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local Loaded = false
	local UIHidden = false

	WindowConfig = WindowConfig or {}
	WindowConfig.Name = WindowConfig.Name or "Orion Library"
	WindowConfig.ConfigFolder = WindowConfig.ConfigFolder or WindowConfig.Name
	WindowConfig.SaveConfig = WindowConfig.SaveConfig or false
	WindowConfig.HidePremium = WindowConfig.HidePremium or false
	WindowConfig.CloseCallback = WindowConfig.CloseCallback or function() end
	WindowConfig.ShowIcon = WindowConfig.ShowIcon or false
	WindowConfig.Icon = WindowConfig.Icon or "rbxassetid://8834748103"
	OrionLib.Folder = WindowConfig.ConfigFolder
	OrionLib.SaveCfg = WindowConfig.SaveConfig

	if WindowConfig.SaveConfig then
		if not isfolder(WindowConfig.ConfigFolder) then
			makefolder(WindowConfig.ConfigFolder)
		end	
	end

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 4), {
		Size = UDim2.new(1, 0, 1, 0)
	}), {
		MakeElement("List"),
		MakeElement("Padding", 8, 0, 0, 8)
	}), "Divider")

	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
	end)

	local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size = UDim2.new(0, 18, 0, 18)
		}), "Text")
	})

	local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size = UDim2.new(0, 18, 0, 18),
			Name = "Ico"
		}), "Text")
	})

	local DragPoint = SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, 0, 0, 50)
	})

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 14), {
		Size = UDim2.new(1, -30, 2, 0),
		Position = UDim2.new(0, 25, 0, -24),
		Font = Enum.Font.GothamBlack,
		TextSize = 20
	}), "Text")

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1)
	}), "Stroke")
	
	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
		Size = UDim2.new(0, 150, 1, -50), -- Tam olarak 150 genişlik, yükseklik - 50
		Position = UDim2.new(0, 0, 0, 50) -- Tam olarak 50 piksel aşağıda
	}), {
		-- 3 Frame silindi
		TabHolder,
	}), "Second")

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 22), {
		Parent = Orion,
		Position = UDim2.new(0.5, -307, 0.5, -172),
		Size = UDim2.new(0, 615, 0, 344),
		ClipsDescendants = true
	}), {
		-- Kar efekti için container - en üstte görünmesi için
		SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Name = "SnowContainer",
			ZIndex = 9999 -- Çok yüksek ZIndex değeri
		}),
		--SetProps(MakeElement("Image", "rbxassetid://3523728077"), {
		--	AnchorPoint = Vector2.new(0.5, 0.5),
		--	Position = UDim2.new(0.5, 0, 0.5, 0),
		--	Size = UDim2.new(1, 80, 1, 320),
		--	ImageColor3 = Color3.fromRGB(33, 33, 33),
		--	ImageTransparency = 0.7
		--}),
		SetChildren(SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 40), -- TopBar daha basık
			Name = "TopBar"
		}), {
			WindowName,
			WindowTopBarLine,
			AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 7), {
				Size = UDim2.new(0, 70, 0, 30),
				Position = UDim2.new(1, -90, 0, 5) -- TopBar'ın ortasına hizalandı
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Frame"), {
					Size = UDim2.new(0, 1, 1, 0),
					Position = UDim2.new(0.5, 0, 0, 0)
				}), "Stroke"), 
				CloseBtn,
				MinimizeBtn
			}), "Second"), 
		}),
		DragPoint,
		WindowStuff
	}), "Main")
	
	-- ScrollingFrame görünürlük kontrolü için değişken
	local isTabsVisible = true
	
	-- ScrollingFrame gizleme/gösterme butonu
	local TabsToggleBtn = Instance.new("ImageButton")
	TabsToggleBtn.Name = "TabsToggleBtn"
	TabsToggleBtn.Image = "rbxassetid://3926305904" -- Roblox'un kendi ok ikonları
	TabsToggleBtn.ImageRectOffset = Vector2.new(924, 364) -- Sağa ok
	TabsToggleBtn.ImageRectSize = Vector2.new(36, 36)
	TabsToggleBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
	TabsToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	TabsToggleBtn.Size = UDim2.new(0, 22, 0, 22)
	TabsToggleBtn.Position = UDim2.new(1, -16, 0, 5)
	TabsToggleBtn.AnchorPoint = Vector2.new(0.5, 0)
	TabsToggleBtn.BackgroundTransparency = 0.3
	TabsToggleBtn.BorderSizePixel = 0
	TabsToggleBtn.ZIndex = 100
	TabsToggleBtn.Parent = WindowStuff
	TabsToggleBtn.Rotation = 45 -- Başlangıçta 45 derece rotasyon
	
	-- Buton köşesini yuvarla
	local BtnCorner = Instance.new("UICorner")
	BtnCorner.CornerRadius = UDim.new(1, 0) -- Tam yuvarlak
	BtnCorner.Parent = TabsToggleBtn
	
	-- TabsToggleBtn pozisyonunu düzeltme fonksiyonu
	local function FixTabsTogglePosition()
		if TabsToggleBtn and TabsToggleBtn.Parent then
			-- Sabit bir pozisyon ayarla - sadece sağ kenardan uzaklık
			TabsToggleBtn.Position = UDim2.new(1, -16, 0, 5)
			TabsToggleBtn.AnchorPoint = Vector2.new(0.5, 0)
		end
	end
	
	-- İlk çalıştırmada pozisyonu düzelt
	FixTabsTogglePosition()
	
	-- Buton tıklama olayı - ScrollingFrame'i göster/gizle - sadece sola kaydırma
	TabsToggleBtn.MouseButton1Click:Connect(function()
		isTabsVisible = not isTabsVisible
		
		-- İkon değişimi - sürüklenebilir ve daha stabil
		pcall(function()
			if isTabsVisible then
				TabsToggleBtn.Rotation = 45
				TabsToggleBtn.ImageRectOffset = Vector2.new(924, 364)
			else
				TabsToggleBtn.Rotation = 225
				TabsToggleBtn.ImageRectOffset = Vector2.new(924, 364)
			end
		end)
		
		-- WindowStuff ve TabHolder boyutlandırması - sadece yatay yönde değişiklik
		pcall(function()
			if isTabsVisible then
				-- ScrollingFrame'i göster
				if TabHolder then TabHolder.Visible = true end
				
				-- WindowStuff'ı normal genişliğe getir (sadece genişlik değişir)
				if WindowStuff then
					-- Pozisyon sabit kalır, sadece genişlik değişir
					TweenService:Create(WindowStuff, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
						Size = UDim2.new(0, 150, 1, -50) -- Sadece genişlik değişir
					}):Play()
					
					-- Buton pozisyonunu düzelt
					FixTabsTogglePosition()
				end
				
				-- ItemContainer boyutlandırma - sadece yatay değişiklik
				if MainWindow then
					for _, ItemContainer in pairs(MainWindow:GetChildren()) do
						if ItemContainer.Name == "ItemContainer" and ItemContainer.Visible then
							pcall(function()
								TweenService:Create(ItemContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
									Size = UDim2.new(1, -150, 1, -(MainWindow.TopBar.Size.Y.Offset + 4)),
									Position = UDim2.new(0, 150, 0, MainWindow.TopBar.Size.Y.Offset + 2)
								}):Play()
							end)
							
							-- İçerik öğelerinin genişliğini güncelle
							pcall(function()
								for _, Element in pairs(ItemContainer:GetChildren()) do
									if Element:IsA("Frame") or Element:IsA("TextButton") then
										if not Element:IsA("UIListLayout") and not Element:IsA("UIPadding") and
										   not Element:IsA("UICorner") and Element.Name ~= "ScrollToggleBtn" then
											TweenService:Create(Element, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
												Size = UDim2.new(1, 0, Element.Size.Y.Scale, Element.Size.Y.Offset)
											}):Play()
										end
									end
								end
							end)
							
							-- CanvasSize ayarlama (güvenli)
							wait(0.1)
							pcall(function()
								if ItemContainer:FindFirstChild("UIListLayout") then
									ItemContainer.CanvasSize = UDim2.new(0, 0, 0, ItemContainer.UIListLayout.AbsoluteContentSize.Y + 30)
								end
							end)
						end
					end
				end
			else
				-- ScrollingFrame'i gizle
				if TabHolder then TabHolder.Visible = false end
				
				-- WindowStuff'ı küçült (sadece genişlik değişir)
				if WindowStuff then
					-- Pozisyon sabit kalır, sadece genişlik değişir
					TweenService:Create(WindowStuff, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
						Size = UDim2.new(0, 30, 1, -50) -- Sadece genişlik değişir
					}):Play()
					
					-- Buton pozisyonunu düzelt
					FixTabsTogglePosition()
				end
				
				-- ItemContainer genişletme - sadece yatay değişiklik
				if MainWindow then
					for _, ItemContainer in pairs(MainWindow:GetChildren()) do
						if ItemContainer.Name == "ItemContainer" and ItemContainer.Visible then
							pcall(function()
								TweenService:Create(ItemContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
									Size = UDim2.new(1, -30, 1, -(MainWindow.TopBar.Size.Y.Offset + 4)),
									Position = UDim2.new(0, 30, 0, MainWindow.TopBar.Size.Y.Offset + 2)
								}):Play()
							end)
							
							-- İçerik öğelerinin genişliğini güncelle
							pcall(function()
								for _, Element in pairs(ItemContainer:GetChildren()) do
									if Element:IsA("Frame") or Element:IsA("TextButton") then
										if not Element:IsA("UIListLayout") and not Element:IsA("UIPadding") and
										   not Element:IsA("UICorner") and Element.Name ~= "ScrollToggleBtn" then
											TweenService:Create(Element, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
												Size = UDim2.new(1, 0, Element.Size.Y.Scale, Element.Size.Y.Offset)
											}):Play()
										end
									end
								end
							end)
							
							-- CanvasSize ayarlama (güvenli)
							wait(0.1)
							pcall(function()
								if ItemContainer:FindFirstChild("UIListLayout") then
									ItemContainer.CanvasSize = UDim2.new(0, 0, 0, ItemContainer.UIListLayout.AbsoluteContentSize.Y + 30)
								end
							end)
						end
					end
				end
			end
		end)
	end)

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1)
	}), "Stroke")

	-- Ana pencereye beyaz şerit ekleme
	local MainStroke = Instance.new("UIStroke")
	MainStroke.Thickness = 4.0 -- Daha kalın (2.2'den 4.0'a çıkarıldı)
	MainStroke.Color = Color3.fromRGB(255, 255, 255) -- Tam beyaz
	MainStroke.Transparency = 0.1 -- Daha görünür ve parlak (0.3'ten 0.1'e düşürüldü)
	MainStroke.Parent = MainWindow
	
	-- Kanistay HUB yazısı - sol kenara tam yapışık
	local KanistayLabel = Instance.new("TextLabel")
	KanistayLabel.Name = "KanistayLabel"
	KanistayLabel.Size = UDim2.new(0, 32, 0, 120) -- Daha büyük ve belirgin
	KanistayLabel.BackgroundTransparency = 1
	KanistayLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	KanistayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	KanistayLabel.Font = Enum.Font.GothamBlack
	KanistayLabel.TextSize = 18
	KanistayLabel.Text = "Kanistay Hub"
	KanistayLabel.TextXAlignment = Enum.TextXAlignment.Center
	KanistayLabel.TextYAlignment = Enum.TextYAlignment.Center
	KanistayLabel.Rotation = -90
	KanistayLabel.ZIndex = 9999
	KanistayLabel.Visible = true
	KanistayLabel.Parent = Orion
	KanistayLabel.Position = KanistayLabel.Position + UDim2.new(0, 3, 0, 0)
	
	-- RenderStepped ile label'ı menünün sol dış kenarına ve ortasına hizala
	RunService.RenderStepped:Connect(function()
		pcall(function()
			if MainWindow and MainWindow.Parent and KanistayLabel and KanistayLabel.Parent then
				local pos = MainWindow.AbsolutePosition
				local size = MainWindow.AbsoluteSize
				-- Sol dış kenara ve dikey olarak ortala
				KanistayLabel.Position = UDim2.new(0, pos.X - KanistayLabel.Size.X.Offset - 8, 0, pos.Y + size.Y/2 - KanistayLabel.Size.Y.Offset/2)
			end
		end)
	end)
	
	-- Yazının yanıp sönme efekti
	spawn(function()
		local visible = true
		while wait(0.8) do -- 0.8 saniyede bir değişim
			if MainWindow and MainWindow.Parent then
				visible = not visible
				if KanistayLabel and KanistayLabel.Parent then
					KanistayLabel.TextTransparency = visible and 0.2 or 1.0 -- Görünür/görünmez arası geçiş
				end
			else
				break
			end
		end
	end)
	
	-- Dönen beyaz parlak efekt şeridi
	local RotatingHighlight = Instance.new("UIGradient")
	RotatingHighlight.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), -- Tam beyaz
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
	})
	RotatingHighlight.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.2), -- Daha görünür ve parlak
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	RotatingHighlight.Parent = MainStroke
	
	-- Dönen efekt animasyonu - garanti çalışsın
	spawn(function()
		local rot = 0
		while wait(0.02) do -- Daha hızlı animasyon
			if MainStroke and MainStroke.Parent then
				rot = (rot + 1) % 360
				if RotatingHighlight and RotatingHighlight.Parent then
					RotatingHighlight.Rotation = rot
				end
			end
		end
	end)

	-- WindowStuff boyut ve pozisyon güncellemesi doğru konumda (MainWindow tanımlandıktan sonra)
	AddConnection(MainWindow:GetPropertyChangedSignal("Size"), function()
		if WindowStuff and MainWindow and MainWindow:FindFirstChild("TopBar") then
			if not Minimized then
				-- Normal durumda doğru boyut ve pozisyon
				WindowStuff.Size = UDim2.new(0, 150, 1, -50) -- Sabit boyut değeri
				WindowStuff.Position = UDim2.new(0, 0, 0, 50) -- Sabit pozisyon değeri
				
				-- Buton pozisyonunu düzelt
				if TabsToggleBtn and TabsToggleBtn.Parent then
					FixTabsTogglePosition()
				end
			end
		end
	end)

	if WindowConfig.ShowIcon then
		WindowName.Position = UDim2.new(0, 50, 0, -24)
		local WindowIcon = SetProps(MakeElement("Image", WindowConfig.Icon), {
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(0, 25, 0, 15)
		})
		WindowIcon.Parent = MainWindow.TopBar
	end	

	AddDraggingFunctionality(DragPoint, MainWindow)

	AddConnection(CloseBtn.MouseButton1Up, function()
		-- ScreenGui'yi tamamen devre dışı bırak
		Orion.Enabled = false
		WindowConfig.CloseCallback()
	end)


	
	-- Optimize edilmiş kar efekti oluşturma fonksiyonu
	local function CreateSnowEffect()
		local SnowContainer = MainWindow:FindFirstChild("SnowContainer")
		if not SnowContainer then return end
		
		-- Performans için kar tanesi sayısını sınırlı tutalım
		local maxSnowflakes = 10 -- Daha da az kar tanesi (15'ten 10'a düşürüldü)
		local activeSnowflakes = 0
		local snowflakes = {}
		
		-- Performans izleme
		local lastFrameTime = tick()
		local frameCount = 0
		local frameTimeTotal = 0
		local isLowPerformance = false
		local minSpawnInterval = 0.8 -- Minimum kar tanesi oluşturma aralığı (saniye)
		
		-- Kar tanesi oluşturma fonksiyonu - optimize edilmiş
		local function createSnowflake()
			if activeSnowflakes >= maxSnowflakes then return end
			
			-- Sadece tek tip kar tanesi kullan (daha az işlem yükü)
			local snowflake = Instance.new("Frame")
			snowflake.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			snowflake.BorderSizePixel = 0
			
			-- Farklı boyutlarda kar taneleri
			local size = math.random(2, 3) -- Daha küçük boyut
			snowflake.Size = UDim2.new(0, size, 0, size)
			
			-- Kar tanesi köşelerini yuvarla
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = snowflake
			
			-- Kar tanelerini rastgele konumlara yerleştir
			snowflake.Position = UDim2.new(math.random(), 0, -0.05, 0)
			
			-- Şeffaflık ekle
			snowflake.BackgroundTransparency = math.random(0.2, 0.6) -- Daha şeffaf
			snowflake.ZIndex = 10000 -- Çok yüksek ZIndex (tüm öğelerin üstünde)
			snowflake.Parent = SnowContainer
			
			table.insert(snowflakes, snowflake)
			activeSnowflakes = activeSnowflakes + 1
			
			-- Kar tanesinin düşüş animasyonu - optimize edilmiş
			spawn(function()
				local duration = math.random(5, 8) -- Daha yavaş düşüş
				local startTime = tick()
				local startX = snowflake.Position.X.Scale
				local amplitude = math.random(3, 8) / 100 -- Daha az sallanma
				local frequency = math.random(5, 10) / 10 -- Daha yavaş sallanma
				
				while snowflake and snowflake.Parent and (snowflake.Position.Y.Scale < 1) do
					local elapsed = tick() - startTime
					local progress = elapsed / duration
					
					-- Yatay sallanma hareketi - daha az hesaplama
					local xOffset = math.sin(elapsed * frequency) * amplitude
					local newX = startX + xOffset
					
					-- Düşüş hareketi - daha az güncelleme
					snowflake.Position = UDim2.new(
						newX, 0,
						progress, 0
					)
					
					-- Daha az sık güncelleme
					wait(0.05)
				end
				
				-- Kar tanesi ekrandan çıktığında temizle
				if snowflake and snowflake.Parent then
					snowflake:Destroy()
					activeSnowflakes = activeSnowflakes - 1
				end
			end)
		end
		
		-- Performans izleme fonksiyonu
		local function checkPerformance()
			local now = tick()
			local deltaTime = now - lastFrameTime
			frameTimeTotal = frameTimeTotal + deltaTime
			frameCount = frameCount + 1
			
			-- Her 2 saniyede bir performans kontrolü (daha hızlı tepki)
			if frameTimeTotal >= 2 then
				local averageFrameTime = frameTimeTotal / frameCount
				local fps = 1 / averageFrameTime
				
				-- FPS durumuna göre kar tanesi sayısını ayarla
				if fps < 40 then -- Çok düşük FPS
					isLowPerformance = true
					maxSnowflakes = 5 -- Çok düşük performansta çok daha az kar tanesi
				elseif fps < 55 then -- Düşük FPS
					isLowPerformance = true
					maxSnowflakes = 8 -- Düşük performansta az kar tanesi
				else -- Normal FPS
					isLowPerformance = false
					maxSnowflakes = 10 -- Normal performansta standart kar tanesi sayısı
				end
				
				-- Sayaçları sıfırla
				frameCount = 0
				frameTimeTotal = 0
			end
			
			lastFrameTime = now
		end
		
		-- Düzenli aralıklarla kar taneleri oluştur - daha fazla optimize edilmiş
		local lastSnowflakeTime = tick()
		spawn(function()
			while MainWindow and MainWindow.Parent do
				-- Performans kontrolü
				checkPerformance()
				
				-- Kar tanelerinin üst üste gelmesini önlemek için minimum bekleme süresi kontrolü
				local currentTime = tick()
				local timeSinceLastSnowflake = currentTime - lastSnowflakeTime
				
				-- Menü görünür olduğunda ve minimum bekleme süresi geçtiyse kar tanelerini oluştur
				if timeSinceLastSnowflake >= minSpawnInterval then
					createSnowflake()
					lastSnowflakeTime = currentTime
				end
				
				-- Performansa göre bekleme süresini ayarla - daha uzun bekleme süreleri
				local waitTime = isLowPerformance 
					and math.random(12, 20) / 10  -- Düşük performansta 1.2-2.0 saniye
					or math.random(8, 15) / 10   -- Normal performansta 0.8-1.5 saniye
					
				wait(waitTime)
			end
		end)
	end
	
	-- Kar efektini başlat
	CreateSnowEffect()

	-- WindowStuff'ın doğru konumunu ayarlayan fonksiyon - Y pozisyonu sabit
	local function FixWindowStuffPosition()
		if WindowStuff then
			-- Y pozisyonu her zaman sabit (50)
			WindowStuff.Position = UDim2.new(0, 0, 0, 50)
			
			if Minimized then
				-- Küçültülmüş durumda - sadece genişlik değişir
				WindowStuff.Size = UDim2.new(0, 30, 1, -50)
			else
				-- Normal durumda - sadece genişlik değişir
				WindowStuff.Size = UDim2.new(0, 150, 1, -50)
			end
		end
	end
	
	-- İlk çalıştırmada pozisyonu düzelt
	FixWindowStuffPosition()
	
	-- 1. BUTTON CONTAINER (ScreenGui'ye, menünün altını takip edecek şekilde)
	local ButtonContainer = Instance.new("Frame")
	ButtonContainer.Name = "ButtonContainer"
	ButtonContainer.Size = UDim2.new(0, 22, 0, 22)
	ButtonContainer.BackgroundTransparency = 1
	ButtonContainer.Visible = true
	ButtonContainer.ZIndex = 10000
	ButtonContainer.Position = UDim2.new(0, 15, 1, -90)
	ButtonContainer.Parent = Orion
	
	-- 2. ARTILI BUTON (TextLabel ile '+')
	local PlusBtn = Instance.new("TextButton")
	PlusBtn.Name = "PlusBtn"
	PlusBtn.Size = UDim2.new(1, 0, 1, 0)
	PlusBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	PlusBtn.BackgroundTransparency = 0.1
	PlusBtn.Text = "+"
	PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	PlusBtn.Font = Enum.Font.GothamBold
	PlusBtn.TextSize = 14
	PlusBtn.ZIndex = 10001
	PlusBtn.Parent = ButtonContainer
	
	-- Butonun köşelerini yuvarla
	local PlusCorner = Instance.new("UICorner")
	PlusCorner.CornerRadius = UDim.new(1, 0)
	PlusCorner.Parent = PlusBtn

	-- ButtonContainer ve KanistayLabel'ın görünürlüğünü senkronize et
	local function syncVisibility()
		if ButtonContainer and KanistayLabel then
			KanistayLabel.Visible = ButtonContainer.Visible
		end
	end
	
	-- ButtonContainer'ın görünürlüğü değiştiğinde KanistayLabel'ı da güncelle
	ButtonContainer:GetPropertyChangedSignal("Visible"):Connect(syncVisibility)
	
	-- İlk senkronizasyonu yap
	syncVisibility()

	-- Toggle butonunu oluştur
	self:CreateToggleButton()

	AddConnection(MinimizeBtn.MouseButton1Up, function()
		if Minimized then
			-- Büyütme işlemi
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 615, 0, 344)}):Play()
			MinimizeBtn.Ico.Image = "rbxassetid://7072719338"
			wait(.02)
			MainWindow.ClipsDescendants = false
			
			-- WindowStuff'ı önce gizli tut, pozisyonu düzelt, sonra göster
			WindowStuff.Visible = false
			WindowStuff.Position = UDim2.new(0, 0, 0, 50)
			WindowStuff.Size = UDim2.new(0, 150, 1, -50)
			wait(0.1)
			WindowStuff.Visible = true
			WindowTopBarLine.Visible = true
			
			-- ButtonContainer'ı göster (KanistayLabel otomatik olarak takip edecek)
			if ButtonContainer then ButtonContainer.Visible = true end
		else
			-- Küçültme işlemi
			MainWindow.ClipsDescendants = true
			WindowTopBarLine.Visible = false
			MinimizeBtn.Ico.Image = "rbxassetid://7072720870"

			-- Menüyü başlığın genişliği + biraz ekstra alan kadar küçültme
			WindowName.Text = WindowName.Text -- Yazıyı yenileyerek TextBounds'un doğru hesaplanmasını sağla 
			
			local titleWidth = WindowName.TextBounds.X
			local bufferSpace = 140 -- Butonlar ve başlık için daha fazla alan
			local minimizedWidth = math.max(titleWidth + bufferSpace, 280) -- Minimum genişlik 280
			
			-- WindowStuff'ı önce gizli tut, pozisyonu düzelt
			if WindowStuff then
				WindowStuff.Position = UDim2.new(0, 0, 0, 0)
			end
			
			-- ButtonContainer'ı gizle (KanistayLabel otomatik olarak takip edecek)
			if ButtonContainer then ButtonContainer.Visible = false end
			
			-- Sadece genişliği küçült
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, minimizedWidth, 0, 40)}):Play()
			
			wait(0.1)
			WindowStuff.Visible = false
		end
		
		Minimized = not Minimized
		
		-- Pozisyonu düzelt (güvenlik için)
		FixWindowStuffPosition()
	end)


	
	-- 3. SLIDER PANEL (ekranın altına, ortalanmış)
	local SliderPanel = Instance.new("Frame")
	SliderPanel.Name = "SliderPanel"
	-- Slider paneli sade ve küçük
	SliderPanel.Size = UDim2.new(0, 280, 0, 120) -- Genişletilmiş panel
	SliderPanel.BackgroundColor3 = Color3.fromRGB(24,24,24)
	SliderPanel.BackgroundTransparency = 0.1 -- Daha koyu
	SliderPanel.Position = UDim2.new(0.5, -140, 1, -140) -- Daha aşağıda
	SliderPanel.AnchorPoint = Vector2.new(0, 0)
	SliderPanel.Visible = false -- Başlangıçta gizli
	SliderPanel.ZIndex = 11 -- En üstte görünsün
	SliderPanel.Parent = Orion
	local PanelCorner = Instance.new("UICorner")
	PanelCorner.CornerRadius = UDim.new(0, 12)
	PanelCorner.Parent = SliderPanel
	
	-- X Kapatma Butonu
	local CloseButton = Instance.new("TextButton")
	CloseButton.Name = "CloseButton"
	CloseButton.Size = UDim2.new(0, 24, 0, 24)
	CloseButton.Position = UDim2.new(1, -30, 0, 6)
	CloseButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	CloseButton.BackgroundTransparency = 0.3
	CloseButton.Text = "✖" -- X işareti (daha belirgin)
	CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	CloseButton.Font = Enum.Font.GothamBold
	CloseButton.TextSize = 14
	CloseButton.ZIndex = 12
	CloseButton.Parent = SliderPanel
	
	-- X Butonunun köşelerini yuvarla
	local CloseCorner = Instance.new("UICorner")
	CloseCorner.CornerRadius = UDim.new(1, 0)
	CloseCorner.Parent = CloseButton
	
	-- X Butonuna tıklama olayı
	CloseButton.MouseButton1Click:Connect(function()
		SliderPanel.Visible = false
	end)
	
	-- X Butonu için hover efekti
	CloseButton.MouseEnter:Connect(function()
		TweenService:Create(CloseButton, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
			BackgroundColor3 = Color3.fromRGB(255, 80, 80),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()
	end)
	
	CloseButton.MouseLeave:Connect(function()
		TweenService:Create(CloseButton, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()
	end)
	
	-- Butonun tıklama olayı - SliderPanel nil kontrolü ile
	PlusBtn.MouseButton1Click:Connect(function()
		if SliderPanel then
			SliderPanel.Visible = not SliderPanel.Visible
			
			-- SliderPanel görünür olduğunda tüm içeriğinin görünürlüğünü kontrol et
			if SliderPanel.Visible then
				-- Tüm alt öğelerin görünürlüğünü kontrol et
				for _, child in pairs(SliderPanel:GetChildren()) do
					if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("Frame") then
						child.Visible = true
						
						-- Frame içindeki alt öğeleri de kontrol et
						if child:IsA("Frame") or child:IsA("TextButton") then
							for _, subChild in pairs(child:GetChildren()) do
								if subChild:IsA("TextLabel") or subChild:IsA("Frame") then
									subChild.Visible = true
								end
							end
						end
					end
				end
				
				-- Özellikle sliderları kontrol et
				if SizeSlider then SizeSlider.Visible = true end
				if TransSlider then TransSlider.Visible = true end
				if ResetBtn then ResetBtn.Visible = true end
				
				-- Slider barları ve knobları kontrol et
				if SizeSliderBar then SizeSliderBar.Visible = true end
				if SizeSliderKnob then SizeSliderKnob.Visible = true end
				if TransSliderBar then TransSliderBar.Visible = true end
				if TransSliderKnob then TransSliderKnob.Visible = true end
			end
		end
	end)
	
	-- Buton için hover efekti
	PlusBtn.MouseEnter:Connect(function()
		TweenService:Create(PlusBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()
	end)
	
	PlusBtn.MouseLeave:Connect(function()
		TweenService:Create(PlusBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()
	end)
	
	-- Panel Başlığı
	local PanelTitle = Instance.new("TextLabel")
	PanelTitle.Name = "PanelTitle"
	PanelTitle.Size = UDim2.new(1, -20, 0, 24)
	PanelTitle.Position = UDim2.new(0, 10, 0, 6)
	PanelTitle.BackgroundTransparency = 1
	PanelTitle.Text = "Settings"
	PanelTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	PanelTitle.Font = Enum.Font.GothamBold
	PanelTitle.TextSize = 16
	PanelTitle.ZIndex = 12
	PanelTitle.TextXAlignment = Enum.TextXAlignment.Center
	PanelTitle.Parent = SliderPanel
	
	-- Size Slider
	local SizeSlider = Instance.new("TextButton")
	SizeSlider.Name = "SizeSlider"
	SizeSlider.Size = UDim2.new(0.9, 0, 0, 26)
	SizeSlider.Position = UDim2.new(0.05, 0, 0, 36)
	SizeSlider.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	SizeSlider.BackgroundTransparency = 0.5
	SizeSlider.Text = "Size"
	SizeSlider.TextColor3 = Color3.fromRGB(230, 230, 230)
	SizeSlider.Font = Enum.Font.GothamBold
	SizeSlider.TextSize = 14
	SizeSlider.ZIndex = 12
	SizeSlider.TextXAlignment = Enum.TextXAlignment.Left
	SizeSlider.AutoButtonColor = false
	SizeSlider.Parent = SliderPanel
	
	-- Size Corner
	local SizeCorner = Instance.new("UICorner")
	SizeCorner.CornerRadius = UDim.new(0, 6)
	SizeCorner.Parent = SizeSlider
	
	-- Size Slider Bar
	local SizeSliderBar = Instance.new("Frame")
	SizeSliderBar.Name = "Bar"
	SizeSliderBar.Size = UDim2.new(0.65, 0, 0, 5)
	SizeSliderBar.Position = UDim2.new(0.25, 0, 0.5, 0)
	SizeSliderBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	SizeSliderBar.BackgroundTransparency = 0.7
	SizeSliderBar.ZIndex = 12
	SizeSliderBar.Parent = SizeSlider
	
	-- Size Bar Corner
	local SizeBarCorner = Instance.new("UICorner")
	SizeBarCorner.CornerRadius = UDim.new(0, 10)
	SizeBarCorner.Parent = SizeSliderBar
	
	-- Size Slider Knob
	local SizeSliderKnob = Instance.new("Frame")
	SizeSliderKnob.Name = "Knob"
	SizeSliderKnob.Size = UDim2.new(0, 16, 0, 16)
	SizeSliderKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
	SizeSliderKnob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	SizeSliderKnob.ZIndex = 13
	SizeSliderKnob.Parent = SizeSliderBar
	
	-- Size Knob Corner
	local KnobCorner = Instance.new("UICorner")
	KnobCorner.CornerRadius = UDim.new(1, 0)
	KnobCorner.Parent = SizeSliderKnob
	
	-- Size Knob Label
	local SizeValueLabel = Instance.new("TextLabel")
	SizeValueLabel.Name = "ValueLabel"
	SizeValueLabel.Size = UDim2.new(0, 40, 0, 20)
	SizeValueLabel.Position = UDim2.new(0, 8, 0.5, -10)
	SizeValueLabel.BackgroundTransparency = 1
	SizeValueLabel.Text = "100%"
	SizeValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	SizeValueLabel.Font = Enum.Font.GothamSemibold
	SizeValueLabel.TextSize = 12
	SizeValueLabel.ZIndex = 12
	SizeValueLabel.Parent = SizeSlider
	
	-- Size Reset Button
	local SizeResetBtn = Instance.new("TextButton")
	SizeResetBtn.Name = "SizeResetBtn"
	SizeResetBtn.Size = UDim2.new(0, 18, 0, 18)
	SizeResetBtn.Position = UDim2.new(0.95, -9, 0.5, -9)
	SizeResetBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	SizeResetBtn.Text = "⟳"
	SizeResetBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	SizeResetBtn.Font = Enum.Font.GothamBold
	SizeResetBtn.TextSize = 12
	SizeResetBtn.ZIndex = 12
	SizeResetBtn.AutoButtonColor = true
	SizeResetBtn.Parent = SizeSlider
	
	-- Size Reset Corner
	local SizeResetCorner = Instance.new("UICorner")
	SizeResetCorner.CornerRadius = UDim.new(1, 0)
	SizeResetCorner.Parent = SizeResetBtn
	
	-- Transparency Slider
	local TransSlider = Instance.new("TextButton")
	TransSlider.Name = "TransSlider"
	TransSlider.Size = UDim2.new(0.9, 0, 0, 26)
	TransSlider.Position = UDim2.new(0.05, 0, 0, 68)
	TransSlider.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	TransSlider.BackgroundTransparency = 0.5
	TransSlider.Text = "Theme"
	TransSlider.TextColor3 = Color3.fromRGB(230, 230, 230)
	TransSlider.Font = Enum.Font.GothamBold
	TransSlider.TextSize = 14
	TransSlider.ZIndex = 12
	TransSlider.TextXAlignment = Enum.TextXAlignment.Left
	TransSlider.AutoButtonColor = false
	TransSlider.Parent = SliderPanel
	
	-- Trans Corner
	local TransCorner = Instance.new("UICorner")
	TransCorner.CornerRadius = UDim.new(0, 6)
	TransCorner.Parent = TransSlider
	
	-- Trans Slider Bar
	local TransSliderBar = Instance.new("Frame")
	TransSliderBar.Name = "Bar"
	TransSliderBar.Size = UDim2.new(0.65, 0, 0, 5)
	TransSliderBar.Position = UDim2.new(0.25, 0, 0.5, 0)
	TransSliderBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	TransSliderBar.BackgroundTransparency = 0.7
	TransSliderBar.ZIndex = 12
	TransSliderBar.Parent = TransSlider
	
	-- Trans Bar Corner
	local TransBarCorner = Instance.new("UICorner")
	TransBarCorner.CornerRadius = UDim.new(0, 10)
	TransBarCorner.Parent = TransSliderBar
	
	-- Trans Slider Knob
	local TransSliderKnob = Instance.new("Frame")
	TransSliderKnob.Name = "Knob"
	TransSliderKnob.Size = UDim2.new(0, 16, 0, 16)
	TransSliderKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
	TransSliderKnob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	TransSliderKnob.ZIndex = 13
	TransSliderKnob.Parent = TransSliderBar
	
	-- Trans Knob Corner
	local KnobCorner2 = Instance.new("UICorner")
	KnobCorner2.CornerRadius = UDim.new(1, 0)
	KnobCorner2.Parent = TransSliderKnob
	
	-- Trans Value Label
	local TransValueLabel = Instance.new("TextLabel")
	TransValueLabel.Name = "ValueLabel"
	TransValueLabel.Size = UDim2.new(0, 40, 0, 20)
	TransValueLabel.Position = UDim2.new(0, 8, 0.5, -10)
	TransValueLabel.BackgroundTransparency = 1
	TransValueLabel.Text = "0%"
	TransValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	TransValueLabel.Font = Enum.Font.GothamSemibold
	TransValueLabel.TextSize = 12
	TransValueLabel.ZIndex = 12
	TransValueLabel.Parent = TransSlider
	
	-- Trans Reset Button
	local TransResetBtn = Instance.new("TextButton")
	TransResetBtn.Name = "TransResetBtn"
	TransResetBtn.Size = UDim2.new(0, 18, 0, 18)
	TransResetBtn.Position = UDim2.new(0.95, -9, 0.5, -9)
	TransResetBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	TransResetBtn.Text = "⟳"
	TransResetBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	TransResetBtn.Font = Enum.Font.GothamBold
	TransResetBtn.TextSize = 12
	TransResetBtn.ZIndex = 12
	TransResetBtn.AutoButtonColor = true
	TransResetBtn.Parent = TransSlider
	
	-- Trans Reset Corner
	local TransResetCorner = Instance.new("UICorner")
	TransResetCorner.CornerRadius = UDim.new(1, 0)
	TransResetCorner.Parent = TransResetBtn
	
	-- Reset Butonu
	local ResetBtn = Instance.new("TextButton")
	ResetBtn.Name = "ResetBtn"
	ResetBtn.Size = UDim2.new(0, 100, 0, 22)
	ResetBtn.Position = UDim2.new(0.5, -50, 0, 100)
	ResetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	ResetBtn.Text = "Reset All"
	ResetBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	ResetBtn.Font = Enum.Font.GothamBold
	ResetBtn.TextSize = 14
	ResetBtn.ZIndex = 12
	ResetBtn.AutoButtonColor = true
	ResetBtn.Parent = SliderPanel
	
	-- Reset Corner
	local ResetCorner = Instance.new("UICorner")
	ResetCorner.CornerRadius = UDim.new(0, 6)
	ResetCorner.Parent = ResetBtn
	
	-- Reset butonları fonksiyonları
	ResetBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if MainWindow then
				MainWindow.Size = UDim2.new(0, 615, 0, 344)
			end
			if SizeSliderKnob then
				SizeSliderKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
				SizeValueLabel.Text = "100%"
			end
			if TransSliderKnob then
				TransSliderKnob.Position = UDim2.new(0, -8, 0.5, -8)
				TransValueLabel.Text = "0%"
			end
			if MainWindow then
				MainWindow.BackgroundTransparency = 0
				
				-- Tüm ScrollingFrame'lerin parent'larını güncelle
				for _, v in pairs(MainWindow:GetChildren()) do
					if v:IsA("ScrollingFrame") and v.Parent and v.Parent ~= MainWindow then
						v.Parent.BackgroundTransparency = 0
					end
				end
				
				-- WindowStuff frame'ini güncelle
				if WindowStuff then
					WindowStuff.BackgroundTransparency = 0
				end
			end
		end)
	end)
	
	SizeResetBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if MainWindow then
				MainWindow.Size = UDim2.new(0, 615, 0, 344)
			end
			if SizeSliderKnob then
				SizeSliderKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
				SizeValueLabel.Text = "100%"
			end
		end)
	end)
	
	TransResetBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if MainWindow then
				MainWindow.BackgroundTransparency = 0
			end
			if TransSliderKnob then
				TransSliderKnob.Position = UDim2.new(0, -8, 0.5, -8)
				TransValueLabel.Text = "0%"
			end
			
			-- Tüm ScrollingFrame'lerin parent'larını güncelle
			if MainWindow then
				for _, v in pairs(MainWindow:GetChildren()) do
					if v:IsA("ScrollingFrame") and v.Parent and v.Parent ~= MainWindow then
						v.Parent.BackgroundTransparency = 0
					end
				end
				
				-- WindowStuff frame'ini güncelle
				if WindowStuff then
					WindowStuff.BackgroundTransparency = 0
				end
			end
		end)
	end)
	
	-- Size Slider drag - sürükleme işlemi
	local draggingSize = false
	
	pcall(function()
		if SizeSliderKnob then
			SizeSliderKnob.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then 
					draggingSize = true 
				end
			end)
			
			SizeSliderKnob.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then 
					draggingSize = false 
				end
			end)
		end
		
		UserInputService.InputChanged:Connect(function(input)
			if draggingSize and input.UserInputType == Enum.UserInputType.MouseMovement and SizeSliderBar then
				pcall(function()
					local abs = SizeSliderBar.AbsolutePosition
					local size = SizeSliderBar.AbsoluteSize.X
					local rel = math.clamp((input.Position.X - abs.X) / size, 0, 1)
					
					if SizeSliderKnob then
						SizeSliderKnob.Position = UDim2.new(rel, -8, 0.5, -8)
					end
					
					-- Size değişikliği
					local minW, maxW = 400, 900
					local minH, maxH = 200, 600
					local newW = minW + (maxW-minW)*rel
					local newH = minH + (maxH-minH)*rel
					
					if MainWindow then
						MainWindow.Size = UDim2.new(0, newW, 0, newH)
					end
					
					-- Label değerini güncelle
					if SizeValueLabel then
						SizeValueLabel.Text = math.floor(rel * 100) .. "%"
					end
				end)
			end
		end)
	end)
	
	-- Transparency Slider drag
	local draggingTrans = false
	
	pcall(function()
		if TransSliderKnob then
			TransSliderKnob.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then 
					draggingTrans = true 
				end
			end)
			
			TransSliderKnob.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then 
					draggingTrans = false 
				end
			end)
		end
		
		UserInputService.InputChanged:Connect(function(input)
			if draggingTrans and input.UserInputType == Enum.UserInputType.MouseMovement and TransSliderBar then
				pcall(function()
					local abs = TransSliderBar.AbsolutePosition
					local size = TransSliderBar.AbsoluteSize.X
					local rel = math.clamp((input.Position.X - abs.X) / size, 0, 1)
					
					if TransSliderKnob then
						TransSliderKnob.Position = UDim2.new(rel, -8, 0.5, -8)
					end
					
					-- SADECE şeffaflık değişimi, renk değişimi tamamen kaldırıldı
					if MainWindow then
						local tval = tonumber(rel) or 0
						tval = tval * 0.8 -- 0 ila 0.8 arası transparanlık
						MainWindow.BackgroundTransparency = tval
					end
					
					-- Sadece şeffaflık değişimi
					if WindowStuff then
						local tval = tonumber(rel) or 0
						tval = tval * 0.8
						WindowStuff.BackgroundTransparency = tval
					end
					
					-- Label değerini güncelle
					if TransValueLabel then
						TransValueLabel.Text = math.floor((tonumber(rel) or 0) * 100) .. "%"
					end
				end)
			end
		end)
	end)
	
	-- MainWindow'un altını takip etmesi için her frame konum güncelle (iyileştirilmiş)
	local lastUpdate = 0
	local updateInterval = 0.1 -- 100 ms (saniyede 10 kez güncellenecek)
	
	RunService.RenderStepped:Connect(function()
		-- Artı butonunun menüyü anında takip etmesi için optimizasyon
		pcall(function()
			-- Artı butonunun konumunu MainWindow'un sol altına ayarla - anında takip için
			if MainWindow and MainWindow.Parent and ButtonContainer and ButtonContainer.Parent then
				local pos = MainWindow.AbsolutePosition
				local size = MainWindow.AbsoluteSize
				-- Daha yapışık ve anında takip için doğrudan pozisyon atama
				ButtonContainer.Position = UDim2.new(0, pos.X - 5, 0, pos.Y + size.Y - 25)
			end
			
			-- ScrollingFrame'in parent'ı olan frame'in boyutunu güncelle
			if MainWindow then
				for _, v in pairs(MainWindow:GetChildren()) do
					if v.Name == "ItemContainer" and MainWindow:FindFirstChild("TopBar") then
						pcall(function()
							-- TopBar offset değerini doğru hesaplayarak frame boyutunu düzgün ayarla
							local topBarOffset = MainWindow.TopBar.Size.Y.Offset + 2 -- 2 piksel extra padding
							
							-- TabHolder görünürlüğüne göre boyut ayarla
							if TabHolder and TabHolder.Visible then
								v.Size = UDim2.new(1, -150, 1, -topBarOffset) -- Normal boyut
								v.Position = UDim2.new(0, 150, 0, topBarOffset)
							else
								v.Size = UDim2.new(1, -30, 1, -topBarOffset) -- Genişletilmiş boyut
								v.Position = UDim2.new(0, 30, 0, topBarOffset)
							end
							
							-- CanvasSize'ı doğru şekilde güncelle ve sınırla
							if v:FindFirstChild("UIListLayout") and v.Visible then
								local contentHeight = v.UIListLayout.AbsoluteContentSize.Y + 30
								local visibleHeight = v.AbsoluteSize.Y
								v.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
								
								-- ScrollingFrame'in içeriğinin görünür alan dışına taşmasını önle
								if contentHeight < visibleHeight then
									v.CanvasSize = UDim2.new(0, 0, 0, visibleHeight)
								end
							end
						end)
					end
				end
			end
		end)
	end)

	AddOnlineDot(WindowName, MainWindow)

	local TabFunction = {}
	function TabFunction:MakeTab(TabConfig)
		TabConfig = TabConfig or {}
		TabConfig.Name = TabConfig.Name or "Tab"
		TabConfig.Icon = TabConfig.Icon or ""
		TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

		local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
			Size = UDim2.new(1, 0, 0, 30),
			Parent = TabHolder
		}), {
			AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 18, 0, 18),
				Position = UDim2.new(0, 10, 0.5, 0),
				ImageTransparency = 0.4,
				Name = "Ico"
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
				Size = UDim2.new(1, -35, 1, 0),
				Position = UDim2.new(0, 35, 0, 0),
				Font = Enum.Font.GothamSemibold,
				TextTransparency = 0.4,
				Name = "Title"
			}), "Text")
		})

		if GetIcon(TabConfig.Icon) ~= nil then
			TabFrame.Ico.Image = GetIcon(TabConfig.Icon)
		end	

		local Container = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 5), {
			Size = UDim2.new(1, -150, 1, -50),
			Position = UDim2.new(0, 150, 0, 50),
			Parent = MainWindow,
			Visible = false,
			Name = "ItemContainer"
		}), {
			MakeElement("List", 0, 6),
			MakeElement("Padding", 15, 10, 10, 15)
		}), "Divider")
		
		-- ScrollFrame'e köşe yuvarlaklığı ekle
		local ScrollCorner = Instance.new("UICorner")
		ScrollCorner.CornerRadius = UDim.new(0, 8)
		ScrollCorner.Parent = Container

		-- ScrollFrame görünürlük durumu
		local isScrollVisible = true

		AddConnection(Container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			Container.CanvasSize = UDim2.new(0, 0, 0, Container.UIListLayout.AbsoluteContentSize.Y + 30)
			
			-- Container içindeki öğelerin genişliğini ayarla
			for _, Element in pairs(Container:GetChildren()) do
				if (Element:IsA("Frame") or Element:IsA("TextButton")) and not Element:IsA("UIListLayout") and not Element:IsA("UIPadding") and not Element:IsA("UICorner") then
					if Element.Name ~= "ScrollToggleBtn" then
						Element.Size = UDim2.new(1, 0, Element.Size.Y.Scale, Element.Size.Y.Offset)
					end
				end
			end
		end)
		
		-- Container boyutunun MainWindow değiştikçe adapte olmasını sağla
		AddConnection(MainWindow:GetPropertyChangedSignal("Size"), function()
			if Container and MainWindow and MainWindow:FindFirstChild("TopBar") then
				local topBarHeight = MainWindow.TopBar.Size.Y.Offset
				
				-- TabHolder görünürlüğüne göre boyut ayarla
				if TabHolder and TabHolder.Visible then
					Container.Size = UDim2.new(1, -150, 1, -(topBarHeight + 4))
					Container.Position = UDim2.new(0, 150, 0, topBarHeight + 2)
				else
					Container.Size = UDim2.new(1, -30, 1, -(topBarHeight + 4))
					Container.Position = UDim2.new(0, 30, 0, topBarHeight + 2)
				end
				
				-- CanvasSize'ı da yeniden hesaplayalım ve sınırlayalım
				if Container.Visible then
					local contentHeight = Container.UIListLayout.AbsoluteContentSize.Y + 30
					local visibleHeight = Container.AbsoluteSize.Y
					Container.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
					
					-- ScrollingFrame'in içeriğinin görünür alan dışına taşmasını önle
					if contentHeight < visibleHeight then
						Container.CanvasSize = UDim2.new(0, 0, 0, visibleHeight)
					end
				end
			end
		end)

		if FirstTab then
			FirstTab = false
			TabFrame.Ico.ImageTransparency = 0
			TabFrame.Title.TextTransparency = 0
			TabFrame.Title.Font = Enum.Font.GothamBlack
			Container.Visible = true
		end    

		AddConnection(TabFrame.MouseButton1Click, function()
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") then
					Tab.Title.Font = Enum.Font.GothamSemibold
					TweenService:Create(Tab.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.4}):Play()
					TweenService:Create(Tab.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.4}):Play()
				end    
			end
			for _, ItemContainer in next, MainWindow:GetChildren() do
				if ItemContainer.Name == "ItemContainer" then
					ItemContainer.Visible = false
				end    
			end  
			TweenService:Create(TabFrame.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play()
			TweenService:Create(TabFrame.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
			TabFrame.Title.Font = Enum.Font.GothamBlack
			Container.Visible = true
			
			-- TabHolder gizliyse, Container'ı genişletilmiş olarak göster
			if not TabHolder.Visible then
				Container.Size = UDim2.new(1, -30, 1, -(MainWindow.TopBar.Size.Y.Offset + 4))
				Container.Position = UDim2.new(0, 30, 0, MainWindow.TopBar.Size.Y.Offset + 2)
				
				-- Container içindeki öğelerin genişliğini artır
				wait(0.1) -- Kısa bir bekleme ekleyelim
				for _, Element in pairs(Container:GetChildren()) do
					if (Element:IsA("Frame") or Element:IsA("TextButton")) and not Element:IsA("UIListLayout") and not Element:IsA("UIPadding") and not Element:IsA("UICorner") then
						if Element.Name ~= "ScrollToggleBtn" then
							TweenService:Create(Element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
								Size = UDim2.new(1, 0, Element.Size.Y.Scale, Element.Size.Y.Offset)
							}):Play()
						end
					end
				end
				
				-- CanvasSize'ı doğru şekilde güncelle ve sınırla
				wait(0.2) -- Animasyonun tamamlanmasını bekle
				local contentHeight = Container.UIListLayout.AbsoluteContentSize.Y + 30
				local visibleHeight = Container.AbsoluteSize.Y
				Container.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
				
				-- ScrollingFrame'in içeriğinin görünür alan dışına taşmasını önle
				if contentHeight < visibleHeight then
					Container.CanvasSize = UDim2.new(0, 0, 0, visibleHeight)
				end
			else
				Container.Size = UDim2.new(1, -150, 1, -(MainWindow.TopBar.Size.Y.Offset + 4))
				Container.Position = UDim2.new(0, 150, 0, MainWindow.TopBar.Size.Y.Offset + 2)
				
				-- Container içindeki öğelerin genişliğini normal boyuta getir
				wait(0.1) -- Kısa bir bekleme ekleyelim
				for _, Element in pairs(Container:GetChildren()) do
					if (Element:IsA("Frame") or Element:IsA("TextButton")) and not Element:IsA("UIListLayout") and not Element:IsA("UIPadding") and not Element:IsA("UICorner") then
						if Element.Name ~= "ScrollToggleBtn" then
							TweenService:Create(Element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
								Size = UDim2.new(1, 0, Element.Size.Y.Scale, Element.Size.Y.Offset)
							}):Play()
						end
					end
				end
				
				-- CanvasSize'ı doğru şekilde güncelle ve sınırla
				wait(0.2) -- Animasyonun tamamlanmasını bekle
				local contentHeight = Container.UIListLayout.AbsoluteContentSize.Y + 30
				local visibleHeight = Container.AbsoluteSize.Y
				Container.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
				
				-- ScrollingFrame'in içeriğinin görünür alan dışına taşmasını önle
				if contentHeight < visibleHeight then
					Container.CanvasSize = UDim2.new(0, 0, 0, visibleHeight)
				end
			end
		end)

		local function GetElements(ItemParent)
			local ElementFunction = {}
			function ElementFunction:AddLabel(Text)
				local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")

				local LabelFunction = {}
				function LabelFunction:Set(ToChange)
					LabelFrame.Content.Text = ToChange
				end
				return LabelFunction
			end
			function ElementFunction:AddParagraph(Text, Content)
				Text = Text or "Text"
				Content = Content or "Content"

				local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 10),
						Font = Enum.Font.GothamBold,
						Name = "Title"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Label", "", 13), {
						Size = UDim2.new(1, -24, 0, 0),
						Position = UDim2.new(0, 12, 0, 26),
						Font = Enum.Font.GothamSemibold,
						Name = "Content",
						TextWrapped = true
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")

				AddConnection(ParagraphFrame.Content:GetPropertyChangedSignal("Text"), function()
					ParagraphFrame.Content.Size = UDim2.new(1, -24, 0, ParagraphFrame.Content.TextBounds.Y)
					ParagraphFrame.Size = UDim2.new(1, 0, 0, ParagraphFrame.Content.TextBounds.Y + 35)
				end)

				ParagraphFrame.Content.Text = Content

				local ParagraphFunction = {}
				function ParagraphFunction:Set(ToChange)
					ParagraphFrame.Content.Text = ToChange
				end
				return ParagraphFunction
			end    
			function ElementFunction:AddButton(ButtonConfig)
				ButtonConfig = ButtonConfig or {}
				ButtonConfig.Name = ButtonConfig.Name or "Button"
				ButtonConfig.Callback = ButtonConfig.Callback or function() end
				ButtonConfig.Icon = ButtonConfig.Icon or "rbxassetid://3944703587"

				local Button = {}

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 33),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
						Size = UDim2.new(0, 20, 0, 20),
						Position = UDim2.new(1, -30, 0, 7),
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					Click
				}), "Second")

				AddConnection(Click.MouseEnter, function()
					TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseLeave, function()
					TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				AddConnection(Click.MouseButton1Up, function()
					-- Tıklama sonrası normal renge dön
					TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
					spawn(function()
						ButtonConfig.Callback()
					end)
				end)

				AddConnection(Click.MouseButton1Down, function()
					-- Tıklama anında yeşil vurgu
					TweenService:Create(ButtonFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(40, 180, 80)}):Play()
					
					-- Kısa bir süre sonra hafif yeşil kalacak şekilde ayarla
					spawn(function()
						wait(0.1)
						TweenService:Create(ButtonFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 20, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)}):Play()
					end)
				end)

				function Button:Set(ButtonText)
					ButtonFrame.Content.Text = ButtonText
				end	

				return Button
			end    
			function ElementFunction:AddToggle(ToggleConfig)
				ToggleConfig = ToggleConfig or {}
				ToggleConfig.Name = ToggleConfig.Name or "Toggle"
				ToggleConfig.Default = ToggleConfig.Default or false
				ToggleConfig.Callback = ToggleConfig.Callback or function() end
				ToggleConfig.Color = ToggleConfig.Color or Color3.fromRGB(0, 200, 80) -- Yeşil renk varsayılan
				ToggleConfig.Flag = ToggleConfig.Flag or nil
				ToggleConfig.Save = ToggleConfig.Save or false

				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save}

				-- Tıklama butonu için güvenli ve basit bir yapı
				local Click = Instance.new("TextButton")
				Click.Text = ""
				Click.AutoButtonColor = false
				Click.BackgroundTransparency = 1
				Click.BorderSizePixel = 0
				Click.Size = UDim2.new(1, 0, 1, 0)
				Click.ZIndex = 10
				Click.Name = "ClickArea"

				-- Modern swipe toggle yapısı - basitleştirilmiş
				local ToggleBackground = SetProps(MakeElement("RoundFrame", Color3.fromRGB(50, 50, 50), 0, 10), {
					Size = UDim2.new(0, 46, 0, 24),
					Position = UDim2.new(1, -56, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Name = "Background"
				})
				
				-- Toggle knob (sürüklenen kısım) - basitleştirilmiş
				local ToggleKnob = SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(0, 3, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Name = "Knob"
				})
				
				ToggleKnob.Parent = ToggleBackground

				-- Ana çerçeve
				local ToggleFrame = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), "Second")
				
				-- İçeriği ekle
				local Content = AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 15), {
					Size = UDim2.new(1, -64, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Enum.Font.GothamBold,
					Name = "Content"
				}), "Text")
				
				-- Stroke ekle
				local Stroke = AddThemeObject(MakeElement("Stroke"), "Stroke")
				
				-- Tüm öğeleri çerçeveye ekle
				Content.Parent = ToggleFrame
				ToggleBackground.Parent = ToggleFrame
				Stroke.Parent = ToggleFrame
				Click.Parent = ToggleFrame

				function Toggle:Set(Value)
					Toggle.Value = Value
					
					-- Renk ayarlama - aktifse yeşil, değilse kırmızı
					local ActiveColor = Value and ToggleConfig.Color or Color3.fromRGB(220, 40, 40) -- Aktif: yeşil, Pasif: kırmızı
					
					-- Basitleştirilmiş görsel değişiklik
					TweenService:Create(ToggleBackground, TweenInfo.new(0.3, Enum.EasingStyle.Quad), 
					{BackgroundColor3 = ActiveColor}):Play()
					
					TweenService:Create(ToggleKnob, TweenInfo.new(0.3, Enum.EasingStyle.Quad), 
					{Position = Value and UDim2.new(0, 25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)}):Play()
					
					-- Callback'i çağır
					pcall(function()
						ToggleConfig.Callback(Toggle.Value)
					end)
				end    

				Toggle:Set(Toggle.Value)

				-- Hover efekti
				Click.MouseEnter:Connect(function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
						BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)
					}):Play()
				end)

				Click.MouseLeave:Connect(function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), 
					{BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				-- Tıklama işlevi - basitleştirilmiş ve güvenli
				Click.MouseButton1Up:Connect(function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
						BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)
					}):Play()
					Toggle:Set(not Toggle.Value)
					pcall(function() GlobalSaveCfg(game.GameId) end)
				end)

				Click.MouseButton1Down:Connect(function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
						BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 6, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)
					}):Play()
				end)

				if ToggleConfig.Flag then
					OrionLib.Flags[ToggleConfig.Flag] = Toggle
				end
				
				return Toggle
			end    
			function ElementFunction:AddSlider(SliderConfig)
				SliderConfig = SliderConfig or {}
				SliderConfig.Name = SliderConfig.Name or "Slider"
				SliderConfig.Min = SliderConfig.Min or 0
				SliderConfig.Max = SliderConfig.Max or 100
				SliderConfig.Increment = SliderConfig.Increment or 1
				SliderConfig.Default = SliderConfig.Default or 50
				SliderConfig.Callback = SliderConfig.Callback or function() end
				SliderConfig.ValueName = SliderConfig.ValueName or ""
				SliderConfig.Color = SliderConfig.Color or Color3.fromRGB(9, 149, 98)
				SliderConfig.Flag = SliderConfig.Flag or nil
				SliderConfig.Save = SliderConfig.Save or false

				local Slider = {Value = SliderConfig.Default, Save = SliderConfig.Save}
				local Dragging = false

				-- Ana slider çerçevesi
				local SliderFrame = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(1, 0, 0, 65),
					Parent = ItemParent
				}), "Second")

				-- Stroke (kenar) ekle
				local Stroke = AddThemeObject(MakeElement("Stroke"), "Stroke")
				Stroke.Parent = SliderFrame

				-- Slider başlığı
				local Title = AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 15), {
					Size = UDim2.new(1, -12, 0, 14),
					Position = UDim2.new(0, 12, 0, 10),
					Font = Enum.Font.GothamBold,
					Name = "Title",
					Parent = SliderFrame
				}), "Text")

				-- Slider bar arkaplanı
				local SliderBar = SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size = UDim2.new(1, -24, 0, 26),
					Position = UDim2.new(0, 12, 0, 30),
					BackgroundTransparency = 0.9,
					Parent = SliderFrame
				})

				-- Slider bar kenarı
				local SliderStroke = SetProps(MakeElement("Stroke"), {
					Color = SliderConfig.Color,
					Parent = SliderBar
				})

				-- Slider bar değer etiketi (arkaplanda)
				local SliderBarText = AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
					Size = UDim2.new(1, -12, 0, 14),
					Position = UDim2.new(0, 12, 0, 6),
					Font = Enum.Font.GothamBold,
					Name = "Value",
					TextTransparency = 0.8,
					Parent = SliderBar
				}), "Text")

				-- Slider dolgu (drag edilebilir kısım) - neon mavi sıvı görünümü
				local SliderDrag = SetProps(MakeElement("RoundFrame", Color3.fromRGB(30, 120, 255), 0, 5), {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 0.2,
					ClipsDescendants = true,
					Parent = SliderBar
				})
				
				-- Neon efekti için gradient ekle
				local NeonGradient = Instance.new("UIGradient")
				NeonGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 100, 255)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 150, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 100, 255))
				})
				NeonGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(0.5, 0.3),
					NumberSequenceKeypoint.new(1, 0.1)
				})
				NeonGradient.Rotation = 90
				NeonGradient.Parent = SliderDrag
				
				-- Hareketli su efekti için animasyon
				spawn(function()
					local offset = 0
					while wait(0.05) do
						offset = (offset + 2) % 360
						if NeonGradient and NeonGradient.Parent then
							NeonGradient.Rotation = offset
						else
							break
						end
					end
				end)
				
				-- Parlak kenar ekle
				local NeonStroke = Instance.new("UIStroke")
				NeonStroke.Color = Color3.fromRGB(100, 180, 255)
				NeonStroke.Thickness = 1.5
				NeonStroke.Transparency = 0.2
				NeonStroke.Parent = SliderDrag

				-- Slider dolgu değer etiketi (görünür, önde)
				local SliderDragText = AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
					Size = UDim2.new(1, -12, 0, 14),
					Position = UDim2.new(0, 12, 0, 6),
					Font = Enum.Font.GothamBold,
					Name = "Value",
					TextTransparency = 0,
					Parent = SliderDrag
				}), "Text")

				-- Tıklama alanı
				local Click = Instance.new("TextButton")
				Click.Size = UDim2.new(1, 0, 1, 0)
				Click.BackgroundTransparency = 1
				Click.Text = ""
				Click.Name = "ClickArea"
				Click.Parent = SliderBar

				local function UpdateDrag(Input)
					-- Fare pozisyonuna göre değeri hesapla
					local SizeScale = math.clamp((Input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
					local Value = SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale)
					
					-- Değeri increment değerine göre yuvarla
					Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
					
					-- Slider değerini ayarla
					Slider:Set(Value)
					pcall(function()
						pcall(function() GlobalSaveCfg(game.GameId) end)
					end)
				end

				function Slider:Set(Value)
					self.Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
					
					-- Slider dolgu boyutunu hesapla ve animasyon ile göster
					local SizeScale = (self.Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
					-- Minimum boyut sınırı ekle
					if self.Value == SliderConfig.Min then
						SizeScale = 0.08 -- Minimum değerde %8 genişlik
					end
					TweenService:Create(SliderDrag, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
						Size = UDim2.fromScale(SizeScale, 1)
					}):Play()
					
					-- Değer etiketlerini güncelle
					local DisplayValue = self.Value .. " " .. SliderConfig.ValueName
					SliderBarText.Text = DisplayValue
					SliderDragText.Text = DisplayValue
					
					-- Callback çağır
					pcall(function()
						SliderConfig.Callback(self.Value)
					end)
					
					-- Config kaydet
					pcall(function() SaveCfg(game.GameId) end)
				end      

				-- Tıklama eventlerini ekle (hem mouse hem touch için)
				Click.MouseButton1Down:Connect(function()
					Dragging = true
					UpdateDrag({Position = UserInputService:GetMouseLocation()})
				end)
				
				UserInputService.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Dragging = false
					end
				end)

				UserInputService.InputChanged:Connect(function(Input)
					if (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) and Dragging then
						UpdateDrag(Input)
					end
				end)
						
				Slider:Set(Slider.Value)
				if SliderConfig.Flag then				
					OrionLib.Flags[SliderConfig.Flag] = Slider
				end
				return Slider
			end  
			function ElementFunction:AddDropdown(DropdownConfig)
				DropdownConfig = DropdownConfig or {}
				DropdownConfig.Name = DropdownConfig.Name or "Dropdown"
				DropdownConfig.Options = DropdownConfig.Options or {}
				DropdownConfig.Default = DropdownConfig.Default or ""
				DropdownConfig.Callback = DropdownConfig.Callback or function() end
				DropdownConfig.Flag = DropdownConfig.Flag or nil
				DropdownConfig.Save = DropdownConfig.Save or false

				-- Dropdown değerleri için nesne
				local Dropdown = {
					Value = DropdownConfig.Default, 
					Options = DropdownConfig.Options, 
					Buttons = {}, 
					Toggled = false, 
					Type = "Dropdown", 
					Save = DropdownConfig.Save
				}
				local MaxElements = 5
				
				-- Varsayılan değer kontrolü
				if not table.find(Dropdown.Options, Dropdown.Value) then
					Dropdown.Value = "..."
				end
				
				-- Dropdown liste container
				local DropdownContainer = AddThemeObject(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(40, 40, 40), 4), {
					Position = UDim2.new(0, 0, 0, 38),
					Size = UDim2.new(1, 0, 1, -38),
					ClipsDescendants = true,
					Visible = false
				}), "Divider")
				
				-- Liste düzeni
				local DropdownList = MakeElement("List")
				DropdownList.Parent = DropdownContainer
				
				-- Container için padding
				local Padding = MakeElement("Padding", 8, 8, 8, 8) 
				Padding.Parent = DropdownContainer
				
				-- Ana dropdown çerçevesi
				local DropdownFrame = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					ClipsDescendants = true,
					Parent = ItemParent
				}), "Second")
				
				-- Dropdown içerik container
				local DropdownContent = SetProps(MakeElement("TFrame"), {
					Size = UDim2.new(1, 0, 0, 38),
					Name = "F",
					Parent = DropdownFrame
				})
				
				-- Dropdown başlığı
				local DropdownTitle = AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 15), {
					Size = UDim2.new(1, -12, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Enum.Font.GothamBold,
					Name = "Content",
					Parent = DropdownContent
				}), "Text")
				
				-- Dropdown seçili değer etiketi
				local SelectedText = AddThemeObject(SetProps(MakeElement("Label", "Selected", 13), {
					Size = UDim2.new(1, -40, 1, 0),
					Font = Enum.Font.Gotham,
					Name = "Selected",
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = DropdownContent
				}), "TextDark")
				
				-- Dropdown ikonu
				local IconButton = AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
					Size = UDim2.new(0, 20, 0, 20),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(1, -30, 0.5, 0),
					ImageColor3 = Color3.fromRGB(240, 240, 240),
					Name = "Ico",
					Parent = DropdownContent
				}), "TextDark")
				
				-- Çerçeve için alt çizgi
				local DropdownLine = AddThemeObject(SetProps(MakeElement("Frame"), {
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.new(0, 0, 1, -1),
					Name = "Line",
					Visible = false,
					Parent = DropdownContent
				}), "Stroke")
				
				-- Çerçeve için kenar
				local DropdownStroke = AddThemeObject(MakeElement("Stroke"), "Stroke")
				DropdownStroke.Parent = DropdownFrame
				
				-- Köşeleri yuvarla
					local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6) -- Biraz daha yuvarlak köşeler (4'ten 6'ya)
	Corner.Parent = DropdownFrame
				
				-- Dropdown containerını da DropdownFrame'e ekle
				DropdownContainer.Parent = DropdownFrame
				
				-- Tıklanabilir alan
				local Click = Instance.new("TextButton")
				Click.Name = "ClickArea"
				Click.Size = UDim2.new(1, 0, 1, 0)
				Click.BackgroundTransparency = 1
				Click.Text = ""
				Click.ZIndex = 5
				Click.Parent = DropdownContent
				
				-- Liste boyutunu ayarla
				AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownList.AbsoluteContentSize.Y)
				end)

				-- Dropdown öğelerini ekle
				local function AddOptions(Options)
					for _, Option in pairs(Options) do
						-- Option butonu oluştur
						local OptionBtn = Instance.new("TextButton")
						OptionBtn.Size = UDim2.new(1, -16, 0, 32) -- Genişliği azaltıldı ve yükseklik arttırıldı
						OptionBtn.Position = UDim2.new(0, 8, 0, 0) -- Kenarlarda boşluk bırakıldı
						OptionBtn.BackgroundTransparency = 1
						OptionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
						OptionBtn.Text = ""
						OptionBtn.ClipsDescendants = true
						OptionBtn.Parent = DropdownContainer
						
						-- Option butonu köşeleri
						local BtnCorner = Instance.new("UICorner")
						BtnCorner.CornerRadius = UDim.new(0, 6)
						BtnCorner.Parent = OptionBtn
						
						-- Option butonu başlığı
						local BtnTitle = Instance.new("TextLabel")
						BtnTitle.Name = "Title"
						BtnTitle.Size = UDim2.new(1, -8, 1, 0)
						BtnTitle.Position = UDim2.new(0, 8, 0, 0)
						BtnTitle.BackgroundTransparency = 1
						BtnTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
						BtnTitle.TextTransparency = 0.4
						BtnTitle.TextSize = 13
						BtnTitle.Font = Enum.Font.Gotham
						BtnTitle.Text = Option
						BtnTitle.TextXAlignment = Enum.TextXAlignment.Left
						BtnTitle.Parent = OptionBtn
						
						-- Buton tıklama olayı
						OptionBtn.MouseButton1Click:Connect(function()
							Dropdown:Set(Option)
							pcall(function() GlobalSaveCfg(game.GameId) end)
						end)
						
						Dropdown.Buttons[Option] = OptionBtn
					end
				end

				-- Dropdown'ı güncelleyen fonksiyon
				function Dropdown:Refresh(Options, Delete)
					if Delete then
						for _,v in pairs(Dropdown.Buttons) do
							v:Destroy()
						end    
						table.clear(Dropdown.Options)
						table.clear(Dropdown.Buttons)
					end
					Dropdown.Options = Options
					AddOptions(Dropdown.Options)
				end  

				-- Dropdown değerini ayarlayan fonksiyon
				function Dropdown:Set(Value)
					if not table.find(Dropdown.Options, Value) then
						Dropdown.Value = "..."
						SelectedText.Text = Dropdown.Value
						
						for _, v in pairs(Dropdown.Buttons) do
							pcall(function()
								TweenService:Create(v, TweenInfo.new(.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
								TweenService:Create(v.Title, TweenInfo.new(.15, Enum.EasingStyle.Quad), {TextTransparency = 0.4}):Play()
							end)
						end
						return
					end

					Dropdown.Value = Value
					SelectedText.Text = Dropdown.Value

					for _, v in pairs(Dropdown.Buttons) do
						pcall(function()
							TweenService:Create(v, TweenInfo.new(.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
							TweenService:Create(v.Title, TweenInfo.new(.15, Enum.EasingStyle.Quad), {TextTransparency = 0.4}):Play()
						end)
					end
					
					if Dropdown.Buttons[Value] then
						pcall(function()
							TweenService:Create(Dropdown.Buttons[Value], TweenInfo.new(.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()
							TweenService:Create(Dropdown.Buttons[Value].Title, TweenInfo.new(.15, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
						end)
					end
					
					pcall(function()
						DropdownConfig.Callback(Dropdown.Value)
					end)
				end

				-- Tıklama olayı
				Click.MouseButton1Click:Connect(function()
					Dropdown.Toggled = not Dropdown.Toggled
					DropdownLine.Visible = Dropdown.Toggled
					DropdownContainer.Visible = Dropdown.Toggled
					
					-- İkon rotasyonu animasyonu
					TweenService:Create(IconButton, TweenInfo.new(.15, Enum.EasingStyle.Quad), {
						Rotation = Dropdown.Toggled and 180 or 0
					}):Play()
					
					-- Dropdown boyut animasyonu
					if #Dropdown.Options > MaxElements then
						TweenService:Create(DropdownFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {
							Size = Dropdown.Toggled and 
							UDim2.new(1, 0, 0, 38 + (MaxElements * 28)) or 
							UDim2.new(1, 0, 0, 38)
						}):Play()
					else
						TweenService:Create(DropdownFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {
							Size = Dropdown.Toggled and 
							UDim2.new(1, 0, 0, DropdownList.AbsoluteContentSize.Y + 38) or 
							UDim2.new(1, 0, 0, 38)
						}):Play()
					end
				end)

				-- Seçenekleri ekle
				Dropdown:Refresh(Dropdown.Options, false)
				Dropdown:Set(Dropdown.Value)
				
				-- Flag varsa ekle
				if DropdownConfig.Flag then				
					OrionLib.Flags[DropdownConfig.Flag] = Dropdown
				end
				return Dropdown
			end
			function ElementFunction:AddBind(BindConfig)
				BindConfig.Name = BindConfig.Name or "Bind"
				BindConfig.Default = BindConfig.Default or Enum.KeyCode.Unknown
				BindConfig.Hold = BindConfig.Hold or false
				BindConfig.Callback = BindConfig.Callback or function() end
				BindConfig.Flag = BindConfig.Flag or nil
				BindConfig.Save = BindConfig.Save or false

				local Bind = {Value, Binding = false, Type = "Bind", Save = BindConfig.Save}
				local Holding = false

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5)
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
						Size = UDim2.new(1, 0, 1, 0),
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						Name = "Value"
					}), "Text")
				}), "Main")

				local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
						Size = UDim2.new(1, 0, 0, 38),
						Parent = ItemParent
					}), {
						AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 15), {
							Size = UDim2.new(1, -12, 1, 0),
							Position = UDim2.new(0, 12, 0, 0),
								Font = Enum.Font.GothamBold,
								Name = "Content"
						}), "Text"),
						AddThemeObject(MakeElement("Stroke"), "Stroke"),
						BindBox,
						Click
					}), "Second")

				AddConnection(BindBox.Value:GetPropertyChangedSignal("Text"), function()
					--BindBox.Size = UDim2.new(0, BindBox.Value.TextBounds.X + 16, 0, 24)
					TweenService:Create(BindBox, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, BindBox.Value.TextBounds.X + 16, 0, 24)}):Play()
				end)

				AddConnection(Click.InputEnded, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						if Bind.Binding then return end
						Bind.Binding = true
						BindBox.Value.Text = ""
					end
				end)

				AddConnection(UserInputService.InputBegan, function(Input)
					if UserInputService:GetFocusedTextBox() then return end
					if (Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value) and not Bind.Binding then
						if BindConfig.Hold then
							Holding = true
							BindConfig.Callback(Holding)
						else
							BindConfig.Callback()
						end
					elseif Bind.Binding then
						local Key
						pcall(function()
							if not CheckKey(BlacklistedKeys, Input.KeyCode) then
								Key = Input.KeyCode
							end
						end)
						pcall(function()
							if CheckKey(WhitelistedMouse, Input.UserInputType) and not Key then
								Key = Input.UserInputType
							end
						end)
						Key = Key or Bind.Value
						Bind:Set(Key)
						pcall(function() GlobalSaveCfg(game.GameId) end)
					end
				end)

				AddConnection(UserInputService.InputEnded, function(Input)
					if Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value then
						if BindConfig.Hold and Holding then
							Holding = false
							BindConfig.Callback(Holding)
						end
					end
				end)

				AddConnection(Click.MouseEnter, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseLeave, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				AddConnection(Click.MouseButton1Up, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseButton1Down, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)}):Play()
				end)

				function Bind:Set(Key)
					Bind.Binding = false
					Bind.Value = Key or Bind.Value
					Bind.Value = Bind.Value.Name or Bind.Value
					BindBox.Value.Text = Bind.Value
				end

				Bind:Set(BindConfig.Default)
				if BindConfig.Flag then				
					OrionLib.Flags[BindConfig.Flag] = Bind
				end
				return Bind
			end  
			function ElementFunction:AddTextbox(TextboxConfig)
				TextboxConfig = TextboxConfig or {}
				TextboxConfig.Name = TextboxConfig.Name or "Textbox"
				TextboxConfig.Default = TextboxConfig.Default or ""
				TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
				TextboxConfig.Callback = TextboxConfig.Callback or function() end

				-- Adaptive Input için daha güvenilir bir container
				local TextboxFrame = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), "Second")
				
				-- Başlık etiketi
				local Title = AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 15), {
					Size = UDim2.new(1, -12, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Enum.Font.GothamBold,
					Name = "Title",
					Parent = TextboxFrame
				}), "Text")
				
				-- Çerçeve
				local Stroke = AddThemeObject(MakeElement("Stroke"), "Stroke")
				Stroke.Parent = TextboxFrame
				
				-- Input alanı için container - sağda
				local TextContainer = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 150, 0, 24),
					Position = UDim2.new(1, -160, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Parent = TextboxFrame
				}), "Main")
				
				-- Basitleştirilmiş InputBox - standart API kullanımı
				local TextboxActual = Instance.new("TextBox")
				TextboxActual.Size = UDim2.new(1, -8, 1, 0)
				TextboxActual.Position = UDim2.new(0, 4, 0, 0)
				TextboxActual.BackgroundTransparency = 1
				TextboxActual.TextColor3 = Color3.fromRGB(255, 255, 255)
				TextboxActual.PlaceholderColor3 = Color3.fromRGB(210, 210, 210)
				TextboxActual.PlaceholderText = "Input"
				TextboxActual.Text = TextboxConfig.Default
				TextboxActual.Font = Enum.Font.GothamSemibold
				TextboxActual.TextXAlignment = Enum.TextXAlignment.Left
				TextboxActual.TextSize = 14
				TextboxActual.ClearTextOnFocus = false
				TextboxActual.Parent = TextContainer
				
				-- Çerçeve için kenar
				local InputStroke = AddThemeObject(MakeElement("Stroke"), "Stroke")
				InputStroke.Parent = TextContainer
				
				-- Tıklama alanı - tüm container
				local Click = Instance.new("TextButton")
				Click.Name = "ClickArea"
				Click.Size = UDim2.new(1, 0, 1, 0)
				Click.BackgroundTransparency = 1
				Click.Text = ""
				Click.ZIndex = 5
				Click.Parent = TextboxFrame
				
				-- Tıklanınca TextBox'a odaklan
				Click.MouseButton1Click:Connect(function()
					TextboxActual:CaptureFocus()
				end)
				
				-- Hover efekti için event bağlantıları
				Click.MouseEnter:Connect(function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
						BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, 
						OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)
					}):Play()
				end)

				Click.MouseLeave:Connect(function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), 
					{BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				-- FocusLost eventi
				TextboxActual.FocusLost:Connect(function(EnterPressed)
					-- Callback'e değeri gönder
					pcall(function()
						TextboxConfig.Callback(TextboxActual.Text)
					end)
					
					-- Gerekirse metni temizle
					if TextboxConfig.TextDisappear then
						TextboxActual.Text = ""
					end
				end)
				
				-- Input kutusu yazmaya başladığında boyutu dinamik olarak ayarla
				TextboxActual:GetPropertyChangedSignal("Text"):Connect(function()
					-- Container genişliğini TextBox içeriğine göre ayarla (minimum 80px)
					local textWidth = TextboxActual.TextBounds.X
					local newWidth = math.max(80, textWidth + 20) -- 20px padding
					
					-- Maksimum genişliği container'a göre sınırla
					local maxWidth = TextboxFrame.AbsoluteSize.X * 0.7
					newWidth = math.min(newWidth, maxWidth)
					
					-- Animasyonlu boyut değişikliği
					TweenService:Create(TextContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
						Size = UDim2.new(0, newWidth, 0, 24)
					}):Play()
				end)
				
				-- Başlangıç değeriyle boyut ayarı
				TextboxActual.Text = TextboxConfig.Default
			end 
			function ElementFunction:AddColorpicker(ColorpickerConfig)
				ColorpickerConfig = ColorpickerConfig or {}
				ColorpickerConfig.Name = ColorpickerConfig.Name or "Colorpicker"
				ColorpickerConfig.Default = ColorpickerConfig.Default or Color3.fromRGB(255,255,255)
				ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
				ColorpickerConfig.Flag = ColorpickerConfig.Flag or nil
				ColorpickerConfig.Save = ColorpickerConfig.Save or false

				local ColorH, ColorS, ColorV = 1, 1, 1
				local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}

				local ColorSelection = Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(select(3, Color3.toHSV(Colorpicker.Value))),
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000"
				})

				local HueSelection = Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(0.5, 0, 1 - select(1, Color3.toHSV(Colorpicker.Value))),
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000"
				})

				local Color = Create("ImageLabel", {
					Size = UDim2.new(1, -25, 1, 0),
					Visible = false,
					Image = "rbxassetid://4155801252"
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					ColorSelection
				})

				local Hue = Create("Frame", {
					Size = UDim2.new(0, 20, 1, 0),
					Position = UDim2.new(1, -20, 0, 0),
					Visible = false
				}, {
					Create("UIGradient", {Rotation = 270, Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 4)), ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234, 255, 0)), ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21, 255, 0)), ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0, 17, 255)), ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255, 0, 251)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 4))},}),
					Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					HueSelection
				})

				local ColorpickerContainer = Create("Frame", {
					Position = UDim2.new(0, 0, 0, 32),
					Size = UDim2.new(1, 0, 1, -32),
					BackgroundTransparency = 1,
					ClipsDescendants = true
				}, {
					Hue,
					Color,
					Create("UIPadding", {
						PaddingLeft = UDim.new(0, 35),
						PaddingRight = UDim.new(0, 35),
						PaddingBottom = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 17)
					})
				})

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5)
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Main")

				local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 15), {
							Size = UDim2.new(1, -12, 1, 0),
							Position = UDim2.new(0, 12, 0, 0),
							Font = Enum.Font.GothamBold,
							Name = "Content"
						}), "Text"),
						ColorpickerBox,
						Click,
						AddThemeObject(SetProps(MakeElement("Frame"), {
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.new(0, 0, 1, -1),
							Name = "Line",
							Visible = false
						}), "Stroke"), 
					}), {
						Size = UDim2.new(1, 0, 0, 38),
						ClipsDescendants = true,
						Name = "F"
					}),
					ColorpickerContainer,
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")

				AddConnection(Click.MouseButton1Click, function()
					Colorpicker.Toggled = not Colorpicker.Toggled
					TweenService:Create(ColorpickerFrame,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{Size = Colorpicker.Toggled and UDim2.new(1, 0, 0, 148) or UDim2.new(1, 0, 0, 38)}):Play()
					Color.Visible = Colorpicker.Toggled
					Hue.Visible = Colorpicker.Toggled
					ColorpickerFrame.F.Line.Visible = Colorpicker.Toggled
				end)

				local function UpdateColorPicker()
					ColorpickerBox.BackgroundColor3 = Color3.fromHSV(ColorH, ColorS, ColorV)
					Color.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
					Colorpicker:Set(ColorpickerBox.BackgroundColor3)
					ColorpickerConfig.Callback(ColorpickerBox.BackgroundColor3)
					pcall(function() SaveCfg(game.GameId) end)
				end

				ColorH = 1 - (math.clamp(HueSelection.AbsolutePosition.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)
				ColorS = (math.clamp(ColorSelection.AbsolutePosition.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
				ColorV = 1 - (math.clamp(ColorSelection.AbsolutePosition.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)

				AddConnection(Color.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if ColorInput then
							ColorInput:Disconnect()
						end
						ColorInput = AddConnection(RunService.RenderStepped, function()
							local ColorX = (math.clamp(Mouse.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
							local ColorY = (math.clamp(Mouse.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)
							ColorSelection.Position = UDim2.new(ColorX, 0, ColorY, 0)
							ColorS = ColorX
							ColorV = 1 - ColorY
							UpdateColorPicker()
						end)
					end
				end)

				AddConnection(Color.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if ColorInput then
							ColorInput:Disconnect()
						end
					end
				end)

				AddConnection(Hue.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if HueInput then
							HueInput:Disconnect()
						end;

						HueInput = AddConnection(RunService.RenderStepped, function()
							local HueY = (math.clamp(Mouse.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)

							HueSelection.Position = UDim2.new(0.5, 0, HueY, 0)
							ColorH = 1 - HueY

							UpdateColorPicker()
						end)
					end
				end)

				AddConnection(Hue.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if HueInput then
							HueInput:Disconnect()
						end
					end
				end)

				function Colorpicker:Set(Value)
					Colorpicker.Value = Value
					ColorpickerBox.BackgroundColor3 = Colorpicker.Value
					ColorpickerConfig.Callback(Colorpicker.Value)
					pcall(function() SaveCfg(game.GameId) end)
				end

				Colorpicker:Set(Colorpicker.Value)
				if ColorpickerConfig.Flag then				
					OrionLib.Flags[ColorpickerConfig.Flag] = Colorpicker
				end
				return Colorpicker
			end  
			function ElementFunction:AddMultiSelect(MultiSelectConfig)
				MultiSelectConfig = MultiSelectConfig or {}
				MultiSelectConfig.Name = MultiSelectConfig.Name or "MultiSelect"
				MultiSelectConfig.Options = MultiSelectConfig.Options or {}
				MultiSelectConfig.Default = MultiSelectConfig.Default or {}
				MultiSelectConfig.Callback = MultiSelectConfig.Callback or function() end
				MultiSelectConfig.Flag = MultiSelectConfig.Flag or nil
				MultiSelectConfig.Save = MultiSelectConfig.Save or false

				-- MultiSelect değerleri için nesne
				local MultiSelect = {
					Values = type(MultiSelectConfig.Default) == "table" and MultiSelectConfig.Default or {}, 
					Options = MultiSelectConfig.Options, 
					Buttons = {}, 
					Toggled = false, 
					Type = "MultiSelect", 
					Save = MultiSelectConfig.Save
				}
				local MaxElements = 5

				-- MultiSelect liste container
				local MultiSelectContainer = AddThemeObject(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(40, 40, 40), 4), {
					Position = UDim2.new(0, 0, 0, 38),
					Size = UDim2.new(1, 0, 1, -38),
					ClipsDescendants = true,
					Visible = false
				}), "Divider")

				-- Liste düzeni
				local MultiSelectList = MakeElement("List")
				MultiSelectList.Parent = MultiSelectContainer

				-- Container için padding
				local Padding = MakeElement("Padding", 8, 8, 8, 8) 
				Padding.Parent = MultiSelectContainer

				-- Ana MultiSelect çerçevesi
				local MultiSelectFrame = AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					ClipsDescendants = true,
					Parent = ItemParent
				}), "Second")

				-- MultiSelect içerik container
				local MultiSelectContent = SetProps(MakeElement("TFrame"), {
					Size = UDim2.new(1, 0, 0, 38),
					Name = "F",
					Parent = MultiSelectFrame
				})

				-- MultiSelect başlığı
				local MultiSelectTitle = AddThemeObject(SetProps(MakeElement("Label", MultiSelectConfig.Name, 15), {
					Size = UDim2.new(1, -12, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Enum.Font.GothamBold,
					Name = "Content",
					Parent = MultiSelectContent
				}), "Text")

				-- MultiSelect seçili değer etiketi
				local SelectedText = AddThemeObject(SetProps(MakeElement("Label", "Selected", 13), {
					Size = UDim2.new(1, -40, 1, 0),
					Font = Enum.Font.Gotham,
					Name = "Selected",
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = MultiSelectContent
				}), "TextDark")

				-- MultiSelect ikonu
				local IconButton = AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
					Size = UDim2.new(0, 20, 0, 20),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(1, -30, 0.5, 0),
					ImageColor3 = Color3.fromRGB(240, 240, 240),
					Name = "Ico",
					Parent = MultiSelectContent
				}), "TextDark")

				-- Çerçeve için alt çizgi
				local MultiSelectLine = AddThemeObject(SetProps(MakeElement("Frame"), {
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.new(0, 0, 1, -1),
					Name = "Line",
					Visible = false,
					Parent = MultiSelectContent
				}), "Stroke")

				-- Çerçeve için kenar
				local MultiSelectStroke = AddThemeObject(MakeElement("Stroke"), "Stroke")
				MultiSelectStroke.Parent = MultiSelectFrame

				-- Köşeleri yuvarla
				local Corner = Instance.new("UICorner")
				Corner.CornerRadius = UDim.new(0, 6)
				Corner.Parent = MultiSelectFrame

				-- MultiSelect containerını da MultiSelectFrame'e ekle
				MultiSelectContainer.Parent = MultiSelectFrame

				-- Tıklanabilir alan
				local Click = Instance.new("TextButton")
				Click.Name = "ClickArea"
				Click.Size = UDim2.new(1, 0, 1, 0)
				Click.BackgroundTransparency = 1
				Click.Text = ""
				Click.ZIndex = 5
				Click.Parent = MultiSelectContent

				-- Liste boyutunu ayarla
				AddConnection(MultiSelectList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					MultiSelectContainer.CanvasSize = UDim2.new(0, 0, 0, MultiSelectList.AbsoluteContentSize.Y)
				end)

				-- MultiSelect öğelerini ekle
				local function AddOptions(Options)
					for _, Option in pairs(Options) do
						-- Option butonu oluştur
                        local OptionBtn = Instance.new("TextButton")
                        OptionBtn.Size = UDim2.new(1, -16, 0, 32) -- Genişliği azaltıldı ve yükseklik arttırıldı
                        OptionBtn.Position = UDim2.new(0, 8, 0, 0) -- Kenarlarda boşluk bırakıldı
                        OptionBtn.BackgroundTransparency = 1
                        OptionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                        OptionBtn.Text = ""
                        OptionBtn.ClipsDescendants = true
                        OptionBtn.Parent = MultiSelectContainer

						-- Option butonu köşeleri
						local BtnCorner = Instance.new("UICorner")
						BtnCorner.CornerRadius = UDim.new(0, 6)
						BtnCorner.Parent = OptionBtn

						-- Yeşil nokta göstergesi
						local SelectionDot = Instance.new("Frame")
						SelectionDot.Name = "SelectionDot"
						SelectionDot.Size = UDim2.new(0, 8, 0, 8)
						SelectionDot.Position = UDim2.new(0, 8, 0.5, 0)
						SelectionDot.AnchorPoint = Vector2.new(0, 0.5)
						SelectionDot.BackgroundColor3 = Color3.fromRGB(40, 200, 80) -- Yeşil renk
						SelectionDot.BackgroundTransparency = 1
						SelectionDot.BorderSizePixel = 0
						SelectionDot.Parent = OptionBtn

						-- Nokta için yuvarlak köşe
						local DotCorner = Instance.new("UICorner")
						DotCorner.CornerRadius = UDim.new(1, 0)
						DotCorner.Parent = SelectionDot

						-- Option butonu başlığı
						local BtnTitle = Instance.new("TextLabel")
						BtnTitle.Name = "Title"
						BtnTitle.Size = UDim2.new(1, -35, 1, 0) -- Nokta için ekstra boşluk
						BtnTitle.Position = UDim2.new(0, 25, 0, 0) -- Nokta için ekstra boşluk
						BtnTitle.BackgroundTransparency = 1
						BtnTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
						BtnTitle.TextTransparency = 0.4
						BtnTitle.TextSize = 13
						BtnTitle.Font = Enum.Font.Gotham
						BtnTitle.Text = Option
						BtnTitle.TextXAlignment = Enum.TextXAlignment.Left
						BtnTitle.Parent = OptionBtn

						-- Buton tıklama olayı
						OptionBtn.MouseButton1Click:Connect(function()
							-- Seçim durumunu değiştir
							local isSelected = table.find(MultiSelect.Values, Option) ~= nil
							
							if isSelected then
								-- Seçimi kaldır
								for i, v in pairs(MultiSelect.Values) do
									if v == Option then
										table.remove(MultiSelect.Values, i)
										break
									end
								end
								-- Noktayı gizle
								TweenService:Create(SelectionDot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
									BackgroundTransparency = 1
								}):Play()
							else
								-- Seçimi ekle
								table.insert(MultiSelect.Values, Option)
								-- Noktayı göster
								TweenService:Create(SelectionDot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
									BackgroundTransparency = 0
								}):Play()
							end
							
							-- Seçili değerleri güncelle
							local displayText = table.concat(MultiSelect.Values, ", ")
							if #displayText == 0 then displayText = "..." end
							if #displayText > 20 then displayText = displayText:sub(1, 17) .. "..." end
							SelectedText.Text = displayText
							
							-- Callback'i çağır
							pcall(function()
								MultiSelectConfig.Callback(MultiSelect.Values)
							end)
							
							-- Config'i kaydet
							pcall(function() GlobalSaveCfg(game.GameId) end)
						end)

						MultiSelect.Buttons[Option] = OptionBtn
					end
				end

				-- MultiSelect'i güncelleyen fonksiyon
				function MultiSelect:Refresh(Options, Delete)
					if Delete then
						for _,v in pairs(MultiSelect.Buttons) do
							v:Destroy()
						end    
						table.clear(MultiSelect.Options)
						table.clear(MultiSelect.Buttons)
						table.clear(MultiSelect.Values)
					end
					MultiSelect.Options = Options
					AddOptions(MultiSelect.Options)
					MultiSelect:Set(MultiSelect.Values)
				end  

				-- MultiSelect değerlerini ayarlayan fonksiyon
				function MultiSelect:Set(Values)
					MultiSelect.Values = type(Values) == "table" and Values or {}
					
					-- Tüm noktaları sıfırla
					for _, btn in pairs(MultiSelect.Buttons) do
						local dot = btn:FindFirstChild("SelectionDot")
						if dot then
							dot.BackgroundTransparency = 1
						end
					end
					
					-- Seçili değerlerin noktalarını göster
					for _, value in pairs(MultiSelect.Values) do
						if MultiSelect.Buttons[value] then
							local dot = MultiSelect.Buttons[value]:FindFirstChild("SelectionDot")
							if dot then
								dot.BackgroundTransparency = 0
							end
						end
					end
					
					-- Seçili değerleri göster
					local displayText = table.concat(MultiSelect.Values, ", ")
					if #displayText == 0 then displayText = "..." end
					if #displayText > 20 then displayText = displayText:sub(1, 17) .. "..." end
					SelectedText.Text = displayText
					
					-- Callback'i çağır
					pcall(function()
						MultiSelectConfig.Callback(MultiSelect.Values)
					end)
				end

				-- Tıklama olayı
				Click.MouseButton1Click:Connect(function()
					MultiSelect.Toggled = not MultiSelect.Toggled
					MultiSelectLine.Visible = MultiSelect.Toggled
					MultiSelectContainer.Visible = MultiSelect.Toggled
					
					-- İkon rotasyonu animasyonu
					TweenService:Create(IconButton, TweenInfo.new(.15, Enum.EasingStyle.Quad), {
						Rotation = MultiSelect.Toggled and 180 or 0
					}):Play()
					
					-- MultiSelect boyut animasyonu
					if #MultiSelect.Options > MaxElements then
						TweenService:Create(MultiSelectFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {
							Size = MultiSelect.Toggled and 
							UDim2.new(1, 0, 0, 38 + (MaxElements * 28)) or 
							UDim2.new(1, 0, 0, 38)
						}):Play()
					else
						TweenService:Create(MultiSelectFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {
							Size = MultiSelect.Toggled and 
							UDim2.new(1, 0, 0, MultiSelectList.AbsoluteContentSize.Y + 38) or 
							UDim2.new(1, 0, 0, 38)
						}):Play()
					end
				end)

				-- Seçenekleri ekle
				MultiSelect:Refresh(MultiSelect.Options, false)
				MultiSelect:Set(MultiSelect.Values)
				
				-- Flag varsa ekle
				if MultiSelectConfig.Flag then				
					OrionLib.Flags[MultiSelectConfig.Flag] = MultiSelect
				end
				return MultiSelect
			end
			return ElementFunction   
		end	

		local ElementFunction = {}

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig.Name = SectionConfig.Name or "Section"

			local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1, 0, 0, 26),
				Parent = Container
			}), {
				AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 14), {
					Size = UDim2.new(1, -12, 0, 16),
					Position = UDim2.new(0, 0, 0, 3),
					Font = Enum.Font.GothamSemibold
				}), "TextDark"),
				SetChildren(SetProps(MakeElement("TFrame"), {
					AnchorPoint = Vector2.new(0, 0),
					Size = UDim2.new(1, 0, 1, -24),
					Position = UDim2.new(0, 0, 0, 23),
					Name = "Holder"
				}), {
					MakeElement("List", 0, 6)
				}),
			})

			AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
				SectionFrame.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 31)
				SectionFrame.Holder.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
			end)

			local SectionFunction = {}
			for i, v in next, GetElements(SectionFrame.Holder) do
				SectionFunction[i] = v 
			end
			return SectionFunction
		end	

		for i, v in next, GetElements(Container) do
			ElementFunction[i] = v 
		end

		if TabConfig.PremiumOnly then
			for i, v in next, ElementFunction do
				ElementFunction[i] = function() end
			end    
			Container:FindFirstChild("UIListLayout"):Destroy()
			Container:FindFirstChild("UIPadding"):Destroy()
			SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1, 0, 1, 0),
				Parent = ItemParent
			}), {
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3610239960"), {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(0, 15, 0, 15),
					ImageTransparency = 0.4
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "Unauthorised Access", 14), {
					Size = UDim2.new(1, -38, 0, 14),
					Position = UDim2.new(0, 38, 0, 18),
					TextTransparency = 0.4
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4483345875"), {
					Size = UDim2.new(0, 56, 0, 56),
					Position = UDim2.new(0, 84, 0, 110),
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "Premium Features", 14), {
					Size = UDim2.new(1, -150, 0, 14),
					Position = UDim2.new(0, 150, 0, 112),
					Font = Enum.Font.GothamBold
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "This part of the script is locked to Sirius Premium users. Purchase Premium in the Discord server (discord.gg/sirius)", 12), {
					Size = UDim2.new(1, -200, 0, 14),
					Position = UDim2.new(0, 150, 0, 138),
					TextWrapped = true,
					TextTransparency = 0.4
				}), "Text")
			})
		end
		return ElementFunction   
	end 
	

	
	return TabFunction
end   

function OrionLib:Destroy()
	Orion:Destroy()
end

-- Güvenli config kaydetme fonksiyonu
function SaveCfg(Name)
	if not OrionLib.SaveCfg or not OrionLib.Folder then return end
	
	pcall(function()
		-- Klasör kontrolü ve oluşturma
		if not EXECUTOR_CHECK.functions.isfolder(OrionLib.Folder) then
			EXECUTOR_CHECK.functions.makefolder(OrionLib.Folder)
		end
		
		-- Flag verilerini topla
		local Data = {}
		for i, v in pairs(OrionLib.Flags) do
			if v.Save then
				if v.Type == "Colorpicker" then
					Data[i] = {R = v.Value.R * 255, G = v.Value.G * 255, B = v.Value.B * 255}
				else
					Data[i] = v.Value
				end
			end
		end
		
		-- Dosyaya yaz
		local json = SafeJsonEncode(Data)
		EXECUTOR_CHECK.functions.writefile(OrionLib.Folder .. "/" .. Name .. ".txt", json)
	end)
end

function OrionLib:Init()
	if OrionLib.SaveCfg then	
		pcall(function()
			if EXECUTOR_CHECK.functions.isfile(OrionLib.Folder .. "/" .. game.GameId .. ".txt") then
				LoadCfg(EXECUTOR_CHECK.functions.readfile(OrionLib.Folder .. "/" .. game.GameId .. ".txt"))
				OrionLib:MakeNotification({
					Name = "Configuration",
					Content = "Auto-loaded configuration for the game " .. game.GameId .. ".",
					Time = 5
				})
			end
		end)		
	end	
end	

RunService.RenderStepped:Connect(function()
    pcall(function()
        if MainWindow and MainWindow.Parent then
            local pos = MainWindow.AbsolutePosition
            local size = MainWindow.AbsoluteSize
            -- Menü açık ve büyükse göster, değilse gizle
            local menuVisible = MainWindow.Visible and not Minimized and not UIHidden
            if KanistayLabel and KanistayLabel.Parent then
                KanistayLabel.Visible = menuVisible
                -- Menüyle neredeyse bitişik, biraz daha sağda
                KanistayLabel.Position = UDim2.new(0, pos.X - KanistayLabel.Size.X.Offset + 2, 0, pos.Y + size.Y/2 - KanistayLabel.Size.Y.Offset/2)
            end
            if ButtonContainer and ButtonContainer.Parent then
                ButtonContainer.Visible = menuVisible
            end
        end
    end)
end)

-- ButtonContainer'ın içine örnek bir child ekle
local ButtonChild = Instance.new("Frame")
ButtonChild.Name = "ButtonChild"
ButtonChild.Size = UDim2.new(1, 0, 1, 0)
ButtonChild.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
ButtonChild.BackgroundTransparency = 0.2
ButtonChild.Parent = ButtonContainer

-- RenderStepped'da ButtonContainer'ı MainWindow'un üst sol dışına hizala
RunService.RenderStepped:Connect(function()
	pcall(function()
		if MainWindow and MainWindow.Parent and ButtonContainer and ButtonContainer.Parent then
			local pos = MainWindow.AbsolutePosition
			local size = MainWindow.AbsoluteSize
			ButtonContainer.Visible = not MenuHiddenOrMinimized
			if not MenuHiddenOrMinimized then
				-- Üst sol dışa hizala
				ButtonContainer.Position = UDim2.new(0, pos.X - ButtonContainer.Size.X.Offset, 0, pos.Y - ButtonContainer.Size.Y.Offset - 5)
			end
			if KanistayLabel and KanistayLabel.Parent then
				KanistayLabel.Position = UDim2.new(0, pos.X - KanistayLabel.Size.X.Offset, 0, pos.Y)
			end
		end
	end)
end)


local function setupOrionVisibilitySync()
    -- CoreGui'ye erişim
    local CoreGui = game:GetService("CoreGui")
    
    -- Orion'u bul
    local orionScreenGui = CoreGui:FindFirstChild("Orion")
    if not orionScreenGui then
        warn("Orion ScreenGui bulunamadı!")
        return
    end
    
    -- Hedef frame (SnowContainer'ın parent'ı) - GetChildren()[2]
    local children = orionScreenGui:GetChildren()
    if #children < 2 then
        warn("Orion'da yeterli çocuk öğe yok!")
        return
    end
    
    local targetFrame = children[2]
    
    -- SnowContainer'ın varlığını kontrol et (isteğe bağlı)
    local snowContainer = targetFrame:FindFirstChild("SnowContainer")
    if not snowContainer then
        warn("SnowContainer bulunamadı! Path doğru mu?")
        return
    end
    
    -- Kontrol edilecek öğeler
    local kanistayLabel = orionScreenGui:FindFirstChild("KanistayLabel")
    local buttonContainer = orionScreenGui:FindFirstChild("ButtonContainer")
    
    if not kanistayLabel then
        warn("KanistayLabel bulunamadı!")
        return
    end
    
    if not buttonContainer then
        warn("ButtonContainer bulunamadı!")
        return
    end
    
    -- Visibility sync fonksiyonu
    local function syncVisibility()
        local isVisible = targetFrame.Visible
        local frameSize = targetFrame.Size.Y
        
        -- Eğer Y size 0, 40 ise visible false olsun
        if frameSize.Scale == 0 and frameSize.Offset == 40 then
            isVisible = false
        end
        
        kanistayLabel.Visible = isVisible
        buttonContainer.Visible = isVisible
    end
    
    -- İlk senkronizasyonu yap
    syncVisibility()
    
    -- Changed sinyalleri ile bağlantı kur
    local visibilityConnection = targetFrame:GetPropertyChangedSignal("Visible"):Connect(syncVisibility)
    local sizeConnection = targetFrame:GetPropertyChangedSignal("Size"):Connect(syncVisibility)
    
    -- Connection'ları geri döndür
    return {visibilityConnection, sizeConnection}
end

-- Fonksiyonu 3 saniye sonra çalıştır (asenkron)
spawn(function()
    wait(4.5) -- 3 saniye bekle
    setupOrionVisibilitySync()
end)

-- Bağlantıları kesmek için (isteğe bağlı):
-- for _, connection in pairs(visibilityConnections) do
--     connection:Disconnect()
-- end


return OrionLib
