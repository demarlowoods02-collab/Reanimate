--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

print("Initializing Delta Studio (Movement Sync & FPS Independent Version)...")

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
MainFrame.Size = UDim2.new(0, 240, 0, 390) 
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
TitleLabel.Text = " ☰ Studio Move Recorder"
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
local startRootCF = nil 

local RecordBtn = setupButton("⏺ Start Recording Me", 1, Color3.fromRGB(180, 50, 50))

-- Speed UI
local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(0.9, 0, 0, 35)
SpeedFrame.BackgroundTransparency = 1
SpeedFrame.LayoutOrder = 2
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

local LoopBtn = setupButton("🔁 Loop: OFF", 3, Color3.fromRGB(90, 90, 90))
LoopBtn.MouseButton1Click:Connect(function()
	isLooping = not isLooping
	LoopBtn.Text = isLooping and "🔁 Loop: ON" or "🔁 Loop: OFF"
	LoopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(45, 120, 120) or Color3.fromRGB(90, 90, 90)
end)

-- Dropdown Setup
local DropdownBtn = setupButton("▼ Select Auto-Saved Anim", 4, Color3.fromRGB(55, 55, 55))
local DropdownContainer = Instance.new("ScrollingFrame")
DropdownContainer.Size = UDim2.new(0.9, 0, 0, 70)
DropdownContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
DropdownContainer.BorderSizePixel = 0
DropdownContainer.Visible = false
DropdownContainer.LayoutOrder = 5
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
			if file:match("^Anim_") and file:sub(-5) == ".json" then
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
			local match = file:match("^Anim_(%d+)%.json")
			if match then local num = tonumber(match) if num and num > highestNum then highestNum = num end end
		end
	end
	return "Anim_" .. (highestNum + 1) .. ".json"
end

local ActionRowFrame = Instance.new("Frame")
ActionRowFrame.Size = UDim2.new(0.9, 0, 0, 35)
ActionRowFrame.BackgroundTransparency = 1
ActionRowFrame.LayoutOrder = 6
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

local CopyBtn = setupButton("📋 Copy CFrame Data", 7)
local ClearBtn = setupButton("🗑 Clear Selected Save File", 8, Color3.fromRGB(85, 85, 85))
local DeleteAllBtn = setupButton("💥 Delete All Saved Anims", 9, Color3.fromRGB(140, 35, 35))

-- SMOOTH FIX: Removed aggressive rounding entirely to preserve high precision float spaces
local function cfToTable(cf)
	return {cf:GetComponents()}
end

local function tableToCf(t) return CFrame.new(unpack(t)) end

-- HIGH ACCURACY RECORDER BLOCK
RecordBtn.MouseButton1Click:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then return end

	if not isRecording then
		isRecording = true
		tempFrames = {}
		frameCount = 1
		startRootCF = root.CFrame 
		RecordBtn.Text = "⏹ Tap to Save & Stop"
		RecordBtn.BackgroundColor3 = Color3.fromRGB(230, 140, 40)
		
		local joints = {}
		for _, v in ipairs(char:GetDescendants()) do if v:IsA("Motor6D") then table.insert(joints, v) end end
		
		recordConnection = RunService.Heartbeat:Connect(function(dt)
			if not root or not root.Parent then return end
			local currentFrame = {}
			local hasJoints = false
			
			currentFrame["_RootMovement"] = cfToTable(startRootCF:ToObjectSpace(root.CFrame))
			currentFrame["_FrameTime"] = dt -- Smooth Fix: True raw delta step
			
			for _, joint in ipairs(joints) do
				if joint and joint.Parent then
					currentFrame[joint.Name] = cfToTable(joint.Transform)
					hasJoints = true
				end
			end
			if hasJoints then
				tempFrames[tostring(frameCount)] = currentFrame
				frameCount = frameCount + 1
			end
		end)
	else
		isRecording = false
		if recordConnection then recordConnection:Disconnect() recordConnection = nil end
		
		-- Capture and inject original world starting position directly into data packet
		tempFrames["_WorldStartCF"] = cfToTable(startRootCF)
		
		savedData = tempFrames
		if writefile then
			local calculatedName = getNextAutoName()
			pcall(function() writefile(calculatedName, HttpService:JSONEncode(savedData)) end)
			selectedFile = calculatedName DropdownBtn.Text = "📁 " .. calculatedName
		end
		RecordBtn.Text = "⏺ Start Recording Me"
		RecordBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		refreshDropdown()
	end
end)

-- INTERPOLATED SMOOTH PLAYBACK BLOCK
PlayBtn.MouseButton1Click:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root or isPlaying or not savedData or next(savedData) == nil then return end
	
	isPlaying = true
	forceStopPlayback = false
	PlayBtn.Text = "Playing..."
	
	local joints = {}
	for _, v in ipairs(char:GetDescendants()) do if v:IsA("Motor6D") then joints[v.Name] = v end end
	
	local totalFrames = 0
	for k, _ in pairs(savedData) do local n = tonumber(k) or 0 if n > totalFrames then totalFrames = n end end
	
	task.spawn(function()
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animatorParent = animator and animator.Parent
		if animator then animator.Parent = nil end
		
		repeat
			local elapsedTime = 0
			
			-- If a saved world position exists from the recording, teleport the character there before running the animation.
			local initialPlaybackCF = root.CFrame 
			if savedData["_WorldStartCF"] then
				initialPlaybackCF = tableToCf(savedData["_WorldStartCF"])
				root.CFrame = initialPlaybackCF
			end
			
			-- Generate timelines marks
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
				
				-- Scan indices flanking current runtime mark
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
					
					-- Smoothly blend main node placement tracking
					if dataA["_RootMovement"] and dataB["_RootMovement"] and root then
						local cfA = tableToCf(dataA["_RootMovement"])
						local cfB = tableToCf(dataB["_RootMovement"])
						root.CFrame = initialPlaybackCF * cfA:Lerp(cfB, alpha)
					end
					
					-- Smoothly interpolate joint transforms to completely crush shaking artifacts
					for jName, jointInstance in pairs(joints) do
						local tA = dataA[jName]
						local tB = dataB[jName]
						if tA and tB then
							jointInstance.Transform = tableToCf(tA):Lerp(tableToCf(tB), alpha)
						elseif tA then
							jointInstance.Transform = tableToCf(tA)
						end
					end
				end
			end
		until not isLooping or forceStopPlayback
		
		if animator then animator.Parent = animatorParent end
		isPlaying = false
		forceStopPlayback = false
		PlayBtn.Text = "▶ Play"
	end)
end)

StopBtn.MouseButton1Click:Connect(function() if isPlaying then forceStopPlayback = true end end)
CopyBtn.MouseButton1Click:Connect(function()
	if not savedData or next(savedData) == nil then return end
	local dataString = HttpService:JSONEncode(savedData)
	if setclipboard then setclipboard(dataString) CopyBtn.Text = "Copied!" task.wait(2) CopyBtn.Text = "📋 Copy CFrame Data" end
end)

ClearBtn.MouseButton1Click:Connect(function()
	savedData = {} if selectedFile and writefile then pcall(function() writefile(selectedFile, "{}") end) end
	ClearBtn.Text = "Cleared!" task.wait(1.5) ClearBtn.Text = "🗑 Clear Selected Save File" refreshDropdown()
end)

local confirmWipeState = false
DeleteAllBtn.MouseButton1Click:Connect(function()
	if not confirmWipeState then
		confirmWipeState = true DeleteAllBtn.Text = "⚠ Confirm Delete All?" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(210, 40, 40)
		task.delay(4, function() if confirmWipeState then confirmWipeState = false DeleteAllBtn.Text = "💥 Delete All Saved Anims" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(140, 35, 35) end end)
	else
		confirmWipeState = false DeleteAllBtn.Text = "Wiping..."
		if listfiles then
			local files = {} pcall(function() files = listfiles("") end)
			for _, file in ipairs(files) do
				if file:match("^Anim_") and file:sub(-5) == ".json" then pcall(function() if delfile then delfile(file) elseif odfdelfile then odfdelfile(file) end end) end
			end
		end
		selectedFile = nil savedData = {} DropdownBtn.Text = "▼ Select Auto-Saved Anim" task.wait(1)
		DeleteAllBtn.Text = "💥 Delete All Saved Anims" DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(140, 35, 35) refreshDropdown()
	end
end)

pcall(refreshDropdown)
print("Delta Animation Studio successfully loaded onto screen!")
