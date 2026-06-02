
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local talkEvent = ReplicatedStorage:WaitForChild("StaffTalk")
local payEvent = ReplicatedStorage:WaitForChild("PayRequest")
local pickupEvent = ReplicatedStorage:WaitForChild("PickupItem")
local missionEvent = ReplicatedStorage:WaitForChild("MissionUpdate")
local billEvent = ReplicatedStorage:WaitForChild("BillEvent")
local missionProgressEvent = ReplicatedStorage:WaitForChild("MissionProgress")
local cartUpdateEvent = ReplicatedStorage:WaitForChild("CartUpdate")
local choiceEvent = ReplicatedStorage:WaitForChild("Mission2Choice")

local PRODUCT_NAMES = {
	cheetos="치토스", pringles="프링글스", pocky="포키", potato_chips="감자칩",
	neoguri="너구리라면", buldak="불닭볶음탕면",
	banana_milk="바나나우유", choco_milk="초코우유", coffee="커피", cola="코카콜라",
}
local PROMOS = {
	banana_milk = "ONE_PLUS_ONE",
	choco_milk = "TWO_PLUS_ONE",
}
local CATEGORY_LABELS = {drink="음료", snack="간식", ramen="라면"}

local FONT_MAIN = Enum.Font.GothamBold
local BIG_TEXT = 34
local TITLE_TEXT = 24
local NORMAL_TEXT = 17
local SMALL_TEXT = 14
local sfxOn = true

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI_FinalSpec"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local clickSound = Instance.new("Sound")
clickSound.Name = "CuteClick"
clickSound.SoundId = "rbxassetid://12221967"
clickSound.Volume = 0.35
clickSound.Parent = gui

local function playClick()
	if sfxOn then pcall(function() clickSound:Play() end) end
end

local function disableJump(char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end
disableJump(character)
player.CharacterAdded:Connect(function(char) character = char; disableJump(char) end)

local function fmt(n)
	return tostring(math.floor(tonumber(n) or 0)).."원"
end
local function parseMoneyText(txt)
	local cleaned = tostring(txt or ""):gsub("원", ""):gsub(",", ""):gsub("%s+", "")
	return tonumber(cleaned)
end
local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end
local function makeStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255,255,255)
	s.Thickness = thickness or 1
	s.Transparency = 0.25
	s.Parent = parent
	return s
end
local function makeLabel(parent, text, size, pos, textSize, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or Color3.fromRGB(245,245,245)
	label.Font = FONT_MAIN
	label.TextSize = textSize or NORMAL_TEXT
	label.TextScaled = false
	label.TextWrapped = true
	label.Parent = parent
	return label
end
local function makeButton(parent, text, size, pos, color, textSize)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color or Color3.fromRGB(70,100,160)
	btn.Text = text or ""
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = FONT_MAIN
	btn.TextSize = textSize or NORMAL_TEXT
	btn.TextWrapped = true
	btn.AutoButtonColor = true
	btn.Parent = parent
	makeCorner(btn, 10)
	btn.MouseButton1Click:Connect(playClick)
	return btn
end
local function drawTrashIcon(button, iconColor)
	-- 이모지/특수문자가 ??로 깨지는 문제를 피하려고 GUI Frame으로 휴지통 아이콘을 직접 그린다.
	button.Text = ""
	iconColor = iconColor or Color3.fromRGB(255,255,255)
	local holder = Instance.new("Frame")
	holder.Name = "TrashIcon"
	holder.Size = UDim2.new(0, 28, 0, 28)
	holder.Position = UDim2.new(0.5, -14, 0.5, -14)
	holder.BackgroundTransparency = 1
	holder.Parent = button
	holder.ZIndex = button.ZIndex + 1

	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.Size = UDim2.new(0, 22, 0, 4)
	lid.Position = UDim2.new(0.5, -11, 0, 6)
	lid.BackgroundColor3 = iconColor
	lid.BorderSizePixel = 0
	lid.Parent = holder
	lid.ZIndex = holder.ZIndex + 1
	makeCorner(lid, 2)

	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Size = UDim2.new(0, 10, 0, 3)
	handle.Position = UDim2.new(0.5, -5, 0, 2)
	handle.BackgroundColor3 = iconColor
	handle.BorderSizePixel = 0
	handle.Parent = holder
	handle.ZIndex = holder.ZIndex + 1
	makeCorner(handle, 2)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(0, 18, 0, 16)
	body.Position = UDim2.new(0.5, -9, 0, 11)
	body.BackgroundColor3 = iconColor
	body.BorderSizePixel = 0
	body.Parent = holder
	body.ZIndex = holder.ZIndex + 1
	makeCorner(body, 3)

	for i = 1, 2 do
		local line = Instance.new("Frame")
		line.Name = "Line" .. i
		line.Size = UDim2.new(0, 2, 0, 11)
		line.Position = UDim2.new(0, 6 + (i-1)*6, 0, 3)
		line.BackgroundColor3 = button.BackgroundColor3
		line.BackgroundTransparency = 0.15
		line.BorderSizePixel = 0
		line.Parent = body
		line.ZIndex = body.ZIndex + 1
		makeCorner(line, 1)
	end
end
local function isOverlap(a, b)
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and ap.X + as.X > bp.X and ap.Y < bp.Y + bs.Y and ap.Y + as.Y > bp.Y
end

-- 모든 큰 창은 이 함수를 거쳐 하나씩만 표시한다.
local allModals = {}
local hudFrames = {}
local currentMissionBaseLine = ""
local function registerModal(frame)
	table.insert(allModals, frame)
	return frame
end
local function closeAllModals(except)
	for _, frame in ipairs(allModals) do
		if frame ~= except then frame.Visible = false end
	end
end
local function captureHudState()
	local state = {}
	for _, frame in ipairs(hudFrames) do
		state[frame] = frame.Visible
	end
	return state
end
local function hideHud()
	for _, frame in ipairs(hudFrames) do
		frame.Visible = false
	end
end
local function restoreHudState(state)
	hideHud()
	for frame, wasVisible in pairs(state or {}) do
		if frame and frame.Parent then frame.Visible = wasVisible end
	end
end
local function showModal(frame)
	closeAllModals(frame)
	hideHud()
	frame.Visible = true
end

-- 오프닝: 투명 배경 + 글씨 버튼만
local startFrame = Instance.new("Frame")
startFrame.Name = "StartFrame"
startFrame.Size = UDim2.new(1,0,1,0)
startFrame.BackgroundTransparency = 1
startFrame.Parent = gui
registerModal(startFrame)

local startBtn = makeButton(startFrame, "게임 시작", UDim2.new(0,330,0,88), UDim2.new(0.5,-165,0.45,-44), Color3.fromRGB(255,190,65), BIG_TEXT)
startBtn.BackgroundTransparency = 0.08
makeStroke(startBtn, Color3.fromRGB(255,255,255), 2)

local missionSelectFrame = Instance.new("Frame")
missionSelectFrame.Name = "MissionSelectFrame"
missionSelectFrame.Size = UDim2.new(0,520,0,350)
missionSelectFrame.Position = UDim2.new(0.5,-260,0.5,-175)
missionSelectFrame.BackgroundTransparency = 1
missionSelectFrame.Visible = false
missionSelectFrame.Parent = gui
registerModal(missionSelectFrame)
local missionSelectTitle = makeLabel(missionSelectFrame, "미션 선택", UDim2.new(1,0,0,55), UDim2.new(0,0,0,0), BIG_TEXT, Color3.fromRGB(255,230,100))
local missionButtons = {
	{"현금 미션", "select_cash", Color3.fromRGB(65,155,100)},
	{"카드 미션", "select_card", Color3.fromRGB(80,95,185)},
	{"쿠폰 미션", "select_coupon", Color3.fromRGB(210,130,60)},
	{"종합 미션", "select_combo", Color3.fromRGB(205,90,135)},
}
for i, data in ipairs(missionButtons) do
	local btn = makeButton(missionSelectFrame, data[1], UDim2.new(0.82,0,0,56), UDim2.new(0.09,0,0,65 + (i-1)*66), data[3], TITLE_TEXT)
	btn.MouseButton1Click:Connect(function()
		missionSelectFrame.Visible = false
		missionProgressEvent:FireServer(data[2])
	end)
end
-- =====================
-- 조작법 안내 창 - 작고 읽기 쉬운 버전
-- 흐름: 게임 시작 버튼 클릭 -> 조작법 안내 -> 미션 선택
-- =====================
local tutorialFrame = Instance.new("Frame")
tutorialFrame.Name = "TutorialFrame"
tutorialFrame.Size = UDim2.new(0, 640, 0, 450)
tutorialFrame.Position = UDim2.new(0.5, -320, 0.5, -225)
tutorialFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 45)
tutorialFrame.BackgroundTransparency = 0.03
tutorialFrame.Visible = false
tutorialFrame.Parent = gui
registerModal(tutorialFrame)
makeCorner(tutorialFrame, 18)
makeStroke(tutorialFrame, Color3.fromRGB(255, 220, 90), 2)

local tutorialTitle = makeLabel(
	tutorialFrame,
	"편의점 이용 안내",
	UDim2.new(1, -40, 0, 44),
	UDim2.new(0, 20, 0, 16),
	BIG_TEXT,
	Color3.fromRGB(255, 230, 100)
)
tutorialTitle.TextXAlignment = Enum.TextXAlignment.Center

local tutorialIntro = makeLabel(
	tutorialFrame,
	"상품을 찾고  →  장바구니에 담고  →  계산하는 연습을 해요.",
	UDim2.new(1, -60, 0, 34),
	UDim2.new(0, 30, 0, 64),
	NORMAL_TEXT + 1,
	Color3.fromRGB(245, 245, 245)
)
tutorialIntro.TextXAlignment = Enum.TextXAlignment.Center
tutorialIntro.TextYAlignment = Enum.TextYAlignment.Center

local function makeGuideCard(parent, numberText, titleText, bodyText, xPos, yPos)
	local card = Instance.new("Frame")
	card.Name = "GuideCard_" .. tostring(numberText)
	card.Size = UDim2.new(0, 280, 0, 112)
	card.Position = UDim2.new(0, xPos, 0, yPos)
	card.BackgroundColor3 = Color3.fromRGB(28, 36, 66)
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Parent = parent
	makeCorner(card, 14)
	makeStroke(card, Color3.fromRGB(90, 130, 210), 1)

	local numberCircle = Instance.new("Frame")
	numberCircle.Name = "NumberCircle"
	numberCircle.Size = UDim2.new(0, 38, 0, 38)
	numberCircle.Position = UDim2.new(0, 14, 0, 14)
	numberCircle.BackgroundColor3 = Color3.fromRGB(255, 190, 65)
	numberCircle.Parent = card
	makeCorner(numberCircle, 19)

	local numberLabel = makeLabel(
		numberCircle,
		tostring(numberText),
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		TITLE_TEXT,
		Color3.fromRGB(35, 35, 35)
	)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Center
	numberLabel.TextYAlignment = Enum.TextYAlignment.Center

	local titleLabel = makeLabel(
		card,
		titleText,
		UDim2.new(1, -70, 0, 30),
		UDim2.new(0, 62, 0, 13),
		TITLE_TEXT,
		Color3.fromRGB(255, 230, 120)
	)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center

	local bodyLabel = makeLabel(
		card,
		bodyText,
		UDim2.new(1, -28, 0, 56),
		UDim2.new(0, 18, 0, 52),
		NORMAL_TEXT,
		Color3.fromRGB(235, 235, 235)
	)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top

	return card
end

makeGuideCard(
	tutorialFrame,
	1,
	"화면 구성",
	"위쪽 : 현재 미션\n오른쪽 : 장바구니\n담은 상품과 금액 확인",
	35,
	112
)

makeGuideCard(
	tutorialFrame,
	2,
	"이동 방법",
	"W / ↑ : 앞으로\nS / ↓ : 뒤로\nA,D / ←,→ : 방향 전환",
	325,
	112
)

makeGuideCard(
	tutorialFrame,
	3,
	"상품과 계산",
	"상품 클릭 : 장바구니 담기\n직원 NPC 클릭 : 계산\n계산대 클릭 : 계산",
	35,
	238
)

makeGuideCard(
	tutorialFrame,
	4,
	"돌발 미션",
	"중간에 미션이 뜰 수 있어요.\n화면 안내를 읽고\n알맞은 선택을 해보세요.",
	325,
	238
)

local tutorialNextBtn = makeButton(
	tutorialFrame,
	"확인했어요! 미션 선택하기",
	UDim2.new(0, 330, 0, 46),
	UDim2.new(0.5, -165, 1, -62),
	Color3.fromRGB(255, 190, 65),
	TITLE_TEXT
)
makeStroke(tutorialNextBtn, Color3.fromRGB(255, 255, 255), 2)
tutorialNextBtn.TextColor3 = Color3.fromRGB(20, 20, 20)

tutorialNextBtn.MouseButton1Click:Connect(function()
	showModal(missionSelectFrame)
end)

startBtn.MouseButton1Click:Connect(function()
	showModal(tutorialFrame)
end)

-- 상단 미션 한 줄 표시
local missionBanner = Instance.new("Frame")
missionBanner.Name = "MissionBanner"
missionBanner.Size = UDim2.new(0,720,0,76)
missionBanner.Position = UDim2.new(0.5,-360,0,16)
missionBanner.BackgroundColor3 = Color3.fromRGB(20,25,48)
missionBanner.BackgroundTransparency = 0.06
missionBanner.Visible = false
missionBanner.Parent = gui
makeCorner(missionBanner, 16)
makeStroke(missionBanner, Color3.fromRGB(255,220,80), 1)
local missionLine = makeLabel(missionBanner, "", UDim2.new(1,-150,1,-16), UDim2.new(0,12,0,8), TITLE_TEXT, Color3.fromRGB(255,230,90))
missionLine.TextXAlignment = Enum.TextXAlignment.Center

-- 목표/진행 패널
local targetPanel = Instance.new("Frame")
targetPanel.Name = "TargetPanel"
targetPanel.Size = UDim2.new(0,275,0,190)
targetPanel.Position = UDim2.new(0,15,0.5,-95)
targetPanel.BackgroundColor3 = Color3.fromRGB(22,28,50)
targetPanel.BackgroundTransparency = 0.04
targetPanel.Visible = false
targetPanel.Parent = gui
makeCorner(targetPanel, 14)
makeStroke(targetPanel, Color3.fromRGB(255,220,80), 1)
makeLabel(targetPanel, "오늘의 목표", UDim2.new(1,-14,0,32), UDim2.new(0,7,0,7), NORMAL_TEXT, Color3.fromRGB(255,220,80))
local targetList = makeLabel(targetPanel, "", UDim2.new(1,-14,1,-48), UDim2.new(0,7,0,44), NORMAL_TEXT)
targetList.Font = Enum.Font.Gotham

-- 장바구니
local localCart = {}
local cartPanel = Instance.new("Frame")
cartPanel.Name = "CartPanel"
cartPanel.Size = UDim2.new(0,315,0,330)
cartPanel.Position = UDim2.new(1,-330,0.5,-165)
cartPanel.BackgroundColor3 = Color3.fromRGB(18,18,35)
cartPanel.BackgroundTransparency = 0.04
cartPanel.Visible = false
cartPanel.Parent = gui
makeCorner(cartPanel, 14)
makeStroke(cartPanel, Color3.fromRGB(255,255,255), 1)
makeLabel(cartPanel, "장바구니", UDim2.new(0.68,0,0,36), UDim2.new(0,12,0,8), TITLE_TEXT, Color3.fromRGB(255,220,80))
local clearCartBtn = makeButton(cartPanel, "", UDim2.new(0,64,0,36), UDim2.new(1,-76,0,8), Color3.fromRGB(150,60,60), 22)
drawTrashIcon(clearCartBtn, Color3.fromRGB(255,255,255))
clearCartBtn.MouseButton1Click:Connect(function()
	localCart = {}
	cartUpdateEvent:FireServer("clear")
end)
local cartRows = Instance.new("Frame")
cartRows.Size = UDim2.new(1,-20,1,-62)
cartRows.Position = UDim2.new(0,10,0,54)
cartRows.BackgroundTransparency = 1
cartRows.Parent = cartPanel
local cartLayout = Instance.new("UIListLayout")
cartLayout.SortOrder = Enum.SortOrder.LayoutOrder
cartLayout.Padding = UDim.new(0,6)
cartLayout.Parent = cartRows
local function clearRows(frame)
	for _, ch in ipairs(frame:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end
local function promoPaidQty(cartID, count)
	local promo = PROMOS[cartID]
	count = tonumber(count) or 0
	if promo == "ONE_PLUS_ONE" then
		local paid = math.ceil(count / 2)
		return paid, count - paid
	elseif promo == "TWO_PLUS_ONE" then
		local free = math.floor(count / 3)
		return count - free, free
	end
	return count, 0
end
local function cartLineText(id, info)
	local count = info.count or 0
	local unit = info.price or 0
	local base = unit * count
	local paid, free = promoPaidQty(id, count)
	local discounted = unit * paid
	if free > 0 and discounted < base then
		return string.format("%s x%d  %s → %s", info.name or id, count, fmt(base), fmt(discounted))
	end
	return string.format("%s x%d  %s", info.name or id, count, fmt(base))
end
local function cartTotal()
	local total = 0
	for id, info in pairs(localCart) do
		local paid = promoPaidQty(id, info.count or 0)
		total += (info.price or 0) * paid
	end
	return total
end
local function refreshCart()
	clearRows(cartRows)
	local order = 1
	local any = false
	for id, info in pairs(localCart) do
		if info.count and info.count > 0 then
			any = true
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1,0,0,42)
			row.BackgroundColor3 = Color3.fromRGB(34,38,62)
			row.LayoutOrder = order
			row.Parent = cartRows
			makeCorner(row, 8)
			local txt = makeLabel(row, cartLineText(id, info), UDim2.new(1,-58,1,0), UDim2.new(0,8,0,0), SMALL_TEXT)
			txt.TextXAlignment = Enum.TextXAlignment.Left
			local cancelBtn = makeButton(row, "", UDim2.new(0,42,0,30), UDim2.new(1,-48,0.5,-15), Color3.fromRGB(110,70,80), SMALL_TEXT)
			drawTrashIcon(cancelBtn, Color3.fromRGB(255,255,255))
			cancelBtn.MouseButton1Click:Connect(function()
				cartUpdateEvent:FireServer("removeOneBase", id)
			end)
			order += 1
		end
	end
	if not any then
		local empty = makeLabel(cartRows, "담긴 상품이 없어요.\n상품을 담으면 가격이 여기에 표시돼요.", UDim2.new(1,0,0,72), UDim2.new(0,0,0,0), NORMAL_TEXT, Color3.fromRGB(220,220,220))
		empty.TextXAlignment = Enum.TextXAlignment.Center
	else
		local totalRow = makeLabel(cartRows, "합계: "..fmt(cartTotal()), UDim2.new(1,0,0,30), UDim2.new(0,0,0,0), NORMAL_TEXT, Color3.fromRGB(255,230,90))
		totalRow.LayoutOrder = 999
	end
end

-- 미션/장바구니/목표 패널은 동시에 보이지 않도록 HUD 그룹으로 관리
hudFrames = {missionBanner, targetPanel, cartPanel}

local openCartBtn = makeButton(missionBanner, "장바구니", UDim2.new(0,112,0,42), UDim2.new(1,-124,0.5,-21), Color3.fromRGB(80,120,165), SMALL_TEXT)
openCartBtn.MouseButton1Click:Connect(function()
	showModal(cartPanel)
end)

local closeCartBtn = makeButton(cartPanel, "미션으로 돌아가기", UDim2.new(0.86,0,0,34), UDim2.new(0.07,0,1,-42), Color3.fromRGB(70,100,145), SMALL_TEXT)
closeCartBtn.MouseButton1Click:Connect(function()
	closeAllModals()
	hideHud()
	missionBanner.Visible = true
end)

-- 공통 선택지 모달
local choiceFrame = Instance.new("Frame")
choiceFrame.Name = "ChoiceFrame"
choiceFrame.Size = UDim2.new(0,600,0,340)
choiceFrame.Position = UDim2.new(0.5,-300,0.5,-170)
choiceFrame.BackgroundColor3 = Color3.fromRGB(35,30,58)
choiceFrame.Visible = false
choiceFrame.Parent = gui
registerModal(choiceFrame)
makeCorner(choiceFrame, 16)
makeStroke(choiceFrame, Color3.fromRGB(255,255,255), 1)
local choiceText = makeLabel(choiceFrame, "", UDim2.new(1,-28,0,132), UDim2.new(0,14,0,14), NORMAL_TEXT)
local choiceButtonsFrame = Instance.new("Frame")
choiceButtonsFrame.Size = UDim2.new(1,-28,1,-160)
choiceButtonsFrame.Position = UDim2.new(0,14,0,150)
choiceButtonsFrame.BackgroundTransparency = 1
choiceButtonsFrame.Parent = choiceFrame
local choiceLayout = Instance.new("UIListLayout")
choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
choiceLayout.Padding = UDim.new(0,8)
choiceLayout.Parent = choiceButtonsFrame
local function clearChoiceButtons()
	for _, child in ipairs(choiceButtonsFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
end
local function showChoices(message, choices)
	clearChoiceButtons()
	choiceText.Text = tostring(message or "")
	showModal(choiceFrame)
	for i, choice in ipairs(choices or {}) do
		local btn = makeButton(choiceButtonsFrame, choice.text, UDim2.new(1,0,0,44), UDim2.new(0,0,0,0), Color3.fromRGB(90,75,150), NORMAL_TEXT)
		btn.LayoutOrder = i
		btn.MouseButton1Click:Connect(function()
			choiceFrame.Visible = false
			choiceEvent:FireServer(choice.id)
		end)
	end
end

-- 알림/힌트/오답 모달: 확인을 누른 뒤에만 이전 창 복귀
local alertFrame = Instance.new("Frame")
alertFrame.Size = UDim2.new(0,560,0,250)
alertFrame.Position = UDim2.new(0.5,-280,0.5,-125)
alertFrame.BackgroundColor3 = Color3.fromRGB(45,35,50)
alertFrame.Visible = false
alertFrame.Parent = gui
registerModal(alertFrame)
makeCorner(alertFrame, 16)
makeStroke(alertFrame, Color3.fromRGB(255,255,255), 1)
local alertText = makeLabel(alertFrame, "", UDim2.new(1,-28,0,150), UDim2.new(0,14,0,20), NORMAL_TEXT)
local alertOk = makeButton(alertFrame, "확인", UDim2.new(0.8,0,0,46), UDim2.new(0.1,0,1,-64), Color3.fromRGB(55,135,90), NORMAL_TEXT)
local alertCallback = nil
local alertHudState = nil
local function showAlert(text, callback)
	alertText.Text = tostring(text or "")
	alertCallback = callback
	alertHudState = captureHudState()
	showModal(alertFrame)
end
alertOk.MouseButton1Click:Connect(function()
	alertFrame.Visible = false
	local cb = alertCallback
	alertCallback = nil
	if cb then
		cb()
	else
		restoreHudState(alertHudState)
	end
	alertHudState = nil
end)

-- 직원 대화 모달
local dialog = Instance.new("Frame")
dialog.Name = "DialogFrame"
dialog.Size = UDim2.new(0,560,0,230)
dialog.Position = UDim2.new(0.5,-280,0.5,-115)
dialog.BackgroundColor3 = Color3.fromRGB(20,20,40)
dialog.Visible = false
dialog.Parent = gui
registerModal(dialog)
makeCorner(dialog, 16)
local dialogText = makeLabel(dialog, "", UDim2.new(1,-24,0,145), UDim2.new(0,12,0,18), NORMAL_TEXT)
local closeDialogBtn = makeButton(dialog, "확인", UDim2.new(0.82,0,0,46), UDim2.new(0.09,0,1,-60), Color3.fromRGB(80,100,150), NORMAL_TEXT)
local dialogHudState = nil
closeDialogBtn.MouseButton1Click:Connect(function()
	dialog.Visible = false
	restoreHudState(dialogHudState)
	dialogHudState = nil
end)

-- 현금 UI
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashFrame"
cashFrame.Size = UDim2.new(0,690,0,520)
cashFrame.Position = UDim2.new(0.5,-345,0.5,-260)
cashFrame.BackgroundColor3 = Color3.fromRGB(16,30,46)
cashFrame.Visible = false
cashFrame.Parent = gui
registerModal(cashFrame)
makeCorner(cashFrame, 16)
makeStroke(cashFrame, Color3.fromRGB(255,255,255), 1)
local cashTitle = makeLabel(cashFrame, "현금 결제", UDim2.new(1,-24,0,40), UDim2.new(0,12,0,12), TITLE_TEXT, Color3.fromRGB(255,220,80))
local cashInfo = makeLabel(cashFrame, "", UDim2.new(1,-30,0,118), UDim2.new(0,15,0,58), NORMAL_TEXT)
local selectedLabel = makeLabel(cashFrame, "선택한 지폐: 없음", UDim2.new(1,-30,0,56), UDim2.new(0,15,0,184), NORMAL_TEXT)
selectedLabel.Font = Enum.Font.Gotham
local selectedBills = {}
local cashDue, cashPaid, cashWrongCount = 0, 0, 0
local function cartPriceSummary(maxLines)
	local lines = {}
	local hidden = 0
	maxLines = maxLines or 3
	for id, info in pairs(localCart) do
		if info.count and info.count > 0 then
			if #lines < maxLines then
				table.insert(lines, cartLineText(id, info))
			else
				hidden += 1
			end
		end
	end
	if hidden > 0 then table.insert(lines, "외 "..hidden.."개 상품") end
	if #lines == 0 then return "담긴 상품 금액: "..fmt(cashDue) end
	return "담은 상품 가격:\n"..table.concat(lines, "\n")
end
local function cashPaymentSummary(extraLine)
	local text = cartPriceSummary(3).."\n결제 금액: "..fmt(cashDue)
	if extraLine and extraLine ~= "" then text ..= "\n"..extraLine end
	return text
end
local cashInput = Instance.new("TextBox")
cashInput.Size = UDim2.new(0.58,0,0,46)
cashInput.Position = UDim2.new(0.06,0,0,398)
cashInput.BackgroundColor3 = Color3.fromRGB(245,245,245)
cashInput.PlaceholderText = "거스름돈 입력 예: 1500 또는 1,500원"
cashInput.Text = ""
cashInput.TextColor3 = Color3.fromRGB(20,20,20)
cashInput.Font = FONT_MAIN
cashInput.TextSize = NORMAL_TEXT
cashInput.Visible = false
cashInput.Parent = cashFrame
makeCorner(cashInput, 8)
local cashSubmit = makeButton(cashFrame, "제출", UDim2.new(0.28,0,0,46), UDim2.new(0.66,0,0,398), Color3.fromRGB(40,130,80), NORMAL_TEXT)
cashSubmit.Visible = false
local payBtn = makeButton(cashFrame, "점원에게 돈 내기", UDim2.new(0.40,0,0,42), UDim2.new(0.06,0,1,-56), Color3.fromRGB(45,120,80), NORMAL_TEXT)
local resetBillsBtn = makeButton(cashFrame, "전체 다시 선택", UDim2.new(0.25,0,0,42), UDim2.new(0.49,0,1,-56), Color3.fromRGB(130,70,45), NORMAL_TEXT)
local closeCashBtn = makeButton(cashFrame, "닫기", UDim2.new(0.18,0,0,42), UDim2.new(0.76,0,1,-56), Color3.fromRGB(100,30,30), NORMAL_TEXT)

local function billSum()
	local s = 0
	for _, n in ipairs(selectedBills) do s += n end
	return s
end
local function updateSelectedBills()
	local parts = {}
	for i, n in ipairs(selectedBills) do table.insert(parts, fmt(n)) end
	selectedLabel.Text = "선택한 지폐: "..(#parts == 0 and "없음" or table.concat(parts, ", ")).."\n현재 합계: "..fmt(billSum()).." / 최대 5장"
end
local function resetCashInputOnly()
	cashInput.Visible = false
	cashSubmit.Visible = false
	cashInput.Text = ""
	cashWrongCount = 0
end
local function resetBills()
	selectedBills = {}
	resetCashInputOnly()
	updateSelectedBills()
end

local function createBillButton(amount, x, color, portrait)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,185,0,84)
	btn.Position = UDim2.new(0,x,0,268)
	btn.BackgroundColor3 = color
	btn.Text = ""
	btn.Parent = cashFrame
	makeCorner(btn, 8)
	makeStroke(btn, Color3.fromRGB(240,240,240), 2)
	local p = Instance.new("Frame")
	p.Size = UDim2.new(0,46,0,54); p.Position = UDim2.new(0,12,0.5,-27); p.BackgroundColor3 = portrait; p.Parent = btn; makeCorner(p, 24)
	makeLabel(btn, fmt(amount), UDim2.new(1,-70,0,38), UDim2.new(0,66,0,10), 22, Color3.fromRGB(20,20,20)).TextXAlignment = Enum.TextXAlignment.Left
	makeLabel(btn, "학습용 지폐", UDim2.new(1,-70,0,24), UDim2.new(0,66,0,48), SMALL_TEXT, Color3.fromRGB(40,40,40)).TextXAlignment = Enum.TextXAlignment.Left
	btn.MouseButton1Click:Connect(function()
		playClick()
		if #selectedBills >= 5 then
			showAlert("지폐는 한 번에 최대 5장까지만 낼 수 있어요.", function() showModal(cashFrame) end)
			return
		end
		table.insert(selectedBills, amount)
		resetCashInputOnly()
		updateSelectedBills()
	end)
end
createBillButton(1000, 34, Color3.fromRGB(180,215,245), Color3.fromRGB(120,165,205))
createBillButton(5000, 252, Color3.fromRGB(235,205,165), Color3.fromRGB(190,135,90))
createBillButton(10000, 470, Color3.fromRGB(180,230,195), Color3.fromRGB(105,175,125))
resetBillsBtn.MouseButton1Click:Connect(resetBills)
closeCashBtn.MouseButton1Click:Connect(function() cashFrame.Visible = false end)
local function showCashChangeInput()
	cashInfo.Text = cashPaymentSummary("받은 돈: "..fmt(cashPaid).." / 거스름돈은 얼마일까요?")
	cashInput.Visible = true
	cashSubmit.Visible = true
	cashInput.Text = ""
	showModal(cashFrame)
end
payBtn.MouseButton1Click:Connect(function()
	local paid = billSum()
	if paid <= 0 then showAlert("낼 지폐를 먼저 선택해주세요.", function() showModal(cashFrame) end); return end
	if paid < cashDue then
		showAlert(fmt(paid).." 받았습니다. 아직 "..fmt(cashDue-paid).." 부족해요. 돈을 더 내볼까요?", function() showModal(cashFrame) end)
		return
	end
	if paid >= 10000 and cashDue < 3000 then
		showChoices("10,000원을 내도 되지만, 거스름돈이 많아져요.\n이대로 낼까요?", {
			{id="client_keep_big_bill", text="이대로 낼래요"},
			{id="client_reset_big_bill", text="다시 고를래요"},
		})
		return
	end
	cashPaid = paid
	if paid - cashDue == 0 then
		cashFrame.Visible = false
		payEvent:FireServer(paid, "0")
	else
		showCashChangeInput()
	end
end)
cashSubmit.MouseButton1Click:Connect(function()
	local expected = cashPaid - cashDue
	local answer = parseMoneyText(cashInput.Text)
	if answer == expected then
		cashFrame.Visible = false
		payEvent:FireServer(cashPaid, tostring(cashInput.Text))
	else
		cashWrongCount += 1
		local msg
		if cashWrongCount == 1 then
			msg = "괜찮아요. 다시 계산해볼까요?\n"..fmt(cashPaid).."에서 "..fmt(cashDue).."을 빼면 돼요."
		elseif cashWrongCount == 2 then
			msg = "조금 더 쉽게 볼게요.\n받은 돈 - 결제 금액 = 거스름돈이에요."
		else
			msg = "정답은 "..fmt(expected).."이에요.\n정답을 확인하고 진행할게요."
		end
		if cashWrongCount >= 3 then
			showAlert(msg, function() cashFrame.Visible = false; payEvent:FireServer(cashPaid, tostring(expected)) end)
		else
			showAlert(msg, showCashChangeInput)
		end
	end
end)

-- 예산 남은 돈 주관식 UI
local budgetFrame = Instance.new("Frame")
budgetFrame.Size = UDim2.new(0,560,0,290)
budgetFrame.Position = UDim2.new(0.5,-280,0.5,-145)
budgetFrame.BackgroundColor3 = Color3.fromRGB(20,35,45)
budgetFrame.Visible = false
budgetFrame.Parent = gui
registerModal(budgetFrame)
makeCorner(budgetFrame, 16)
local budgetLabel = makeLabel(budgetFrame, "", UDim2.new(1,-24,0,130), UDim2.new(0,12,0,18), NORMAL_TEXT)
local budgetInput = Instance.new("TextBox")
budgetInput.Size = UDim2.new(0.62,0,0,48)
budgetInput.Position = UDim2.new(0.06,0,0,165)
budgetInput.BackgroundColor3 = Color3.fromRGB(245,245,245)
budgetInput.PlaceholderText = "남은 돈 입력"
budgetInput.Text = ""
budgetInput.TextColor3 = Color3.fromRGB(20,20,20)
budgetInput.Font = FONT_MAIN
budgetInput.TextSize = NORMAL_TEXT
budgetInput.Parent = budgetFrame
makeCorner(budgetInput, 8)
local budgetSubmit = makeButton(budgetFrame, "제출", UDim2.new(0.26,0,0,48), UDim2.new(0.70,0,0,165), Color3.fromRGB(40,130,80), NORMAL_TEXT)
local budgetExpected, budgetWrong = 0, 0
local function showBudgetFrame()
	showModal(budgetFrame)
end
budgetSubmit.MouseButton1Click:Connect(function()
	local ans = parseMoneyText(budgetInput.Text)
	if ans == budgetExpected then
		budgetFrame.Visible = false
		choiceEvent:FireServer("budget_answer_ok")
	else
		budgetWrong += 1
		local msg
		if budgetWrong == 1 then msg = "예산에서 결제 금액을 빼면 돼요. 다시 입력해볼까요?"
		elseif budgetWrong == 2 then msg = "큰 금액부터 빼고 남은 금액을 한 번 더 빼보세요."
		else msg = "정답은 "..fmt(budgetExpected).."이에요. 정답을 확인하고 진행할게요." end
		if budgetWrong >= 3 then showAlert(msg, function() budgetFrame.Visible = false; choiceEvent:FireServer("budget_answer_ok") end) else showAlert(msg, showBudgetFrame) end
	end
end)

-- 카드 단말기 UI: 카드 클릭 회전 + 세로 카드 슬롯 삽입 애니메이션
local cardFrame = Instance.new("Frame")
cardFrame.Name = "CardFrame"
cardFrame.Size = UDim2.new(0,720,0,500)
cardFrame.Position = UDim2.new(0.5,-360,0.5,-250)
cardFrame.BackgroundColor3 = Color3.fromRGB(18,25,36)
cardFrame.Visible = false
cardFrame.Parent = gui
registerModal(cardFrame)
makeCorner(cardFrame, 16)
makeLabel(cardFrame, "카드를 카드 단말기에 넣어주세요", UDim2.new(1,-24,0,42), UDim2.new(0,12,0,12), TITLE_TEXT, Color3.fromRGB(255,220,70))
local cardHint = makeLabel(cardFrame, "IC칩이 위를 향한 상태예요. 카드를 그대로 드래그해서 단말기 슬롯 안쪽까지 밀어 넣으면 결제돼요.", UDim2.new(1,-24,0,60), UDim2.new(0,12,0,58), NORMAL_TEXT)

local terminal = Instance.new("Frame")
terminal.Size = UDim2.new(0,280,0,255)
terminal.Position = UDim2.new(0.58,0,0.30,0)
terminal.BackgroundColor3 = Color3.fromRGB(45,47,54)
terminal.Parent = cardFrame
terminal.ZIndex = 10
makeCorner(terminal, 18)
makeStroke(terminal, Color3.fromRGB(180,180,185), 2)
local terminalScreen = Instance.new("Frame")
terminalScreen.Size = UDim2.new(0.72,0,0,68)
terminalScreen.Position = UDim2.new(0.14,0,0,20)
terminalScreen.BackgroundColor3 = Color3.fromRGB(25,80,90)
terminalScreen.Parent = terminal
terminalScreen.ZIndex = 12
makeCorner(terminalScreen, 8)
makeLabel(terminalScreen, "카드 삽입", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), NORMAL_TEXT, Color3.fromRGB(230,255,255))

local slotGuide = Instance.new("Frame")
slotGuide.Size = UDim2.new(0,206,0,44)
slotGuide.Position = UDim2.new(0.5,-103,0,128)
slotGuide.BackgroundColor3 = Color3.fromRGB(75,77,84)
slotGuide.Parent = terminal
slotGuide.ZIndex = 18
makeCorner(slotGuide, 10)
local cardSlot = Instance.new("Frame")
cardSlot.Size = UDim2.new(0,176,0,18)
cardSlot.Position = UDim2.new(0.5,-88,0.5,-9)
cardSlot.BackgroundColor3 = Color3.fromRGB(5,5,8)
cardSlot.Parent = slotGuide
cardSlot.ZIndex = 24
makeCorner(cardSlot, 6)
local slotCover = Instance.new("Frame")
slotCover.Size = UDim2.new(1,0,0,10)
slotCover.Position = UDim2.new(0,0,0,0)
slotCover.BackgroundColor3 = Color3.fromRGB(0,0,0)
slotCover.Parent = cardSlot
slotCover.ZIndex = 32
makeCorner(slotCover, 5)
makeLabel(terminal, "카드의 좁은 쪽을 위 슬롯에 넣기", UDim2.new(1,-12,0,34), UDim2.new(0,6,0,178), SMALL_TEXT, Color3.fromRGB(225,225,225))

local cardObj = Instance.new("TextButton")
cardObj.Size = UDim2.new(0,126,0,205)
cardObj.Position = UDim2.new(0.11,0,0.42,0)
cardObj.BackgroundColor3 = Color3.fromRGB(55,92,178)
cardObj.Text = ""
cardObj.Parent = cardFrame
cardObj.ZIndex = 26
makeCorner(cardObj, 14)
makeStroke(cardObj, Color3.fromRGB(240,240,255), 2)
local chip = Instance.new("Frame")
chip.Size = UDim2.new(0,42,0,32)
chip.Position = UDim2.new(0,17,0,22)
chip.BackgroundColor3 = Color3.fromRGB(235,195,80)
chip.Parent = cardObj
chip.ZIndex = 27
makeCorner(chip, 5)
local chipText = makeLabel(chip, "IC", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), 13, Color3.fromRGB(70,50,20))
chipText.ZIndex = 28
local cardBrand = makeLabel(cardObj, "CARD", UDim2.new(1,-18,0,36), UDim2.new(0,9,1,-52), 22, Color3.fromRGB(255,255,255))
cardBrand.ZIndex = 27
cardBrand.TextXAlignment = Enum.TextXAlignment.Right
local cardGuide = makeLabel(cardObj, "IC칩 ↑", UDim2.new(1,-14,0,26), UDim2.new(0,7,0,62), 13, Color3.fromRGB(245,245,255))
cardGuide.ZIndex = 27

local cardDirection, cardFail = 0, 0
local dragging, dragStart, startPos = false, nil, nil
local cardAnimating = false
local function resetCardVisual()
	cardObj.Position = UDim2.new(0.11,0,0.42,0)
	cardObj.ZIndex = 26
end
local function updateCardVisual()
	cardObj.Rotation = cardDirection * 90
end
cardObj.MouseButton1Click:Connect(function()
	-- 카드 방향은 처음부터 IC칩이 위를 향하도록 고정한다. 클릭해도 뒤집히지 않는다.
	if cardAnimating then return end
	cardDirection = 0
	updateCardVisual()
end)
cardObj.InputBegan:Connect(function(input)
	if cardAnimating then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = cardObj.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging or cardAnimating then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = input.Position - dragStart
	cardObj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end)
local function animateCardInsertThenOut()
	cardAnimating = true
	cardHint.Text = "카드가 슬롯에 들어갔어요. 잠시만 기다려주세요."
	local framePos = cardFrame.AbsolutePosition
	local slotPos = cardSlot.AbsolutePosition
	local slotSize = cardSlot.AbsoluteSize
	local cardSize = cardObj.AbsoluteSize
	local insertX = slotPos.X + slotSize.X/2 - cardSize.X/2 - framePos.X
	local insertY = slotPos.Y - cardSize.Y + 18 - framePos.Y
	cardObj.ZIndex = 16 -- 단말기 몸체보다 살짝 아래로 내려 카드가 가려져 보이게 함
	local tweenIn = TweenService:Create(cardObj, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, insertX, 0, insertY)})
	tweenIn:Play()
	tweenIn.Completed:Wait()
	task.wait(0.22)
	local tweenOut = TweenService:Create(cardObj, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, insertX, 0, insertY + 42)})
	tweenOut:Play()
	tweenOut.Completed:Wait()
	cardFrame.Visible = false
	cardAnimating = false
	choiceEvent:FireServer("card_direction_ok")
end
local function cardTryFinish()
	if not dragging or cardAnimating then return end
	dragging = false
	local cardTop = cardObj.AbsolutePosition.Y
	local cardCenterX = cardObj.AbsolutePosition.X + cardObj.AbsoluteSize.X/2
	local slotLeft = cardSlot.AbsolutePosition.X
	local slotRight = slotLeft + cardSlot.AbsoluteSize.X
	local slotBottom = cardSlot.AbsolutePosition.Y + cardSlot.AbsoluteSize.Y
	local insertedFarEnough = cardTop <= slotBottom + 18 and cardCenterX >= slotLeft and cardCenterX <= slotRight
	if isOverlap(cardObj, cardSlot) and insertedFarEnough then
		if cardDirection == 0 then
			animateCardInsertThenOut()
		else
			cardFail += 1
			resetCardVisual()
			cardDirection = 0
			updateCardVisual()
			if cardFail >= 3 then
				cardHint.Text = "카드를 카드 단말기에 넣어주세요. 슬롯 위치가 노란색으로 표시돼요."
				makeStroke(slotGuide, Color3.fromRGB(255,220,90), 4)
			else
				showAlert("카드를 슬롯 안쪽까지 조금 더 밀어 넣어볼까요?", function() showModal(cardFrame) end)
			end
		end
	else
		resetCardVisual()
	end
end
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		cardTryFinish()
	end
end)

-- 쿠폰 밝기 UI
local phoneFrame = Instance.new("Frame")
phoneFrame.Name = "PhoneFrame"
phoneFrame.Size = UDim2.new(0,430,0,590)
phoneFrame.Position = UDim2.new(0.5,-215,0.5,-295)
phoneFrame.BackgroundColor3 = Color3.fromRGB(12,12,16)
phoneFrame.Visible = false
phoneFrame.Parent = gui
registerModal(phoneFrame)
makeCorner(phoneFrame, 30)
makeStroke(phoneFrame, Color3.fromRGB(80,80,90), 4)
-- 휴대폰 상단 시간/배터리 영역은 미션 집중을 위해 표시하지 않는다.
local sliderBack = Instance.new("Frame")
sliderBack.Size = UDim2.new(0.78,0,0,24)
sliderBack.Position = UDim2.new(0.11,0,0,28)
sliderBack.BackgroundColor3 = Color3.fromRGB(60,60,65)
sliderBack.Parent = phoneFrame
makeCorner(sliderBack, 14)
local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.25,0,1,0)
sliderFill.BackgroundColor3 = Color3.fromRGB(255,245,150)
sliderFill.Parent = sliderBack
makeCorner(sliderFill, 14)
local sliderHandle = Instance.new("Frame")
sliderHandle.Size = UDim2.new(0,38,0,38)
sliderHandle.Position = UDim2.new(0.25,-19,0.5,-19)
sliderHandle.BackgroundColor3 = Color3.fromRGB(255,255,255)
sliderHandle.Parent = sliderBack
makeCorner(sliderHandle, 22)
makeLabel(phoneFrame, "화면 밝기", UDim2.new(1,0,0,22), UDim2.new(0,0,0,58), SMALL_TEXT)
local couponArea = Instance.new("Frame")
couponArea.Size = UDim2.new(0.86,0,0,348)
couponArea.Position = UDim2.new(0.07,0,0,88)
couponArea.BackgroundColor3 = Color3.fromRGB(245,245,250)
couponArea.Parent = phoneFrame
makeCorner(couponArea, 18)
makeLabel(couponArea, "모바일 쿠폰", UDim2.new(1,0,0,42), UDim2.new(0,0,0,15), TITLE_TEXT, Color3.fromRGB(20,20,20))
local barcodeFrame = Instance.new("Frame")
barcodeFrame.Name = "CouponBarcode"
barcodeFrame.Size = UDim2.new(0,314,0,112)
barcodeFrame.Position = UDim2.new(0.5,-157,0,86)
barcodeFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
barcodeFrame.BorderSizePixel = 0
barcodeFrame.ClipsDescendants = true
barcodeFrame.Parent = couponArea
local barcodePattern = {2,1,1,2,3,1,1,1,2,2,1,3,1,1,2,1,3,2,1,1,2,3,1,2,1,1,3,1,2,2,1,1,2,1,3,2,1,1,2,2,1,3,1,2,1,1,3,2,1,1,2,3,1,2,1,1,2,2,3,1,1,2,1,3,2,1,1,2,2,1,3,1,2,1}
local barcodeX = 10
local barcodeMaxWidth = barcodeFrame.Size.X.Offset - 20
local rawWidth = 0
for _, width in ipairs(barcodePattern) do rawWidth += width end
local unit = barcodeMaxWidth / rawWidth
for i, width in ipairs(barcodePattern) do
	local px = math.max(1, math.floor(width * unit))
	if i % 2 == 1 then
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. i
		bar.Size = UDim2.new(0, px, 0, 82)
		bar.Position = UDim2.new(0, barcodeX, 0, 8)
		bar.BackgroundColor3 = Color3.fromRGB(0,0,0)
		bar.BorderSizePixel = 0
		bar.Parent = barcodeFrame
	end
	barcodeX += px
end
local barcodeNumber = makeLabel(barcodeFrame, "8801 2345 6789", UDim2.new(1,0,0,22), UDim2.new(0,0,1,-22), 14, Color3.fromRGB(0,0,0))
barcodeNumber.TextXAlignment = Enum.TextXAlignment.Center
makeLabel(couponArea, "CU 모바일 상품권\n금액: 3,000원", UDim2.new(1,-40,0,70), UDim2.new(0,20,0,214), NORMAL_TEXT, Color3.fromRGB(20,20,20))
local darkOverlay = Instance.new("Frame")
darkOverlay.Size = UDim2.new(1,0,1,0)
darkOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
darkOverlay.BackgroundTransparency = 0.65
darkOverlay.Parent = couponArea
makeCorner(darkOverlay, 18)
local phoneMsg = makeLabel(phoneFrame, "", UDim2.new(1,-40,0,54), UDim2.new(0,20,0,452), SMALL_TEXT)
local showAgainBtn = makeButton(phoneFrame, "결제하기", UDim2.new(0.76,0,0,46), UDim2.new(0.12,0,0,512), Color3.fromRGB(90,90,90), NORMAL_TEXT)
showAgainBtn.Visible = false
local brightness = 25
local draggingSlider = false
local function updateBrightnessUI()
	local pct = math.clamp(brightness/100,0,1)
	sliderFill.Size = UDim2.new(pct,0,1,0)
	sliderHandle.Position = UDim2.new(pct,-19,0.5,-19)
	darkOverlay.BackgroundTransparency = 0.82 * pct
	if brightness >= 100 then
		phoneMsg.Text = "밝기를 최대로 올렸어요! 이제 결제할 수 있어요."
		showAgainBtn.Text = "결제하기"
		showAgainBtn.Visible = true
		showAgainBtn.BackgroundColor3 = Color3.fromRGB(45,130,80)
	else
		phoneMsg.Text = brightness < 45 and "아직 화면이 너무 어두워요." or "조금 밝아졌어요. 끝까지 올려볼까요?"
		showAgainBtn.Visible = false
		showAgainBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
	end
end
local function setBrightnessFromX(x)
	local left = sliderBack.AbsolutePosition.X
	local width = sliderBack.AbsoluteSize.X
	brightness = math.floor(math.clamp((x-left)/width,0,1)*100)
	updateBrightnessUI()
end
sliderBack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = true; setBrightnessFromX(input.Position.X) end
end)
sliderHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = true; setBrightnessFromX(input.Position.X) end
end)
UserInputService.InputChanged:Connect(function(input)
	if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setBrightnessFromX(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = false end
end)
showAgainBtn.MouseButton1Click:Connect(function()
	if brightness < 100 then
		showAlert("아직 화면이 조금 어두워요.\n밝기 바를 오른쪽으로 더 밀어볼까요?", function() showModal(phoneFrame) end)
	else
		phoneFrame.Visible = false
		choiceEvent:FireServer("phone_brightness_ok")
	end
end)

-- 미션 완료/상품 가져가기/다음 회차
local completeFrame = Instance.new("Frame")
completeFrame.Name = "CompleteFrame"
completeFrame.Size = UDim2.new(0,600,0,330)
completeFrame.Position = UDim2.new(0.5,-300,0.5,-165)
completeFrame.BackgroundColor3 = Color3.fromRGB(30,60,45)
completeFrame.Visible = false
completeFrame.Parent = gui
registerModal(completeFrame)
makeCorner(completeFrame, 16)
makeLabel(completeFrame, "상품을 챙겨주세요", UDim2.new(1,-24,0,50), UDim2.new(0,12,0,18), TITLE_TEXT, Color3.fromRGB(255,235,120))
local completeDesc = makeLabel(completeFrame, "", UDim2.new(1,-28,0,120), UDim2.new(0,14,0,78), NORMAL_TEXT)
local takeProductBtn = makeButton(completeFrame, "상품 가져가기", UDim2.new(0.78,0,0,52), UDim2.new(0.11,0,1,-78), Color3.fromRGB(60,150,90), TITLE_TEXT)
local successFrame = Instance.new("Frame")
successFrame.Name = "SuccessFrame"
successFrame.Size = UDim2.new(0,620,0,380)
successFrame.Position = UDim2.new(0.5,-310,0.5,-190)
successFrame.BackgroundColor3 = Color3.fromRGB(24,58,42)
successFrame.Visible = false
successFrame.Parent = gui
registerModal(successFrame)
makeCorner(successFrame, 18)
makeStroke(successFrame, Color3.fromRGB(255,230,100), 2)
makeLabel(successFrame, "미션 성공!", UDim2.new(1,-24,0,58), UDim2.new(0,12,0,20), BIG_TEXT, Color3.fromRGB(255,235,100))
local successDesc = makeLabel(successFrame, "", UDim2.new(1,-30,0,140), UDim2.new(0,15,0,90), NORMAL_TEXT)
local retryBtn = makeButton(successFrame, "다시하기", UDim2.new(0.40,0,0,54), UDim2.new(0.07,0,1,-76), Color3.fromRGB(90,110,150), TITLE_TEXT)
local nextBtn = makeButton(successFrame, "다음미션", UDim2.new(0.40,0,0,54), UDim2.new(0.53,0,1,-76), Color3.fromRGB(60,145,85), TITLE_TEXT)
local currentCompletePayload = nil
takeProductBtn.MouseButton1Click:Connect(function()
	showModal(successFrame)
end)
retryBtn.MouseButton1Click:Connect(function()
	missionProgressEvent:FireServer("retry")
end)
nextBtn.MouseButton1Click:Connect(function()
	missionProgressEvent:FireServer("next")
end)

-- 인벤토리/설정/리포트
local invBtn = makeButton(gui, "?", UDim2.new(0,52,0,52), UDim2.new(0,14,0,14), Color3.fromRGB(60,70,110), 24)
local invFrame = Instance.new("Frame")
invFrame.Size = UDim2.new(0,420,0,360)
invFrame.Position = UDim2.new(0,78,0,74)
invFrame.BackgroundColor3 = Color3.fromRGB(25,30,55)
invFrame.Visible = false
invFrame.Parent = gui
registerModal(invFrame)
makeCorner(invFrame, 16)
makeLabel(invFrame, "인벤토리", UDim2.new(1,-24,0,46), UDim2.new(0,12,0,14), TITLE_TEXT, Color3.fromRGB(255,230,100))
local soundBtn = makeButton(invFrame, "효과음 ON", UDim2.new(0.84,0,0,48), UDim2.new(0.08,0,0,80), Color3.fromRGB(70,110,160), NORMAL_TEXT)
local reportBtn = makeButton(invFrame, "학부모 리포트", UDim2.new(0.84,0,0,48), UDim2.new(0.08,0,0,145), Color3.fromRGB(70,150,95), NORMAL_TEXT)
local voiceInfoBtn = makeButton(invFrame, "음성모드 안내", UDim2.new(0.84,0,0,48), UDim2.new(0.08,0,0,210), Color3.fromRGB(160,105,70), NORMAL_TEXT)
local closeInvBtn = makeButton(invFrame, "닫기", UDim2.new(0.84,0,0,42), UDim2.new(0.08,0,1,-58), Color3.fromRGB(110,70,80), NORMAL_TEXT)
invBtn.MouseButton1Click:Connect(function() showModal(invFrame) end)
soundBtn.MouseButton1Click:Connect(function()
	sfxOn = not sfxOn
	soundBtn.Text = sfxOn and "효과음 ON" or "효과음 OFF"
	if sfxOn then playClick() end
end)
closeInvBtn.MouseButton1Click:Connect(function() invFrame.Visible = false end)
reportBtn.MouseButton1Click:Connect(function()
	local score = player:GetAttribute("Score") or 0
	local total = player:GetAttribute("TotalSuccess") or 0
	local cash = player:GetAttribute("CashSuccess") or 0
	local card = player:GetAttribute("CardSuccess") or 0
	local coupon = player:GetAttribute("CouponSuccess") or 0
	local combo = player:GetAttribute("ComboSuccess") or 0
	showAlert("학부모 리포트\n\n누적 성공: "..total.."회\n현금: "..cash.."회\n카드: "..card.."회 / 쿠폰: "..coupon.."회\n종합: "..combo.."회\n점수: "..score.."점\n\n현재 버전은 플레이 중 누적 기록을 보여줘요. 영구 저장은 DataStore 같은 백엔드 저장이 필요해요.", function() showModal(invFrame) end)
end)
voiceInfoBtn.MouseButton1Click:Connect(function()
	showAlert("음성모드 고급 기능\n\nRoblox 안에서 음성 답변을 정답/오답으로 판별하려면 음성→텍스트 변환 서버가 필요해요.\n구조: Roblox → 외부 STT 서버 → AI 판정 → Roblox로 결과 반환\n\n현재 파일에는 안내 버튼만 넣어두고, 실제 음성 판정은 백엔드 연동 단계에서 추가하는 게 안전해요.", function() showModal(invFrame) end)
end)

-- 반짝임 효과
local activeHighlights = {}
local function clearHighlights()
	for _, h in ipairs(activeHighlights) do if h and h.Parent then h:Destroy() end end
	activeHighlights = {}
end
local function highlightProducts(ids)
	clearHighlights()
	local products = workspace:FindFirstChild("Products")
	if not products then return end
	local set = {}
	for _, id in ipairs(ids or {}) do set[id] = true end
	for _, item in ipairs(products:GetChildren()) do
		local baseID = item.Name:gsub("_r%d+_c%d+$", "")
		if set[baseID] then
			local hl = Instance.new("Highlight")
			hl.Name = "MissionHighlight"
			hl.Adornee = item
			hl.FillTransparency = 0.35
			hl.OutlineTransparency = 0
			hl.FillColor = Color3.fromRGB(255,230,80)
			hl.OutlineColor = Color3.fromRGB(255,255,255)
			hl.Parent = item
			table.insert(activeHighlights, hl)
		end
	end
end
local function updateTargetPanel(data)
	targetPanel.Visible = false
	if not data or not data.targets then clearHighlights(); return end
	local lines = {}
	for id, need in pairs(data.targets) do
		local got = data.progress and data.progress[id] or 0
		local mark = got >= need and "?" or ""
		table.insert(lines, (PRODUCT_NAMES[id] or id).." "..got.."/"..need..mark)
	end
	targetList.Text = table.concat(lines, "\n")
	if currentMissionBaseLine ~= "" then
		missionLine.Text = currentMissionBaseLine.."  |  "..table.concat(lines, " · ")
	end
	highlightProducts(data.highlight or {})
end

-- 리모트 수신
pickupEvent.OnClientEvent:Connect(function(actionOrUniqueID, a, b, c, d)
	if actionOrUniqueID ~= "cartAdd" and actionOrUniqueID ~= "cartRemove" then
		pickupEvent:FireServer(actionOrUniqueID, a, b, c)
		return
	end
	if actionOrUniqueID == "cartAdd" then
		local cartID, name, price = b, c, d
		if localCart[cartID] then localCart[cartID].count += 1 else localCart[cartID] = {name=name, count=1, price=price} end
	elseif actionOrUniqueID == "cartRemove" then
		local cartID = a
		if localCart[cartID] then localCart[cartID].count -= 1; if localCart[cartID].count <= 0 then localCart[cartID] = nil end end
	end
	refreshCart()
end)
cartUpdateEvent.OnClientEvent:Connect(function(action, cartID)
	if action == "localClear" then localCart = {}; refreshCart(); return end
	if action == "localRemove" then
		if localCart[cartID] then localCart[cartID].count -= 1; if localCart[cartID].count <= 0 then localCart[cartID] = nil end end
		refreshCart()
	end
end)

talkEvent.OnClientEvent:Connect(function(message)
	dialogHudState = captureHudState()
	dialogText.Text = "직원: "..tostring(message)
	showModal(dialog)
end)

billEvent.OnClientEvent:Connect(function(kind, total)
	if kind ~= "cash" then total = kind end
	cashDue = tonumber(total) or 0
	cashTitle.Text = "현금 결제"
	cashInfo.Text = cashPaymentSummary("1,000원 / 5,000원 / 10,000원 지폐를 조합해보세요.")
	resetBills()
	showModal(cashFrame)
end)

choiceEvent.OnClientEvent:Connect(function(action, message, choices)
	if action == "show" then
		showChoices(message, choices)
	elseif action == "alert" then
		showAlert(tostring(message or ""), nil)
	elseif action == "budgetInput" then
		local budget = tonumber(message) or 0
		local total = tonumber(choices) or 0
		budgetExpected = budget - total
		budgetWrong = 0
		budgetInput.Text = ""
		budgetLabel.Text = "오늘 예산: "..fmt(budget).."\n결제 금액: "..fmt(total).."\n남은 돈은 얼마일까요?"
		showModal(budgetFrame)
	elseif action == "cardUI" then
		cardDirection = 0
		cardFail = 0
		cardHint.Text = "카드를 카드 단말기에 넣어주세요. IC칩이 위를 향한 카드를 그대로 드래그해서 슬롯 안쪽까지 밀어 넣으면 결제돼요."
		resetCardVisual()
		updateCardVisual()
		showModal(cardFrame)
	elseif action == "phoneBrightness" then
		brightness = 25
		showAgainBtn.Visible = false
		updateBrightnessUI()
		phoneMsg.Text = tostring(message or "상단 밝기 바를 오른쪽으로 밀어주세요.")
		showModal(phoneFrame)
	end
end)

missionEvent.OnClientEvent:Connect(function(eventType, data, message)
	if eventType == "resetStart" then
		closeAllModals()
		startFrame.Visible = true
		missionBanner.Visible = false
		missionSelectFrame.Visible = false
		cartPanel.Visible = false
		targetPanel.Visible = false
		localCart = {}; refreshCart(); clearHighlights(); currentMissionBaseLine = ""
	elseif eventType == "start" then
		closeAllModals()
		hideHud()
		missionBanner.Visible = true
		startFrame.Visible = false
		missionSelectFrame.Visible = false
		localCart = {}; refreshCart(); clearHighlights()
		currentMissionBaseLine = data and (data.line or data.desc or data.title or "미션") or "미션"
		missionLine.Text = currentMissionBaseLine
		updateTargetPanel(data)
	elseif eventType == "specificUpdate" then
		if message and tostring(message) ~= "" then currentMissionBaseLine = tostring(message); missionLine.Text = currentMissionBaseLine end
		updateTargetPanel(data)
	elseif eventType == "showComplete" then
		closeAllModals()
		missionBanner.Visible = false
		cartPanel.Visible = false
		targetPanel.Visible = false
		clearHighlights()
		completeDesc.Text = message or "계산이 끝났어요. 상품을 챙겨주세요."
		successDesc.Text = (data and data.successText) or "잘했어요! 미션을 성공했어요."
		nextBtn.Text = (data and data.isFinalRound) and "첫 화면" or "다음미션"
		showModal(completeFrame)
	elseif eventType == "pickup" then
		if message then currentMissionBaseLine = tostring(message); missionLine.Text = currentMissionBaseLine end
	elseif eventType == "wrong" then
		if message then showAlert(message, nil) end
	end
end)

-- 클라이언트 내부 선택지 처리
choiceEvent.OnClientEvent:Connect(function() end)
choiceButtonsFrame.ChildAdded:Connect(function() end)
choiceEvent.OnClientEvent:Connect(function() end)
-- 위 빈 연결은 안전상 아무 동작 없음.

-- showChoices에서 쓰는 클라이언트 전용 선택지 처리
local oldShowChoices = showChoices
showChoices = function(message, choices)
	clearChoiceButtons()
	choiceText.Text = tostring(message or "")
	showModal(choiceFrame)
	for i, choice in ipairs(choices or {}) do
		local btn = makeButton(choiceButtonsFrame, choice.text, UDim2.new(1,0,0,44), UDim2.new(0,0,0,0), Color3.fromRGB(90,75,150), NORMAL_TEXT)
		btn.LayoutOrder = i
		btn.MouseButton1Click:Connect(function()
			choiceFrame.Visible = false
			if choice.id == "client_keep_big_bill" then
				cashPaid = billSum(); showCashChangeInput(); return
			elseif choice.id == "client_reset_big_bill" then
				resetBills(); showModal(cashFrame); return
			end
			choiceEvent:FireServer(choice.id)
		end)
	end
end

print("GameClient final v5 loaded")
