local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 기존 Products 폴더가 있으면 제거 후 재생성
local existingFolder = workspace:FindFirstChild("Products")
if existingFolder then
	existingFolder:Destroy()
end

local prodFolder = Instance.new("Folder")
prodFolder.Name = "Products"
prodFolder.Parent = workspace

local pickupEvent = ReplicatedStorage:WaitForChild("PickupItem")

local function getPrimaryPart(obj)
	if obj:IsA("Model") then
		if obj.PrimaryPart then return obj.PrimaryPart end
		for _, v in ipairs(obj:GetDescendants()) do
			if v:IsA("BasePart") then return v end
		end
	elseif obj:IsA("BasePart") then
		return obj
	end
	return nil
end

local function tagAllParts(obj, uniqueID, cartID, name, price)
	local function tag(p)
		p:SetAttribute("ProductID", uniqueID) -- 매대에 있는 실제 개별 상품 ID
		p:SetAttribute("CartID", cartID)      -- 장바구니에서 묶을 상품 ID
		p:SetAttribute("ProductName", name)
		p:SetAttribute("Price", price)
	end

	if obj:IsA("BasePart") then tag(obj) end
	for _, v in ipairs(obj:GetDescendants()) do
		if v:IsA("BasePart") then tag(v) end
	end
end

local function anchorAll(obj)
	if obj:IsA("BasePart") then obj.Anchored = true end
	for _, v in ipairs(obj:GetDescendants()) do
		if v:IsA("BasePart") then v.Anchored = true end
	end
end

local function scaleToSize(obj, targetSize)
	local primary = getPrimaryPart(obj)
	if not primary then return end

	local s = primary.Size
	local maxAxis = math.max(s.X, s.Y, s.Z)
	if maxAxis == 0 then return end

	local scale = targetSize / maxAxis

	for _, v in ipairs(obj:GetDescendants()) do
		if v:IsA("BasePart") then
			local offset = v.Position - primary.Position
			v.Size = v.Size * scale
			v.Position = primary.Position + offset * scale
		end
	end

	if obj:IsA("BasePart") then
		obj.Size = obj.Size * scale
	end
end

local function placeAt(obj, pos, rotY)
	local rot = rotY or 0

	if obj:IsA("Model") and obj.PrimaryPart then
		obj:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, rot, 0))
	else
		local primary = getPrimaryPart(obj)
		if primary then
			primary.CFrame = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
		end
	end
end


local function addClickDetector(obj, uniqueID, cartID, name, price)
	local primary = getPrimaryPart(obj)
	if not primary then return end

	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 20
	cd.Parent = primary

	cd.MouseClick:Connect(function(player)
		if primary.Transparency >= 1 then return end
		print("클릭됨:", name, "uniqueID:", uniqueID, "cartID:", cartID)
		pickupEvent:FireClient(player, uniqueID, cartID, name, price)
	end)
end

local function placeProduct(templateName, uniqueID, cartID, displayName, price, pos, targetSize, rotY)
	local template = ServerStorage:FindFirstChild(templateName)
	if not template then
		warn("? 모델 없음: " .. templateName)
		return
	end

	local clone = template:Clone()
	clone.Name = uniqueID

	scaleToSize(clone, targetSize or 2)
	placeAt(clone, pos, rotY or 0)
	anchorAll(clone)
	tagAllParts(clone, uniqueID, cartID, displayName, price)

	clone.Parent = prodFolder
	addClickDetector(clone, uniqueID, cartID, displayName, price)
end

local Y_OFFSET = 17

-- =====================
-- 과자 매대
-- =====================
local SNACK_ROT = math.rad(270)
local SNACK_X = -6.5
local SNACK_Y = {1.8 + Y_OFFSET, 4.6 + Y_OFFSET, 7.4 + Y_OFFSET}
local SNACK_Z = {-4.5, -1.5, 1.5, 4.5}

local SNACK_LIST = {
	{template="Cheetos",      id="cheetos",      name="치토스",   price=1500, rot=nil},
	{template="pringles",     id="pringles",     name="프링글스", price=2000, rot=math.rad(180)},
	{template="pocky",        id="pocky",        name="포키",     price=1500, rot=nil},
	{template="potato chips", id="potato_chips", name="감자칩",   price=1200, rot=nil},
}

for rowIdx, y in ipairs(SNACK_Y) do
	for colIdx, snack in ipairs(SNACK_LIST) do
		local uid = snack.id .. "_r" .. rowIdx .. "_c" .. colIdx
		local pos = Vector3.new(SNACK_X, y, SNACK_Z[colIdx])
		local rot = snack.rot ~= nil and snack.rot or SNACK_ROT
		placeProduct(snack.template, uid, snack.id, snack.name, snack.price, pos, 2, rot)
	end
end

-- =====================
-- 라면 매대
-- =====================
local RAMEN_ROT = math.rad(270)
local RAMEN_X = 6.5
local RAMEN_Y = {1.8 + Y_OFFSET, 4.6 + Y_OFFSET, 7.4 + Y_OFFSET}
local RAMEN_Z = {-2.5, 2.5}

local RAMEN_LIST = {
	{template="neoguri_ramen", id="neoguri", name="너구리라면",   price=1100, rot=nil},
	{template="buldak",        id="buldak",  name="불닭볶음탕면", price=1500, rot=nil},
}

for rowIdx, y in ipairs(RAMEN_Y) do
	for colIdx, item in ipairs(RAMEN_LIST) do
		local uid = item.id .. "_r" .. rowIdx .. "_c" .. colIdx
		local pos = Vector3.new(RAMEN_X, y, RAMEN_Z[colIdx])
		local rot = item.rot ~= nil and item.rot or RAMEN_ROT
		placeProduct(item.template, uid, item.id, item.name, item.price, pos, 2, rot)
	end
end

-- =====================
-- 음료 매대
-- =====================
local DRINK_ROT = math.rad(270)
local DRINK_X = 27.5
local DRINK_Y = {1.8 + Y_OFFSET, 4.6 + Y_OFFSET, 7.4 + Y_OFFSET}
local DRINK_Z = {-4.5, -1.5, 1.5, 4.5}

local DRINK_LIST = {
	{template="banana milk",    id="banana_milk", name="바나나우유", price=1500, rot=nil},
	{template="chocolate milk", id="choco_milk",  name="초코우유",   price=1500, rot=nil},
	{template="coffee",         id="coffee",      name="커피",       price=2000, rot=math.rad(0)},
	{template="Coca-Cola",      id="cola",        name="코카콜라",   price=1800, rot=math.rad(90)},
}

for rowIdx, y in ipairs(DRINK_Y) do
	for colIdx, drink in ipairs(DRINK_LIST) do
		local uid = drink.id .. "_r" .. rowIdx .. "_c" .. colIdx
		local pos = Vector3.new(DRINK_X, y, DRINK_Z[colIdx])
		local rot = drink.rot ~= nil and drink.rot or DRINK_ROT
		placeProduct(drink.template, uid, drink.id, drink.name, drink.price, pos, 2, rot)
	end
end

print("StoreSetup final v5 loaded - no floating price labels")
