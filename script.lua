if (not game:IsLoaded()) then
    game.Loaded:Wait();
end

local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/itsaclarny/UI/refs/heads/main/ui"))();

local PlaceId = game.PlaceId

local Players = game:GetService("Players");
local HttpService = game:GetService("HttpService");
local Workspace = game:GetService("Workspace");
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService");

local CurrentCamera = Workspace.CurrentCamera
local WorldToViewportPoint = CurrentCamera.WorldToViewportPoint

local Inset = game:GetService("GuiService"):GetGuiInset().Y

local FindFirstChild = game.FindFirstChild
local FindFirstChildWhichIsA = game.FindFirstChildWhichIsA
local IsA = game.IsA
local Vector2new = Vector2.new
local Vector3new = Vector3.new
local CFramenew = CFrame.new
local Color3new = Color3.new

local Tfind = table.find
local create = table.create
local format = string.format
local floor = math.floor
local gsub = string.gsub
local sub = string.sub
local lower = string.lower
local upper = string.upper
local random = math.random

local DefaultSettings = {
    Esp = {
        NamesEnabled = true,
        DisplayNamesEnabled = false,
        DistanceEnabled = true,
        HealthEnabled = true,
        TracersEnabled = false,
        BoxEsp = false,
        TeamColors = true,
        Thickness = 1.5,
        TracerThickness = 1.6,
        Transparency = .9,
        TracerTrancparency = .7,
        Size = 16,
        RenderDistance = 9e9,
        Color = Color3.fromRGB(19, 130, 226),
        OutlineColor = Color3new(),
        TracerTo = "Head",
        BlacklistedTeams = {}
    },
    Aimbot = {
        Enabled = false,
        ThirdPerson = false,
        FirstPerson = false,
        ClosestCharacter = false,
        ClosestCursor = true,
        Smoothness = 1,
        FovThickness = 1,
        FovTransparency = 1,
        FovSize = 150,
        FovColor = Color3new(1, 1, 1),
        Aimlock = "Head",
        BlacklistedTeams = {},
        ShowFov = false,
        Snaplines = false
    },
    WindowPosition = UDim2.new(0.5, -200, 0.5, -139),
    Version = 1.2
}

local EncodeConfig, DecodeConfig;
do
    local deepsearchset;
    deepsearchset = function(tbl, ret, value)
        if (type(tbl) == 'table') then
            local new = {}
            for i, v in next, tbl do
                new[i] = v
                if (type(v) == 'table') then
                    new[i] = deepsearchset(v, ret, value);
                end
                if (ret(i, v)) then
                    new[i] = value(i, v);
                end
            end
            return new
        end
    end

    DecodeConfig = function(Config)
        local DecodedConfig = deepsearchset(Config, function(Index, Value)
            return type(Value) == "table" and (Value.HSVColor or Value.Position);
        end, function(Index, Value)
            local Color = Value.HSVColor
            local Position = Value.Position
            if (Color) then
                return Color3.fromHSV(Color.H, Color.S, Color.V);
            end
            if (Position and Position.Y and Position.X) then
                return UDim2.new(UDim.new(Position.X.Scale, Position.X.Offset), UDim.new(Position.Y.Scale, Position.Y.Offset));
            else
                return DefaultSettings.WindowPosition;
            end
        end);
        return DecodedConfig
    end

    EncodeConfig = function(Config)
        local ToHSV = Color3new().ToHSV
        local EncodedConfig = deepsearchset(Config, function(Index, Value)
            return typeof(Value) == "Color3" or typeof(Value) == "UDim2"
        end, function(Index, Value)
            local Color = typeof(Value) == "Color3"
            local Position = typeof(Value) == "UDim2"
            if (Color) then
                local H, S, V = ToHSV(Value);
                return { HSVColor = { H = H, S = S, V = V } };
            end
            if (Position) then
                return { Position = {
                    X = { Scale = Value.X.Scale, Offset = Value.X.Offset };
                    Y = { Scale = Value.Y.Scale, Offset = Value.Y.Offset }
                } };
            end
        end)
        return EncodedConfig
    end
end

local GetConfig = function()
    local read, data = pcall(readfile, "revive.json");
    local canDecode, config = pcall(HttpService.JSONDecode, HttpService, data);
    if (read and canDecode) then
        local Decoded = DecodeConfig(config);
        if (Decoded.Version ~= DefaultSettings.Version) then
            local Encoded = HttpService:JSONEncode(EncodeConfig(DefaultSettings));
            writefile("revive.json", Encoded);
            return DefaultSettings;
        end
        return Decoded;
    else
        local Encoded = HttpService:JSONEncode(EncodeConfig(DefaultSettings));
        writefile("revive.json", Encoded);
        return DefaultSettings
    end
end

local Settings = GetConfig();

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse();
local MouseVector = Vector2new(Mouse.X, Mouse.Y);
local Characters = {}

local CustomGet = {
    [0] = function()
        return {}
    end
}

local Get;
if (CustomGet[PlaceId]) then
    Get = CustomGet[PlaceId]();
end

local GetCharacter = function(Player)
    if (Get) then
        return Get.GetCharacter(Player);
    end
    return Player.Character
end
local CharacterAdded = function(Player, Callback)
    if (Get) then
        return
    end
    Player.CharacterAdded:Connect(Callback);
end
local CharacterRemoving = function(Player, Callback)
    if (Get) then
        return
    end
    Player.CharacterRemoving:Connect(Callback);
end

local GetTeam = function(Player)
    if (Get) then
        return Get.GetTeam(Player);
    end
    return Player.Team
end

local Drawings = {}

local AimbotSettings = Settings.Aimbot
local EspSettings = Settings.Esp
local MiscSettings = Settings.Misc

local FOV = Drawing.new("Circle");
FOV.Color = AimbotSettings.FovColor
FOV.Thickness = AimbotSettings.FovThickness
FOV.Transparency = AimbotSettings.FovTransparency
FOV.Filled = false
FOV.Radius = AimbotSettings.FovSize

local Snaplines = Drawing.new("Line");
Snaplines.Color = AimbotSettings.FovColor
Snaplines.Thickness = .1
Snaplines.Transparency = 1
Snaplines.Visible = false

table.insert(Drawings, FOV);
table.insert(Drawings, Snaplines);

local HandlePlayer = function(Player)
    local Character = GetCharacter(Player);
    if (Character) then
        Characters[Player] = Character
    end
    CharacterAdded(Player, function(Char)
        Characters[Player] = Char
    end);
    CharacterRemoving(Player, function(Char)
        Characters[Player] = nil
        local PlayerDrawings = Drawings[Player]
        if (PlayerDrawings) then
            PlayerDrawings.Text.Visible = false
        end
    end);

    if (Player == LocalPlayer) then return; end

    local Text = Drawing.new("Text");
    Text.Color = EspSettings.Color
    Text.OutlineColor = EspSettings.OutlineColor
    Text.Size = EspSettings.Size
    Text.Transparency = EspSettings.Transparency
    Text.Center = true
    Text.Outline = true

    Drawings[Player] = { Text = Text }
end

for Index, Player in pairs(Players:GetPlayers()) do
    HandlePlayer(Player);
end
Players.PlayerAdded:Connect(function(Player)
    HandlePlayer(Player);
end);

Players.PlayerRemoving:Connect(function(Player)
    Characters[Player] = nil
    local PlayerDrawings = Drawings[Player]
    if PlayerDrawings then
        for Index, Drawing in pairs(PlayerDrawings) do
            if Drawing and typeof(Drawing) == "Instance" then
                Drawing.Visible = false
            end
        end
    end
    Drawings[Player] = nil
end);

local SetProperties = function(Properties)
    for Player, PlayerDrawings in pairs(Drawings) do
        if (type(Player) ~= "number" and PlayerDrawings) then
            for Property, Value in pairs(Properties.Text or {}) do
                if PlayerDrawings.Text then
                    PlayerDrawings.Text[Property] = Value
                end
            end
        end
    end
end

local GetClosestPlayerAndRender = function()
    MouseVector = Vector2new(Mouse.X, Mouse.Y + Inset);
    local Closest = create(4);
    local Vector2Distance = math.huge
    local Vector3DistanceOnScreen = math.huge
    local Vector3Distance = math.huge

    if (AimbotSettings.ShowFov) then
        FOV.Position = MouseVector
        FOV.Visible = true
        Snaplines.Visible = false
    else
        FOV.Visible = false
    end

    local LocalRoot = Characters[LocalPlayer] and FindFirstChild(Characters[LocalPlayer], "HumanoidRootPart");
    for Player, Character in pairs(Characters) do
        if (Player == LocalPlayer) then continue; end
        local PlayerDrawings = Drawings[Player]
        if not PlayerDrawings or not PlayerDrawings.Text then continue end
        
        local PlayerRoot = FindFirstChild(Character, "HumanoidRootPart");
        local PlayerTeam = GetTeam(Player);
        if (PlayerRoot) then
            local Redirect = FindFirstChild(Character, AimbotSettings.Aimlock);
            if (not Redirect) then
                PlayerDrawings.Text.Visible = false
                continue;
            end
            local RedirectPos = Redirect.Position
            local Tuple, Visible = WorldToViewportPoint(CurrentCamera, RedirectPos);
            local CharacterVec2 = Vector2new(Tuple.X, Tuple.Y);
            local Vector2Magnitude = (MouseVector - CharacterVec2).Magnitude
            local Vector3Magnitude = LocalRoot and (RedirectPos - LocalRoot.Position).Magnitude or math.huge
            local InRenderDistance = Vector3Magnitude <= EspSettings.RenderDistance

            if (not Tfind(AimbotSettings.BlacklistedTeams, PlayerTeam)) then
                local InFovRadius = Vector2Magnitude <= FOV.Radius
                if (InFovRadius) then
                    if (Visible and Vector2Magnitude <= Vector2Distance and AimbotSettings.ClosestCursor) then
                        Vector2Distance = Vector2Magnitude
                        Closest = {Character, CharacterVec2, Player, Redirect}
                        if (AimbotSettings.Snaplines and AimbotSettings.ShowFov) then
                            Snaplines.Visible = true
                            Snaplines.From = MouseVector
                            Snaplines.To = CharacterVec2
                        else
                            Snaplines.Visible = false
                        end
                    end

                    if (Visible and Vector3Magnitude <= Vector3DistanceOnScreen and AimbotSettings.ClosestCharacter) then
                        Vector3DistanceOnScreen = Vector3Magnitude
                        Closest = {Character, CharacterVec2, Player, Redirect}
                    end
                end
            end

            if (InRenderDistance and Visible and not Tfind(EspSettings.BlacklistedTeams, PlayerTeam)) then
                local CharacterHumanoid = FindFirstChildWhichIsA(Character, "Humanoid") or { Health = 0, MaxHealth = 0 };
                PlayerDrawings.Text.Text = format("%s\n%s%s",
                        EspSettings.NamesEnabled and Player.Name or "",
                        EspSettings.DistanceEnabled and format("[%s]",
                            floor(Vector3Magnitude)
                        ) or "",
                        EspSettings.HealthEnabled and format(" [%s/%s]",
                            floor(CharacterHumanoid.Health),
                            floor(CharacterHumanoid.MaxHealth)
                        )  or ""
                    );

                PlayerDrawings.Text.Position = Vector2new(Tuple.X, Tuple.Y - 40);

                if (EspSettings.TeamColors) then
                    local TeamColor;
                    if (PlayerTeam) then
                        local BrickTeamColor = PlayerTeam.TeamColor
                        TeamColor = BrickTeamColor.Color
                    else
                        TeamColor = Color3new(0.639216, 0.635294, 0.647059);
                    end
                    PlayerDrawings.Text.Color = TeamColor
                end

                PlayerDrawings.Text.Visible = true
            else
                PlayerDrawings.Text.Visible = false
            end
        else
            PlayerDrawings.Text.Visible = false
        end
    end

    return unpack(Closest);
end

local Locked, SwitchedCamera = false, false
UserInputService.InputBegan:Connect(function(Inp)
    if (AimbotSettings.Enabled and Inp.UserInputType == Enum.UserInputType.MouseButton2) then
        Locked = true
        if (AimbotSettings.FirstPerson and LocalPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson) then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            SwitchedCamera = true
        end
    end
end);
UserInputService.InputEnded:Connect(function(Inp)
    if (AimbotSettings.Enabled and Inp.UserInputType == Enum.UserInputType.MouseButton2) then
        Locked = false
        if (SwitchedCamera) then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
        end
    end
end);

local ClosestCharacter, Vector, Player, Aimlock;
RunService.RenderStepped:Connect(function()
    ClosestCharacter, Vector, Player, Aimlock = GetClosestPlayerAndRender();
    if (Locked and AimbotSettings.Enabled and ClosestCharacter) then
        if (AimbotSettings.FirstPerson) then
            if (syn) then
                CurrentCamera.CoordinateFrame = CFramenew(CurrentCamera.CoordinateFrame.p, Aimlock.Position);
            else
                mousemoverel((Vector.X - MouseVector.X) / AimbotSettings.Smoothness, (Vector.Y - MouseVector.Y) / AimbotSettings.Smoothness);
            end
        elseif (AimbotSettings.ThirdPerson) then
            mousemoveabs(Vector.X, Vector.Y);
        end
    end
end);

-- Safe UI creation
local success, MainUI = pcall(function()
    return UILibrary.new(Color3.fromRGB(255, 79, 87));
end)

if success and MainUI then
    local Window = MainUI:LoadWindow('<font color="#ff4f57">Revive</font>', UDim2.fromOffset(400, 279));
    local ESP = Window.NewPage("esp");
    local Aimbot = Window.NewPage("aimbot");
    local Misc = Window.NewPage("misc");
    local EspSettingsUI = ESP.NewSection("Esp");
    local AimbotSection = Aimbot.NewSection("Aimbot");
    local MiscSection = Misc.NewSection("Misc");

    EspSettingsUI.Toggle("Show Names", EspSettings.NamesEnabled, function(Callback)
        EspSettings.NamesEnabled = Callback
    end);
    EspSettingsUI.Toggle("Show Health", EspSettings.HealthEnabled, function(Callback)
        EspSettings.HealthEnabled = Callback
    end);
    EspSettingsUI.Toggle("Show Distance", EspSettings.DistanceEnabled, function(Callback)
        EspSettings.DistanceEnabled = Callback
    end);
    EspSettingsUI.Slider("Render Distance", { Min = 0, Max = 50000, Default = math.clamp(EspSettings.RenderDistance, 0, 50000), Step = 10 }, function(Callback)
        EspSettings.RenderDistance = Callback
    end);
    EspSettingsUI.Slider("Esp Size", { Min = 0, Max = 30, Default = EspSettings.Size, Step = 1}, function(Callback)
        EspSettings.Size = Callback
        SetProperties({ Text = { Size = Callback } });
    end);
    EspSettingsUI.ColorPicker("Esp Color", EspSettings.Color, function(Callback)
        EspSettings.TeamColors = false
        EspSettings.Color = Callback
        SetProperties({ Text = { Color = Callback } });
    end);
    EspSettingsUI.Toggle("Team Colors", EspSettings.TeamColors, function(Callback)
        EspSettings.TeamColors = Callback
        if (not Callback) then
            SetProperties({ Text = { Color = EspSettings.Color } })
        end
    end);
    EspSettingsUI.Dropdown("Teams", {"Allies", "Enemies", "All"}, function(Callback)
        table.clear(EspSettings.BlacklistedTeams);
        if (Callback == "Enemies") then
            table.insert(EspSettings.BlacklistedTeams, LocalPlayer.Team);
        end
        if (Callback == "Allies") then
            local AllTeams = Teams:GetTeams();
            table.remove(AllTeams, table.find(AllTeams, LocalPlayer.Team));
            EspSettings.BlacklistedTeams = AllTeams
        end
    end);

    AimbotSection.Toggle("Aimbot (M2)", AimbotSettings.Enabled, function(Callback)
        AimbotSettings.Enabled = Callback
        if (not AimbotSettings.FirstPerson and not AimbotSettings.ThirdPerson) then
            AimbotSettings.FirstPerson = true
        end
    end);
    AimbotSection.Slider("Aimbot Smoothness", {Min = 0, Max = 10, Default = AimbotSettings.Smoothness, Step = .1}, function(Callback)
        AimbotSettings.Smoothness = Callback
    end);
    local sortTeams = function(Callback)
        table.clear(AimbotSettings.BlacklistedTeams);
        if (Callback == "Enemies") then
            table.insert(AimbotSettings.BlacklistedTeams, LocalPlayer.Team);
        end
        if (Callback == "Allies") then
            local AllTeams = Teams:GetTeams();
            table.remove(AllTeams, table.find(AllTeams, LocalPlayer.Team));
            AimbotSettings.BlacklistedTeams = AllTeams
        end
    end
    AimbotSection.Dropdown("Team Target", {"Allies", "Enemies", "All"}, sortTeams);
    sortTeams("Enemies");
    AimbotSection.Dropdown("Aimlock Type", {"Third Person", "First Person"}, function(callback)
        if (callback == "Third Person") then
            AimbotSettings.ThirdPerson = true
            AimbotSettings.FirstPerson = false
        else
            AimbotSettings.ThirdPerson = false
            AimbotSettings.FirstPerson = true
        end
    end);

    AimbotSection.Toggle("Show Fov", AimbotSettings.ShowFov, function(Callback)
        AimbotSettings.ShowFov = Callback
        FOV.Visible = Callback
    end);
    AimbotSection.ColorPicker("Fov Color", AimbotSettings.FovColor, function(Callback)
        AimbotSettings.FovColor = Callback
        FOV.Color = Callback
        Snaplines.Color = Callback
    end);
    AimbotSection.Slider("Fov Size", {Min = 70, Max = 500, Default = AimbotSettings.FovSize, Step = 10}, function(Callback)
        AimbotSettings.FovSize = Callback
        FOV.Radius = Callback
    end);

    Window.SetPosition(Settings.WindowPosition);

    if (gethui) then
        MainUI.UI.Parent = gethui();
    else
        local protect_gui = (syn and syn.protect_gui) or getgenv().protect_gui
        if (protect_gui) then
            protect_gui(MainUI.UI);
        end
        MainUI.UI.Parent = game:GetService("CoreGui");
    end

    -- GUI Toggle with Insert key
    local GUIEnabled = true
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.Insert then
            GUIEnabled = not GUIEnabled
            MainUI.UI.Enabled = GUIEnabled
        end
    end)
end

while wait(5) do
    if Settings then
        Settings.WindowPosition = Window and Window.GetPosition and Window.GetPosition() or DefaultSettings.WindowPosition
        local Encoded = HttpService:JSONEncode(EncodeConfig(Settings));
        writefile("revive.json", Encoded);
    end
end
