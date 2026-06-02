-- FixedKeyboardMoveCamera.client.lua
-- 위치: StarterPlayer > StarterPlayerScripts > LocalScript
-- 마우스로 시점이 돌아가지 않고, 방향키/WASD로 이동 + 시점 전환을 같이 합니다.
-- 이전 버전보다 회전 민감도는 낮추고 이동량은 키웠습니다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

camera.CameraType = Enum.CameraType.Scriptable
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true

local yaw = math.rad(0)
local cameraHeight = 1.7
local forwardOffset = 1.35

-- 수정 포인트
local turnSpeed = math.rad(40) -- 회전 속도를 낮춰 어지러움을 줄임
local moveSpeed = 9            -- 방향키 이동 속도를 낮춤


local blockingGuiNames = {
	ChoiceFrame = true, DialogFrame = true, CashFrame = true, CardFrame = true,
	PhoneFrame = true, BudgetFrame = true, CompleteFrame = true, SuccessFrame = true,
	CartPanel = true, MissionSelectFrame = true, StartFrame = true, InventoryFrame = true,
	TutorialFrame = true,
}

local function uiBlocksMovement()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return false end
	local gameUI = playerGui:FindFirstChild("GameUI_FinalSpec")
	if not gameUI then return false end
	for _, obj in ipairs(gameUI:GetDescendants()) do
		if blockingGuiNames[obj.Name] and obj:IsA("GuiObject") and obj.Visible then
			return true
		end
	end
	return false
end

local keys = {
	forward = false,
	backward = false,
	left = false,
	right = false,
}

local function setKey(input, isDown)
	local key = input.KeyCode
	if key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
		keys.forward = isDown
	elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
		keys.backward = isDown
	elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
		keys.left = isDown
	elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
		keys.right = isDown
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	setKey(input, true)
end)

UserInputService.InputEnded:Connect(function(input)
	setKey(input, false)
end)

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = moveSpeed
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character)
	task.wait(0.2)
	setupCharacter(character)
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end)

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local blocked = uiBlocksMovement()
	if blocked then
		humanoid:Move(Vector3.zero, false)
	else
		if keys.left then
			yaw += turnSpeed * dt
		end

		if keys.right then
			yaw -= turnSpeed * dt
		end
	end

	local rotation = CFrame.Angles(0, yaw, 0)
	local lookDir = rotation.LookVector

	root.CFrame = CFrame.new(root.Position) * rotation

	local moveDirection = Vector3.zero

	if not blocked then
		if keys.forward then
			moveDirection += lookDir
		end

		if keys.backward then
			moveDirection -= lookDir
		end
	end

	-- 좌/우 방향키는 회전만 하고 자동 전진하지 않게 하여 움직임과 방향 전환을 분리합니다.

	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit
	end

	humanoid:Move(moveDirection, false)

	local camPos = root.Position + Vector3.new(0, cameraHeight, 0) + lookDir * forwardOffset
	camera.CFrame = CFrame.lookAt(camPos, camPos + lookDir)
end)
