local name,addon = ...

-- GUI Library
StdUi = LibStub('StdUi')

-- Locals
local realmName, charName, realmData
local MAuc = {} -- addon Object (needed to keep functions local)
local window, cancelFrame = {}, {} 
local itemsTable, cancelTable, cancelItems = {}, {}, {}
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

	[152639] = 15,
	[152638] = 15,
	[152641] = 15,
	[163222] = 15,
	[163223] = 15,
	[163224] = 15
}

local defaultStackSize = {
	[152510] = 200,
	[152509] = 200,
	[152505] = 200,
	[152507] = 200,
	[152508] = 200,
	[152511] = 200,
	[152506] = 200,

	[152639] = 20,
	[152638] = 20,
	[152641] = 20,
	[163222] = 20,
	[163223] = 20,
	[163224] = 20
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

function events:AUCTION_HOUSE_SHOW()
	cancelFrame:Show()
end

function events:AUCTION_HOUSE_CLOSED()
	cancelFrame:Hide()
end

function events:CHAT_MSG_ADDON(prefix, message, channel, name)
	if prefix == 'Multiboxer' then 
		MAuc:UpdateAuctionData()
	end
end

-------------------------------------------------------------------------------

function MAuc:Init()
	realmName = GetRealmName()
	charName = UnitName("player")
	local herbSeller = addon.sellerDb['herbs'][realmName]
	local alchSeller = addon.sellerDb['alchemy'][realmName]

	if herbSeller and string.find(herbSeller, charName) then
		itemsTable = herbsTable
	elseif alchSeller and string.find(alchSeller, charName) then
		itemsTable = alchTable
	else
		return
	end

	realmData = MultiboxerDB['scanData'][realmName] or {}
	MultiboxerDB['scanData'][realmName] = realmData

	MAuc:CheckGlobalData()

	-- receive messages from Multiboxer addon
	C_ChatInfo.RegisterAddonMessagePrefix('Multiboxer')

	MAuc:DrawWindow()
	MAuc:DrawCancelFrame()
end

function MAuc:CheckGlobalData()
	-- no data so return
	if not addon.realmDataGlobal[realmName] then
		return
	end
	-- no data so return
	if not realmData[itemID] then
		return
	end

	local realmDataGlobal = addon.realmDataGlobal[realmName]
	for itemID, _ in pairs(realmDataGlobal) do
		if realmDataGlobal[itemID]['scanTime'] > realmData[itemID]['scanTime'] then
			realmData[itemID] = realmDataGlobal[itemID]
		end
	end
end

function MAuc:DrawWindow()
	window = StdUi:Window(UIParent,'MultiboxAuctions',606,420)
	window:SetPoint('TOPLEFT',UIParent,'CENTER',-240,46)
	window:SetFrameStrata("MEDIUM")

	-- Clear Prices Button
	window.clearAll = StdUi:Button(window,120,20,'Clear Sell Prices')
	window.clearAll:SetPoint("TOPLEFT",window,"TOPLEFT",6,-6)
	window.clearAll:SetScript("OnClick",function()
		MAuc:ClearAllButton()
	end)

	-- Cancel Auctions Button
	window.cancelAuctions = StdUi:Button(window,120,20,'Cancel Auctions')
	window.cancelAuctions:SetPoint("LEFT", window.clearAll, "RIGHT", 5, 0)
	window.cancelAuctions:SetScript("OnClick", function()
		--print(cancelItems[152510])
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
		item.sellEditBox:SetValue(defaultStackCount[itemID] or 0)
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
		local size = scanData[i]['stackSize']
		local qty = scanData[i]['qty']
		local timeLeft = scanData[i]['timeLeft']
		local owner = scanData[i]['owner']
		parent.slides[i] = MAuc:DrawAuctionSlide(parent,price,qty,size,itemID,timeLeft,owner)
		parent.slides[i]:SetPoint('TOP',parent.slides[i-1],'BOTTOM',0,0)
	end
	-- in case there is no slide
	if parent.slides[1] then
		parent.slides[1]:SetPoint('TOP',parent,'TOP',5,0)
	end
end

function MAuc:DrawAuctionSlide(parent,price,qty,size,itemID,timeLeft,owner)
	local displayPrice = math.floor(price*100)/100
	local slide = StdUi:HighlightButton(parent,70,16,displayPrice)
	slide.price = price
	slide.timeLeft = timeLeft
	slide.owner = owner

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
	local timestamp = realmData[itemID]['scanTime']
	local scanTime = date("%d/%m %H:%M", timestamp)

	-- create/update scanTime
	if parent.time == nil then
		parent.time = StdUi:FontString(parent,scanTime)
		parent.time:SetPoint("BOTTOM",parent,"TOP",-7,54)
	else 
		parent.time:SetText(scanTime)
	end

	-- color time different based on freshness
	if time() - timestamp > 3600 then
		local r, g, b = MAuc:RGBToPercent(229, 73, 73)
		parent.time:SetTextColor(r, g, b, 1)
	elseif time() - timestamp > 1800 then
		local r, g, b = MAuc:RGBToPercent(255, 176, 86)
		parent.time:SetTextColor(r, g, b, 1)
	else
		local r, g, b = MAuc:RGBToPercent(86, 255, 120)
		parent.time:SetTextColor(r, g, b, 1)
	end
end

function MAuc:ClearAllButton()
	for i,itemID in ipairs(itemsTable) do
		window.items[i].editBox:SetText('')
		if realmData[itemID] then
			realmData[itemID]['postPrice'] = nil
		end
	end
end

function MAuc:DrawCancelFrame()
	cancelFrame = StdUi:Window(UIParent, "Cancel Auctions", 60, 200)
	cancelFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 362, -100)
	cancelFrame:SetFrameStrata("MEDIUM")

	cancelFrame.items = cancelFrame.items or {}
	cancelFrame.items[0] = cancelFrame
	for i, itemID in ipairs(itemsTable) do
		cancelItems[itemID] = false

		local item = StdUi:Checkbox(cancelFrame, 24, 24)
		item:SetPoint('TOP', cancelFrame.items[i-1], 'BOTTOM', 0, -4)
		item.OnValueChanged = function(self, state, value)
			cancelItems[itemID] = item.isChecked
		end
		cancelFrame.items[i] = item

		local textureID = GetItemTextureID(itemID)
		item.texture = StdUi:Texture(item, 24, 24, textureID)
		item.texture:SetPoint("LEFT", item, "RIGHT", 0, 0)
	end
	cancelFrame.items[1]:SetPoint('TOPLEFT', cancelFrame, 'TOPLEFT', 3, -20)
	cancelFrame:Hide()
end

-- TODO: cancel based on a hash table of itemids
function MAuc:CancelAuctions()
	-- if we already have a cancel table just cancel the highest index auction
	if #cancelTable > 0 then
			CancelAuction(cancelTable[1])
			print(cancelTable[1])
			table.remove(cancelTable, 1)
		return
	end
	
	-- Populate cancelTable
	cancelTable = {}
	local numAuctions = GetNumAuctionItems("owner")
	
	-- find all auctions to cancel
	for i = 1, numAuctions do
		local _,_,itemCount,_,_,_,_,_,_,buyoutPrice,_,_,_,_,_,_, itemID,_ =  
			GetAuctionItemInfo("owner", i)
		--local timeLeft = GetAuctionItemTimeLeft("owner", i)
		if cancelItems[itemID] then
			table.insert(cancelTable, i)
		end
	end

	-- sort the cancelTable so when we cancel indices dont change because
	-- we cancel from highest to lowest index
	table.sort(cancelTable, function(a, b) return a > b end)
end

function MAuc:UpdateAuctionData()
	for i, itemID in ipairs(itemsTable) do
		local item = window.items[i]
		item.slides[0] = item
		if realmData[itemID] and realmData[itemID]['scanData'] then
			local scanData = realmData[itemID]['scanData']
			

			-- modify old slides or create new ones if needed
			local count = 0
			for j, scanObj in ipairs(scanData) do
				local price = math.floor(scanData[j]['price'] * 10000) / 10000
				local displayPrice = math.floor(price*100)/100 
				local size = scanData[j]['stackSize']
				local qty = scanData[j]['qty']
				local timeLeft = scanData[j]['timeLeft']
				local owner = scanData[j]['owner']
				count = count + 1

				local slide = item.slides[j]

				if slide then		
					slide.text:SetText(displayPrice)
					slide.price = price
					slide.qty:SetText(qty)
					slide:Show()
					MAuc:SetColorBySize(slide.qty,size)
					slide.owner = owner
					slide.timeLeft = timeLeft
					MAuc:IsOwnAuction(slide,itemID)
				else
					item.slides[j] = MAuc:DrawAuctionSlide(window.items[i],price,qty,size,itemID,timeLeft,owner)
					item.slides[j]:SetPoint('TOP',item.slides[j-1],'BOTTOM',0,0)
				end
			end

			-- hide excess slides
			while item.slides[count+1] do
				item.slides[count+1]:Hide()
				item.slides[count+1].text:SetTextColor(1,1,1,1) -- set color to default
				count = count + 1
			end

			-- Update scanTime aswell
			MAuc:DrawScanTime(item,itemID)

			-- in case no slides have been drawn before, attach slides[1] to it's parent
			if item.slides[1] then
				item.slides[1]:SetPoint('TOP',item.slides[0],'TOP',5,0)
			end
		end
	end
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

function MAuc:RGBToPercent(r,g,b)
	return r / 255, g / 255, b / 255
end

function MAuc:IsOwnAuction(slide, itemID)
	slide.text:SetTextColor(1,1,1,1)

	if slide.owner == charName then
		slide.text:SetTextColor(0.37,1,0.97,1)
	elseif slide.timeLeft < 3 then
		slide.text:SetTextColor(0.6, 0.6, 0.6)
	end
end

-- Sells Item
function MAuc:SellItem(item, itemID)
	local price = nil
	local time = 3 -- Probably always gonna be 48h
	local stackSize = defaultStackSize[itemID] -- gonna have different buttons for this
	local stackCount = tonumber(item.sellEditBox:GetValue())

	if realmData[itemID] then
		price = realmData[itemID]['postPrice']
		if price then
			price = math.floor(price * 10000 + 0.5) -- posting price is in coppers
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

-- Slash Command List
SLASH_MultiboxAuctions1 = '/mauctions'
SLASH_MultiboxAuctions2 = '/mauc'
SlashCmdList['MultiboxAuctions'] = function(argString) MAuc:SlashCommand(argString) end

function MAuc:SlashCommand(argString)
	local args = {strsplit(" ",argString)}
	local cmd = table.remove(args, 1)

	if cmd == 'cancel' then
		MAuc:CancelAuctions()
	else
		print('MultiboxAuctions:')
		print('  /mauc cancel')
	end
end