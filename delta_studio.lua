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
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 240, 0, 430) 
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
TitleLabel.Text = " ☰ Dual Animation Recorder"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = MainFrame

local function setupButton(text, order, color, customParent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.9, 0, 0, 35)
	btn.Text = text
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundColor3 = color or Color3.fromRGB(65, 65, 65)
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order
	btn.Parent = customParent or MainFrame
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
local selectingDummy = false

local RecordBtn = setupButton("⏺ Record (You + Dummy)", 1, Color3.fromRGB(180, 50, 50))

-- Dummy Selection
local DummyFrame = Instance.new("Frame")
DummyFrame.Size = UDim2.new(0.9, 0, 0, 35)
DummyFrame.BackgroundTransparency = 1
DummyFrame.LayoutOrder = 2
DummyFrame.Parent = MainFrame

local DummyLabel = Instance.new("TextLabel")
DummyLabel.Size = UDim2.new(0.6, 0, 1, 0)
DummyLabel.Text = "Dummy: None"
DummyLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
DummyLabel.Font = Enum.Font.SourceSansBold
DummyLabel.TextSize = 12
DummyLabel.TextXAlignment = Enum.TextXAlignment.Left
DummyLabel.Parent = DummyFrame

local SelectDummyBtn = Instance.new("TextButton")
SelectDummyBtn.Size = UDim2.new(0.38, 0, 0.8, 0)
SelectDummyBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
SelectDummyBtn.BorderSizePixel = 0
SelectDummyBtn.Text = "Select"
SelectDummyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectDummyBtn.Font = Enum.Font.SourceSansBold
SelectDummyBtn.TextSize = 12
SelectDummyBtn.Parent = DummyFrame

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
				DummyLabel.Text = "Dummy: " .. char.Name
				SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(45, 150, 45)
				SelectDummyBtn.Text = "✓ Selected"
				selectingDummy = false
				task.wait(1)
				SelectDummyBtn.Text = "Select"
				SelectDummyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
			else
				SelectDummyBtn.Text = "Not a Dummy!"
				task.wait(1)
				SelectDummyBtn.Text = "Click Dummy!"
			end
		end
	end
end)

-- Speed UI
local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(0.9, 0, 0, 35)
SpeedFrame.BackgroundTransparency = 1
SpeedFrame.LayoutOrder = 3
SpeedFrame.Parent = MainFrame

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0.6, 0, 1, 0)
SpeedLabel.Text = "Speed: 1.0x"
SpeedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
SpeedLabel.Font = Enum.Font.SourceSansBold
SpeedLabel.TextSize = 14
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = SpeedFrame

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0.38, 0, 0.8, 0)
SpeedInput.Position = UDim2.new(0.62, 0, 0.1, 0)
SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SpeedInput.BorderSizePixel = 0
SpeedInput.Text = "1.0"
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.Font = Enum.Font.SourceSansBold
SpeedInput.TextSize = 14
SpeedInput.Parent = SpeedFrame

SpeedInput.FocusLost:Connect(function()
	local num = tonumber(SpeedInput.Text)
	if num and num > 0 then animSpeed = num SpeedLabel.Text = "Speed: " .. num .. "x" else SpeedInput.Text = tostring(animSpeed) end
end)

local LoopBtn = setupButton("🔁 Loop: OFF", 4, Color3.fromRGB(90, 90, 90))
LoopBtn.MouseButton1Click:Connect(function()
	isLooping = not isLooping
	LoopBtn.Text = isLooping and "🔁 Loop: ON" or "🔁 Loop: OFF"
	LoopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(45, 120, 120) or Color3.fromRGB(90, 90, 90)
end)

-- Dropdown Setup
local DropdownBtn = setupButton("▼ Select Auto-Saved Anim", 5, Color3.fromRGB(55, 55, 55))
local DropdownContainer = Instance.new("ScrollingFrame")
DropdownContainer.Size = UDim2.new(0.9, 0, 0, 70)
DropdownContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
DropdownContainer.BorderSizePixel = 0
DropdownContainer.Visible = false
DropdownContainer.LayoutOrder = 6
DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownContainer.Parent = MainFrame

local DropdownList = Instance.new("UIListLayout")
DropdownList.SortOrder = Enum.SortOrder.LayoutOrder
DropdownList.Parent = DropdownContainer

local function refreshDropdown()
	for _, child in ipairs(DropdownContainer:GetChildren()) do if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end end
	if listfiles then
		local files = {} pcall(function() files = listfiles("") end)
		local itemOrder, totalHeight = 1, 0
		for _, file in ipairs(files) do
			if file:match("^DualAnim_") and file:sub(-5) == ".json" then
				local itemBtn = Instance.new("TextButton")
				itemBtn.Size = UDim2.new(1, 0, 0, 25)
				itemBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				itemBtn.Text = file
				itemBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
				itemBtn.Font = Enum.Font.SourceSans
				itemBtn.TextSize = 13
				itemBtn.BorderSizePixel = 0
				itemBtn.LayoutOrder = itemOrder
				itemBtn.Parent = DropdownContainer
				
				totalHeight = totalHeight + 25
				itemOrder = itemOrder + 1
				
				local deleteBtn = Instance.new("TextButton")
				deleteBtn.Size = UDim2.new(1, 0, 0, 22)
				deleteBtn.BackgroundColor3 = Color3.fromRGB(150, 35, 35)
				deleteBtn.Text = "⚠ Tap to Confirm Delete"
				deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				deleteBtn.Font = Enum.Font.SourceSansBold
				deleteBtn.TextSize = 12
				deleteBtn.BorderSizePixel = 0
				deleteBtn.LayoutOrder = itemOrder
				deleteBtn.Visible = false
				deleteBtn.Parent = DropdownContainer
				itemOrder = itemOrder + 1
				
				local holding = false
				itemBtn.MouseButton1Down:Connect(function()
					holding = true task.wait(1.5)
					if holding then
						deleteBtn.Visible = not deleteBtn.Visible
						DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownContainer.CanvasSize.Y.Offset + (deleteBtn.Visible and 22 or -22))
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
					if selectedFile == file then selectedFile = nil savedData = {} DropdownBtn.Text = "▼ Select Auto-Saved Anim" end
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
ActionRowFrame.Size = UDim2.new(0.9, 0, 0, 35)
ActionRowFrame.BackgroundTransparency = 1
ActionRowFrame.LayoutOrder = 7
ActionRowFrame.Parent = MainFrame

local ActionRowLayout = Instance.new("UIListLayout")
ActionRowLayout.FillDirection = Enum.FillDirection.Horizontal
ActionRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ActionRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
ActionRowLayout.Padding = UDim.new(0, 6)
ActionRowLayout.Parent = ActionRowFrame

local PlayBtn = setupButton("▶ Play", 1, Color3.fromRGB(50, 120, 50), ActionRowFrame)
PlayBtn.Size = UDim2.new(0.48, 0, 1, 0)

local StopBtn = setupButton("⏹ Stop", 2, Color3.fromRGB(150, 85, 35), ActionRowFrame)
StopBtn.Size = UDim2.new(0.48, 0, 1, 0)

local CopyBtn = setupButton("📋 Copy Data", 8)
local ClearBtn = setupButton("🗑 Clear Save", 9, Color3.fromRGB(85, 85, 85))
local DeleteAllBtn = setupButton("💥 Delete All", 10, Color3.fromRGB(140, 35, 35))

local function cfToTable(cf)
	return {cf:GetComponents()}
end

local function tableToCf(t) return CFrame.new(unpack(t)) end

-- DUAL ANIMATION RECORDER
RecordBtn.MouseButton1Click:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then return end
	if not targetDummy or not targetDummy:FindFirstChild("HumanoidRootPart") then return end

	if not isRecording then
		isRecording = true
		tempFrames = {}
		frameCount = 1
		RecordBtn.Text = "⏹ Stop Recording"
		RecordBtn.BackgroundColor3 = Color3.fromRGB(230, 140, 40)
		
		local myJoints = {}
		for _, v in ipairs(char:GetDescendants()) do if v:IsA("Motor6D") then table.insert(myJoints, v) end end
		
		local dummyJoints = {}
		for _, v in ipairs(targetDummy:GetDescendants()) do if v:IsA("Motor6D") then table.insert(dummyJoints, v) end end
		
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
		end
		RecordBtn.Text = "⏺ Record (You + Dummy)"
		RecordBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		refreshDropdown()
	end
end)

-- DUAL ANIMATION PLAYBACK
PlayBtn.MouseButton1Click:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root or isPlaying or not savedData or next(savedData) == nil then return end
	
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
	
	isPlaying = true
	forceStopPlayback = false
	PlayBtn.Text = "Playing..."
	
	local myJoints = {}
	for _, v in ipairs(char:GetDescendants()) do if v:IsA("Motor6D") then myJoints[v.Name] = v end end
	
	local targetChar = nearestPlayer and nearestPlayer.Character
	local dummyJoints = {}
	if targetChar then
		for _, v in ipairs(targetChar:GetDescendants()) do if v:IsA("Motor6D") then dummyJoints[v.Name] = v end end
	end
	
	local totalFrames = 0
	for k, _ in pairs(savedData) do local n = tonumber(k) or 0 if n > totalFrames then totalFrames = n end end
	
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
							jointInstance.Transform = tableToCf(tA):Lerp(tableToCf(tB), alpha)
						elseif tA then
							jointInstance.Transform = tableToCf(tA)
						end
					end
					
					-- Play dummy animation on nearest player
					if targetChar then
						for jName, jointInstance in pairs(dummyJoints) do
							local tA = dataA["_DummyJoints"] and dataA["_DummyJoints"][jName]
							local tB = dataB["_DummyJoints"] and dataB["_DummyJoints"][jName]
							if tA and tB then
								jointInstance.Transform = tableToCf(tA):Lerp(tableToCf(tB), alpha)
							elseif tA then
								jointInstance.Transform = tableToCf(tA)
							end
						end
					end
				end
			end
		until not isLooping or forceStopPlayback
		
		isPlaying = false
		forceStopPlayback = false
		PlayBtn.Text = "▶ Play"
	end)
end)

StopBtn.MouseButton1Click:Connect(function() if isPlaying then forceStopPlayback = true end end)
CopyBtn.MouseButton1Click:Connect(function()
	if not savedData or next(savedData) == nil then return end
	local dataString = HttpService:JSONEncode(savedData)
	if setclipboard then setclipboard(dataString) CopyBtn.Text = "Copied!" task.wait(2) CopyBtn.Text = "📋 Copy Data" end
end)

ClearBtn.MouseButton1Click:Connect(function()
	savedData = {} if selectedFile and writefile then pcall(function() writefile(selectedFile, "{}") end) end
	ClearBtn.Text = "Cleared!" task.wait(1.5) ClearBtn.Text = "🗑 Clear Save" refreshDropdown()
end)

local confirmWipeState = false
DeleteAllBtn.MouseButton1Click:Connect(function()
	if not confirmWipeState then
		confirmWipeState = true DeleteAllBtn.Text = "⚠ Confirm?" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(210, 40, 40)
		task.delay(4, function() if confirmWipeState then confirmWipeState = false DeleteAllBtn.Text = "💥 Delete All" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(140, 35, 35) end end)
	else
		confirmWipeState = false DeleteAllBtn.Text = "Wiping..."
		if listfiles then
			local files = {} pcall(function() files = listfiles("") end)
			for _, file in ipairs(files) do
				if file:match("^DualAnim_") and file:sub(-5) == ".json" then pcall(function() if delfile then delfile(file) elseif odfdelfile then odfdelfile(file) end end) end
			end
		end
		selectedFile = nil savedData = {} DropdownBtn.Text = "▼ Select Auto-Saved Anim" task.wait(1)
		DeleteAllBtn.Text = "💥 Delete All" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(140, 35, 35) refreshDropdown()
	end
end)

pcall(refreshDropdown)
print("Delta Dual Animation Studio loaded!")
