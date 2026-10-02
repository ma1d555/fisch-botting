-- (Progression build) this run's session: loops and event handlers stop when it ends
local FISHTP_SESSION = getgenv().FishTPSession
-- discord.gg/ancestral
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RenderStepped = RunService.RenderStepped
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local function generateRandomString(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:',.<>/?`~"
    local str = {}
    for i = 1, length do
        local randIndex = math.random(1, #chars)
        str[i] = string.sub(chars, randIndex, randIndex)
    end
    return table.concat(str)
end

local Custom = {} do
    -- Purple Accent Palette
    Custom.ColorRGB = Color3.fromRGB(138, 43, 226)   -- Purple
    Custom.AccentColor = Color3.fromRGB(120, 60, 210) -- Dark Purple
    Custom.DarkBlue = Color3.fromRGB(28, 28, 35)     -- Secondary Background (slight purple tint)
    Custom.BackgroundDark = Color3.fromRGB(0, 0, 0)  -- System Background
    Custom.FrameDark = Color3.fromRGB(44, 44, 46)    -- Secondary Grouped Background
    
    -- Terminal macOS Colors
    Custom.MacRedButton = Color3.fromRGB(255, 69, 58)    -- System Red
    Custom.MacYellowButton = Color3.fromRGB(255, 214, 10) -- System Yellow
    Custom.MacGreenButton = Color3.fromRGB(48, 209, 88)   -- System Green

    function Custom:Create(Name, Properties, Parent)
        local _instance = Instance.new(Name)

        for i, v in pairs(Properties) do
            _instance[i] = v
        end

        if Parent then
            _instance.Parent = Parent
        end

        return _instance
    end
end


local function OpenClose()
  local ScreenGui = Custom:Create("ScreenGui", {
    Name = "OpenClose",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  }, RunService:IsStudio() and Player.PlayerGui or game:GetService("CoreGui"))
  ProtectGui(ScreenGui)

  -- Restore to standard ImageButton (User Image)
  local Close_ImageButton = Custom:Create("ImageButton", {
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BackgroundTransparency = 0,
    Position = UDim2.new(0.1021, 0, 0.0743, 0),
    Size = UDim2.new(0, 60, 0, 60), -- Circle Shape
    Image = "rbxassetid://125992172976297",
    Visible = false,
    Name = "RestoreButton"
  }, ScreenGui)

  -- Make it Circular/Eye-like
  Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, Close_ImageButton)
  Custom:Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.8 }, Close_ImageButton)



  return Close_ImageButton
end

local Open_Close = OpenClose()


local function MakeDraggable(topbarObject, object)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    topbarObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position

            local inputChangedConn, inputEndedConn

            inputChangedConn = UserInputService.InputChanged:Connect(function(moveInput)
                if dragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
                    local delta = moveInput.Position - dragStart
                    object.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end)

            inputEndedConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                    if inputChangedConn then
                        inputChangedConn:Disconnect()
                        inputChangedConn = nil
                    end
                    if inputEndedConn then
                        inputEndedConn:Disconnect()
                        inputEndedConn = nil
                    end
                end
            end)
        end
    end)
end

MakeDraggable(Open_Close, Open_Close)

function CircleClick(Button, X, Y)
    local originalBgColor = Button.BackgroundColor3
    local originalBgTransparency = Button.BackgroundTransparency
    Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Button.BackgroundTransparency = math.max(0, originalBgTransparency - 0.15)
    task.delay(0.12, function()
        pcall(function()
            if Button and Button.Parent then
                Button.BackgroundColor3 = originalBgColor
                Button.BackgroundTransparency = originalBgTransparency
            end
        end)
    end)
end

local function LockItem(ItemFrame, InteractiveElements)
    local isTab = (ItemFrame.Name == "SubTabBtn")
    local LockOverlay = ItemFrame:FindFirstChild("LockOverlay")
    if not LockOverlay then
        LockOverlay = Custom:Create("Frame", {
            Name = "LockOverlay",
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(15, 15, 20),
            BackgroundTransparency = isTab and 1 or 0.5,
            ZIndex = 40,
            Active = true
        }, ItemFrame)
        
        Custom:Create("UICorner", {
            CornerRadius = UDim.new(0, 4)
        }, LockOverlay)
        
        local LockIcon = Custom:Create("ImageLabel", {
            Name = "LockIcon",
            Image = "http://www.roblox.com/asset/?id=6031082533",
            ImageColor3 = Color3.fromRGB(220, 220, 220),
            BackgroundTransparency = 1,
            AnchorPoint = isTab and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5),
            Position = isTab and UDim2.new(1, -8, 0.5, 0) or UDim2.new(0.5, 0, 0.5, -6),
            Size = UDim2.new(0, 14, 0, 14),
            ZIndex = 41
        }, LockOverlay)

        if not isTab then
            Custom:Create("TextLabel", {
                Name = "LockText",
                Font = Enum.Font.GothamBold,
                Text = "Premium Feature Locked",
                TextColor3 = Color3.fromRGB(180, 180, 190),
                TextSize = 8,
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0.5, 10),
                Size = UDim2.new(1, 0, 0, 12),
                ZIndex = 41
            }, LockOverlay)
        end
    else
        LockOverlay.BackgroundTransparency = isTab and 1 or 0.5
        local icon = LockOverlay:FindFirstChild("LockIcon")
        if icon then
            icon.AnchorPoint = isTab and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5)
            icon.Position = isTab and UDim2.new(1, -8, 0.5, 0) or UDim2.new(0.5, 0, 0.5, -6)
        end
    end
    LockOverlay.Visible = true
    
    if isTab then
        local lbl = ItemFrame:FindFirstChild("SubLabel")
        if lbl then
            if not lbl:GetAttribute("OriginalColor") then
                lbl:SetAttribute("OriginalColor", lbl.TextColor3)
            end
            lbl.TextColor3 = Color3.fromRGB(100, 100, 110)
        end
    else
        -- Hide all descendants for section to avoid showing titles/contents (blur/frost style)
        for _, child in ipairs(ItemFrame:GetDescendants()) do
            if child:IsA("GuiObject") and not child:IsDescendantOf(LockOverlay) and child ~= LockOverlay then
                if child:GetAttribute("OriginalVisible") == nil then
                    child:SetAttribute("OriginalVisible", child.Visible)
                end
                child.Visible = false
            end
        end
    end
    
    for _, elem in ipairs(InteractiveElements) do
        if elem:IsA("TextButton") or elem:IsA("ImageButton") then
            elem.Active = false
        elseif elem:IsA("TextBox") then
            elem.Active = false
            elem.TextEditable = false
        end
    end
end

local function UnlockItem(ItemFrame, InteractiveElements)
    local LockOverlay = ItemFrame:FindFirstChild("LockOverlay")
    if LockOverlay then
        LockOverlay.Visible = false
    end
    
    local isTab = (ItemFrame.Name == "SubTabBtn")
    if isTab then
        local lbl = ItemFrame:FindFirstChild("SubLabel")
        if lbl then
            local originalColor = lbl:GetAttribute("OriginalColor")
            if originalColor then
                lbl.TextColor3 = originalColor
            else
                lbl.TextColor3 = Color3.fromRGB(160, 160, 190)
            end
        end
    else
        -- Restore visibility of descendants for section
        for _, child in ipairs(ItemFrame:GetDescendants()) do
            if child:IsA("GuiObject") and not child:IsDescendantOf(LockOverlay) and child ~= LockOverlay then
                local wasVisible = child:GetAttribute("OriginalVisible")
                if wasVisible ~= nil then
                    child.Visible = wasVisible
                else
                    child.Visible = true
                end
            end
        end
    end
    
    for _, elem in ipairs(InteractiveElements) do
        if elem:IsA("TextButton") or elem:IsA("ImageButton") then
            elem.Active = true
        elseif elem:IsA("TextBox") then
            elem.Active = true
            elem.TextEditable = true
        end
    end
end

local Speed_Library, Notification = {}, {}
Speed_Library.Unloaded = false

local GlobalNotificationGui = nil
local GlobalNotificationLayout = nil

function Speed_Library:SetNotification(Config)
    local Title = Config[1] or Config.Title or ""
    local Description = Config[2] or Config.Description or ""
    local Content = Config[3] or Config.Content or ""
    local Time = Config[5] or Config.Time or 0.5
    local Delay = Config[6] or Config.Delay or 5

    if not GlobalNotificationGui or not GlobalNotificationGui.Parent then
        GlobalNotificationGui = Custom:Create("ScreenGui", {
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Name = "NotificationGui"
        }, RunService:IsStudio() and Player.PlayerGui or game:GetService("CoreGui"))
        ProtectGui(GlobalNotificationGui)
        
        GlobalNotificationLayout = Custom:Create("Frame", {
            AnchorPoint = Vector2.new(1,1),
            BackgroundTransparency = 0.999,
            Position = UDim2.new(1,-30,1,-30),
            Size = UDim2.new(0,320,1,0),
            Name = "NotificationLayout"
        }, GlobalNotificationGui)

        local Count = 0
        GlobalNotificationLayout.ChildRemoved:Connect(function()
            Count = 0
            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            for _, v in ipairs(GlobalNotificationLayout:GetChildren()) do
                local NewPOS = UDim2.new(0,0,1,-((v.Size.Y.Offset + 12) * Count))
                TweenService:Create(v,tweenInfo,{Position=NewPOS}):Play()
                Count = Count + 1
            end
        end)
    end

    local NotificationLayout = GlobalNotificationLayout

    local _Count = 0
    for _, v in ipairs(NotificationLayout:GetChildren()) do
        _Count = -(v.Position.Y.Offset) + v.Size.Y.Offset + 12
    end

    local NotificationFrame = Custom:Create("Frame", {
        BackgroundColor3 = Custom.BackgroundDark,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,150),
        Name = "NotificationFrame",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0,1),
        Position = UDim2.new(0,0,1,-(_Count))
    }, NotificationLayout)

    local NotificationFrameReal = Custom:Create("Frame", {
        BackgroundColor3 = Custom.BackgroundDark,
        BorderSizePixel = 0,
        Position = UDim2.new(0,400,0,0),
        Size = UDim2.new(1,0,1,0),
        Name = "NotificationFrameReal"
    }, NotificationFrame)

    Custom:Create("UICorner",{CornerRadius=UDim.new(0,12)}, NotificationFrameReal)
    Custom:Create("UIGradient", {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Custom.BackgroundDark),
            ColorSequenceKeypoint.new(0.5, Custom.FrameDark),
            ColorSequenceKeypoint.new(1, Custom.AccentColor)
        },
        Rotation = 135,
    }, NotificationFrameReal)

    local DropShadowHolder = Custom:Create("Frame", {
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Size=UDim2.new(1,0,1,0),
        ZIndex=0,
        Name="DropShadowHolder",
        Parent=NotificationFrameReal
    })

    local DropShadow = Custom:Create("ImageLabel", {
        Image="rbxassetid://6015897843",
        ImageColor3=Custom.BackgroundDark,
        ImageTransparency=0.3,
        ScaleType=Enum.ScaleType.Slice,
        SliceCenter=Rect.new(49,49,450,450),
        AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Position=UDim2.new(0.5,0,0.5,0),
        Size=UDim2.new(1,47,1,47),
        ZIndex=0,
        Name="DropShadow",
        Parent=DropShadowHolder
    })

    local Top = Custom:Create("Frame", {
        BackgroundTransparency=0.999,
        Size=UDim2.new(1,0,0,36),
        Name="Top",
        Parent=NotificationFrameReal
    })

    local TextLabel = Custom:Create("TextLabel", {
        Font=Enum.Font.GothamBold,
        Text=Title,
        TextColor3=Color3.fromRGB(255,255,255),
        TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Left,
        BackgroundTransparency=0.999,
        Size=UDim2.new(1,0,1,0),
        Position=UDim2.new(0,10,0,0),
        Parent=Top
    })

    Custom:Create("UIStroke",{Color=Color3.fromRGB(255,255,255),Thickness=0.5,Parent=TextLabel})
    Custom:Create("UICorner",{Parent=Top,CornerRadius=UDim.new(0,8)})

    local TextLabel1 = Custom:Create("TextLabel", {
        Font=Enum.Font.GothamBold,
        Text=Description,
        TextColor3=Custom.ColorRGB,
        TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Left,
        BackgroundTransparency=0.999,
        Size=UDim2.new(1,0,1,0),
        Position=UDim2.new(0,TextLabel.TextBounds.X+15,0,0),
        Parent=Top
    })

    Custom:Create("UIStroke",{Color=Custom.ColorRGB,Thickness=0.6,Parent=TextLabel1})

    local Close = Custom:Create("TextButton", {
        Font=Enum.Font.SourceSans,
        Text="",
        BackgroundTransparency=0.999,
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-5,0.5,0),
        Size=UDim2.new(0,25,0,25),
        Name="Close",
        Parent=Top
    })

    local ImageLabel = Custom:Create("ImageLabel", {
        Image="rbxassetid://9886659671",
        ImageColor3=Custom.ColorRGB,
        AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundTransparency=0.999,
        BorderSizePixel=0,
        Position=UDim2.new(0.49,0,0.5,0),
        Size=UDim2.new(1,-8,1,-8),
        Parent=Close
    })

    local TextLabel2 = Custom:Create("TextLabel", {
        Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(200,200,200),
        TextSize=13,
        Text=Content,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,
        BackgroundTransparency=0.999,
        BorderSizePixel=0,
        Position=UDim2.new(0,10,0,27),
        Size=UDim2.new(1,-20,0,13),
        Parent=NotificationFrameReal,
        TextWrapped=true
    })

    TextLabel2.Size = UDim2.new(1,-20,0,13+(13*math.floor(TextLabel2.TextBounds.X/TextLabel2.AbsoluteSize.X)))

    if TextLabel2.AbsoluteSize.Y < 27 then
        NotificationFrame.Size = UDim2.new(1,0,0,65)
    else
        NotificationFrame.Size = UDim2.new(1,0,0,TextLabel2.AbsoluteSize.Y+40)
    end

    local Waitted = false
    function Notification:Close()
        if Waitted then return false end
        Waitted = true
        local tween = TweenService:Create(NotificationFrameReal,TweenInfo.new(tonumber(Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),{Position=UDim2.new(0,400,0,0)})
        tween:Play()
        task.wait(tonumber(Time)/1.2)
        NotificationFrame:Destroy()
        Waitted = false
    end

    Close.Activated:Connect(function() Notification:Close() end)

    TweenService:Create(NotificationFrameReal, TweenInfo.new(tonumber(Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {Position=UDim2.new(0,0,0,0)} ):Play()
    task.delay(tonumber(Delay), Notification.Close)

    return Notification
end


function Speed_Library:CreateWindow(Config)
    local Title = Config[1] or Config.Title or ""
    local Description = Config[2] or Config.Description or ""
    local TabWidth = Config[3] or Config["Tab Width"] or 120
    local SizeUi = Config[4] or Config.SizeUi or UDim2.fromOffset(750, 350)
    local LoadMode = Config[5] or Config.LoadMode or "slow" -- "slow" = chunked task.wait() untuk mencegah framedrop, "fast" = langsung semua seketika

    local Funcs = {}
    local Templates = {}
    
    -- Setup Toggle Template
    do
      local Toggle = Custom:Create("Frame", {
          Name = "Toggle",
          BackgroundColor3 = Color3.fromRGB(12, 12, 16),
          BackgroundTransparency = 0,
          BorderSizePixel = 0,
          Size = UDim2.new(1, 0, 0, 32),
          AutomaticSize = Enum.AutomaticSize.Y
      })
      Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Toggle)
      Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Toggle)

      -- Title (bold white)
      Custom:Create("TextLabel", {
          Name = "ToggleTitle",
          Font = Enum.Font.GothamBold,
          Text = "Title",
          TextSize = 12,
          TextColor3 = Color3.fromRGB(235, 235, 240),
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Center,
          BackgroundTransparency = 1,
          Position = UDim2.new(0, 10, 0.5, -7),
          Size = UDim2.new(1, -58, 0, 14)
      }, Toggle)

      -- Description (gray, below title)
      Custom:Create("TextLabel", {
          Name = "ToggleContent",
          Font = Enum.Font.Gotham,
          Text = "",
          TextSize = 11,
          TextColor3 = Color3.fromRGB(145, 140, 155),
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Top,
          BackgroundTransparency = 1,
          Position = UDim2.new(0, 10, 0, 22),
          Size = UDim2.new(1, -58, 0, 0),
          AutomaticSize = Enum.AutomaticSize.Y,
          TextWrapped = true
      }, Toggle)

      -- Invisible click button
      Custom:Create("TextButton", {
          Name = "ToggleButton",
          Text = "",
          BackgroundTransparency = 1,
          Size = UDim2.new(1, 0, 1, 0)
      }, Toggle)

      -- Pill-shaped toggle switch (28x14), anchored right-center
      local FeatureFrame = Custom:Create("Frame", {
          Name = "FeatureFrame",
          AnchorPoint = Vector2.new(1, 0.5),
          BackgroundColor3 = Color3.fromRGB(30, 30, 35),
          BackgroundTransparency = 0,
          BorderSizePixel = 0,
          Position = UDim2.new(1, -10, 0.5, 0),
          Size = UDim2.new(0, 28, 0, 14)
      }, Toggle)
      Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, FeatureFrame)

      Custom:Create("UIStroke", {
          Name = "UIStroke",
          Color = Color3.fromRGB(60, 60, 70),
          Thickness = 1,
          Transparency = 0.7
      }, FeatureFrame)

      -- Circle inside pill
      local ToggleCircle = Custom:Create("Frame", {
          Name = "ToggleCircle",
          AnchorPoint = Vector2.new(0, 0.5),
          BackgroundColor3 = Color3.fromRGB(150, 150, 150),
          BorderSizePixel = 0,
          Size = UDim2.new(0, 10, 0, 10),
          Position = UDim2.new(0, 2, 0.5, 0)
      }, FeatureFrame)
      Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, ToggleCircle)

      Templates.Toggle = Toggle
    end
    
    -- Setup Button Template
    do
      local Button = Custom:Create("Frame", {
					Name = "Button",
					BackgroundColor3 = Color3.fromRGB(12, 12, 16),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 32),
                    AutomaticSize = Enum.AutomaticSize.Y
				})
        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Button)
        Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Button)

        Custom:Create("TextLabel", {
					Name = "ButtonTitle",
					Font = Enum.Font.GothamBold,
					Text = "Title",
					TextColor3 = Color3.fromRGB(235, 235, 240),
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.999,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 10, 0, 8),
					Size = UDim2.new(1, -100, 0, 13)
				}, Button)

      Custom:Create("TextLabel", {
					Name = "ButtonContent",
					Font = Enum.Font.Gotham,
					Text = "Content",
					TextColor3 = Color3.fromRGB(145, 140, 155),
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.999,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 10, 0, 22),
					Size = UDim2.new(1, -100, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextWrapped = true
				}, Button)
        
        Custom:Create("TextButton", {
					Name = "ButtonButton",
					Font = Enum.Font.SourceSans,
					Text = "",
					TextColor3 = Color3.fromRGB(0, 0, 0),
					TextSize = 14,
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 0.999,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0)
				}, Button)

        local FeatureFrame1 = Custom:Create("Frame", {
					Name = "FeatureFrame",
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 0.999,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0, 16, 0, 16)
				}, Button)

        local FeatureImg = Custom:Create("ImageLabel", {
          Name = "FeatureImg",
          Image = "",
          AnchorPoint = Vector2.new(0.5, 0.5),
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 0.999,
          BorderSizePixel = 0,
          Position = UDim2.new(0.5, 0, 0.5, 0),
          Size = UDim2.new(1, 0, 1, 0),
          ImageColor3 = Custom.ColorRGB
        }, FeatureFrame1)
        
        Templates.Button = Button
    end

    
  local SpeedHubXGui = Custom:Create("ScreenGui", {
      Name = "ShieldTeam || Luowis",
      ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
      Enabled = false
    }, RunService:IsStudio() and Player.PlayerGui or game:GetService("CoreGui"))
    task.defer(function() SpeedHubXGui.Enabled = true end)
    ProtectGui(SpeedHubXGui)

    local DropShadowHolder = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 455, 0, 350),
        ZIndex = 0,
        Name = "DropShadowHolder",
        Position = UDim2.new(0, (math.floor(SpeedHubXGui.AbsoluteSize.X / 2) - math.floor(455 / 2)), 0, (math.floor(SpeedHubXGui.AbsoluteSize.Y / 2) - math.floor(350 / 2)))
    }, SpeedHubXGui)

    local DropShadow = Custom:Create("ImageLabel", {
        Image = "rbxassetid://6015897843",
        ImageColor3 = Custom.BackgroundDark,
        ImageTransparency = 0.3,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = SizeUi,
        ZIndex = 0,
        Name = "DropShadow"
    }, DropShadowHolder)

    -- ---- UIScale: cara paling efisien scale SEMUA descendant ----
    local GlobalUIScale = Custom:Create("UIScale", {
        Scale = 1,
        Name = "GlobalUIScale"
    }, DropShadowHolder)

    local function GetUnscaledSize(sizePixels)
        local scale = GlobalUIScale.Scale
        if scale == 0 then scale = 1 end
        return sizePixels / scale
    end

    local Main = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(15, 15, 15),
        BackgroundTransparency = 0, -- Solid Opaque
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = SizeUi,
        Name = "MainFrame",
        ZIndex = 10 -- Bring to front
    }, DropShadow)

    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 24) }, Main)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.2, Transparency = 0.8 }, Main)

    -- HUGE Cat Ears
    local EarLeft = Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(15, 15, 15),
        BackgroundTransparency = 0, -- Solid Opaque
        Position = UDim2.new(0, 10, 0, -35), 
        Size = UDim2.new(0, 85, 0, 85),
        Rotation = 30,
        Name = "EarLeft",
        ZIndex = 9 -- Behind Main
    }, DropShadow)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 15) }, EarLeft)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.2, Transparency = 0.8 }, EarLeft)
    
    local InnerEarLeft = Custom:Create("Frame", {
         BackgroundColor3 = Color3.fromRGB(40, 40, 40),
         Position = UDim2.new(0.3, 0, 0.3, 0),
         Size = UDim2.new(0.4, 0, 0.4, 0),
         ZIndex = 10
    }, EarLeft)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, InnerEarLeft)

    local EarRight = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Color3.fromRGB(15, 15, 15),
        BackgroundTransparency = 0, -- Solid Opaque
        Position = UDim2.new(1, -10, 0, -35),
        Size = UDim2.new(0, 85, 0, 85),
        Rotation = -30,
        Name = "EarRight",
        ZIndex = 9
    }, DropShadow)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 15) }, EarRight)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.2, Transparency = 0.8 }, EarRight)

    local InnerEarRight = Custom:Create("Frame", {
         BackgroundColor3 = Color3.fromRGB(40, 40, 40),
         Position = UDim2.new(0.3, 0, 0.3, 0),
         Size = UDim2.new(0.4, 0, 0.4, 0),
         ZIndex = 10
    }, EarRight)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, InnerEarRight)

    -- TAIL (Buntut) - Curved shape using a frame
    local TailContainer = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -30, 0.8, 0),
        Size = UDim2.new(0, 60, 0, 60),
        ZIndex = 8,
        Name = "Tail"
    }, DropShadow)

    local TailPart1 = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(0.5,1),
        BackgroundColor3 = Color3.fromRGB(15, 15, 15),
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(0, 20, 0, 140), -- Panjangin lagi (80 -> 140)
        Rotation = 45,
        ZIndex = 8
    }, TailContainer)
    Custom:Create("UICorner", { CornerRadius = UDim.new(1,0) }, TailPart1)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.2, Transparency = 0.8 }, TailPart1)
    
    -- Using TweenService to animate tail wagging slightly
    task.spawn(function()
        local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(TailPart1, tweenInfo, {Rotation = 65}):Play()
    end)


    -- WHISKERS (Kumis)
    local _whiskers = {}  -- simpan referensi untuk di-scale saat resize
    local function CreateWhisker(parent, pos, rot)
       local w = Custom:Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(200, 200, 200),
            BackgroundTransparency = 0.5,
            Size = UDim2.new(0, 60, 0, 2),
            Position = pos,
            Rotation = rot,
            ZIndex = 8
       }, parent)
       Custom:Create("UICorner", { CornerRadius = UDim.new(1,0) }, w)
       table.insert(_whiskers, {frame = w, basePos = pos})
    end
    
    CreateWhisker(DropShadow, UDim2.new(0, -45, 0.3, 0), 10)
    CreateWhisker(DropShadow, UDim2.new(0, -45, 0.4, 0), -5)
    
    CreateWhisker(DropShadow, UDim2.new(1, -15, 0.3, 0), -10)
    CreateWhisker(DropShadow, UDim2.new(1, -15, 0.4, 0), 5)

    local Top = Custom:Create("Frame", {
        BackgroundColor3 = Custom.FrameDark,
        BackgroundTransparency = 1, -- Fully Transparent Header
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
        Name = "Top"
    }, Main)
    
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 20) }, Top)

    -- Icon placed in center top, protruding upwards
    Custom:Create("ImageLabel", {
        Image = "rbxassetid://123091588302961",
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, -20), -- Raised slightly to sit better
        Size = UDim2.new(0, 100, 0, 100),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Name = "IconSHIELD",
        ZIndex = 9,
        Parent = DropShadow -- Layered behind Main so it doesn't overlap text
    }, DropShadow)
    
    -- Fix bottom corners of Top frame to be square? 
    -- Actually with ClipsDescendants on Main, we don't need to worry, but Main ClipsDescendants is NOT set in this visible code.
    -- I will add a "Filler" frame to square off the bottom of Top if needed, or just let it be rounded (iPad style).
    
    -- Removed UIGradient for Top

    -- Modern Minimalist Buttons Container
    local ButtonsContainer = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        Size = UDim2.new(0, 60, 1, 0),
        Name = "ButtonsContainer"
    }, Top)

    -- Minimize Button (-)
    local MinimizeButton = Custom:Create("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        BackgroundTransparency = 0, -- Solid Opaque
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 25, 0, 25),
        Text = "—",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Name = "MinimizeButton"
    }, ButtonsContainer)

    Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 6)
    }, MinimizeButton)

    -- Close Button (×)
    local CloseButton = Custom:Create("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        BackgroundTransparency = 0, -- Solid Opaque
        Position = UDim2.new(0, 35, 0.5, 0),
        Size = UDim2.new(0, 25, 0, 25),
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Name = "CloseButton"
    }, ButtonsContainer)

    Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 6)
    }, CloseButton)

    local TextLabel = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBold,
        Text = Title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextScaled = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -6),
        Size = UDim2.new(1, -90, 0, 18)
    }, Top)

    Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 16)
    }, Top)

    Custom:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 0.8,
        Transparency = 0.7
    }, TextLabel)

    local TextLabel1 = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBold,
        Text = Description,
        TextColor3 = Custom.ColorRGB,
        TextSize = 11,
        TextScaled = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 9),
        Size = UDim2.new(0.5, 0, 0, 12)
    }, Top)

    Custom:Create("UIStroke", {
        Color = Custom.ColorRGB,
        Thickness = 0.6
    }, TextLabel1)

    -- Update SmoothHover to prevent transparency
    local function AddSmoothHover(button, hoverColor, normalColor)
        local isCooldown = false
        
        button.MouseEnter:Connect(function()
            if not isCooldown then
                TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = hoverColor,
                    BackgroundTransparency = 0 -- Opaque
                }):Play()
            end
        end)

        button.MouseLeave:Connect(function()
            if not isCooldown then
                TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = normalColor,
                    BackgroundTransparency = 0 -- Opaque
                }):Play()
            end
        end)
    end

    AddSmoothHover(MinimizeButton, Color3.fromRGB(80, 80, 80), Color3.fromRGB(50, 50, 50))
    AddSmoothHover(CloseButton, Color3.fromRGB(255, 80, 80), Color3.fromRGB(50, 50, 50))

    -- Minimize functionality - lebih smooth
    MinimizeButton.Activated:Connect(function()
        -- Quick flash animation
        TweenService:Create(MinimizeButton, TweenInfo.new(0.1), {
            BackgroundTransparency = 0
        }):Play()
        
        task.wait(0.1)
        
        TweenService:Create(MinimizeButton, TweenInfo.new(0.15), {
            BackgroundTransparency = 0
        }):Play()
        
        -- Fade out animation
        TweenService:Create(DropShadowHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(DropShadowHolder.Size.X.Scale, DropShadowHolder.Size.X.Offset, 0, 0)
        }):Play()
        
        task.wait(0.2)
        DropShadowHolder.Visible = false
        -- Adjust size for restored state using TextBounds
        DropShadowHolder.Size = UDim2.new(0, 115 + TextLabel.TextBounds.X + 1 + TextLabel1.TextBounds.X, 0, SizeUi.Y.Offset)
        
        if not Open_Close.Visible then 
            Open_Close.Visible = true 
        end
    end)

    -- Restore window dengan smooth animation
    Open_Close.Activated:Connect(function()
        DropShadowHolder.Visible = true
        DropShadowHolder.Size = UDim2.new(0, 0, 0, 0)
        
        TweenService:Create(DropShadowHolder, TweenInfo.new(0), {
            Size = UDim2.new(0, 115 + TextLabel.TextBounds.X + 1 + TextLabel1.TextBounds.X, 0, SizeUi.Y.Offset)
        }):Play()
        
        if Open_Close.Visible then 
            Open_Close.Visible = false 
        end
    end)

    -- Close functionality - lebih smooth
    CloseButton.Activated:Connect(function()
        -- Flash red
        TweenService:Create(CloseButton, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(255, 100, 100),
            BackgroundTransparency = 0
        }):Play()
        
        task.wait(0.1)
        
        -- Fade out animation
        TweenService:Create(DropShadowHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        
        TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        }):Play()
        
        task.wait(0.2)
        
        if SpeedHubXGui then 
            SpeedHubXGui:Destroy() 
        end
        if GlobalNotificationGui then
            GlobalNotificationGui:Destroy()
            GlobalNotificationGui = nil
            GlobalNotificationLayout = nil
        end
        if not Speed_Library.Unloaded then 
            Speed_Library.Unloaded = true 
        end
        -- Reset guard agar script bisa dijalankan ulang setelah GUI ditutup
        _G.ShieldScriptActive = nil
    end)

    -- ============================================================
    -- SIDEBAR (LayersTab)
    -- ============================================================
    local LayersTab = Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(18, 18, 22),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 9, 0, 50),
        Size = UDim2.new(0, TabWidth, 1, -59),
        Name = "LayersTab"
    }, Main)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 10) }, LayersTab)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, LayersTab)

    -- Logo area at top of sidebar (compact)
    local LogoArea = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        Name = "LogoArea"
    }, LayersTab)

    Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBlack,
        Text = "ShielD",
        TextColor3 = Custom.ColorRGB,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        Name = "LogoText"
    }, LogoArea)

    -- Divider under logo
    Custom:Create("Frame", {
        BackgroundColor3 = Custom.ColorRGB,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.new(0.05, 0, 1, -1),
        Size = UDim2.new(0.9, 0, 0, 1),
        Name = "LogoDivider"
    }, LogoArea)

    local ScrollTab = Custom:Create("ScrollingFrame", {
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarImageColor3 = Custom.ColorRGB,
        ScrollBarThickness = 2,
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(1, 0, 1, -42),
        Name = "ScrollTab",
        ScrollBarImageTransparency = 0.5
    }, LayersTab)

    local SidebarLayout = Custom:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, ScrollTab)

    local SidebarPadding = Custom:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
        PaddingTop = UDim.new(0, 4)
    }, ScrollTab)

    local function UpdateSidebarSize()
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, GetUnscaledSize(SidebarLayout.AbsoluteContentSize.Y) + 10)
    end
    SidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSidebarSize)

    -- Accent divider below Top bar
    Custom:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Custom.ColorRGB,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0, 38),
        Size = UDim2.new(1, 0, 0, 2),
        Name = "DecideFrame"
    }, Main)

    -- ============================================================
    -- CONTENT AREA: Header + two column panels
    -- ============================================================
    local ContentArea = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, TabWidth + 18, 0, 50),
        Size = UDim2.new(1, -(TabWidth + 9 + 18), 1, -59),
        Name = "ContentArea"
    }, Main)

    -- Content header (sub-tab name + description)
    local ContentHeader = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 38),
        Name = "ContentHeader"
    }, ContentArea)

    local NameTab = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBlack,
        Text = "",
        TextColor3 = Custom.ColorRGB,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 0, 2),
        Size = UDim2.new(0.5, 0, 0, 20),
        Name = "NameTab"
    }, ContentHeader)

    local NameTabSub = Custom:Create("TextLabel", {
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = Color3.fromRGB(160, 160, 180),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 7, 0, 22),
        Size = UDim2.new(0.5, 0, 0, 14),
        Name = "NameTabSub"
    }, ContentHeader)

    -- Divider below header
    Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(50, 50, 65),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        Name = "HeaderDivider"
    }, ContentHeader)

    -- Two column panels area
    local PanelsArea = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 40),
        Size = UDim2.new(1, 0, 1, -40),
        Name = "PanelsArea"
    }, ContentArea)

    -- LEFT PANEL
    local Layers = Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(20, 20, 26),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.5, -3, 1, 0),
        Name = "Layers"
    }, PanelsArea)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, Layers)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(50, 50, 70), Thickness = 1, Transparency = 0.3 }, Layers)

    -- RIGHT PANEL
    local LayersRight = Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(20, 20, 26),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 3, 0, 0),
        Size = UDim2.new(0.5, -3, 1, 0),
        Name = "LayersRight"
    }, PanelsArea)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, LayersRight)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(50, 50, 70), Thickness = 1, Transparency = 0.3 }, LayersRight)

    -- Container frames for scrollframes (Visible-switching)
    local LayersReal = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 1, 0),
        Name = "LayersReal"
    }, Layers)

    local LayersRealRight = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 1, 0),
        Name = "LayersRealRight"
    }, LayersRight)

    local LayersFolder = Custom:Create("Folder", {
        Name = "LayersFolder"
    }, LayersReal)

    local LayersFolderRight = Custom:Create("Folder", {
        Name = "LayersFolderRight"
    }, LayersRealRight)

    -- Helper: switch active sub-tab scrollframes
    local _activeSubScrollLeft = nil
    local _activeSubScrollRight = nil

    local function switchSubTab(scrollLeft, scrollRight)
        -- Hide previous
        if _activeSubScrollLeft and _activeSubScrollLeft ~= scrollLeft then
            _activeSubScrollLeft.Visible = false
        end
        if _activeSubScrollRight and _activeSubScrollRight ~= scrollRight then
            _activeSubScrollRight.Visible = false
        end
        -- Show new
        _activeSubScrollLeft = scrollLeft
        _activeSubScrollRight = scrollRight
        if scrollLeft then scrollLeft.Visible = true end
        if scrollRight then scrollRight.Visible = true end
    end

    -- Compat stubs (keep names available for MoreBlur section below)
    local LayersPageLayout = {JumpToIndex = function() end}
    local LayersPageLayoutRight = {JumpToIndex = function() end}
    local NameTabRight = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBlack, Text = "",
        TextColor3 = Color3.fromRGB(160, 160, 180), TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 0, 22), Size = UDim2.new(0.5, 0, 0, 14),
        Name = "NameTabRight"
    }, ContentHeader)


    DropShadowHolder.Size = UDim2.new(0, 115 + TextLabel.TextBounds.X + 1 + TextLabel1.TextBounds.X, 0, SizeUi.Y.Offset)
    MakeDraggable(Top, DropShadowHolder)

    -- ============================================================
    -- RESIZE HANDLE (pojok kanan bawah) + TEXT SCALE + JSON SAVE
    -- ============================================================
    local MIN_W, MIN_H = 400, 260
    local MAX_W, MAX_H = 1100, 700

    -- Base size (default ukuran pertama kali GUI dibuat)
    local BASE_W = SizeUi.X.Offset
    local BASE_H = SizeUi.Y.Offset

    -- ---- JSON Save/Load ----
    local SAVE_FILE = "ShieldGUI_size.json"

    local function saveSize(w, h)
        pcall(function()
            local json = game:GetService("HttpService"):JSONEncode({width = w, height = h})
            writefile(SAVE_FILE, json)
        end)
    end

    local function loadSavedSize()
        local ok, result = pcall(function()
            if isfile(SAVE_FILE) then
                local raw = readfile(SAVE_FILE)
                return game:GetService("HttpService"):JSONDecode(raw)
            end
        end)
        if ok and result and result.width and result.height then
            return result.width, result.height
        end
        return nil, nil
    end

    -- (GlobalUIScale dipindah ke atas)

    -- ---- Detect platform (Mobile vs PC) ----
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    -- Handle size: lebih besar di mobile agar mudah dijangkau jari
    local HANDLE_SIZE = isMobile and 32 or 18

    -- ---- Resize handle visual ----
    local ResizeHandle = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Custom.ColorRGB,
        BackgroundTransparency = isMobile and 0.3 or 0.5,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(0, HANDLE_SIZE, 0, HANDLE_SIZE),
        ZIndex = 50,
        Name = "ResizeHandle",
        ClipsDescendants = true,
    }, Main)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, isMobile and 10 or 4) }, ResizeHandle)

    -- Icon resize (3 garis diagonal)
    local ResizeIcon = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 51,
        Name = "ResizeIconHolder",
    }, ResizeHandle)
    for i = 1, 3 do
        Custom:Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -(i * 5 - 3), 1, -(i * 5 - 3)),
            Size = UDim2.new(0, (4 - i) * 4 + 4, 0, 2),
            Rotation = -45,
            ZIndex = 52,
        }, ResizeIcon)
    end

    -- Transparent button overlay untuk input
    local ResizeBtn = Custom:Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 53,
        Name = "ResizeBtn",
    }, ResizeHandle)

    -- Hover effect (PC only - mobile tidak punya MouseEnter)
    if not isMobile then
        ResizeBtn.MouseEnter:Connect(function()
            TweenService:Create(ResizeHandle, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.1,
                BackgroundColor3 = Color3.fromRGB(170, 80, 255)
            }):Play()
        end)
        ResizeBtn.MouseLeave:Connect(function()
            TweenService:Create(ResizeHandle, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.5,
                BackgroundColor3 = Custom.ColorRGB
            }):Play()
        end)
    end

    -- ---- Resize logic ----
    local resizing = false
    local resizeStart = nil
    local resizeStartSize = nil
    local _activeResizeInput = nil  -- track specific touch input agar tidak kena jari lain

    local function applyResize(newW, newH)
        -- UIScale: scale SEMUA konten di dalam DropShadowHolder (Main, Shadow, Telinga, Ekor)
        local scaleRatio = math.clamp(newW / BASE_W, MIN_W / BASE_W, MAX_W / BASE_W)
        GlobalUIScale.Scale = scaleRatio
    end

    local resizeMoveConn = nil
    local resizeEndConn = nil

    local function onResizeEnd()
        if resizing then
            resizing = false
            _activeResizeInput = nil
            if resizeMoveConn then
                resizeMoveConn:Disconnect()
                resizeMoveConn = nil
            end
            if resizeEndConn then
                resizeEndConn:Disconnect()
                resizeEndConn = nil
            end
            -- Restore handle appearance
            TweenService:Create(ResizeHandle, TweenInfo.new(0.15), {
                BackgroundTransparency = isMobile and 0.3 or 0.5,
                BackgroundColor3 = Custom.ColorRGB
            }):Play()
            -- Simpan ukuran terakhir ke JSON
            local finalW = math.clamp(math.round(Main.AbsoluteSize.X), MIN_W, MAX_W)
            local finalH = math.clamp(math.round(Main.AbsoluteSize.Y), MIN_H, MAX_H)
            saveSize(finalW, finalH)
        end
    end

    ResizeBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            _activeResizeInput = input
            resizeStart = input.Position
            resizeStartSize = {W = Main.AbsoluteSize.X, H = Main.AbsoluteSize.Y}

            -- Visual feedback saat mulai resize
            TweenService:Create(ResizeHandle, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.05,
                BackgroundColor3 = Color3.fromRGB(170, 80, 255)
            }):Play()

            -- MOBILE: Track langsung dari objek input ini (bukan InputChanged global)
            local changedConnection
            changedConnection = input.Changed:Connect(function()
                if resizing and _activeResizeInput == input then
                    if input.UserInputState == Enum.UserInputState.Change then
                        local delta = input.Position - resizeStart
                        applyResize(resizeStartSize.W + delta.X, resizeStartSize.H + delta.Y)
                    elseif input.UserInputState == Enum.UserInputState.End then
                        onResizeEnd()
                        if changedConnection then
                            changedConnection:Disconnect()
                            changedConnection = nil
                        end
                    end
                else
                    if changedConnection then
                        changedConnection:Disconnect()
                        changedConnection = nil
                    end
                end
            end)

            if not isMobile then
                if resizeMoveConn then
                    resizeMoveConn:Disconnect()
                    resizeMoveConn = nil
                end
                resizeMoveConn = UserInputService.InputChanged:Connect(function(moveInput)
                    if resizing and moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                        local delta = moveInput.Position - resizeStart
                        applyResize(resizeStartSize.W + delta.X, resizeStartSize.H + delta.Y)
                    end
                end)

                if resizeEndConn then
                    resizeEndConn:Disconnect()
                    resizeEndConn = nil
                end
                resizeEndConn = UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
                        onResizeEnd()
                    end
                end)
            end
        end
    end)

    -- ---- Restore ukuran dari JSON saat startup ----
    task.defer(function()
        local savedW, savedH = loadSavedSize()
        if savedW and savedH then
            applyResize(savedW, savedH)
        end
    end)

    local MoreBlur = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Custom.BackgroundDark,
        BackgroundTransparency = 1,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(1, 8, 1, 8),
        Size = UDim2.new(1, 8, 1, 16),
        Visible = false,
        Name = "MoreBlur"
    }, ContentArea)

    Custom:Create("UIGradient", {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Custom.BackgroundDark),
            ColorSequenceKeypoint.new(0.5, Custom.FrameDark),
            ColorSequenceKeypoint.new(1, Custom.AccentColor)
        },
        Rotation = 90,
    }, MoreBlur)

    local DropShadowHolder1 = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 0,
        Name = "DropShadowHolder"
    }, MoreBlur)

    local DropShadow1 = Custom:Create("ImageLabel", {
        Image = "rbxassetid://6015897843",
        ImageColor3 = Custom.BackgroundDark,
        ImageTransparency = 0.2,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, 35, 1, 35),
        ZIndex = 0,
        Name = "DropShadow"
    }, DropShadowHolder1)

    Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 12)
    }, MoreBlur)

    local ConnectButton = Custom:Create("TextButton", {
        Font = Enum.Font.SourceSans,
        Text = "",
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = 14,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.999,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Name = "ConnectButton",
    }, MoreBlur)    local DropdownSelect = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Position = UDim2.new(1, 172, 0.5, 0),
        Size = UDim2.new(0, 160, 1, -16),
        Name = "DropdownSelect",
        ClipsDescendants = true,
    }, MoreBlur)

    local function hideDropdownDrawer()
        if MoreBlur.Visible then
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local _Hide = TweenService:Create(MoreBlur, tweenInfo, {BackgroundTransparency = 0.999})
            local _Move = TweenService:Create(DropdownSelect, tweenInfo, {Position = UDim2.new(1, 172, 0.5, 0)})
            _Hide:Play()
            _Move:Play()
            task.delay(0.2, function()
                MoreBlur.Visible = false
            end)
        end
    end

    ConnectButton.Activated:Connect(hideDropdownDrawer)

    Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 6),
    }, DropdownSelect)

    Custom:Create("UIStroke", {
        Color = Color3.fromRGB(45, 45, 55),
        Thickness = 1,
        Transparency = 0.4,
    }, DropdownSelect)

    local DropdownSelectReal = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.999,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -10, 1, -10),
        Name = "DropdownSelectReal",
    }, DropdownSelect)

    local DropdownFolder = Custom:Create("Folder", {
        Name = "DropdownFolder",
    }, DropdownSelectReal)

    local DropPageLayout = Custom:Create("UIPageLayout", {
        EasingDirection = Enum.EasingDirection.InOut,
        EasingStyle = Enum.EasingStyle.Quad,
        TweenTime = 0.01,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Archivable = false,
        Name = "DropPageLayout",
    }, DropdownFolder)

    -- ============================================================
    -- TAB SYSTEM: CreateGroup + Group:CreateTab
    -- ============================================================
    local Tabs = {}
    local CountTab = 0
    local CountDropdown = 0
    local _activeSubTabBtn = nil  -- currently selected sub-tab button
    local isFirstSubTabOverall = true

    -- Helper: deselect all sub-tab buttons
    local function deselectAllSubTabs()
        for _, child in ipairs(ScrollTab:GetChildren()) do
            if child.Name == "GroupItems" then
                for _, subBtn in ipairs(child:GetChildren()) do
                    if subBtn.Name == "SubTabBtn" then
                        subBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                        subBtn.BackgroundTransparency = 1
                        local lbl = subBtn:FindFirstChild("SubLabel")
                        if lbl then lbl.TextColor3 = Color3.fromRGB(160, 160, 190) end
                        local dot = subBtn:FindFirstChild("ActiveDot")
                        if dot then dot.Visible = false end
                    end
                end
            end
        end
    end

    -- Helper: select a sub-tab button
    local function selectSubTabBtn(btn)
        deselectAllSubTabs()
        btn.BackgroundColor3 = Color3.fromRGB(120, 60, 210)
        btn.BackgroundTransparency = 0.75
        local lbl = btn:FindFirstChild("SubLabel")
        if lbl then lbl.TextColor3 = Color3.fromRGB(255, 255, 255) end
        local dot = btn:FindFirstChild("ActiveDot")
        if dot then dot.Visible = true end
        _activeSubTabBtn = btn
    end

    function Tabs:CreateGroup(Config)
        local GroupName = Config[1] or Config.Name or ""
        local GroupIcon = Config[2] or Config.Icon or ""
        local isExpanded = true

        local GroupOrder = CountTab
        CountTab = CountTab + 1

        -- GROUP HEADER
        local GroupHeader = Custom:Create("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = GroupOrder * 100,
            Size = UDim2.new(1, 0, 0, 34),
            Name = "GroupHeader"
        }, ScrollTab)

        local GroupBtn = Custom:Create("TextButton", {
            Font = Enum.Font.GothamBold,
            Text = "",
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Name = "GroupBtn"
        }, GroupHeader)

        -- Icon
        Custom:Create("ImageLabel", {
            Image = GroupIcon,
            ImageColor3 = Color3.fromRGB(150, 150, 180),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 6, 0.5, -8),
            Size = UDim2.new(0, 16, 0, 16),
            Name = "GroupIcon"
        }, GroupHeader)

        -- Label
        Custom:Create("TextLabel", {
            Font = Enum.Font.GothamBold,
            Text = string.upper(GroupName),
            TextColor3 = Color3.fromRGB(160, 160, 190),
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 26, 0.5, -6),
            Size = UDim2.new(1, -48, 0, 14),
            Name = "GroupLabel"
        }, GroupHeader)

        -- Arrow indicator (use ImageLabel with Roblox arrow asset)
        local ArrowLabel = Custom:Create("ImageLabel", {
            Image = "rbxassetid://7072706796",
            ImageColor3 = Color3.fromRGB(120, 120, 150),
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12),
            Rotation = 0,
            Name = "Arrow"
        }, GroupHeader)

        -- Sub-tabs container
        local GroupItems = Custom:Create("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = GroupOrder * 100 + 1,
            Size = UDim2.new(1, 0, 0, 0),
            ClipsDescendants = true,
            Name = "GroupItems"
        }, ScrollTab)

        local GroupItemsLayout = Custom:Create("UIListLayout", {
            Padding = UDim.new(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder
        }, GroupItems)

        local function refreshGroupSize()
            if isExpanded then
                GroupItems.Size = UDim2.new(1, 0, 0, GetUnscaledSize(GroupItemsLayout.AbsoluteContentSize.Y))
                ArrowLabel.Rotation = 0    -- pointing down
            else
                GroupItems.Size = UDim2.new(1, 0, 0, 0)
                ArrowLabel.Rotation = -90  -- pointing right (collapsed)
            end
            UpdateSidebarSize()
        end

        GroupItemsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshGroupSize)

        GroupBtn.Activated:Connect(function()
            isExpanded = not isExpanded
            refreshGroupSize()
        end)

        -- GROUP object returned to caller
        local GroupObj = {}
        local SubCountInGroup = 0

        function GroupObj:CreateTab(TabConfig)
            local TabName = TabConfig[1] or TabConfig.Name or ""
            local TabIcon = TabConfig[2] or TabConfig.Icon or ""
            local TabDescription = TabConfig[3] or TabConfig.Description or ""
            local TabObj = {}

            SubCountInGroup = SubCountInGroup + 1
            local subOrder = SubCountInGroup

            -- Create LEFT scroll frame
            local ScrolLayers = Custom:Create("ScrollingFrame", {
                ScrollBarImageColor3 = Custom.ColorRGB,
                ScrollBarThickness = 3,
                Active = true,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0),
                Visible = false,
                Name = "ScrolLayers",
            }, LayersFolder)

            Custom:Create("UIPadding", {
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4)
            }, ScrolLayers)

            local ScrolLayersLayout = Custom:Create("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, ScrolLayers)
            ScrolLayersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, GetUnscaledSize(ScrolLayersLayout.AbsoluteContentSize.Y) + 10)
            end)

            -- Create RIGHT scroll frame
            local ScrolLayersRight = Custom:Create("ScrollingFrame", {
                ScrollBarImageColor3 = Custom.ColorRGB,
                ScrollBarThickness = 3,
                Active = true,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0),
                Visible = false,
                Name = "ScrolLayersRight",
            }, LayersFolderRight)

            Custom:Create("UIPadding", {
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4)
            }, ScrolLayersRight)

            local ScrolLayersLayoutRight = Custom:Create("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, ScrolLayersRight)
            ScrolLayersLayoutRight:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                ScrolLayersRight.CanvasSize = UDim2.new(0, 0, 0, GetUnscaledSize(ScrolLayersLayoutRight.AbsoluteContentSize.Y) + 10)
            end)

            -- SUB-TAB BUTTON in sidebar
            local SubTabBtn = Custom:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = subOrder,
                Size = UDim2.new(1, 0, 0, 30),
                Name = "SubTabBtn"
            }, GroupItems)
            Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, SubTabBtn)

            -- Active accent dot (purple)
            local ActiveDot = Custom:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(150, 80, 255),
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 4, 0.5, 0),
                Size = UDim2.new(0, 3, 0, 14),
                Visible = false,
                Name = "ActiveDot"
            }, SubTabBtn)
            Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, ActiveDot)

            -- Tab label (no icon, start from left)
            Custom:Create("TextLabel", {
                Font = Enum.Font.Gotham,
                Text = TabName,
                TextColor3 = Color3.fromRGB(160, 160, 190),
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -16, 1, 0),
                Name = "SubLabel"
            }, SubTabBtn)

            local SubClickBtn = Custom:Create("TextButton", {
                Text = "", BackgroundTransparency = 1,
                BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
                Name = "SubClick"
            }, SubTabBtn)

            -- Auto-select first sub-tab
            if isFirstSubTabOverall then
                isFirstSubTabOverall = false
                selectSubTabBtn(SubTabBtn)
                switchSubTab(ScrolLayers, ScrolLayersRight)
                NameTab.Text = TabName
                NameTabSub.Text = TabDescription ~= "" and TabDescription or (GroupName .. " › " .. TabName)
            end

            SubClickBtn.Activated:Connect(function()
                if TabObj.Locked then return end
                CircleClick(SubClickBtn, Player:GetMouse().X, Player:GetMouse().Y)
                selectSubTabBtn(SubTabBtn)
                switchSubTab(ScrolLayers, ScrolLayersRight)
                NameTab.Text = TabName
                NameTabSub.Text = TabDescription ~= "" and TabDescription or (GroupName .. " › " .. TabName)
            end)

            refreshGroupSize()

            -- TAB object (already declared at top of CreateTab)
            local Sections, CountSection = {}, 0
            local CountSectionRight = 0

            function TabObj:AddSection(Title, OpenSection, Side, Locked)
                local Title = Title or ""
                local OpenSection = (OpenSection == nil) and true or OpenSection
                local Side = Side or "Left"
                local Locked = Locked or false
                local TargetScrol = (Side == "Right") and ScrolLayersRight or ScrolLayers
                local currentOrder = (Side == "Right") and CountSectionRight or CountSection
    
            local Section = Custom:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                BackgroundTransparency = 0,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                ClipsDescendants = true,
                LayoutOrder = currentOrder,
                Size = UDim2.new(1, 0, 0, 35),
                Name = "Section"
            }, TargetScrol)
            
            Custom:Create("UICorner", {
                CornerRadius = UDim.new(0, 6)
            }, Section)

            Custom:Create("UIStroke", {
                Color = Color3.fromRGB(45, 45, 55),
                Thickness = 1,
                Transparency = 0.4
            }, Section)
    
            local SectionReal = Custom:Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                Position = UDim2.new(0.5, 0, 0, 0),
                Size = UDim2.new(1, 0, 0, 35),
                Name = "SectionReal"
            }, Section)
 
            local SectionButton = Custom:Create("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0),
                Name = "SectionButton"
            }, SectionReal)

            -- Purple accent bar on left edge
            local SectionAccent = Custom:Create("Frame", {
                Name = "SectionAccent",
                Size = UDim2.new(0, 3, 0, 16),
                Position = UDim2.new(0, 8, 0.5, -8),
                BackgroundColor3 = Custom.ColorRGB,
                BorderSizePixel = 0,
            }, SectionReal)
            Custom:Create("UICorner", { CornerRadius = UDim.new(0, 2) }, SectionAccent)

            -- Collapse chevron button (∨ open / ∧ closed)
            local FeatureFrame = Custom:Create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Custom.ColorRGB,
                BackgroundTransparency = 0.08,
                BorderSizePixel = 0,
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 20, 0, 20),
                Name = "FeatureFrame"
            }, SectionReal)
            Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, FeatureFrame)

            local ChevronLbl = Custom:Create("TextLabel", {
                Name = "ChevronLbl",
                Text = "\226\136\168",  -- ∨ (open state default)
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 1, 0)
            }, FeatureFrame)
    
            local SectionTitle = Custom:Create("TextLabel", {
                Font = Enum.Font.GothamBold,
                Text = Title,
                TextColor3 = Custom.ColorRGB,
                TextStrokeTransparency = 1,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 18, 0, 0),
                Size = UDim2.new(1, -55, 1, 0),
                Name = "SectionTitle"
            }, SectionReal)

            -- Tampilkan icon tab di sebelah kiri judul section
            if TabIcon and TabIcon ~= "" then
                Custom:Create("ImageLabel", {
                    Name = "SectionTabIcon",
                    Image = TabIcon,
                    ImageColor3 = Custom.ColorRGB,
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 16, 0.5, 0),
                    Size = UDim2.new(0, 14, 0, 14),
                }, SectionReal)
                -- Geser judul supaya tidak tumpang tindih dengan icon
                SectionTitle.Position = UDim2.new(0, 34, 0, 0)
            end

      local SectionDecideFrame = Custom:Create("Frame", {
        BackgroundColor3 = Custom.ColorRGB,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 34),
        Size = UDim2.new(1, -16, 0, 1),
        Name = "SectionDecideFrame"
      }, Section)

      Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 1)
      }, SectionDecideFrame)

      Custom:Create("UIGradient", {
        Color = ColorSequence.new{
          ColorSequenceKeypoint.new(0, Custom.ColorRGB),
          ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
        }
      }, SectionDecideFrame)
  
      local SectionAdd = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 1,
        Position = UDim2.new(0.5, 0, 0, 39),
        Size = UDim2.new(1, -16, 0, 100),
        Name = "SectionAdd"
      }, Section)
  
      Custom:Create("UICorner", {
        CornerRadius = UDim.new(0, 6)
      }, SectionAdd)
    
      local SectionListLayout = Custom:Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder
      }, SectionAdd)
  
      -- Removed UpdateSizeScroll as it is handled by the main tab Updaters now
      -- local function UpdateSizeScroll() ... end
    
      local function UpdateSizeSection()
        if OpenSection then
          local SectionSizeYWitdh = GetUnscaledSize(SectionListLayout.AbsoluteContentSize.Y)
          ChevronLbl.Text = "\226\136\168"  -- ∨ (open)
          Section.Size = UDim2.new(1, 0, 0, SectionSizeYWitdh + 39 + 6)
          SectionAdd.Size = UDim2.new(1, -16, 0, SectionSizeYWitdh)
          SectionDecideFrame.Size = UDim2.new(1, -16, 0, 1)
        end
      end

      -- Auto resize when items are added to list
      SectionListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
          UpdateSizeSection()
      end)

       local function ToggleSection()
        if Locked then return end
        CircleClick(SectionButton, Player:GetMouse().X, Player:GetMouse().Y)

        if OpenSection then
            -- Tutup section
            ChevronLbl.Text = "\226\136\167"  -- ∧ (closed)
            Section.Size = UDim2.new(1, 0, 0, 35)
            SectionDecideFrame.Size = UDim2.new(0, 0, 0, 1)
            OpenSection = false
        else
            -- Buka section
            OpenSection = true
            local SectionSizeYWitdh = GetUnscaledSize(SectionListLayout.AbsoluteContentSize.Y)
            ChevronLbl.Text = "\226\136\168"  -- ∨ (open)
            Section.Size = UDim2.new(1, 0, 0, SectionSizeYWitdh + 39 + 6)
            SectionAdd.Size = UDim2.new(1, -16, 0, SectionSizeYWitdh)
            SectionDecideFrame.Size = UDim2.new(1, -16, 0, 1)
        end
    end
    
          SectionButton.Activated:Connect(ToggleSection)
    
          -- SectionAdd.ChildAdded/Removed replaced by UIListLayout PropertyChangedSignal logic above

      local Item, ItemCount = {}, 0
function Item:AddParagraph(Config)
    local Title = Config[1] or Config.Title or ""
    local Content = Config[2] or Config.Content or ""
    local SettingFuncs = {}

    local Paragraph = Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(12, 12, 16),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        LayoutOrder = ItemCount,
        Size = UDim2.new(1, 0, 0, 32),
        AutomaticSize = Enum.AutomaticSize.Y,
        Name = "Paragraph",
    }, SectionAdd)

    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Paragraph)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Paragraph)

    Custom:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8)
    }, Paragraph)

    local ParagraphTitle = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBold,
        Text = Title,
        TextColor3 = Color3.fromRGB(235, 235, 240),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 13),
        Name = "ParagraphTitle",
    }, Paragraph)

    local ParagraphContent = Custom:Create("TextLabel", {
        Font = Enum.Font.Gotham,
        Text = Content,
        TextColor3 = Color3.fromRGB(145, 140, 155),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 16),
        Size = UDim2.new(1, 0, 0, 0),
        Name = "ParagraphContent",
        RichText = true,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y
    }, Paragraph)
    
    if Content == "" then
        ParagraphContent.Visible = false
        Paragraph.AutomaticSize = Enum.AutomaticSize.None
        Paragraph.Size = UDim2.new(1, 0, 0, 32)
        ParagraphTitle.Position = UDim2.new(0, 0, 0.5, -6)
    else
        ParagraphContent.Visible = true
        Paragraph.AutomaticSize = Enum.AutomaticSize.Y
        Paragraph.Size = UDim2.new(1, 0, 0, 0)
        ParagraphTitle.Position = UDim2.new(0, 0, 0, 0)
        ParagraphContent.Position = UDim2.new(0, 0, 0, 16)
    end

    local function parseColors(str)
        local coloredStr = str
        coloredStr = coloredStr:gsub('default%("([^"]-)"%)', '<font color="#ffffff"><b>%1</b></font>')
        coloredStr = coloredStr:gsub('red%("([^"]-)"%)', '<font color="#ff0000"><b>%1</b></font>')
        coloredStr = coloredStr:gsub('blue%("([^"]-)"%)', '<font color="#0000ff"><b>%1</b></font>')
        coloredStr = coloredStr:gsub('green%("([^"]-)"%)', '<font color="#00ff00"><b>%1</b></font>')
        return coloredStr
    end

    function SettingFuncs:Set(Config)
        local Title = Config[1] or Config.Title or ""
        local Content = Config[2] or Config.Content or ""
        ParagraphTitle.Text = Title
        ParagraphContent.Text = parseColors(Content)
    end
    
    ParagraphContent.Text = parseColors(Content)
    return SettingFuncs
end

function Item:AddSeperator(Config)
        local Title = Config[1] or Config.Title or ""
        local Sep_Funcs = {}

        local Seperator = Custom:Create("Frame", {
          BackgroundColor3 = Color3.fromRGB(12, 12, 16),
          BackgroundTransparency = 0,
          BorderSizePixel = 0,
          LayoutOrder = ItemCount,
          Size = UDim2.new(1, 0, 0, 24),
          Name = "Seperator",
        }, SectionAdd)
      
        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Seperator)
        Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Seperator)

        local SeperatorTitle = Custom:Create("TextLabel", {
          Font = Enum.Font.GothamBold,
          Text = Title,
          TextColor3 = Color3.fromRGB(235, 235, 240),
          TextSize = 11,
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Center,
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderSizePixel = 0,
          Position = UDim2.new(0, 10, 0, 0),
          Size = UDim2.new(1, -20, 1, 0),
          Name = "SeperatorTitle",
        }, Seperator)
  
        function Sep_Funcs:Set(Config)
          local Title = Config[1] or Config.Title or ""

          SeperatorTitle.Text = Title
        end

        ItemCount = ItemCount + 1
        return Sep_Funcs
      end

      function Item:AddLine()
        local LineFuncs = {}
    
        local Line = Custom:Create("Frame", {
          BackgroundColor3 = Color3.fromRGB(35, 35, 45),
          BackgroundTransparency = 0.5,
          BorderSizePixel = 0,
          LayoutOrder = ItemCount,
          Size = UDim2.new(1, 0, 0, 1),
          Name = "Line",
        }, SectionAdd)
    
        ItemCount = ItemCount + 1
        return LineFuncs
     end

      function Item:AddButton(Config)
        local Title = Config[1] or Config.Title or ""
        local Content = Config[2] or Config.Content or ""
        local Icon = Config[3] or Config.Icon or "rbxassetid://16932740082"
        local Callback = Config[4] or Config.Callback or function() end
        local Funcs_Button = {}

        local Button = Templates.Button:Clone()
        Button.LayoutOrder = ItemCount
        Button.Parent = SectionAdd
        
        local ButtonTitle = Button.ButtonTitle
        ButtonTitle.Text = Title
        
        local ButtonContent = Button.ButtonContent
        ButtonContent.Text = Content
        
        local ButtonButton = Button.ButtonButton
        local FeatureFrame = Button.FeatureFrame
        local FeatureImg = FeatureFrame.FeatureImg
        FeatureImg.Image = Icon

        if Content == "" then
            ButtonContent.Visible = false
            Button.Size = UDim2.new(1, 0, 0, 32)
            ButtonTitle.Position = UDim2.new(0, 10, 0.5, -7)
            FeatureFrame.Position = UDim2.new(1, -10, 0.5, 0)
        else
            ButtonContent.Visible = true
            Button.Size = UDim2.new(1, 0, 0, 44)
            ButtonTitle.Position = UDim2.new(0, 10, 0, 6)
            ButtonContent.Position = UDim2.new(0, 10, 0, 22)
            FeatureFrame.Position = UDim2.new(1, -10, 0.5, 0)
        end

        ButtonButton.Activated:Connect(function()
            if Funcs_Button.Locked then return end
            CircleClick(ButtonButton, Player:GetMouse().X, Player:GetMouse().Y)
            Callback()
        end)

        function Funcs_Button:Lock()
            self.Locked = true
            LockItem(Button, {ButtonButton})
        end

        function Funcs_Button:Unlock()
            self.Locked = false
            UnlockItem(Button, {ButtonButton})
        end

        if Config.Locked or Config.Lock then
            Funcs_Button:Lock()
        end

        ItemCount = ItemCount + 1
        return Funcs_Button
      end

function Item:AddToggle(Config)
    local Title = Config[1] or Config.Title or ""
    local Content = Config[2] or Config.Content or ""
    local Default = Config[3] or Config.Default or false
    local Mode = Config[4] or Config.Mode or "Toggle" -- "Toggle" atau "Box"
    local Callback = Config[5] or Config.Callback or function() end

    local Funcs_Toggle = {Value = Default}

    local Toggle = Templates.Toggle:Clone()
    Toggle.LayoutOrder = ItemCount
    Toggle.Parent = SectionAdd
    
    local ToggleTitle = Toggle.ToggleTitle
    ToggleTitle.Text = Title
    
    local ToggleContent = Toggle.ToggleContent
    ToggleContent.Text = Content
    
    local ToggleButton = Toggle.ToggleButton
    local FeatureFrame = Toggle.FeatureFrame
    local UIStroke = FeatureFrame.UIStroke
    local ToggleCircle = FeatureFrame:FindFirstChild("ToggleCircle") -- Keep this dynamic

    if Mode ~= "Toggle" and ToggleCircle then
         ToggleCircle:Destroy()
         ToggleCircle = nil
    end

    if Content == "" then
        ToggleContent.Visible = false
        Toggle.Size = UDim2.new(1, 0, 0, 32)
        ToggleTitle.Position = UDim2.new(0, 10, 0.5, -7)
        FeatureFrame.Position = UDim2.new(1, -10, 0.5, 0)
    else
        ToggleContent.Visible = true
        Toggle.Size = UDim2.new(1, 0, 0, 44)
        ToggleTitle.Position = UDim2.new(0, 10, 0, 6)
        ToggleContent.Position = UDim2.new(0, 10, 0, 22)
        FeatureFrame.Position = UDim2.new(1, -10, 0.5, 0)
    end

    local function Animate(Value, Instant)
        if Mode == "Toggle" then
            local TitleColor = Value and Custom.ColorRGB or Color3.fromRGB(235, 235, 240)
            local CirclePosition = Value and UDim2.new(0, 16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
            local StrokeColor = Value and Custom.ColorRGB or Color3.fromRGB(60, 60, 70)
            local StrokeTransparency = Value and 0.4 or 0.7
            local FrameColor = Value and Custom.ColorRGB or Color3.fromRGB(30, 30, 35)
            local CircleColor = Value and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)

            if Instant then
                ToggleTitle.TextColor3 = TitleColor
                if ToggleCircle then 
                    ToggleCircle.Position = CirclePosition 
                    ToggleCircle.BackgroundColor3 = CircleColor
                end
                UIStroke.Color = StrokeColor
                UIStroke.Transparency = StrokeTransparency
                FeatureFrame.BackgroundColor3 = FrameColor
            else
                local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenService:Create(ToggleTitle, tweenInfo, {TextColor3 = TitleColor}):Play()
                if ToggleCircle then 
                    TweenService:Create(ToggleCircle, tweenInfo, {Position = CirclePosition, BackgroundColor3 = CircleColor}):Play() 
                end
                TweenService:Create(UIStroke, tweenInfo, {Color = StrokeColor, Transparency = StrokeTransparency}):Play()
                TweenService:Create(FeatureFrame, tweenInfo, {BackgroundColor3 = FrameColor}):Play()
            end
        else
            -- Mode Box simple nyala/mati
            local FrameColor = Value and Custom.ColorRGB or Color3.fromRGB(30, 30, 35)
            if Instant then
                 FeatureFrame.BackgroundColor3 = FrameColor
            else
                TweenService:Create(FeatureFrame, TweenInfo.new(0.12), {BackgroundColor3 = FrameColor}):Play()
            end
        end
    end

    ToggleButton.Activated:Connect(function()
        if Funcs_Toggle.Locked then return end
        Funcs_Toggle.Value = not Funcs_Toggle.Value
        Funcs_Toggle:Set(Funcs_Toggle.Value)
    end)

    function Funcs_Toggle:Set(Value, Instant)
        Callback(Value)
        if self.ChangedCallback then
            task.spawn(function()
                local ok, err = pcall(self.ChangedCallback, Value)
                if not ok then
                    warn("Error in toggle OnChanged: " .. tostring(err))
                end
            end)
        end
        Animate(Value, Instant)
    end

    function Funcs_Toggle:OnChanged(ChangedCallback)
        self.ChangedCallback = ChangedCallback
        return self
    end

    function Funcs_Toggle:Lock()
        self.Locked = true
        LockItem(Toggle, {ToggleButton})
    end

    function Funcs_Toggle:Unlock()
        self.Locked = false
        UnlockItem(Toggle, {ToggleButton})
    end

    Funcs_Toggle:Set(Default, true)

    if Config.Locked or Config.Lock then
        Funcs_Toggle:Lock()
    end

    ItemCount = ItemCount + 1
    return Funcs_Toggle
end

   function Item:AddSlider(Config)
        local Title = Config[1] or Config.Title or ""
        local Content = Config[2] or Config.Content or ""
        local Increment = Config[3] or Config.Increment or 1
        local Min = Config[4] or Config.Min or 0
        local Max = Config[5] or Config.Max or 100
        local Default = Config[6] or Config.Default or 50
        local Callback = Config[7] or Config.Callback or function() end

        local Funcs_Slider = {Value = Default}
        local Slider = Custom:Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(12, 12, 16),
					BackgroundTransparency = 0,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = ItemCount,
					Size = UDim2.new(1, 0, 0, 32),
					Name = "Slider",
				}, SectionAdd)

        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Slider)
        Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Slider)

        local SliderTitle = Custom:Create("TextLabel", {
            Font = Enum.Font.GothamBold,
            Text = Title,
            TextColor3 = Color3.fromRGB(235, 235, 240),
            TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 10, 0.5, -7),
            Size = UDim2.new(1, -145, 0, 13),
            Name = "SliderTitle",
        }, Slider)

        local SliderContent = Custom:Create("TextLabel", {
            Font = Enum.Font.Gotham,
            Text = Content,
            TextColor3 = Color3.fromRGB(145, 140, 155),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 10, 0, 22),
            Size = UDim2.new(1, -145, 0, 0),
            Name = "SliderContent",
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true
        }, Slider)

        if Content == "" then
            SliderContent.Visible = false
            Slider.Size = UDim2.new(1, 0, 0, 32)
            SliderTitle.Position = UDim2.new(0, 10, 0.5, -7)
        else
            SliderContent.Visible = true
            Slider.Size = UDim2.new(1, 0, 0, 44)
            SliderTitle.Position = UDim2.new(0, 10, 0, 6)
            SliderContent.Position = UDim2.new(0, 10, 0, 22)
        end

        local SliderInput = Custom:Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Custom.ColorRGB,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -115, 0.5, 0),
            Size = UDim2.new(0, 32, 0, 20),
            Name = "SliderInput",
        }, Slider)

        Custom:Create("UICorner", {
          CornerRadius = UDim.new(0, 5),
        }, SliderInput)

        local TextBox = Custom:Create("TextBox", {
            Font = Enum.Font.GothamBold,
            Text = "0",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 12,
            TextWrapped = true,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
        }, SliderInput)

        local SliderFrame = Custom:Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Color3.fromRGB(40, 40, 45),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.new(0, 100, 0, 3),
            Name = "SliderFrame",
        }, Slider)

        Custom:Create("UICorner", {}, SliderFrame)

        local SliderDraggable = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Custom.ColorRGB,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(0.899999976, 0, 0, 1),
					Name = "SliderDraggable",
				}, SliderFrame)

        Custom:Create("UICorner", {}, SliderDraggable)

        local SliderCircle = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Custom.ColorRGB,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Position = UDim2.new(1, 4, 0.5, 0),
					Size = UDim2.new(0, 8, 0, 8),
					Name = "SliderCircle",
				}, SliderDraggable)

        Custom:Create("UICorner", {}, SliderCircle)

        Custom:Create("UIStroke", {
          Color = Custom.ColorRGB,
        }, SliderCircle)

        local Dragging = false
        local dragInputConn, dragEndConn = nil, nil

        local function Round(Number, Factor)
          local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
          if Result < 0 then 
            Result = Result + Factor 
          end
          return Result
        end
        
        function Funcs_Slider:Set(Value)
          Value = math.clamp(Round(Value, Increment), Min, Max)
          Funcs_Slider.Value = Value
          TextBox.Text = tostring(Value)
            
          SliderDraggable.Size = UDim2.fromScale((Value - Min) / (Max - Min), 1)
          if self.ChangedCallback then
              task.spawn(function()
                  local ok, err = pcall(self.ChangedCallback, Value)
                  if not ok then
                      warn("Error in slider OnChanged: " .. tostring(err))
                  end
              end)
          end
        end

        function Funcs_Slider:OnChanged(ChangedCallback)
            self.ChangedCallback = ChangedCallback
            return self
        end

        SliderFrame.InputBegan:Connect(function(Input)
          if Funcs_Slider.Locked then return end
          if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true

            if dragInputConn then dragInputConn:Disconnect() dragInputConn = nil end
            if dragEndConn then dragEndConn:Disconnect() dragEndConn = nil end

            local function updateSlider(moveInput)
              local currPosX = moveInput.Position.X
              local sizeScale = math.clamp((currPosX - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X, 0, 1)
              Funcs_Slider:Set(Min + ((Max - Min) * sizeScale))
            end

            updateSlider(Input)

            dragInputConn = UserInputService.InputChanged:Connect(function(moveInput)
              if Dragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(moveInput)
              end
            end)

            dragEndConn = UserInputService.InputEnded:Connect(function(endInput)
              if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                Dragging = false
                if dragInputConn then dragInputConn:Disconnect() dragInputConn = nil end
                if dragEndConn then dragEndConn:Disconnect() dragEndConn = nil end
                Callback(Funcs_Slider.Value)
              end
            end)
          end
        end)
        
        TextBox:GetPropertyChangedSignal("Text"):Connect(function()
          local Valid = TextBox.Text:gsub("[^%d]", "")
          if Valid ~= "" then
            local ValidNumber = math.min(tonumber(Valid), Max)
            TextBox.Text = tostring(ValidNumber)
          else
            TextBox.Text = "0"
          end
        end)
        
        TextBox.FocusLost:Connect(function()
          if Funcs_Slider.Locked then return end
          if TextBox.Text ~= "" then
            Funcs_Slider:Set(tonumber(TextBox.Text))
            Callback(Funcs_Slider.Value)
          else
            Funcs_Slider:Set(0)
            Callback(Funcs_Slider.Value)
          end
        end)
        
        function Funcs_Slider:Lock()
            self.Locked = true
            LockItem(Slider, {TextBox})
        end

        function Funcs_Slider:Unlock()
            self.Locked = false
            UnlockItem(Slider, {TextBox})
        end

        Funcs_Slider:Set(tonumber(Default))
        Callback(Funcs_Slider.Value)

        if Config.Locked or Config.Lock then
            Funcs_Slider:Lock()
        end

        ItemCount = ItemCount + 1
        return Funcs_Slider
      end

      function Item:AddInput(Config)
        local Title = Config[1] or Config.Title or ""
        local Content = Config[2] or Config.Content or ""
        local Default = Config[3] or Config.Default or ""
        local Callback = Config[4] or Config.Callback or function() end
				local Funcs_Input = {Value = Default}

        local Input = Custom:Create("Frame", {
          BackgroundColor3 = Color3.fromRGB(12, 12, 16),
          BackgroundTransparency = 0,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          LayoutOrder = ItemCount,
          Size = UDim2.new(1, 0, 0, 32),
          Name = "Input",
        }, SectionAdd)

        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Input)
        Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Input)

        local InputTitle = Custom:Create("TextLabel", {
          Font = Enum.Font.GothamBold,
          Text = Title,
          TextColor3 = Color3.fromRGB(235, 235, 240),
          TextSize = 12,
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Center,
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 0.999,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Position = UDim2.new(0, 10, 0.5, -7),
          Size = UDim2.new(1, -180, 0, 13),
          Name = "InputTitle",
        }, Input)

        local InputContent = Custom:Create("TextLabel", {
          Font = Enum.Font.Gotham,
          Text = Content,
          TextColor3 = Color3.fromRGB(145, 140, 155),
          TextSize = 11,
          TextWrapped = true,
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Top,
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 0.999,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Position = UDim2.new(0, 10, 0, 22),
          Size = UDim2.new(1, -180, 0, 12),
          Name = "InputContent",
          Parent = Input
        })

        local InputFrame = Custom:Create("Frame", {
          AnchorPoint = Vector2.new(1, 0.5),
          BackgroundColor3 = Color3.fromRGB(8, 8, 12),
          BackgroundTransparency = 0,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          ClipsDescendants = true,
          Position = UDim2.new(1, -7, 0.5, 0),
          Size = UDim2.new(0, 148, 0, 24),
          Name = "InputFrame"
        }, Input)
        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, InputFrame)
        Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, InputFrame)

        local function UpdateInputSize()
          if Content == "" then
             InputContent.Visible = false
             Input.Size = UDim2.new(1, 0, 0, 32)
             InputTitle.Position = UDim2.new(0, 10, 0.5, -7)
             InputFrame.Position = UDim2.new(1, -7, 0.5, 0)
          else
             InputContent.Visible = true
             local Ratio = InputContent.TextBounds.X / GetUnscaledSize(InputContent.AbsoluteSize.X)
             local Calculated = 12 + (12 * math.floor(Ratio))
             InputContent.Size = UDim2.new(1, -180, 0, Calculated)
             Input.Size = UDim2.new(1, 0, 0, GetUnscaledSize(InputContent.AbsoluteSize.Y) + 33)
             InputTitle.Position = UDim2.new(0, 10, 0, 6)
             InputContent.Position = UDim2.new(0, 10, 0, 22)
             InputFrame.Position = UDim2.new(1, -7, 0.5, 0)
          end
        end
      
        UpdateInputSize()
      
        InputContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
          InputContent.TextWrapped = false
          UpdateInputSize()
          InputContent.TextWrapped = true
          UpdateSizeSection()
        end)

        local InputTextBox = Custom:Create("TextBox", {
          CursorPosition = -1,
          Font = Enum.Font.Gotham,
          PlaceholderColor3 = Color3.fromRGB(100, 100, 110),
          PlaceholderText = "Write input here...",
          Text = "",
          TextColor3 = Color3.fromRGB(255, 255, 255),
          TextSize = 11,
          TextXAlignment = Enum.TextXAlignment.Left,
          AnchorPoint = Vector2.new(0, 0.5),
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 0.999,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Position = UDim2.new(0, 5, 0.5, 0),
          Size = UDim2.new(1, -10, 1, 0),
          Name = "InputTextBox"
        }, InputFrame)

        function Funcs_Input:Set(Value)
					InputTextBox.Text = Value
					Funcs_Input.Value = Value
					Callback(Value)
					if self.ChangedCallback then
						task.spawn(function()
							local ok, err = pcall(self.ChangedCallback, Value)
							if not ok then
								warn("Error in input OnChanged: " .. tostring(err))
							end
						end)
					end
				end

        function Funcs_Input:OnChanged(ChangedCallback)
            self.ChangedCallback = ChangedCallback
            return self
        end

        InputTextBox.FocusLost:Connect(function()
            if Funcs_Input.Locked then return end
            Funcs_Input:Set(InputTextBox.Text)
        end)

        function Funcs_Input:Lock()
            self.Locked = true
            LockItem(Input, {InputTextBox})
        end

        function Funcs_Input:Unlock()
            self.Locked = false
            UnlockItem(Input, {InputTextBox})
        end

        Funcs_Input:Set(Default)

        if Config.Locked or Config.Lock then
            Funcs_Input:Lock()
        end

        ItemCount = ItemCount + 1
        return Funcs_Input
      end

function Item:AddDropdown(Config)
    local Title = Config[1] or Config.Title or ""
    local Content = Config[2] or Config.Content or ""
    local Multi = Config[3] or Config.Multi or false
    local Options = Config[4] or Config.Options or {}
    local Default = Config[5] or Config.Default or {}
    local Callback = Config[6] or Config.Callback or function() end

    -- Ensure Default is always a table for internal consistency
    if type(Default) ~= "table" then
        Default = Default and {Default} or {}
    end
    
    local Funcs_Dropdown = {Value = Default, Options = Options}

    local Dropdown = Custom:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(12, 12, 16),
        BackgroundTransparency = 0,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        LayoutOrder = ItemCount,
        Size = UDim2.new(1, 0, 0, 32),
        Name = "Dropdown"
    }, SectionAdd)

    local DropdownButton = Custom:Create("TextButton", {
        Font = Enum.Font.SourceSans,
        Text = "",
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = 14,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.999,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Name = "ToggleButton"
    }, Dropdown)

    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Dropdown)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, Dropdown)

    local DropdownTitle = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBold,
        Text = Title,
        TextColor3 = Color3.fromRGB(235, 235, 240),
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0.5, -7),
        Size = UDim2.new(1, -165, 0, 13),  -- leave 155px for SelectOptionsFrame + 10px gap
        Name = "DropdownTitle",
        Parent = Dropdown
    })

    -- DropdownContent
    local DropdownContent = Custom:Create("TextLabel", {
        Font = Enum.Font.Gotham,
        Text = Content,
        TextColor3 = Color3.fromRGB(145, 140, 155),
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 22),
        Size = UDim2.new(1, -165, 0, 12),
        Visible = false,
        Name = "DropdownContent",
        Parent = Dropdown
    })

    if Content == "" then
        DropdownContent.Visible = false
        Dropdown.Size = UDim2.new(1, 0, 0, 32)
        DropdownTitle.Position = UDim2.new(0, 10, 0.5, -7)
    else
        DropdownContent.Visible = true
        Dropdown.Size = UDim2.new(1, 0, 0, 44)
        DropdownTitle.Position = UDim2.new(0, 10, 0, 6)
        DropdownContent.Position = UDim2.new(0, 10, 0, 22)
    end

    DropdownContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        UpdateSizeSection()
    end)

    local SelectOptionsFrame = Custom:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(8, 8, 12),
        BackgroundTransparency = 0,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.new(0, 148, 0, 24),
        Name = "SelectOptionsFrame",
        LayoutOrder = CountDropdown
    }, Dropdown)

    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, SelectOptionsFrame)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, SelectOptionsFrame)

    DropdownButton.Activated:Connect(function()
        if Funcs_Dropdown.Locked then return end
        if not MoreBlur.Visible then
            MoreBlur.Visible = true
            MoreBlur.BackgroundTransparency = 0.999
            DropdownSelect.Position = UDim2.new(1, 172, 0.5, 0)
            
            DropPageLayout:JumpToIndex(SelectOptionsFrame.LayoutOrder)
                        
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local BlurTween = TweenService:Create(MoreBlur, tweenInfo, {BackgroundTransparency = 0.7})
            local DropdownTween = TweenService:Create(DropdownSelect, tweenInfo, {Position = UDim2.new(1, -11, 0.5, 0)})
            
            BlurTween:Play()
            DropdownTween:Play()
        end
    end)

    local OptionSelecting = Custom:Create("TextLabel", {
        Font = Enum.Font.GothamBold,
        Text = "",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        TextTransparency = 0.6,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.999,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.new(1, -30, 1, -8),
        Name = "OptionSelecting",
    }, SelectOptionsFrame)

    local OptionImg = Custom:Create("ImageLabel", {
        Image = "rbxassetid://16851841101",
        ImageColor3 = Color3.fromRGB(231, 231, 231),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.999,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 25, 0, 25),
        Name = "OptionImg",
    }, SelectOptionsFrame)

    local ScrollSelect = Custom:Create("ScrollingFrame", {
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
        ScrollBarThickness = 0,
        Active = true,
        LayoutOrder = CountDropdown,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.999,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Name = "ScrollSelect",
    }, DropdownFolder)
    
    -- Create Search Bar with proper positioning
    local SearchBar = Custom:Create("TextBox", {
        Font = Enum.Font.GothamMedium,
        PlaceholderText = "Search options...",
        PlaceholderColor3 = Color3.fromRGB(90, 90, 100),
        Text = "",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        BackgroundColor3 = Color3.fromRGB(8, 8, 12),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, 24),
        Position = UDim2.new(0, 3, 0, 3),
        Name = "SearchBar",
        LayoutOrder = -1, -- Put search bar at the top
        Parent = ScrollSelect
    })

    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, SearchBar)
    Custom:Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, SearchBar)

    Custom:Create("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    }, ScrollSelect)

    -- Search Bar Logic - Fixed
    SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
        local searchText = SearchBar.Text:lower()
        for _, optionFrame in pairs(ScrollSelect:GetChildren()) do
            if optionFrame:IsA("Frame") and optionFrame.Name == "Option" then
                local optionText = optionFrame:FindFirstChild("OptionText")
                if optionText then
                    local shouldShow = searchText == "" or optionText.Text:lower():find(searchText, 1, true) ~= nil
                    optionFrame.Visible = shouldShow
                end
            end
        end
        
        -- Update canvas size after search
        local function UpdateCanvasSize()
            local OffsetY = 28 -- Account for search bar
            for _, child in ipairs(ScrollSelect:GetChildren()) do
                if child.Name ~= "UIListLayout" and child.Name ~= "SearchBar" and child.Visible then
                    OffsetY = OffsetY + 3 + child.Size.Y.Offset
                end
            end
            ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
        end
        UpdateCanvasSize()
    end)

    local DropCount = 0

    function Funcs_Dropdown:Clear()
        for _, DropFrame in pairs(ScrollSelect:GetChildren()) do
            if DropFrame.Name == "Option" then
                DropFrame:Destroy()
            end
        end
        Funcs_Dropdown.Value = {}
        Funcs_Dropdown.Options = {}
        OptionSelecting.Text = "Select Options"
        DropCount = 0
    end
    
    function Funcs_Dropdown:Set(Value)
        if type(Value) == "string" then
            Value = {Value}
        elseif Value ~= nil and type(Value) ~= "table" then
            Value = {tostring(Value)}
        end
        Funcs_Dropdown.Value = Value or Funcs_Dropdown.Value

        for _, Drop in ipairs(ScrollSelect:GetChildren()) do
            if Drop.Name == "Option" then
                local optionText = Drop:FindFirstChild("OptionText")
                local checkmark = Drop:FindFirstChild("Checkmark")
                if optionText then
                    local isTextFound = table.find(Funcs_Dropdown.Value, optionText.Text) ~= nil
                    if checkmark then
                        checkmark.Visible = isTextFound
                    end
                    Drop.BackgroundColor3 = isTextFound and Custom.ColorRGB or Color3.fromRGB(255, 255, 255)
                    Drop.BackgroundTransparency = isTextFound and 0.85 or 0.999
                    optionText.TextColor3 = isTextFound and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(210, 210, 220)
                end
            end
        end
    
        local DropdownValueTable = table.concat(Funcs_Dropdown.Value, ", ")
        OptionSelecting.Text = DropdownValueTable ~= "" and DropdownValueTable or "Select Options"
        
        -- For single selection, pass the first value as string, for multi pass the table
        if Multi then
            Callback(Funcs_Dropdown.Value)
            if self.ChangedCallback then
                task.spawn(function()
                    local ok, err = pcall(self.ChangedCallback, Funcs_Dropdown.Value)
                    if not ok then
                        warn("Error in dropdown OnChanged: " .. tostring(err))
                    end
                end)
            end
        else
            local val = Funcs_Dropdown.Value[1] or ""
            Callback(val)
            if self.ChangedCallback then
                task.spawn(function()
                    local ok, err = pcall(self.ChangedCallback, val)
                    if not ok then
                        warn("Error in dropdown OnChanged: " .. tostring(err))
                    end
                end)
            end
        end
    end

    function Funcs_Dropdown:OnChanged(ChangedCallback)
        self.ChangedCallback = ChangedCallback
        return self
    end

    function Funcs_Dropdown:AddOption(OptionName)
        OptionName = OptionName or "Option"

        -- Option Frame
        local Option = Custom:Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.999,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            LayoutOrder = DropCount,
            Size = UDim2.new(1, -6, 0, 28),
            Name = "Option",
            Visible = true
        }, ScrollSelect)

        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Option)

        local OptionButton = Custom:Create("TextButton", {
            Font = Enum.Font.GothamMedium,
            Text = "",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.999,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Name = "OptionButton"
        }, Option)

        local OptionText = Custom:Create("TextLabel", {
            Font = Enum.Font.GothamMedium,
            Text = OptionName,
            TextSize = 11,
            TextColor3 = Color3.fromRGB(210, 210, 220),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -40, 1, 0),
            Name = "OptionText"
        }, Option)

        local Checkmark = Custom:Create("TextLabel", {
            Name = "Checkmark",
            Font = Enum.Font.GothamBold,
            Text = "✓",
            TextColor3 = Custom.ColorRGB,
            TextSize = 11,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12),
            Visible = false
        }, Option)

        -- Lightweight Hover States (Zero Tween Allocation)
        OptionButton.MouseEnter:Connect(function()
            local isSelected = table.find(Funcs_Dropdown.Value, OptionName)
            if not isSelected then
                Option.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Option.BackgroundTransparency = 0.95
            end
        end)

        OptionButton.MouseLeave:Connect(function()
            local isSelected = table.find(Funcs_Dropdown.Value, OptionName)
            if not isSelected then
                Option.BackgroundTransparency = 0.999
            end
        end)

        OptionButton.Activated:Connect(function()
            CircleClick(OptionButton, Player:GetMouse().X, Player:GetMouse().Y)
        
            local isOptionSelected = not table.find(Funcs_Dropdown.Value, OptionName)

            if Multi then
                if isOptionSelected then
                    if not table.find(Funcs_Dropdown.Value, OptionName) then
                        table.insert(Funcs_Dropdown.Value, OptionName)
                    end
                else
                    for i, value in ipairs(Funcs_Dropdown.Value) do
                        if value == OptionName then
                            table.remove(Funcs_Dropdown.Value, i)
                            break
                        end
                    end
                end
            else
                Funcs_Dropdown.Value = {OptionName}
            end

            Funcs_Dropdown:Set(Funcs_Dropdown.Value)
        end)
    
        -- Update canvas size function - Optimized to O(1) to avoid loading lag
        local function UpdateCanvasSize()
            ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, 28 + (DropCount + 1) * 31)
        end
    
        UpdateCanvasSize()
        DropCount = DropCount + 1
    end

    function Funcs_Dropdown:Refresh(RefreshList, Selecting)
        RefreshList = RefreshList or {}
        Selecting = Selecting or {}

        table.sort(RefreshList, function(a, b)
            return tostring(a):lower() < tostring(b):lower()
        end)

        Funcs_Dropdown:Clear()

        if LoadMode == "slow" then
            -- Slow: load dengan task.wait() berkala (tiap 15 item) agar tidak ngelag/framedrop
            task.spawn(function()
                for i, Drop in ipairs(RefreshList) do
                    Funcs_Dropdown:AddOption(Drop)
                    if i % 15 == 0 then
                        task.wait()
                    end
                end
                Funcs_Dropdown.Options = RefreshList
                Funcs_Dropdown:Set(Selecting)
            end)
        else
            -- Fast: langsung load semua tanpa delay
            for _, Drop in ipairs(RefreshList) do
                Funcs_Dropdown:AddOption(Drop)
            end
            Funcs_Dropdown.Options = RefreshList
            Funcs_Dropdown:Set(Selecting)
        end
    end

    -- Initialize with options
    Funcs_Dropdown:Refresh(Funcs_Dropdown.Options, Funcs_Dropdown.Value)

    function Funcs_Dropdown:Lock()
        self.Locked = true
        LockItem(Dropdown, {DropdownButton})
    end

    function Funcs_Dropdown:Unlock()
        self.Locked = false
        UnlockItem(Dropdown, {DropdownButton})
    end

    if Config.Locked or Config.Lock then
        Funcs_Dropdown:Lock()
    end

    ItemCount = ItemCount + 1
    CountDropdown = CountDropdown + 1
    return Funcs_Dropdown
end

      ItemCount = ItemCount + 1
      if Side == "Right" then
          CountSectionRight = CountSectionRight + 1
      else
          CountSection = CountSection + 1
      end

      function Item:Lock()
          self.Locked = true
          LockItem(Section, {SectionButton})
      end
      
      function Item:Unlock()
          self.Locked = false
          UnlockItem(Section, {SectionButton})
      end

      if Locked then
          Item:Lock()
      end

      Item.Frame = Section

      return Item
            end  -- end TabObj:AddSection

            function TabObj:Lock()
                self.Locked = true
                LockItem(SubTabBtn, {SubClickBtn})
            end
            
            function TabObj:Unlock()
                self.Locked = false
                UnlockItem(SubTabBtn, {SubClickBtn})
            end

            TabObj.ScrolLayers = ScrolLayers
            TabObj.ScrolLayersRight = ScrolLayersRight
            TabObj.SubTabBtn = SubTabBtn

            if TabConfig.Locked or TabConfig.Lock then
                TabObj:Lock()
            end

            return TabObj
        end -- end GroupObj:CreateTab

        return GroupObj
    end  -- end Tabs:CreateGroup

    -- Backward-compat alias
    function Tabs:CreateTab(Config)
        local grp = self:CreateGroup({Config[1] or Config.Name or "", Config[2] or Config.Icon or ""})
        return grp:CreateTab({Config[1] or Config.Name or "", Config[2] or Config.Icon or "", Config[3] or Config.Description or ""})
    end

    -- Auto AFK Memory Cleaner (periodic GC to prevent lag & memory leaks during long AFK sessions)
    task.spawn(function()
        while task.wait(180) and getgenv().FishTPSession == FISHTP_SESSION do
            pcall(function()
                collectgarbage("collect")
            end)
        end
    end)

    return Tabs
end

return Speed_Library