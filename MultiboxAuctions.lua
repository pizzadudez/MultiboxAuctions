local name,addon = ...

-- GUI Library
StdUi = LibStub('StdUi')

-- Locals
local realmName, charName, realmData
local MAuc = {} -- addon Object (needed to keep functions local)
local window = {}
local itemsTable = {}
local herbsTable = {152510,152509,152505,152507,152508,152511,152506}
local alchTable = {152639,152638,152641,163222,163223,163224}
local defaultStackCount = {
	[152510] = 5,
	[152509] = 36,
	[152505] = 36,
	[152507] = 24,
	[152508] = 24,
	[152511] = 12,
	[152506] = 12,
}

local defaultDB = {}

-- Need a frame for events
local frame, events = CreateFrame("FRAME"), {}

-------------------------------------------------------------------------------

function events:ADDON_LOADED(name)
	if name == 'MultiboxAuctions' then
		MultiboxAuctionsDB = MultiboxAuctionsDB or defaultDB
	end
end

function events:PLAYER_LOGIN()
    MAuc:Init()
end

-------------------------------------------------------------------------------

function MAuc:Init()
	realmName = GetRealmName()
	charName = UnitName("player")
	local herbSeller = addon.sellerDb['herbs'][realmName]
	local alchSeller = addon.sellerDb['alchemy'][realmName]

	if string.find(herbSeller, charName) then
		itemsTable = herbsTable
	elseif string.find(alchSeller, charName) then
		itemsTable = alchTable
	else
		return
	end
	itemsTable = herbsTable
	realmData = MultiboxAuctionsDB[realmName] or {}
	MultiboxAuctionsDB[realmName] = realmData

	MAuc:DrawWindow()
end

function MAuc:DrawWindow()
	window = StdUi:Window(UIParent,'MultiboxAuctions',606,420)
	window:SetPoint('TOPLEFT',UIParent,'CENTER',-240,46)
	window:SetFrameStrata("MEDIUM")

	window.clearAll = StdUi:Button(window,120,20,'Clear Sell Prices')
	window.clearAll:SetPoint("TOPLEFT",window,"TOPLEFT",6,-6)
	window.clearAll:SetScript("OnClick",function()
		MAuc:ClearAllButton()
	end)

	window.items = window.items or {}
	window.items[0] = window

	-- Draw separate columns for each item
	for i, itemID in ipairs(itemsTable) do

		-- Item Columns
		window.items[i] = StdUi:Frame(window,86,650)
		window.items[i]:SetPoint('TOPLEFT',window.items[i-1],'TOPRIGHT',0,0)
		local item = window.items[i]

		-- Item icons
		local textureID = GetItemTextureID(itemID)
		item.texture = StdUi:Texture(item,24,24,textureID)
		item.texture:SetPoint("BOTTOM",item,"TOP",-34,4)

		-- Sell Button
		item.sellButton = StdUi:Button(item,50,20,'Sell')
		item.sellButton:SetPoint('BOTTOM',item,'TOP',4,32)
		item.sellButton:SetScript('OnClick',function() MAuc:SellItem(item,itemID) end)
		-- Sell NumStacks
		item.sellEditBox = StdUi:EditBox(item,24,20,defaultStackCount[itemID])
		item.sellEditBox:SetPoint('RIGHT',item.sellButton,'LEFT',-2,0)
		item.sellEditBox:SetValue(defaultStackCount[itemID])
		item.sellEditBox.OnValueChanged = function(self)
			self:ClearFocus()
		end

		-- Item EditBoxes
		if realmData[itemID] then
			local lastPrice = realmData[itemID]['postPrice']
		else
			local lastPrice = nil
		end

		item.editBox = StdUi:EditBox(item,50,24,lastPrice or '')
		item.editBox:SetPoint("LEFT",item.texture,"RIGHT",2,0)
		item.editBox.OnValueChanged = function(self)
			local boxVal = tonumber(self:GetValue())
			if boxVal == '' then boxVal = nil end
			realmData[itemID]['postPrice'] = boxVal
			self:ClearFocus()
		end

		-- Item Auction Slides
		item.slides = item.slides or {}
		item.slides[0] = item.slides[0] or item
		if realmData[itemID] then
			MAuc:DrawScanTime(item,itemID)
			MAuc:DrawItemFrame(item,itemID)
		end
	end
	window.items[1]:SetPoint('TOPLEFT',window,"TOPLEFT",10,-100)
end

function MAuc:DrawItemFrame(parent,itemID)
	local scanData = realmData[itemID]['scanData']

	for i, scanObj in ipairs(scanData) do
		local price = math.floor(scanData[i]['price'] * 10000) / 10000
		local size = scanData[i]['size']
		local qty = scanData[i]['qty']
		parent.slides[i] = MAuc:DrawAuctionSlide(parent,price,qty,size,itemID)
		parent.slides[i]:SetPoint('TOP',parent.slides[i-1],'BOTTOM',0,0)
	end
	-- in case there is no slide
	if parent.slides[1] then
		parent.slides[1]:SetPoint('TOP',parent,'TOP',5,0)
	end
end

function MAuc:DrawAuctionSlide(parent,price,qty,size,itemID)
	local displayPrice = math.floor(price*100)/100
	local slide = StdUi:HighlightButton(parent,70,16,displayPrice)
	slide.price = price

	slide:SetScript('OnClick',function()
		parent.editBox:SetValue(slide.price - 0.0101)
	end)

	slide.qty = StdUi:FontString(slide,qty)
	slide.qty:SetPoint('RIGHT',slide,'LEFT',8,0)
	MAuc:SetColorBySize(slide.qty,size)
	MAuc:IsOwnAuction(slide,itemID)

	return slide
end

function MAuc:DrawScanTime(parent,itemID)
	local day,month,_,hour,minute,_ = MAuc:DateFromString(realmData[itemID]['scanTime'])
	local scanTime = day..'/'..month..' '..hour..':'..minute
	
	if parent.time == nil then
		parent.time = StdUi:FontString(parent,scanTime)
		parent.time:SetPoint("BOTTOM",parent,"TOP",-7,54)
	else 
		parent.time:SetText(scanTime)
	end
end

function MAuc:ClearAllButton()
	for i,itemID in ipairs(itemsTable) do
		window.items[i].editBox:SetText('')
		realmData[itemID]['postPrice'] = nil
	end
end

function MAuc:UpdateAuctionData()
	for i, itemID in ipairs(itemsTable) do
		if realmData[itemID] then
			local scanData = realmData[itemID]['scanData']
			local item = window.items[i]

			-- modify old slides or create new ones if needed
			local count = 0
			for j, scanObj in ipairs(scanData) do
				local price = math.floor(scanData[j]['price'] * 10000) / 10000
				local displayPrice = math.floor(price*100)/100
				local size = scanData[j]['size']
				local qty = scanData[j]['qty']
				count = count + 1

				local slide = item.slides[j]

				if slide then
					slide.text:SetText(displayPrice)
					slide.price = price
					slide.qty:SetText(qty)
					MAuc:SetColorBySize(slide.qty,size)
					MAuc:IsOwnAuction(slide,itemID)
				else
					item.slides[j] = MAuc:DrawAuctionSlide(window.items[i],price,qty,size,itemID)
					item.slides[j]:SetPoint('TOP',item.slides[j-1],'BOTTOM',0,0)
				end
			end

			-- hide excess slides
			while item.slides[count+1] do
				item.slides[count+1]:Hide()
				count = count + 1
			end

			-- Update scanTime aswell
			MAuc:DrawScanTime(item,itemID)

			-- in case no slides have been drawn before, attach slides[1] to it's parent
			item.slides[1]:SetPoint('TOP',item,'TOP',5,0)
		end
	end
end

function MAuc:DateFromString(string)
	local pattern = '(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)'
	local day,month,year,hour,minute,second = string:match(pattern)
	return day,month,year,hour,minute,second
end

function MAuc:SetColorBySize(frame, size)
	if size == 100 or size == 10 then
		r,g,b = 1,0.5,0.5
	elseif size == 5 then
		r,g,b = 0,0.7,0.3
	else 
		r,g,b = 9,0.8,0
	end

	frame:SetTextColor(r,g,b,1)
end

function MAuc:IsOwnAuction(slide, itemID)
	local postPrice
	if MCSV[realmName] then
		if MCSV[realmName][charName] then
			if MCSV[realmName][charName]['postPrices'] then
				postPrice = MCSV[realmName][charName]['postPrices'][itemID]
			end
		end
	end

	if postPrice and postPrice == slide.price * 10000 then
		slide.text:SetTextColor(0.37,1,0.97,1)
	else
		slide.text:SetTextColor(1,1,1,1)
	end
end

-- Sells Item
function MAuc:SellItem(item, itemID)
	local price = nil
	local time = 3 -- Probably always gonna be 48h
	local stackSize = 200 -- gonna have different buttons for this
	local stackCount = tonumber(item.sellEditBox:GetValue())

	if realmData[itemID] then
		price = realmData[itemID]['postPrice']
		if price then
			price = price * 10000 -- posting price is in coppers
		elseif not stackCount then
			print('MultiboxAuctions: No stackCount selected')
			return
		else
			print('MultiboxAuctions: No posting price selected')
			return
		end
	end

	-- IMPORTANT!
	local stackPrice = price * stackSize

	-- Put item in sellbox
	MAuc:PutItemInSellBox(itemID)

	-- Sell specified stackCount or maxStacks if not enough and shift key is pressed
	if IsShiftKeyDown() then
		local maxStacks = MAuc:maxStacks(itemID,stackSize)
		if maxStacks <= stackCount then
			PostAuction(stackPrice-stackSize,stackPrice,time,stackSize,maxStacks)
		else
			print('MultiboxAuctions: press without shift Key')
		end
	else
		PostAuction(stackPrice-stackSize,stackPrice,time,stackSize,stackCount)
	end
end

-- Puts item in auction box so we can start selling
function MAuc:PutItemInSellBox(itemID)

	-- if desired item is already in the sell box 
	if MAuc:IsItemInSellBox(itemID) then return true end

	-- no such item found in bag
	local bag, slot = MAuc:FindItemInInventory(itemID)
	if not bag or not slot then
		print('MultiboxAuctions: item not found in bag')
		return false
	end

	-- we found the item so now put it in the sell box
	PickupContainerItem(bag,slot)
	ClickAuctionSellItemButton()
	ClearCursor()
	-- maybe check if CursorHasItem() too

	return true
end

-- Checks if item is in the sell Box
function MAuc:IsItemInSellBox(itemID)
	local _,_,_,_,_,_,_,_,_,curItemID = GetAuctionSellItemInfo()
	if curItemID and curItemID == itemID then
		return true
	end
	return false
end

-- Finds item in bags so we can put it in th sell box
function MAuc:FindItemInInventory(itemID)
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag,slot)
			if id == itemID then
				return bag, slot
			end
		end
	end

	return nil, nil
end

function MAuc:maxStacks(itemID,stackSize)
	local qty = GetItemCount(itemID)
	return math.floor(qty/stackSize)
end


-------------------------------------------------------------------------------

-- Call functions in the events table for events
frame:SetScript("OnEvent", function(self, event, ...)
    events[event](self, ...)
end)

-- Register every event in the events table
for k, v in pairs(events) do
    frame:RegisterEvent(k)
end

-------------------------------------------------------------------------------

-- Checks if there's any new scan data
function NewScanData()
	if AUCTIONATOR_SAVEDVARS['JustScanned'] == true then
		print("update")
		AUCTIONATOR_SAVEDVARS['JustScanned'] = false
		MAuc:UpdateAuctionData()
	end
end

-- Throttle checking for new scan data
local _ = C_Timer.NewTicker(2, function() NewScanData() end, nil)