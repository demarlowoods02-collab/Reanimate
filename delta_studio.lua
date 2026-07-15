--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

print("Initializing Delta Studio (Dual Animation Recorder)...")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
if not PlayerGui then return end

local successClear = pcall(function()
	if PlayerGui:FindFirstChild("DeltaCFrameRecorder") then PlayerGui.DeltaCFrameRecorder:Destroy() end
	if game:GetService("CoreGui"):FindFirstChild("DeltaCFrameRecorder") then game:GetService("CoreGui").DeltaCFrameRecorder:Destroy() end
end)

local targetParent = PlayerGui
local successCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
if successCore and coreGui then targetParent = coreGui end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaCFrameRecorder"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = targetParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 280, 0, 520) 
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

-- Add rounded corners effect
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.BackgroundColor3 = Color3.fromRGB(40, 80, 120)
TitleLabel.Text = "⚡ Dual Animation Recorder"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
TitleLabel.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleLabel

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = MainFrame

-- Add padding
local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 10)
Padding.PaddingRight = UDim.new(0, 10)
Padding.PaddingTop = UDim.new(0, 50)
Padding.PaddingBottom = UDim.new(0, 10)
Padding.Parent = MainFrame

local function setupButton(text, order, color, customParent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundColor3 = color or Color3.fromRGB(60, 60, 80)
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order
	btn.Parent = customParent or MainFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	
	return btn
end

local selectedFile = nil
local animSpeed = 1.0
local isLooping = false
local savedData = {}
local isRecording = false
local isPlaying = false
local forceStopPlayback = false
local tempFrames = {}
local frameCount = 1
local recordConnection = nil
local targetDummy = nil

local RecordBtn = setupButton("⏺ Record (You + Dummy)", 1, Color3.fromRGB(200, 60, 60))

-- Dummy Selection Section
local DummySectionLabel = Instance.new("TextLabel")
DummySectionLabel.Size = UDim2.new(1, 0, 0, 20)
DummySectionLabel.BackgroundTransparency = 1
DummySectionLabel.Text = "📦 Select Dummy"
DummySectionLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
DummySectionLabel.Font = Enum.Font.GothamBold
DummySectionLabel.TextSize = 12
DummySectionLabel.TextXAlignment = Enum.TextXAlignment.Left
DummySectionLabel.LayoutOrder = 2
DummySectionLabel.Parent = MainFrame

local DummyFrame = Instance.new("Frame")
DummyFrame.Size = UDim2.new(1, 0, 0, 40)
DummyFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
DummyFrame.BorderSizePixel = 0
DummyFrame.LayoutOrder = 3
DummyFrame.Parent = MainFrame

local DummyCorner = Instance.new("UICorner")
DummyCorner.CornerRadius = UDim.new(0, 6)
DummyCorner.Parent = DummyFrame

local DummyLabel = Instance.new("TextLabel")
DummyLabel.Size = UDim2.new(0.6, 0, 1, 0)
DummyLabel.BackgroundTransparency = 1
DummyLabel.Text = "None Selected"
DummyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
DummyLabel.Font = Enum.Font.Gotham
DummyLabel.TextSize = 12
DummyLabel.TextXAlignment = Enum.TextXAlignment.Left
DummyLabel.Parent = DummyFrame

local SelectDummyBtn = Instance.new("TextButton")
SelectDummyBtn.Size = UDim2.new(0.35, 0, 0.8, 0)
SelectDummyBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
SelectDummyBtn.BorderSizePixel = 0
SelectDummyBtn.Text = "Select"
SelectDummyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectDummyBtn.Font = Enum.Font.GothamBold
SelectDummyBtn.TextSize = 12
SelectDummyBtn.Parent = DummyFrame

local SelectCorner = Instance.new("UICorner")
SelectCorner.CornerRadius = UDim.new(0, 4)
SelectCorner.Parent = SelectDummyBtn

local selectingDummy = false
local mouse = LocalPlayer:GetMouse()

SelectDummyBtn.MouseButton1Click:Connect(function()
	selectingDummy = true
	SelectDummyBtn.Text = "Click Dummy!"
	SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
end)

mouse.Button1Down:Connect(function()
	if selectingDummy then
		local target = mouse.Target
		if target then
			local char = target.Parent
			if char and char:FindFirstChild("Humanoid") then
				targetDummy = char
				DummyLabel.Text = "✓ " .. char.Name
				SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
				SelectDummyBtn.Text = "✓ Selected"
				selectingDummy = false
				task.wait(1)
				SelectDummyBtn.Text = "Select"
				SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
			else
				SelectDummyBtn.Text = "Not a Dummy!"
				task.wait(1)
				SelectDummyBtn.Text = "Click Dummy!"
			end
		end
	end
end)

-- Speed UI Section
local SpeedSectionLabel = Instance.new("TextLabel")
SpeedSectionLabel.Size = UDim2.new(1, 0, 0, 20)
SpeedSectionLabel.BackgroundTransparency = 1
SpeedSectionLabel.Text = "⚙ Playback Settings"
SpeedSectionLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
SpeedSectionLabel.Font = Enum.Font.GothamBold
SpeedSectionLabel.TextSize = 12
SpeedSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedSectionLabel.LayoutOrder = 4
SpeedSectionLabel.Parent = MainFrame

local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(1, 0, 0, 40)
SpeedFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
SpeedFrame.BorderSizePixel = 0
SpeedFrame.LayoutOrder = 5
SpeedFrame.Parent = MainFrame

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedFrame

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0.5, 0, 1, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Speed: 1.0x"
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpeedLabel.Font = Enum.Font.Gotham
SpeedLabel.TextSize = 12
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = SpeedFrame

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0.45, 0, 0.7, 0)
SpeedInput.Position = UDim2.new(0.53, 0, 0.15, 0)
SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
SpeedInput.BorderSizePixel = 0
SpeedInput.Text = "1.0"
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.Font = Enum.Font.Gotham
SpeedInput.TextSize = 12
SpeedInput.Parent = SpeedFrame

local SpeedInputCorner = Instance.new("UICorner")
SpeedInputCorner.CornerRadius = UDim.new(0, 4)
SpeedInputCorner.Parent = SpeedInput

SpeedInput.FocusLost:Connect(function()
	local num = tonumber(SpeedInput.Text)
	if num and num > 0 then animSpeed = num SpeedLabel.Text = "Speed: " .. num .. "x" else SpeedInput.Text = tostring(animSpeed) end
end)

local LoopBtn = setupButton("🔁 Loop: OFF", 6, Color3.fromRGB(100, 100, 120))
LoopBtn.MouseButton1Click:Connect(function()
	isLooping = not isLooping
	LoopBtn.Text = isLooping and "🔁 Loop: ON" or "🔁 Loop: OFF"
	LoopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(80, 140, 140) or Color3.fromRGB(100, 100, 120)
end)

-- Dropdown Setup
local DropdownBtn = setupButton("▼ Load Animation", 7, Color3.fromRGB(80, 100, 120))
local DropdownContainer = Instance.new("ScrollingFrame")
DropdownContainer.Size = UDim2.new(0.98, 0, 0, 100)
DropdownContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
DropdownContainer.BorderSizePixel = 0
DropdownContainer.Visible = false
DropdownContainer.LayoutOrder = 8
DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownContainer.Parent = MainFrame

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 6)
DropdownCorner.Parent = DropdownContainer

local DropdownList = Instance.new("UIListLayout")
DropdownList.SortOrder = Enum.SortOrder.LayoutOrder
DropdownList.Padding = UDim.new(0, 2)
DropdownList.Parent = DropdownContainer

local function refreshDropdown()
	for _, child in ipairs(DropdownContainer:GetChildren()) do if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end end
	if listfiles then
		local files = {} pcall(function() files = listfiles("") end)
		local itemOrder, totalHeight = 1, 0
		for _, file in ipairs(files) do
			if file:match("^DualAnim_") and file:sub(-5) == ".json" then
				local itemBtn = Instance.new("TextButton")
				itemBtn.Size = UDim2.new(1, 0, 0, 30)
				itemBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
				itemBtn.Text = file
				itemBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
				itemBtn.Font = Enum.Font.Gotham
				itemBtn.TextSize = 11
				itemBtn.BorderSizePixel = 0
				itemBtn.LayoutOrder = itemOrder
				itemBtn.Parent = DropdownContainer
				
				local itemCorner = Instance.new("UICorner")
				itemCorner.CornerRadius = UDim.new(0, 4)
				itemCorner.Parent = itemBtn
				
				totalHeight = totalHeight + 32
				itemOrder = itemOrder + 1
				
				local deleteBtn = Instance.new("TextButton")
				deleteBtn.Size = UDim2.new(1, 0, 0, 25)
				deleteBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
				deleteBtn.Text = "🗑 Delete"
				deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				deleteBtn.Font = Enum.Font.GothamBold
				deleteBtn.TextSize = 10
				deleteBtn.BorderSizePixel = 0
				deleteBtn.LayoutOrder = itemOrder
				deleteBtn.Visible = false
				deleteBtn.Parent = DropdownContainer
				
				local deleteCorner = Instance.new("UICorner")
				deleteCorner.CornerRadius = UDim.new(0, 4)
				deleteCorner.Parent = deleteBtn
				
				itemOrder = itemOrder + 1
				
				local holding = false
				itemBtn.MouseButton1Down:Connect(function()
					holding = true task.wait(1.5)
					if holding then
						deleteBtn.Visible = not deleteBtn.Visible
						DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownContainer.CanvasSize.Y.Offset + (deleteBtn.Visible and 27 or -27))
					end
				end)
				itemBtn.MouseButton1Up:Connect(function() holding = false end)
				
				itemBtn.MouseButton1Click:Connect(function()
					if deleteBtn.Visible then return end
					selectedFile = file DropdownBtn.Text = "📁 " .. file DropdownContainer.Visible = false
					if readfile and isfile(file) then
						local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
						if success then savedData = decoded end
					end
				end)
				
				deleteBtn.MouseButton1Click:Connect(function()
					pcall(function() if delfile and isfile(file) then delfile(file) elseif odfdelfile then odfdelfile(file) end end)
					if selectedFile == file then selectedFile = nil savedData = {} DropdownBtn.Text = "▼ Load Animation" end
					refreshDropdown()
				end)
			end
		end
		DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
	else DropdownBtn.Text = "Missing 'listfiles'" end
end

DropdownBtn.MouseButton1Click:Connect(function()
	DropdownContainer.Visible = not DropdownContainer.Visible
	if DropdownContainer.Visible then refreshDropdown() end
end)

local function getNextAutoName()
	local highestNum = 0
	if listfiles then
		local files = {} pcall(function() files = listfiles("") end)
		for _, file in ipairs(files) do
			local match = file:match("^DualAnim_(%d+)%.json")
			if match then local num = tonumber(match) if num and num > highestNum then highestNum = num end end
		end
	end
	return "DualAnim_" .. (highestNum + 1) .. ".json"
end

local ActionRowFrame = Instance.new("Frame")
ActionRowFrame.Size = UDim2.new(1, 0, 0, 90)
ActionRowFrame.BackgroundTransparency = 1
ActionRowFrame.LayoutOrder = 9
ActionRowFrame.Parent = MainFrame

local ActionRowLayout = Instance.new("UIListLayout")
ActionRowLayout.FillDirection = Enum.FillDirection.Horizontal
ActionRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ActionRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
ActionRowLayout.Padding = UDim.new(0, 6)
ActionRowLayout.Parent = ActionRowFrame

local PlayBtn = setupButton("▶ Play", 1, Color3.fromRGB(60, 140, 60), ActionRowFrame)
PlayBtn.Size = UDim2.new(0.48, 0, 0, 40)

local StopBtn = setupButton("⏹ Stop", 2, Color3.fromRGB(160, 90, 40), ActionRowFrame)
StopBtn.Size = UDim2.new(0.48, 0, 0, 40)

local CopyBtn = setupButton("📋 Copy Data", 10)
local ClearBtn = setupButton("🗑 Clear Save", 11, Color3.fromRGB(100, 100, 120))
local DeleteAllBtn = setupButton("💥 Delete All", 12, Color3.fromRGB(160, 40, 40))

local function cfToTable(cf)
	return {cf:GetComponents()}
end

local function tableToCf(t) return CFrame.new(unpack(t)) end

-- DUAL ANIMATION RECORDER
RecordBtn.MouseButton1Click:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then print("Character not found!") return end
	if not targetDummy or not targetDummy:FindFirstChild("HumanoidRootPart") then print("Dummy not selected!") return end

	if not isRecording then
		isRecording = true
		tempFrames = {}
		frameCount = 1
		RecordBtn.Text = "⏹ Stop Recording"
		RecordBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
		
		local myJoints = {}
		for _, v in ipairs(char:GetDescendants()) do if v:IsA("Motor6D") then table.insert(myJoints, v) end end
		
		local dummyJoints = {}
		for _, v in ipairs(targetDummy:GetDescendants()) do if v:IsA("Motor6D") then table.insert(dummyJoints, v) end end
		
		print("Recording started! Player joints: " .. #myJoints .. ", Dummy joints: " .. #dummyJoints)
		
		recordConnection = RunService.Heartbeat:Connect(function(dt)
			if not root or not root.Parent then return end
			local dummyRoot = targetDummy:FindFirstChild("HumanoidRootPart")
			if not dummyRoot or not dummyRoot.Parent then return end
			
			local currentFrame = {}
			local hasData = false
			
			-- Record player joints
			currentFrame["_PlayerJoints"] = {}
			for _, joint in ipairs(myJoints) do
				if joint and joint.Parent then
					currentFrame["_PlayerJoints"][joint.Name] = cfToTable(joint.Transform)
					hasData = true
				end
			end
			
			-- Record dummy joints
			currentFrame["_DummyJoints"] = {}
			for _, joint in ipairs(dummyJoints) do
				if joint and joint.Parent then
					currentFrame["_DummyJoints"][joint.Name] = cfToTable(joint.Transform)
					hasData = true
				end
			end
			
			-- Record frame time
			currentFrame["_FrameTime"] = dt
			
			if hasData then
				tempFrames[tostring(frameCount)] = currentFrame
				frameCount = frameCount + 1
			end
		end)
	else
		isRecording = false
		if recordConnection then recordConnection:Disconnect() recordConnection = nil end
		
		savedData = tempFrames
		if writefile then
			local calculatedName = getNextAutoName()
			pcall(function() writefile(calculatedName, HttpService:JSONEncode(savedData)) end)
			selectedFile = calculatedName DropdownBtn.Text = "📁 " .. calculatedName
			print("Animation saved: " .. calculatedName .. " (" .. frameCount .. " frames)")
		end
		RecordBtn.Text = "⏺ Record (You + Dummy)"
		RecordBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		refreshDropdown()
	end
end)

-- DUAL ANIMATION PLAYBACK
PlayBtn.MouseButton1Click:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root or isPlaying or not savedData or next(savedData) == nil then print("Cannot play: Invalid state") return end
	
	-- Find nearest player to sync dummy animation
	local nearestPlayer = nil
	local nearestDist = 50
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
			if playerRoot then
				local dist = (playerRoot.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPlayer = player
				end
			end
		end
	end
	
	if not nearestPlayer then print("No nearby players found!") return end
	print("Playing animation on nearest player: " .. nearestPlayer.Name)
	
	isPlaying = true
	forceStopPlayback = false
	PlayBtn.Text = "Playing..."
	
	local myJoints = {}
	for _, v in ipairs(char:GetDescendants()) do if v:IsA("Motor6D") then myJoints[v.Name] = v end end
	
	local targetChar = nearestPlayer.Character
	local dummyJoints = {}
	if targetChar then
		for _, v in ipairs(targetChar:GetDescendants()) do if v:IsA("Motor6D") then dummyJoints[v.Name] = v end end
	end
	
	local totalFrames = 0
	for k, _ in pairs(savedData) do local n = tonumber(k) or 0 if n > totalFrames then totalFrames = n end end
	
	print("Total frames to play: " .. totalFrames)
	
	task.spawn(function()
		repeat
			local elapsedTime = 0
			
			-- Generate timeline marks
			local timelineMarks = {}
			local currentTotalTime = 0
			for i = 1, totalFrames do
				local frameData = savedData[tostring(i)]
				local fTime = frameData and frameData["_FrameTime"] or (1/60)
				timelineMarks[i] = currentTotalTime
				currentTotalTime = currentTotalTime + fTime
			end
			local totalAnimDuration = currentTotalTime
			
			print("Animation duration: " .. totalAnimDuration .. " seconds")
			
			while elapsedTime < totalAnimDuration and not forceStopPlayback do
				local dt = RunService.Heartbeat:Wait()
				elapsedTime = elapsedTime + (dt * animSpeed)
				
				local frameA_Index = 1
				local frameB_Index = 1
				
				for i = 1, totalFrames - 1 do
					if elapsedTime >= timelineMarks[i] and elapsedTime <= timelineMarks[i+1] then
						frameA_Index = i
						frameB_Index = i + 1
						break
					end
				end
				if elapsedTime >= timelineMarks[totalFrames] then
					frameA_Index = totalFrames
					frameB_Index = totalFrames
				end
				
				local dataA = savedData[tostring(frameA_Index)]
				local dataB = savedData[tostring(frameB_Index)]
				
				if dataA and dataB then
					local timeA = timelineMarks[frameA_Index]
					local timeB = timelineMarks[frameB_Index]
					local alpha = 0
					if timeB - timeA > 0 then
						alpha = (elapsedTime - timeA) / (timeB - timeA)
					end
					alpha = math.clamp(alpha, 0, 1)
					
					-- Play player animation on self
					for jName, jointInstance in pairs(myJoints) do
						local tA = dataA["_PlayerJoints"] and dataA["_PlayerJoints"][jName]
						local tB = dataB["_PlayerJoints"] and dataB["_PlayerJoints"][jName]
						if tA and tB then
							pcall(function()
								jointInstance.Transform = tableToCf(tA):Lerp(tableToCf(tB), alpha)
							end)
						elseif tA then
							pcall(function()
								jointInstance.Transform = tableToCf(tA)
							end)
						end
					end
					
					-- Play dummy animation on nearest player
					if targetChar and targetChar.Parent then
						for jName, jointInstance in pairs(dummyJoints) do
							local tA = dataA["_DummyJoints"] and dataA["_DummyJoints"][jName]
							local tB = dataB["_DummyJoints"] and dataB["_DummyJoints"][jName]
							if tA and tB then
								pcall(function()
									jointInstance.Transform = tableToCf(tA):Lerp(tableToCf(tB), alpha)
								end)
							elseif tA then
								pcall(function()
									jointInstance.Transform = tableToCf(tA)
								end)
							end
						end
					end
				end
			end
		until not isLooping or forceStopPlayback
		
		isPlaying = false
		forceStopPlayback = false
		PlayBtn.Text = "▶ Play"
		print("Animation playback finished!")
	end)
end)

StopBtn.MouseButton1Click:Connect(function() if isPlaying then forceStopPlayback = true end end)
CopyBtn.MouseButton1Click:Connect(function()
	if not savedData or next(savedData) == nil then return end
	local dataString = HttpService:JSONEncode(savedData)
	if setclipboard then setclipboard(dataString) CopyBtn.Text = "✅ Copied!" task.wait(2) CopyBtn.Text = "📋 Copy Data" end
end)

ClearBtn.MouseButton1Click:Connect(function()
	savedData = {} if selectedFile and writefile then pcall(function() writefile(selectedFile, "{}") end) end
	ClearBtn.Text = "✅ Cleared!" task.wait(1.5) ClearBtn.Text = "🗑 Clear Save" refreshDropdown()
end)

local confirmWipeState = false
DeleteAllBtn.MouseButton1Click:Connect(function()
	if not confirmWipeState then
		confirmWipeState = true DeleteAllBtn.Text = "⚠ Confirm?" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
		task.delay(4, function() if confirmWipeState then confirmWipeState = false DeleteAllBtn.Text = "💥 Delete All" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40) end end)
	else
		confirmWipeState = false DeleteAllBtn.Text = "Wiping..."
		if listfiles then
			local files = {} pcall(function() files = listfiles("") end)
			for _, file in ipairs(files) do
				if file:match("^DualAnim_") and file:sub(-5) == ".json" then pcall(function() if delfile then delfile(file) elseif odfdelfile then odfdelfile(file) end end) end
			end
		end
		selectedFile = nil savedData = {} DropdownBtn.Text = "▼ Load Animation" task.wait(1)
		DeleteAllBtn.Text = "💥 Delete All" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40) refreshDropdown()
	end
end)

pcall(refreshDropdown)
print("✅ Delta Dual Animation Studio loaded!")
