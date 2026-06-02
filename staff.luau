
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreateRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local talkEvent = getOrCreateRemote("StaffTalk")
local payEvent = getOrCreateRemote("PayRequest")
local pickupEvent = getOrCreateRemote("PickupItem")
local missionEvent = getOrCreateRemote("MissionUpdate")
local billEvent = getOrCreateRemote("BillEvent")
local missionProgressEvent = getOrCreateRemote("MissionProgress")
local cartUpdateEvent = getOrCreateRemote("CartUpdate")
local choiceEvent = getOrCreateRemote("Mission2Choice")

local PRODUCT_NAMES = {
	cheetos="치토스", pringles="프링글스", pocky="포키", potato_chips="감자칩",
	neoguri="너구리라면", buldak="불닭볶음탕면",
	banana_milk="바나나우유", choco_milk="초코우유", coffee="커피", cola="코카콜라",
}
local PRODUCT_PRICES = {
	cheetos=1500, pringles=2000, pocky=1500, potato_chips=1200,
	neoguri=1100, buldak=1500,
	banana_milk=1500, choco_milk=1500, coffee=2000, cola=1800,
}
local PRODUCT_CATEGORIES = {
	cheetos="snack", pringles="snack", pocky="snack", potato_chips="snack",
	neoguri="ramen", buldak="ramen",
	banana_milk="drink", choco_milk="drink", coffee="drink", cola="drink",
}
local CATEGORY_NAMES = {drink="음료", snack="간식", ramen="라면"}
local PRODUCT_IDS = {"cheetos","pringles","pocky","potato_chips","neoguri","buldak","banana_milk","choco_milk","coffee","cola"}
local DRINK_IDS = {"banana_milk","choco_milk","coffee","cola"}
local SNACK_IDS = {"cheetos","pringles","pocky","potato_chips"}
local PROMOS = {banana_milk="ONE_PLUS_ONE", choco_milk="TWO_PLUS_ONE"}
local BAG_PRICE = 100

local MODE = {CASH=2, CARD=3, COUPON=4, COMBO=5}
local MODE_COUNTER = {[MODE.CASH]="CashSuccess", [MODE.CARD]="CardSuccess", [MODE.COUPON]="CouponSuccess", [MODE.COMBO]="ComboSuccess"}
local MODE_NAME = {[MODE.CASH]="현금 결제 미션", [MODE.CARD]="카드 결제 미션", [MODE.COUPON]="쿠폰 결제 미션", [MODE.COMBO]="종합 결제 미션"}

local function getCartBaseID(productID)
	return tostring(productID):gsub("_r%d+_c%d+$", "")
end
local function getProductName(id) return PRODUCT_NAMES[getCartBaseID(id)] or tostring(id) end
local function getPrice(id) return PRODUCT_PRICES[getCartBaseID(id)] or 0 end
local function getCategory(id) return PRODUCT_CATEGORIES[getCartBaseID(id)] end

local function getCart(player)
	local cart = player:FindFirstChild("Cart")
	if not cart then cart = Instance.new("Folder"); cart.Name = "Cart"; cart.Parent = player end
	return cart
end
local function getPicked(player)
	local picked = player:FindFirstChild("PickedItems")
	if not picked then picked = Instance.new("Folder"); picked.Name = "PickedItems"; picked.Parent = player end
	return picked
end

local function setProductVisible(uniqueID, visible)
	local prodFolder = workspace:FindFirstChild("Products")
	if not prodFolder then return end
	local item = prodFolder:FindFirstChild(uniqueID)
	if not item then return end
	local transparency = visible and 0 or 1
	if item:IsA("BasePart") then
		item.Transparency = transparency; item.CanCollide = visible; item.CanTouch = visible; item.CanQuery = visible
	end
	for _, v in ipairs(item:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = transparency; v.CanCollide = visible; v.CanTouch = visible; v.CanQuery = visible
		elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = transparency end
	end
end
local function isProductVisible(uniqueID)
	local prodFolder = workspace:FindFirstChild("Products")
	if not prodFolder then return false end
	local item = prodFolder:FindFirstChild(uniqueID)
	if not item then return false end
	if item:IsA("BasePart") and item.Transparency < 1 then return true end
	for _, v in ipairs(item:GetDescendants()) do if v:IsA("BasePart") and v.Transparency < 1 then return true end end
	return false
end
local function visibleStock(cartID)
	local prodFolder = workspace:FindFirstChild("Products")
	if not prodFolder then return 0 end
	local n = 0
	for _, item in ipairs(prodFolder:GetChildren()) do
		if getCartBaseID(item.Name) == cartID and isProductVisible(item.Name) then n += 1 end
	end
	return n
end
local function recordPickedItem(player, uniqueID, cartID)
	local sv = Instance.new("StringValue")
	sv.Name = uniqueID
	sv.Value = uniqueID
	sv:SetAttribute("CartID", cartID)
	sv.Parent = getPicked(player)
end
local function removeOnePickedItem(player, cartID)
	for _, sv in ipairs(getPicked(player):GetChildren()) do
		if sv:GetAttribute("CartID") == cartID then
			local uniqueID = sv.Value
			sv:Destroy()
			setProductVisible(uniqueID, true)
			return uniqueID
		end
	end
	return nil
end
local function clearCart(player, restoreProducts)
	if restoreProducts then
		for _, sv in ipairs(getPicked(player):GetChildren()) do setProductVisible(sv.Value, true) end
	end
	getCart(player):ClearAllChildren()
	for k, _ in pairs(getCart(player):GetAttributes()) do getCart(player):SetAttribute(k, nil) end
	getPicked(player):ClearAllChildren()
	player:SetAttribute("NeedsBag", false)
	cartUpdateEvent:FireClient(player, "localClear")
end

local function promoPaidQty(cartID, qty, ignorePromo)
	if ignorePromo then return qty, 0 end
	local promo = PROMOS[cartID]
	if promo == "ONE_PLUS_ONE" then local paid = math.ceil(qty/2); return paid, qty-paid end
	if promo == "TWO_PLUS_ONE" then local free = math.floor(qty/3); return qty-free, free end
	return qty, 0
end
local function shouldIgnorePromo(player)
	local mode = player:GetAttribute("MissionMode") or 0
	return mode == MODE.CASH or mode == MODE.CARD or mode == MODE.COUPON
end
local function calcProductTotal(player, ignorePromo)
	local total = 0
	for cartID, qty in pairs(getCart(player):GetAttributes()) do
		local paid = promoPaidQty(cartID, qty, ignorePromo)
		total += getPrice(cartID) * paid
	end
	return total
end
local function calcFinalTotal(player, ignorePromo)
	local total = calcProductTotal(player, ignorePromo)
	if player:GetAttribute("NeedsBag") then total += BAG_PRICE end
	return total
end
local function cartCount(player)
	local total = 0
	for _, qty in pairs(getCart(player):GetAttributes()) do total += qty end
	return total
end
local function hasCategory(player, cat)
	for id, qty in pairs(getCart(player):GetAttributes()) do
		if qty > 0 and getCategory(id) == cat then return true end
	end
	return false
end
local function getSpecificTargets(player)
	local targets = {}
	for attr, value in pairs(player:GetAttributes()) do
		local id = tostring(attr):match("^Target_(.+)")
		if id then targets[id] = value end
	end
	return targets
end
local function setTargets(player, targets)
	for attr, _ in pairs(player:GetAttributes()) do
		local id = tostring(attr):match("^Target_(.+)")
		if id then player:SetAttribute(attr, nil) end
	end
	for id, qty in pairs(targets) do player:SetAttribute("Target_"..id, qty) end
end
local function updateTargetUI(player, message, highlightIDs)
	local targets = getSpecificTargets(player)
	if next(targets) == nil then missionEvent:FireClient(player, "specificUpdate", nil, message); return end
	local progress = {}
	for targetID, need in pairs(targets) do progress[targetID] = getCart(player):GetAttribute(targetID) or 0 end
	missionEvent:FireClient(player, "specificUpdate", {targets=targets, progress=progress, highlight=highlightIDs or {}}, message)
end
local function targetTitle(targets)
	local parts = {}
	for id, qty in pairs(targets) do table.insert(parts, getProductName(id).." "..qty.."개") end
	return table.concat(parts, ", ") .. " 사오기"
end
local function makeTargetsByRound(round)
	local ids = table.clone(PRODUCT_IDS)
	local targets = {}
	local kinds = 1
	if round == 2 then kinds = 2 elseif round >= 3 then kinds = math.random(2,3) end
	local maxTotal = round == 1 and 1 or (round == 2 and 3 or 4)
	local total = 0
	for i=1,kinds do
		if #ids == 0 or total >= maxTotal then break end
		local index = math.random(1,#ids)
		local id = table.remove(ids, index)
		local remaining = maxTotal - total
		local qty = math.random(1, math.min(3, remaining))
		targets[id] = qty
		total += qty
	end
	return targets
end
local function sendChoice(player, message, choices)
	choiceEvent:FireClient(player, "show", message, choices)
end
local function sendAlert(player, message)
	choiceEvent:FireClient(player, "alert", message)
end

local CHECKOUT_CLICK_DISTANCE = 24

-- =========================================================
-- 직원 NPC 아바타 설정
-- =========================================================
-- 1) 특정 Roblox 유저 아바타를 직원 NPC에 입히고 싶으면 아래 숫자 0을 UserId로 바꾸세요.
--    예: local STAFF_AVATAR_USER_ID = 123456789
-- 2) 0이면 기본 R15 더미를 만들고, 코드로 만든 편의점 조끼를 입힙니다.
local STAFF_AVATAR_USER_ID = 10955060176

-- 직원 위치/방향입니다. 기존 직원 위치와 맞춰두었습니다.
-- 계산대 방향이 반대면 STAFF_Y_ROTATION_DEGREES를 0 또는 180으로 바꿔보세요.
local STAFF_POSITION = Vector3.new(-18, 21, -22)
local STAFF_Y_ROTATION_DEGREES = 180

-- 코드로 GS25 느낌의 조끼/명찰을 얹을지 여부입니다.
-- true면 별도 무료 에셋 없이도 파란 조끼 + 민트 포인트 + 명찰이 생깁니다.
local USE_CODE_UNIFORM = true

-- 마켓플레이스/직접 업로드한 Shirt/Pants 에셋 ID가 있으면 여기에 넣으세요.
-- 0이면 사용하지 않습니다. 정확한 옷 이미지는 보통 Shirt/Pants 에셋 ID가 있어야 가장 예쁩니다.
local CUSTOM_SHIRT_ID = 0
local CUSTOM_PANTS_ID = 0

-- STAFF_AVATAR_USER_ID를 쓸 때 기존 아바타의 상하의를 지울지 여부입니다.
-- 지금은 false로 둡니다. true로 하면 아바타 옷이 사라져서 몸만 남아 보일 수 있습니다.
local STRIP_AVATAR_CLOTHES_FOR_CODE_UNIFORM = false

local CHECKOUT_OBJECT_NAMES = {
	["계산대"] = true,
	["카운터"] = true,
	["계산카운터"] = true,
	["CheckoutCounter"] = true,
	["Checkout"] = true,
	["Counter"] = true,
	["CashierCounter"] = true,
	["Register"] = true,
	["CashRegister"] = true,
	["ConveyorCounter"] = true,
	["POS"] = true,
}

local function addCheckoutClickDetector(part, detectors)
	if not part or not part:IsA("BasePart") then return end

	part.CanQuery = true

	local cd = part:FindFirstChild("CheckoutClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.Name = "CheckoutClickDetector"
		cd.Parent = part
	end

	cd.MaxActivationDistance = CHECKOUT_CLICK_DISTANCE
	table.insert(detectors, cd)
end

local function addClickDetectorsToObject(obj, detectors)
	if not obj then return end

	if obj:IsA("BasePart") then
		addCheckoutClickDetector(obj, detectors)
	end

	for _, v in ipairs(obj:GetDescendants()) do
		if v:IsA("BasePart") then
			addCheckoutClickDetector(v, detectors)
		end
	end
end

local function createCheckoutClickArea(detectors)
	local existing = workspace:FindFirstChild("CheckoutClickArea")
	if existing and existing:IsA("BasePart") then
		existing:Destroy()
	end

	-- 계산대 앞쪽을 넓게 덮는 투명 클릭 영역입니다.
	-- 실제 계산대 위치가 다르면 Position만 계산대 중앙으로 조금 옮기면 됩니다.
	local area = Instance.new("Part")
	area.Name = "CheckoutClickArea"
	area.Size = Vector3.new(9, 7, 7)
	area.Position = Vector3.new(-18, 21.5, -20)
	area.Anchored = true
	area.Transparency = 1
	area.CanCollide = false
	area.CanTouch = false
	area.CanQuery = true
	area.Parent = workspace

	addCheckoutClickDetector(area, detectors)
end

local function addExistingCounterClickDetectors(detectors)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if CHECKOUT_OBJECT_NAMES[obj.Name] then
			addClickDetectorsToObject(obj, detectors)
		end
	end
end

local function safeSetDescriptionNumber(description, propertyName, value)
	pcall(function()
		description[propertyName] = value
	end)
end

local function makeDefaultStaffDescription()
	local description = Instance.new("HumanoidDescription")

	-- 기본 R15 체형 비율입니다. 너무 크거나 작으면 여기 숫자를 조정하세요.
	safeSetDescriptionNumber(description, "HeightScale", 1.0)
	safeSetDescriptionNumber(description, "WidthScale", 0.9)
	safeSetDescriptionNumber(description, "DepthScale", 0.9)
	safeSetDescriptionNumber(description, "HeadScale", 1.0)
	safeSetDescriptionNumber(description, "BodyTypeScale", 0.15)
	safeSetDescriptionNumber(description, "ProportionScale", 0.0)

	-- 기본 색상: 얼굴/손은 살구색, 상체는 흰색, 다리는 베이지색 느낌으로 둡니다.
	pcall(function()
		description.HeadColor = Color3.fromRGB(234, 184, 146)
		description.LeftArmColor = Color3.fromRGB(245, 245, 245)
		description.RightArmColor = Color3.fromRGB(245, 245, 245)
		description.TorsoColor = Color3.fromRGB(245, 245, 245)
		description.LeftLegColor = Color3.fromRGB(204, 176, 132)
		description.RightLegColor = Color3.fromRGB(204, 176, 132)
	end)

	return description
end

local function getStaffHumanoidDescription()
	local description

	if STAFF_AVATAR_USER_ID and STAFF_AVATAR_USER_ID > 0 then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(STAFF_AVATAR_USER_ID)
		end)

		if ok and result then
			description = result
		else
			warn("직원 아바타 UserId를 불러오지 못해서 기본 R15 더미로 생성합니다.", result)
			description = makeDefaultStaffDescription()
		end
	else
		description = makeDefaultStaffDescription()
	end

	-- 코드 조끼를 입힐 때 기존 아바타 셔츠/바지가 겹치면 지저분할 수 있어 제거합니다.
	if USE_CODE_UNIFORM and STRIP_AVATAR_CLOTHES_FOR_CODE_UNIFORM then
		safeSetDescriptionNumber(description, "Shirt", 0)
		safeSetDescriptionNumber(description, "Pants", 0)
		safeSetDescriptionNumber(description, "GraphicTShirt", 0)
	end

	-- 직접 만든 Shirt/Pants 에셋 ID가 있으면 코드 조끼보다 우선 적용됩니다.
	if CUSTOM_SHIRT_ID and CUSTOM_SHIRT_ID > 0 then
		safeSetDescriptionNumber(description, "Shirt", CUSTOM_SHIRT_ID)
	end
	if CUSTOM_PANTS_ID and CUSTOM_PANTS_ID > 0 then
		safeSetDescriptionNumber(description, "Pants", CUSTOM_PANTS_ID)
	end

	return description
end

local function removeRuntimeScripts(model)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		end
	end
end

local function setupHumanoid(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
end

local function freezeStaffModel(model)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = true
		end
	end
end

local function addSurfaceText(part, text, textColor, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TextSurface"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(256, 128)
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = textSize or 42
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function makeUniformPart(parent, name, torso, size, localCFrame, color, material)
	if not torso then return nil end

	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = torso.CFrame * localCFrame
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Massless = true
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part

	return part
end

local function applyCodeUniform(model)
	if not USE_CODE_UNIFORM then return end

	local upperTorso = model:FindFirstChild("UpperTorso", true)
	local lowerTorso = model:FindFirstChild("LowerTorso", true)
	if not upperTorso then return end

	local uniformFolder = Instance.new("Folder")
	uniformFolder.Name = "CodeUniform"
	uniformFolder.Parent = model

	local navy = Color3.fromRGB(11, 35, 65)
	local mint = Color3.fromRGB(0, 205, 205)
	local white = Color3.fromRGB(245, 245, 245)
	local badgeWhite = Color3.fromRGB(255, 255, 255)
	local badgeBlue = Color3.fromRGB(25, 85, 180)
	local yellow = Color3.fromRGB(255, 210, 30)

	-- R15 기준: 몸 앞면은 로컬 -Z 방향입니다.
	makeUniformPart(uniformFolder, "VestFrontLeft", upperTorso, Vector3.new(0.95, 1.55, 0.07), CFrame.new(-0.48, -0.05, -0.53), navy)
	makeUniformPart(uniformFolder, "VestFrontRight", upperTorso, Vector3.new(0.95, 1.55, 0.07), CFrame.new(0.48, -0.05, -0.53), navy)
	makeUniformPart(uniformFolder, "VestBack", upperTorso, Vector3.new(1.95, 1.55, 0.07), CFrame.new(0, -0.05, 0.53), navy)
	makeUniformPart(uniformFolder, "VestLeftSide", upperTorso, Vector3.new(0.07, 1.45, 0.9), CFrame.new(-1.03, -0.08, 0), navy)
	makeUniformPart(uniformFolder, "VestRightSide", upperTorso, Vector3.new(0.07, 1.45, 0.9), CFrame.new(1.03, -0.08, 0), navy)

	-- 사진처럼 한쪽 어깨에 민트 포인트를 넣습니다.
	makeUniformPart(uniformFolder, "MintShoulderPanel", upperTorso, Vector3.new(0.72, 0.48, 0.08), CFrame.new(-0.63, 0.48, -0.58), mint)
	makeUniformPart(uniformFolder, "MintZipLine", upperTorso, Vector3.new(0.055, 1.55, 0.09), CFrame.new(0, -0.08, -0.6), mint)

	-- 아래쪽까지 조끼가 살짝 이어져 보이게 합니다.
	if lowerTorso then
		makeUniformPart(uniformFolder, "VestLowerFront", lowerTorso, Vector3.new(1.6, 0.45, 0.07), CFrame.new(0, 0.22, -0.5), navy)
		makeUniformPart(uniformFolder, "VestLowerZip", lowerTorso, Vector3.new(0.055, 0.45, 0.08), CFrame.new(0, 0.22, -0.56), mint)
	end

	-- GS25 느낌 로고. 실제 로고 이미지는 아니고 텍스트로 구현한 버전입니다.
	local logo = makeUniformPart(uniformFolder, "GS25TextPatch", upperTorso, Vector3.new(0.45, 0.2, 0.09), CFrame.new(0.48, 0.45, -0.62), mint)
	if logo then
		addSurfaceText(logo, "GS25", yellow, 34)
	end

	-- 명찰
	local badge = makeUniformPart(uniformFolder, "NameBadge", upperTorso, Vector3.new(0.48, 0.26, 0.09), CFrame.new(0.52, 0.18, -0.63), badgeWhite)
	if badge then
		addSurfaceText(badge, "직원", badgeBlue, 32)
	end

	-- 흰색 티셔츠 느낌을 위해 목 주변 작은 패널을 추가합니다.
	makeUniformPart(uniformFolder, "WhiteCollar", upperTorso, Vector3.new(0.65, 0.22, 0.08), CFrame.new(0, 0.62, -0.61), white)
end

local function buildFallbackBlockStaff()
	local model = Instance.new("Model")
	model.Name = "Staff"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = STAFF_POSITION
	root.BrickColor = BrickColor.new("Bright blue")
	root.Anchored = true
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Position = STAFF_POSITION + Vector3.new(0, 2.75, 0)
	head.BrickColor = BrickColor.new("Pastel brown")
	head.Anchored = true
	head.Parent = model

	local legL = Instance.new("Part")
	legL.Name = "LegL"
	legL.Size = Vector3.new(0.9, 2, 0.9)
	legL.Position = STAFF_POSITION + Vector3.new(0.6, -1, 0)
	legL.BrickColor = BrickColor.new("Dark blue")
	legL.Anchored = true
	legL.Parent = model

	local legR = Instance.new("Part")
	legR.Name = "LegR"
	legR.Size = Vector3.new(0.9, 2, 0.9)
	legR.Position = STAFF_POSITION + Vector3.new(-0.6, -1, 0)
	legR.BrickColor = BrickColor.new("Dark blue")
	legR.Anchored = true
	legR.Parent = model

	local armL = Instance.new("Part")
	armL.Name = "ArmL"
	armL.Size = Vector3.new(0.55, 2, 0.55)
	armL.Position = STAFF_POSITION + Vector3.new(1.35, 0.05, 0)
	armL.BrickColor = BrickColor.new("Pastel brown")
	armL.Anchored = true
	armL.Parent = model

	local armR = Instance.new("Part")
	armR.Name = "ArmR"
	armR.Size = Vector3.new(0.55, 2, 0.55)
	armR.Position = STAFF_POSITION + Vector3.new(-1.35, 0.05, 0)
	armR.BrickColor = BrickColor.new("Pastel brown")
	armR.Anchored = true
	armR.Parent = model

	model.PrimaryPart = root
	model.Parent = workspace
	return model
end

local function forceCharacterBodyVisible(model)
	-- UserId 아바타를 불러왔는데 얼굴/팔/다리가 투명하게 보이는 경우를 막습니다.
	-- HumanoidRootPart는 원래 투명해야 해서 제외합니다.
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			if obj.Name ~= "HumanoidRootPart" then
				obj.Transparency = 0
			end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 0
		end
	end
end

local function countVisibleCharacterParts(model)
	local count = 0
	local names = {
		Head = true,
		-- R15 body parts
		UpperTorso = true, LowerTorso = true,
		LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
		RightUpperArm = true, RightLowerArm = true, RightHand = true,
		LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
		RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
		-- R6 body parts, in case Roblox creates the user's avatar as R6
		Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	}

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") and names[obj.Name] and obj.Transparency < 1 then
			count += 1
		end
	end

	return count
end

local function getStaffModel()
	return workspace:FindFirstChild("Staff") or workspace:FindFirstChild("직원")
end

local function hasStaffClickDetector(model)
	if not model then return false end
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("ClickDetector") and obj.Name == "CheckoutClickDetector" then
			return true
		end
	end
	return false
end

local function makeStaffVisibleAndFixed(model)
	if not model or not model:IsA("Model") then return false end

	-- Use the ASCII name Staff so lookup is stable even if Korean source encoding changes.
	model.Name = "Staff"
	model.Parent = workspace

	local root = model:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		model:PivotTo(CFrame.new(STAFF_POSITION) * CFrame.Angles(0, math.rad(STAFF_Y_ROTATION_DEGREES), 0))
	end

	setupHumanoid(model)
	forceCharacterBodyVisible(model)
	freezeStaffModel(model)

	return countVisibleCharacterParts(model) >= 3
end

local function createStaffModelFromUserId()
	if not STAFF_AVATAR_USER_ID or STAFF_AVATAR_USER_ID <= 0 then
		return nil
	end

	-- 가장 안정적인 방식: 유저 ID로 완성된 캐릭터 모델을 바로 생성합니다.
	local ok, modelOrError = pcall(function()
		return Players:CreateHumanoidModelFromUserId(STAFF_AVATAR_USER_ID)
	end)

	if ok and modelOrError then
		return modelOrError
	end

	warn("CreateHumanoidModelFromUserId 실패. HumanoidDescription 방식으로 다시 시도합니다.", modelOrError)
	return nil
end

local function createStaffModelFromDescription()
	local description = getStaffHumanoidDescription()
	local ok, modelOrError = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)

	if ok and modelOrError then
		return modelOrError
	end

	warn("CreateHumanoidModelFromDescription 실패. 기본 블록 직원으로 대체합니다.", modelOrError)
	return nil
end

local function buildStaffAvatarModel()
	local model = createStaffModelFromUserId() or createStaffModelFromDescription()

	if not model then
		return buildFallbackBlockStaff()
	end

	model.Name = "Staff"
	model.Parent = workspace

	-- 아바타 파츠가 생성 직후 살짝 늦게 들어오는 경우가 있어 한 프레임 기다립니다.
	task.wait(0.2)

	local root = model:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end

	removeRuntimeScripts(model)
	setupHumanoid(model)
	forceCharacterBodyVisible(model)

	-- 여전히 머리/팔/다리가 거의 없다면 UserId 아바타 생성이 깨진 상태이므로 기본 R15로 다시 만듭니다.
	-- R6 아바타는 파츠 수가 적어서 기준을 6으로 둡니다.
	if countVisibleCharacterParts(model) < 6 then
		warn("UserId 아바타의 몸 파츠가 충분히 생성되지 않아 기본 R15 직원으로 다시 생성합니다.")
		model:Destroy()
		model = createStaffModelFromDescription() or buildFallbackBlockStaff()
		model.Name = "Staff"
		model.Parent = workspace
		task.wait(0.2)
		root = model:FindFirstChild("HumanoidRootPart", true)
		if root and root:IsA("BasePart") then
			model.PrimaryPart = root
		end
		removeRuntimeScripts(model)
		setupHumanoid(model)
		forceCharacterBodyVisible(model)
	end

	model:PivotTo(CFrame.new(STAFF_POSITION) * CFrame.Angles(0, math.rad(STAFF_Y_ROTATION_DEGREES), 0))
	applyCodeUniform(model)
	freezeStaffModel(model)

	return model
end

local function buildStaff()
	local existingKorean = workspace:FindFirstChild("직원")
	if existingKorean then existingKorean:Destroy() end

	-- 혹시 이전에 영어 이름 Staff로 만든 모델이 있으면 같이 정리합니다.
	local existingEnglish = workspace:FindFirstChild("Staff")
	if existingEnglish then existingEnglish:Destroy() end

	local model = buildStaffAvatarModel()

	local detectors = {}

	-- NPC 머리뿐 아니라 몸/팔/다리 어디를 눌러도 계산 시작
	addClickDetectorsToObject(model, detectors)

	-- 실제 계산대 이름: CashRegister, ConveyorCounter 전체 클릭 가능
	-- 그 외 계산대/카운터 후보 이름도 같이 지원합니다.
	addExistingCounterClickDetectors(detectors)

	-- 계산대 앞 투명 클릭 영역까지 추가해서 클릭 판정을 넓힙니다.
	createCheckoutClickArea(detectors)

	return detectors
end

local function resetRoundState(player)
	clearCart(player, true)
	player:SetAttribute("NeedsBag", false)
	player:SetAttribute("CouponValue", nil)
	player:SetAttribute("CouponLack", nil)
	player:SetAttribute("CashAmountDue", nil)
	player:SetAttribute("CashContext", nil)
	player:SetAttribute("AfterBag", nil)
	player:SetAttribute("PendingCompletion", nil)
	player:SetAttribute("LastCardIncident", nil)
	player:SetAttribute("CouponSecondEvent", nil)
	player:SetAttribute("ComboIncidentCount", 0)
	setTargets(player, {})
end

local ensureStaffAvailable

local function missionLineFor(player, mode, round, targets)
	local paymentText = "계산하기"
	if mode == MODE.CASH then paymentText = "현금으로 계산하기"
	elseif mode == MODE.CARD then paymentText = "카드로 계산하기"
	elseif mode == MODE.COUPON then paymentText = "모바일 쿠폰으로 계산하기"
	elseif mode == MODE.COMBO then paymentText = "상황에 맞는 결제수단으로 계산하기" end

	return targetTitle(targets or {}) .. " · " .. paymentText
end
local function startMissionRound(player, mode, round)
	if ensureStaffAvailable then ensureStaffAvailable() end
	resetRoundState(player)
	player:SetAttribute("MissionMode", mode)
	player:SetAttribute("MissionRound", round)
	player:SetAttribute("MissionStep", "SHOPPING")
	local data = {line="", targets=nil, progress={}}
	local msg = MODE_NAME[mode].." "..round.."회차 시작!"

	player:SetAttribute("Budget", 0)
	player:SetAttribute("BudgetGoal", "")
	local targets = makeTargetsByRound(round)
	setTargets(player, targets)
	data.targets = targets
	data.line = missionLineFor(player, mode, round, targets)

	missionEvent:FireClient(player, "start", data, msg)
	updateTargetUI(player)
end
local function setWaitingMission(player)
	resetRoundState(player)
	player:SetAttribute("MissionMode", 0)
	player:SetAttribute("MissionRound", 0)
	player:SetAttribute("MissionStep", "")
	player:SetAttribute("Budget", 0)
	missionEvent:FireClient(player, "resetStart", nil, nil)
end

local function completeRound(player, message)
	local mode = player:GetAttribute("MissionMode") or 0
	local round = player:GetAttribute("MissionRound") or 1
	player:SetAttribute("Score", (player:GetAttribute("Score") or 0) + 100)
	player:SetAttribute("TotalSuccess", (player:GetAttribute("TotalSuccess") or 0) + 1)
	local counter = MODE_COUNTER[mode]
	if counter then player:SetAttribute(counter, (player:GetAttribute(counter) or 0) + 1) end
	clearCart(player, true)
	player:SetAttribute("MissionStep", "DONE")
	local final = round >= 3
	missionEvent:FireClient(player, "showComplete", {isFinalRound=final, successText=(MODE_NAME[mode] or "미션").." "..round.."/3 성공!"}, message or "계산이 끝났어요. 상품을 챙겨주세요.")
end

local function beginCashPayment(player, amount, context)
	if ensureStaffAvailable then ensureStaffAvailable() end
	player:SetAttribute("MissionStep", "CASH_PAYMENT")
	player:SetAttribute("CashAmountDue", amount)
	player:SetAttribute("CashContext", context)
	-- 현금 결제창만 띄워 창 중복을 막는다.
	billEvent:FireClient(player, "cash", amount)
end
local function askBudgetRemaining(player)
	local budget = player:GetAttribute("Budget") or 0
	local total = calcFinalTotal(player, false)
	player:SetAttribute("MissionStep", "BUDGET_INPUT")
	choiceEvent:FireClient(player, "budgetInput", budget, total)
end
local function askBag(player, nextAfterBag)
	player:SetAttribute("MissionStep", "BAG")
	player:SetAttribute("AfterBag", nextAfterBag)
	sendChoice(player, "봉투 100원인데 필요하신가요?", {{id="bag_yes", text="네, 주세요."},{id="bag_no", text="아니요, 괜찮아요."}})
end
local function showBudgetOverBag(player)
	local budget = player:GetAttribute("Budget") or 0
	local totalWithBag = calcProductTotal(player,false) + BAG_PRICE
	sendChoice(player, "물건이 여러 개라 봉투가 있으면 들고 가기 편해요.\n하지만 봉투를 추가하면 총 "..totalWithBag.."원이어서 예산 "..budget.."원을 초과해요.\n어떻게 할까요?", {
		{id="bag_without", text="봉투 없이 결제할래요"},
		{id="bag_remove_item", text="상품을 하나 빼고 봉투를 살래요"},
	})
end
local function showCartRemoveChoices(player, context)
	local choices = {}
	for cartID, qty in pairs(getCart(player):GetAttributes()) do
		if qty > 0 then table.insert(choices, {id="remove:"..context..":"..cartID, text=getProductName(cartID).." 1개 빼기"}) end
	end
	if #choices == 0 then table.insert(choices, {id="cancel_remove", text="돌아가기"}) end
	sendChoice(player, "어떤 상품을 뺄까요?", choices)
end
local function validateTargets(player)
	local cart = getCart(player)
	local targets = getSpecificTargets(player)
	local missing, wrong, over = {}, {}, {}
	for id, need in pairs(targets) do
		local got = cart:GetAttribute(id) or 0
		if got < need then missing[id] = need-got end
		if got > need then over[id] = got-need end
	end
	for id, qty in pairs(cart:GetAttributes()) do if not targets[id] and qty > 0 then wrong[id] = qty end end
	return missing, wrong, over
end
local function validateBudgetGoal(player)
	local goal = player:GetAttribute("BudgetGoal") or "ANY1"
	local count = cartCount(player)
	if goal == "ANY1" then return count >= 1, "상품을 1개 이상 골라주세요." end
	if goal == "ANY2" then return count >= 2, "상품을 2개 골라주세요." end
	if goal == "DRINK_SNACK" then
		if not hasCategory(player,"drink") or not hasCategory(player,"snack") then return false, "음료 1개와 간식 1개를 골라주세요.\n음료와 간식 그림 힌트를 보고 다시 골라볼까요?" end
		return true, ""
	end
	return true, ""
end
local function sendHintForCurrentMission(player)
	local ids = {}
	local targets = getSpecificTargets(player)
	local message = "필요한 상품 위치에 노란 화살표를 표시했어요."
	for id, need in pairs(targets) do
		local got = getCart(player):GetAttribute(id) or 0
		if got < need then table.insert(ids, id) end
	end
	if #ids == 0 then
		for _, id in ipairs(PRODUCT_IDS) do table.insert(ids, id) end
		message = "노란 바닥 화살표 방향으로 이동하세요."
	end
	missionEvent:FireClient(player, "hint", {ids=ids}, message)
end
local function getCouponValue(total, round)
	if round == 2 then return total + 200 end
	if round >= 3 then return math.max(1000, total - 500) end
	local r = math.random(1,3)
	if r == 1 then return math.max(1000,total-500) elseif r == 2 then return total else return total+200 end
end
local function proceedCouponCheck(player)
	local total = calcFinalTotal(player, shouldIgnorePromo(player))
	local coupon = player:GetAttribute("CouponValue") or getCouponValue(total, player:GetAttribute("MissionRound") or 1)
	player:SetAttribute("CouponValue", coupon)
	if coupon < total then
		local lack = total - coupon
		player:SetAttribute("CouponLack", lack)
		sendChoice(player, "쿠폰으로 "..coupon.."원이 결제돼요.\n총 금액은 "..total.."원이라 "..lack.."원이 부족해요.\n어떻게 할까요?", {
			{id="coupon_lack_card", text="카드로 "..lack.."원 결제"},
			{id="coupon_lack_cash", text="현금으로 "..lack.."원 결제"},
			{id="coupon_lack_remove", text="상품을 하나 뺄래요"},
		})
	elseif coupon > total then
		local remain = coupon - total
		sendChoice(player, "쿠폰으로 결제하면 남은 "..remain.."원은 돌려받을 수 없어요.\n그래도 결제할까요?", {
			{id="coupon_pay_anyway", text="그래도 쿠폰으로 결제할래요"},
			{id="coupon_other_pay", text="다른 결제수단을 고를래요"},
		})
	else
		completeRound(player, "쿠폰으로 정확히 결제했어요. 상품을 챙겨주세요.")
	end
end
local function beginCouponPayment(player)
	if ensureStaffAvailable then ensureStaffAvailable() end
	local total = calcFinalTotal(player, shouldIgnorePromo(player))
	local round = player:GetAttribute("MissionRound") or 1
	player:SetAttribute("CouponValue", getCouponValue(total, round))
	player:SetAttribute("CouponBrightnessSeen", true)
	player:SetAttribute("MissionStep", "PHONE_BRIGHTNESS")
	choiceEvent:FireClient(player, "phoneBrightness", "화면이 어두워서 바코드가 잘 안 보여요. 밝기 바를 90% 이상 오른쪽으로 올린 뒤 바코드 스캔하기를 눌러주세요.")
end
local function chooseCardIncident(player)
	local round = player:GetAttribute("MissionRound") or 1
	if round == 1 and not player:GetAttribute("CardDirectionSeen") then return "direction" end
	local options = {"direction","read_fail","balance_low"}
	return options[math.random(1,#options)]
end
local function beginCardPayment(player)
	if ensureStaffAvailable then ensureStaffAvailable() end
	local incident = chooseCardIncident(player)
	player:SetAttribute("LastCardIncident", incident)
	if incident == "direction" then
		player:SetAttribute("CardDirectionSeen", true)
		player:SetAttribute("MissionStep", "CARD_UI")
		choiceEvent:FireClient(player, "cardUI", "IC칩이 위쪽을 향하게 카드를 누르고, 슬롯 안쪽까지 밀어 넣어볼까요?")
	elseif incident == "read_fail" then
		player:SetAttribute("MissionStep", "CARD_READ_FAIL")
		sendChoice(player, "카드가 잘 인식되지 않았어요. 다시 한 번 시도해볼까요?", {
			{id="card_retry_once", text="카드 다시 시도"},
			{id="card_to_cash", text="현금으로 결제"},
			{id="card_to_coupon", text="쿠폰으로 결제"},
		})
	elseif incident == "balance_low" then
		player:SetAttribute("MissionStep", "CARD_FAILED")
		sendChoice(player, "카드 잔액이 부족해서 결제가 되지 않았어요.\n다른 결제수단으로 전체 금액을 결제해볼까요?", {
			{id="card_to_cash", text="현금으로 결제"},
			{id="card_to_coupon", text="쿠폰으로 결제"},
		})
	else
		completeRound(player, "카드 결제가 완료됐어요. 상품을 챙겨주세요.")
	end
end
local function proceedAfterBag(player)
	if ensureStaffAvailable then ensureStaffAvailable() end
	local after = player:GetAttribute("AfterBag") or "modePayment"
	local mode = player:GetAttribute("MissionMode") or 0
	if after == "budget" then
		askBudgetRemaining(player)
	elseif after == "modePayment" then
		if mode == MODE.CASH then
			beginCashPayment(player, calcFinalTotal(player, true), "cash")
		elseif mode == MODE.CARD then
			beginCardPayment(player)
		elseif mode == MODE.COUPON then
			beginCouponPayment(player)
		elseif mode == MODE.COMBO then
			player:SetAttribute("MissionStep", "PAYMENT_SELECT")
			sendChoice(player, "총 "..calcFinalTotal(player,false).."원입니다.\n뭘로 결제하시겠어요?", {
				{id="pay_card", text="카드로 결제"}, {id="pay_cash", text="현금으로 결제"}, {id="pay_coupon", text="쿠폰으로 결제"},
			})
		end
	elseif after == "comboPayment" then
		player:SetAttribute("MissionStep", "PAYMENT_SELECT")
		sendChoice(player, "총 "..calcFinalTotal(player,false).."원입니다.\n뭘로 결제하시겠어요?", {
			{id="pay_card", text="카드로 결제"}, {id="pay_cash", text="현금으로 결제"}, {id="pay_coupon", text="쿠폰으로 결제"},
		})
	end
end

local function handleCheckoutClick(player)
	if ensureStaffAvailable then ensureStaffAvailable() end
	local mode = player:GetAttribute("MissionMode") or 0
	local step = player:GetAttribute("MissionStep") or ""
	local hasItem = next(getCart(player):GetAttributes()) ~= nil

	if mode == 0 then
		talkEvent:FireClient(player, "먼저 화면 왼쪽에서 미션을 선택해주세요.")
		return
	end

	if step ~= "SHOPPING" then
		talkEvent:FireClient(player, "현재 화면의 선택을 먼저 완료해주세요.")
		return
	end

	if not hasItem then
		talkEvent:FireClient(player, "상품을 하나 이상 담아 오시면 계산해드릴게요.")
		return
	end

	local missing, wrong, over = validateTargets(player)

	if next(missing) ~= nil then
		local msgLines = {"아직 필요한 상품이 부족해요."}
		local highlight = {}

		for id, cnt in pairs(missing) do
			table.insert(msgLines, getProductName(id).." "..cnt.."개 더")
			table.insert(highlight, id)
		end

		table.insert(msgLines, "반짝이는 상품을 찾아서 담아보세요.")
		updateTargetUI(player, table.concat(msgLines, "\n"), highlight)
		return
	end

	if next(wrong) ~= nil then
		showCartRemoveChoices(player, "targetWrong")
		return
	end

	if next(over) ~= nil then
		showCartRemoveChoices(player, "targetOver")
		return
	end

	if mode == MODE.CASH then
		beginCashPayment(player, calcFinalTotal(player, true), "cash")
	elseif mode == MODE.CARD then
		beginCardPayment(player)
	elseif mode == MODE.COUPON then
		beginCouponPayment(player)
	else
		player:SetAttribute("MissionStep", "PAYMENT_SELECT")
		sendChoice(player, "어떻게 계산하시겠어요?", {
			{id="pay_card", text="카드로 계산"},
			{id="pay_cash", text="현금으로 계산"},
			{id="pay_coupon", text="모바일 쿠폰으로 계산"},
		})
	end
end

local checkoutClickDetectors = {}
local function connectCheckoutDetectors(detectors)
	for _, cd in ipairs(detectors) do
		if cd and cd.Parent and not cd:GetAttribute("StaffManagerConnected") then
			cd:SetAttribute("StaffManagerConnected", true)
			cd.MouseClick:Connect(handleCheckoutClick)
		end
	end
end
local function rebuildStaffDetectors()
	checkoutClickDetectors = buildStaff()
	connectCheckoutDetectors(checkoutClickDetectors)
end
local staffRebuildInProgress = false
ensureStaffAvailable = function()
	if staffRebuildInProgress then return end

	local staffModel = getStaffModel()
	local visibleEnough = false

	if staffModel and staffModel.Parent then
		visibleEnough = makeStaffVisibleAndFixed(staffModel)
	end

	-- Rebuild immediately if the NPC is missing, invisible, unclickable, or the checkout click area is gone.
	if not visibleEnough or not hasStaffClickDetector(staffModel) or not workspace:FindFirstChild("CheckoutClickArea") then
		staffRebuildInProgress = true
		rebuildStaffDetectors()
		staffRebuildInProgress = false
	end
end

-- Create once at server start.
rebuildStaffDetectors()

-- Watchdog: keeps the Staff avatar alive through cash/card/coupon/combo mission UI transitions.
task.spawn(function()
	while true do
		task.wait(1)
		if ensureStaffAvailable then
			ensureStaffAvailable()
		end
	end
end)

pickupEvent.OnServerEvent:Connect(function(player, uniqueID, cartID, productName, price)
	local mode = player:GetAttribute("MissionMode") or 0
	local step = player:GetAttribute("MissionStep") or ""
	if mode == 0 then talkEvent:FireClient(player, "먼저 미션을 선택해주세요."); return end
	if step ~= "SHOPPING" then talkEvent:FireClient(player, "지금은 상품을 담을 수 없어요. 먼저 현재 질문을 완료해주세요."); return end
	cartID = cartID or getCartBaseID(uniqueID)
	productName = productName or getProductName(cartID)
	price = tonumber(price) or getPrice(cartID)
	if not isProductVisible(uniqueID) then return end
	do
		local budget = player:GetAttribute("Budget") or 0
		if budget > 0 then
			local cart = getCart(player)
			local before = cart:GetAttribute(cartID) or 0
			cart:SetAttribute(cartID, before + 1)
			local newTotal = calcProductTotal(player, false)
			if before == 0 then cart:SetAttribute(cartID, nil) else cart:SetAttribute(cartID, before) end
			if newTotal > budget then
				local over = newTotal - budget
				talkEvent:FireClient(player, "이 상품을 담으면 총 "..newTotal.."원이 돼요.\n오늘 예산 "..budget.."원을 "..over.."원 초과해서 담을 수 없어요.\n더 저렴한 상품을 골라볼까요?")
				return
			end
		end
	end
	local cart = getCart(player)
	cart:SetAttribute(cartID, (cart:GetAttribute(cartID) or 0) + 1)
	setProductVisible(uniqueID, false)
	recordPickedItem(player, uniqueID, cartID)
	pickupEvent:FireClient(player, "cartAdd", uniqueID, cartID, productName, price)
	local modeSpecific = (next(getSpecificTargets(player)) ~= nil)
	if modeSpecific then
		updateTargetUI(player, productName.."을(를) 담았어요.")
	else
		local budget = player:GetAttribute("Budget") or 0
		local msg = productName.."을(를) 담았어요.\n현재 금액: "..calcProductTotal(player,false).."원"
		if budget > 0 then msg ..= " / 예산: "..budget.."원" end
		missionEvent:FireClient(player, "pickup", nil, msg)
	end
	if (player:GetAttribute("Budget") or 0) > 0 and PROMOS[cartID] then
		local qty = getCart(player):GetAttribute(cartID) or 0
		local paid, free = promoPaidQty(cartID, qty, false)
		if free > 0 then
			local promoText = PROMOS[cartID] == "ONE_PLUS_ONE" and "1+1" or "2+1"
			local originalLine = getProductName(cartID).." "..qty.."개: "..(getPrice(cartID) * qty).."원"
			local saleLine = getProductName(cartID).." "..qty.."개: "..(getPrice(cartID) * paid).."원"
			sendAlert(player, promoText.." 행사가 적용됐어요!\n"..originalLine.." → "..saleLine.."\n"..free.."개가 무료예요.")
		elseif visibleStock(cartID) > 0 then
			local promoText = PROMOS[cartID] == "ONE_PLUS_ONE" and "1+1" or "2+1"
			missionEvent:FireClient(player, "pickup", nil, promoText.." 행사 상품이에요. 조건을 맞추면 무료 상품이 적용돼요.")
		end
	end
end)

cartUpdateEvent.OnServerEvent:Connect(function(player, action, cartID)
	if action == "clear" then clearCart(player, true); updateTargetUI(player); return end
	if action ~= "removeOneBase" or not cartID then return end
	local cart = getCart(player)
	local qty = cart:GetAttribute(cartID)
	if not qty then return end
	if qty > 1 then cart:SetAttribute(cartID, qty - 1) else cart:SetAttribute(cartID, nil) end
	removeOnePickedItem(player, cartID)
	pickupEvent:FireClient(player, "cartRemove", cartID)
	updateTargetUI(player, "장바구니를 수정했어요.")
end)

local function finishCashContext(player)
	local context = player:GetAttribute("CashContext") or ""
	if context == "cash" then completeRound(player, "현금 결제와 거스름돈 계산까지 완료했어요. 상품을 챙겨주세요.")
	elseif context == "couponLack" then completeRound(player, "쿠폰 차액을 현금으로 결제했어요. 상품을 챙겨주세요.")
	elseif context == "cardFallback" then completeRound(player, "카드 대신 현금으로 결제했어요. 상품을 챙겨주세요.")
	elseif context == "combo" then
		player:SetAttribute("MissionStep", "RECEIPT")
		sendChoice(player, "결제되었습니다.\n영수증 필요하세요?", {{id="receipt_yes", text="네, 받을게요"},{id="receipt_no", text="아니요, 괜찮아요"}})
	else completeRound(player, "현금 결제가 완료됐어요. 상품을 챙겨주세요.") end
end
payEvent.OnServerEvent:Connect(function(player, paid, answer)
	finishCashContext(player)
end)

choiceEvent.OnServerEvent:Connect(function(player, choiceID)
	local step = player:GetAttribute("MissionStep") or ""
	if choiceID == "budget_answer_ok" then completeRound(player, "예산에서 남은 돈을 잘 계산했어요. 상품을 챙겨주세요."); return end
	if choiceID == "card_direction_ok" then completeRound(player, "카드 방향을 맞춰 결제했어요. 상품을 챙겨주세요."); return end
	if choiceID == "phone_brightness_ok" then completeRound(player, "삑! 바코드가 스캔되어 쿠폰 결제가 완료됐어요. 상품을 챙겨주세요."); return end
	if choiceID == "card_retry_once" then
		player:SetAttribute("MissionStep", "CARD_UI")
		choiceEvent:FireClient(player, "cardUI", "카드를 다시 한 번 꽂아볼게요. IC칩이 위쪽을 향하게 맞추고 슬롯 안쪽까지 밀어 넣어주세요.")
		return
	end
	if choiceID == "card_to_cash" then beginCashPayment(player, calcFinalTotal(player, shouldIgnorePromo(player)), "cardFallback"); return end
	if choiceID == "card_to_coupon" then beginCouponPayment(player); return end
	if string.sub(choiceID,1,7) == "remove:" then
		local parts = string.split(choiceID, ":")
		local ctx, cartID = parts[2], parts[3]
		if cartID then
			local cart = getCart(player)
			local qty = cart:GetAttribute(cartID)
			if qty then if qty > 1 then cart:SetAttribute(cartID, qty-1) else cart:SetAttribute(cartID, nil) end; removeOnePickedItem(player, cartID); pickupEvent:FireClient(player, "cartRemove", cartID) end
		end
		if ctx == "targetWrong" or ctx == "targetOver" then updateTargetUI(player, "좋아요. 이제 필요한 상품만 남았는지 다시 확인해보세요.")
		elseif ctx == "budgetOver" then sendAlert(player, "상품을 뺐어요. 다시 계산대로 와주세요.")
		elseif ctx == "bagRemove" then
			local budget = player:GetAttribute("Budget") or 0
			local newTotal = calcProductTotal(player,false) + BAG_PRICE
			if newTotal <= budget then sendChoice(player, "상품을 뺐어요.\n이제 봉투를 추가하면 총 "..newTotal.."원이에요.\n봉투를 추가할까요?", {{id="bag_yes_after_remove", text="봉투 추가할래요"},{id="bag_without", text="봉투 없이 결제할래요"}}) else showCartRemoveChoices(player, "bagRemove") end
		elseif ctx == "couponRemove" then proceedCouponCheck(player)
		end
		return
	end
	if step == "BAG" then
		local budget = player:GetAttribute("Budget") or 0
		if choiceID == "bag_yes" then
			local totalWithBag = calcProductTotal(player,false) + BAG_PRICE
			if budget > 0 and totalWithBag > budget then showBudgetOverBag(player) else player:SetAttribute("NeedsBag", true); proceedAfterBag(player) end
			return
		elseif choiceID == "bag_no" then
			player:SetAttribute("NeedsBag", false)
			if cartCount(player) >= 3 then sendChoice(player, "물건이 여러 개라 들고 가기 어려울 수 있어요.\n정말 봉투 없이 가져가시겠어요?", {{id="bag_no_confirm", text="네, 그냥 들고 갈래요"},{id="bag_yes", text="봉투를 살래요"}}) else proceedAfterBag(player) end
			return
		elseif choiceID == "bag_no_confirm" or choiceID == "bag_without" then player:SetAttribute("NeedsBag", false); proceedAfterBag(player); return
		elseif choiceID == "bag_remove_item" then showCartRemoveChoices(player, "bagRemove"); return
		elseif choiceID == "bag_yes_after_remove" then player:SetAttribute("NeedsBag", true); proceedAfterBag(player); return end
	end
	if step == "PAYMENT_SELECT" then
		if choiceID == "pay_card" then beginCardPayment(player)
		elseif choiceID == "pay_cash" then beginCashPayment(player, calcFinalTotal(player,false), "combo")
		elseif choiceID == "pay_coupon" then beginCouponPayment(player) end
		return
	end
	if choiceID == "coupon_lack_card" then completeRound(player, "쿠폰 차액을 카드로 결제했어요. 상품을 챙겨주세요."); return end
	if choiceID == "coupon_lack_cash" then beginCashPayment(player, player:GetAttribute("CouponLack") or 0, "couponLack"); return end
	if choiceID == "coupon_lack_remove" then showCartRemoveChoices(player, "couponRemove"); return end
	if choiceID == "coupon_pay_anyway" then completeRound(player, "쿠폰 잔액 소멸을 확인하고 결제했어요. 상품을 챙겨주세요."); return end
	if choiceID == "coupon_other_pay" then sendChoice(player, "다른 결제수단을 선택하세요.", {{id="coupon_lack_card", text="카드로 결제"},{id="coupon_lack_cash", text="현금으로 결제"}}); return end
	if choiceID == "receipt_yes" or choiceID == "receipt_no" then completeRound(player, "영수증 질문까지 완료했어요. 상품을 챙겨주세요."); return end
end)

missionProgressEvent.OnServerEvent:Connect(function(player, action)
	if action == "resetToStart" then setWaitingMission(player)
	elseif action == "hint" then sendHintForCurrentMission(player)
	elseif action == "select_cash" then player:SetAttribute("SelectedMode", MODE.CASH); startMissionRound(player, MODE.CASH, 1)
	elseif action == "select_card" then player:SetAttribute("SelectedMode", MODE.CARD); startMissionRound(player, MODE.CARD, 1)
	elseif action == "select_coupon" then player:SetAttribute("SelectedMode", MODE.COUPON); startMissionRound(player, MODE.COUPON, 1)
	elseif action == "select_combo" then player:SetAttribute("SelectedMode", MODE.COMBO); startMissionRound(player, MODE.COMBO, 1)
	elseif action == "retry" then
		local mode = player:GetAttribute("SelectedMode") or player:GetAttribute("MissionMode") or MODE.COMBO
		local round = player:GetAttribute("MissionRound") or 1
		startMissionRound(player, mode, round)
	elseif action == "next" then
		local mode = player:GetAttribute("SelectedMode") or player:GetAttribute("MissionMode") or MODE.COMBO
		local round = player:GetAttribute("MissionRound") or 1
		if round >= 3 then setWaitingMission(player) else startMissionRound(player, mode, round+1) end
	end
end)

Players.PlayerAdded:Connect(function(player)
	getCart(player); getPicked(player)
	player:SetAttribute("Score", 0)
	player:SetAttribute("TotalSuccess", 0)
	player:SetAttribute("CashSuccess", 0)
	player:SetAttribute("CardSuccess", 0)
	player:SetAttribute("CouponSuccess", 0)
	player:SetAttribute("ComboSuccess", 0)
	task.wait(0.5)
	setWaitingMission(player)
end)

print("StaffManager final v3 loaded")
