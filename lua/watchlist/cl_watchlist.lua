local function NetworkWatch(player, reason)
	if (not IsValid(player) || not isstring(reason)) then return end

    net.Start("KWatch_WatchPlayer")
        net.WriteEntity(player)
        net.WriteString(reason)
    net.SendToServer()
end

local function NetworkWatchID(steamid, reason)
	if (not isstring(steamid) || not isstring(reason)) then return end

    net.Start("KWatch_WatchID")
        net.WriteString(steamid)
        net.WriteString(reason)
    net.SendToServer()
end

local function Watch( ply, cmd, args )
    local nick = args[1]
    local reason = tostring(args[2])
	nick = string.lower( nick )

	for k, v in ipairs( player.GetAll() ) do
        if string.find( string.lower( v:Nick() ), nick ) then
            NetworkWatch(player.GetBySteamID(v:SteamID()), reason)
			return
		end
	end
	
	print("Couldn't Find Player.")
end

local function WatchID(ply, cmd, args)
	local id = args[1]..args[2]..args[3]..args[4]..args[5]
	local reason = args[6]

	NetworkWatchID(id, reason)	
end

local function AutoComplete( cmd, stringargs )	
	stringargs = string.Trim( stringargs ) -- Remove any spaces before or after.
	stringargs = string.lower( stringargs )
	
	local tbl = {}
	
	for k, v in ipairs(player.GetAll()) do
		local nick = v:Nick()
		if string.find( string.lower( nick ), stringargs ) then
			nick = "\"" .. nick .. "\"" -- We put quotes around it in case players have spaces in their names.
			nick = "watch " .. nick -- We also need to put the cmd before for it to work properly.
			
			table.insert(tbl, nick)
		end
	end
	
	return tbl
end
concommand.Add("watch", Watch, AutoComplete)
concommand.Add("watchid", WatchID)

net.Receive("KWatch_OpenMenu", function(len)
	local ply = LocalPlayer()
	local list = net.ReadData(len)

	if (isstring(list)) then list = util.Decompress(list) end
	if (isstring(list)) then list = util.JSONToTable(list) end
	
	if (not istable(list)) then ply:ChatPrint("[KWatch] An Error has Occured") return end
	KWatch.OpenMenu(list)
end)

function KWatch.OpenMenu(tbl)
	LocalPlayer().KWatchPage = 1

	KWatch.Frame = vgui.Create("DFrame")
	KWatch.Frame:SetSize(800,500)
	KWatch.Frame:Center()
	KWatch.Frame:MakePopup(true)
	KWatch.Frame:SetTitle("[Watchlist] By Kaslan.")

	KWatch.Filler = vgui.Create("DPanel", KWatch.Frame)
	KWatch.Filler:DockMargin(0,0,0,3)
	KWatch.Filler:Dock(TOP)
	KWatch.Filler:SetTall(20)
	KWatch.Filler:SetWide(KWatch.Frame:GetWide())
	KWatch.Filler.Paint = function(s,w,h) end

	KWatch.Label = vgui.Create("DLabel", KWatch.Filler)
	KWatch.Label:SetText("Search By:")
	KWatch.Label:Dock(LEFT)
	KWatch.Label:SizeToContents()
	
	KWatch.Category = vgui.Create("DComboBox", KWatch.Filler)
	KWatch.Category:Dock(LEFT)
	KWatch.Category:SetSortItems(false)
	KWatch.Category:SetValue("Name")
	KWatch.Category:AddChoice("Name")
	KWatch.Category:AddChoice("SteamID")
	KWatch.Category:AddChoice("Reason")
	KWatch.Category:AddChoice("Admin")

	KWatch.Text = vgui.Create("DTextEntry", KWatch.Filler)
	KWatch.Text:Dock(LEFT)
	KWatch.Text:SetWide(200)

	KWatch.Search = vgui.Create("DButton", KWatch.Filler)
	KWatch.Search:DockMargin(3,0,0,0)
	KWatch.Search:Dock(LEFT)
	KWatch.Search:SetText("Search")

	KWatch.SearchStatus = vgui.Create("DLabel", KWatch.Filler)
	KWatch.SearchStatus:DockMargin(5,0,0,0)
	KWatch.SearchStatus:Dock(LEFT)
	KWatch.SearchStatus:SetText("Not Currently Searching.")
	KWatch.SearchStatus:SizeToContents()

	KWatch.Search.DoClick = function(self)
		local category = KWatch.Category:GetValue()
		local search = KWatch.Text:GetText()
		if (not isstring(search) || not isstring(category) || #search <= 0) then LocalPlayer():ChatPrint("[KWatch] Couldn't search. Please enter a proper string.") return end

		net.Start("KWatch_ReceiveSearch")
			net.WriteString(category)
			net.WriteString(search)
		net.SendToServer()

		KWatch.SearchStatus:SetText("Searching...")
	end

	KWatch.List = vgui.Create("DListView", KWatch.Frame)
	KWatch.List:Dock(FILL)
	KWatch.List:AddColumn("Name")
	KWatch.List:AddColumn("SteamID")
	KWatch.List:AddColumn("Reason")
	KWatch.List:AddColumn("Date")
	KWatch.List:AddColumn("Admin")

	KWatch.List.OnRowRightClick = function(s, lineID, line)
		local menu = DermaMenu()	
		menu:AddOption("Remove From Watchlist", function() 
			net.Start("KWatch_UnWatchPlayer")
				net.WriteString(line:GetColumnText(2))
			net.SendToServer()
		end):SetImage("icon16/user_red.png")
		menu:AddOption("Copy Name", function() SetClipboardText(line:GetColumnText(1)) LocalPlayer():ChatPrint("[KWatch] Copied Name.") end)
		menu:AddOption("Copy SteamID", function() SetClipboardText(line:GetColumnText(2)) LocalPlayer():ChatPrint("[KWatch] Copied SteamID.") end)
		menu:AddOption("Copy Reason", function() SetClipboardText(line:GetColumnText(3)) LocalPlayer():ChatPrint("[KWatch] Copied Reason.") end)
		menu:AddOption("Copy Date", function() SetClipboardText(line:GetColumnText(4)) LocalPlayer():ChatPrint("[KWatch] Copied Date.") end)
		menu:AddOption("Copy Admin", function() SetClipboardText(line:GetColumnText(5)) LocalPlayer():ChatPrint("[KWatch] Copied Admin.") end)

		menu:Open()
	end
	
	for k,v in pairs(tbl) do
		KWatch.List:AddLine(v.Name, v.SteamID, v.Reason, v.Date, v.Admin)
	end
	for k,v in pairs(KWatch.List:GetLines()) do
		for id, pnl in pairs(v.Columns) do
			if not pnl.SetFont then continue end
			pnl:SetContentAlignment(5)        
		end
	end

	KWatch.Filler2 = vgui.Create("DPanel", KWatch.Frame)
	KWatch.Filler2:SetTall(20)
	KWatch.Filler2:Dock(BOTTOM)
	KWatch.Filler2.Paint = function() end

	KWatch.NextButton = vgui.Create("DButton", KWatch.Filler2)
	KWatch.NextButton:Dock(RIGHT)
	KWatch.NextButton:SetText("Next")
	KWatch.NextButton.DoClick = function(s)
		local ply = LocalPlayer()
		ply.KWatchPage = ply.KWatchPage or 1
		ply.KWatchPage = ply.KWatchPage + 1
		if (IsValid(KWatch.PageLabel)) then
			KWatch.PageLabel:SetText(ply.KWatchPage or "1") 		
			KWatch.PageLabel:SizeToContents()
		end
		net.Start("KWatch_RequestPageList")
			net.WriteUInt(ply.KWatchPage, 8)
		net.SendToServer()
	end

	KWatch.PageLabel = vgui.Create("DLabel", KWatch.Filler2)
	KWatch.PageLabel:DockMargin(3,0,3,0)
	KWatch.PageLabel:Dock(RIGHT)
	KWatch.PageLabel:SetFont("Trebuchet24")
	KWatch.PageLabel:SetText(LocalPlayer().KWatchPage or "1")
	KWatch.PageLabel:SizeToContents()

	KWatch.PrevButton = vgui.Create("DButton", KWatch.Filler2)
	KWatch.PrevButton:Dock(RIGHT)
	KWatch.PrevButton:SetText("Previous")
	KWatch.PrevButton.DoClick = function(s)
		local ply = LocalPlayer()

		if (not isnumber(ply.KWatchPage) || ply.KWatchPage <= 1) then return end
		ply.KWatchPage = ply.KWatchPage or 1
		ply.KWatchPage = ply.KWatchPage - 1
		KWatch.PageLabel:SetText(ply.KWatchPage)
		KWatch.PageLabel:SizeToContents()

		net.Start("KWatch_RequestPageList")
			net.WriteUInt(ply.KWatchPage, 8)
		net.SendToServer()
	end
end

net.Receive("KWatch_UpdateList", function(len)
	local list = net.ReadData(len)
	list = util.Decompress(list)
	list = util.JSONToTable(list)

	if (not istable(list)) then LocalPlayer():ChatPrint("[KWatch] An Error Has Occured While Updating The List.") return end

	if (not IsValid(KWatch.List)) then return end

	KWatch.List:Clear()
	for k,v in pairs(list) do
		KWatch.List:AddLine(v.Name, v.SteamID, v.Reason, v.Date, v.Admin)
	end
	for k,v in pairs(KWatch.List:GetLines()) do
		for id, pnl in pairs(v.Columns) do
			if not pnl.SetFont then continue end
			pnl:SetContentAlignment(5)        
		end
	end

end)

net.Receive("KWatch_SendSearchQuery", function(len)
	local query = net.ReadData(len)
	query = util.Decompress(query)
	KWatch.SearchStatus:SetText("Finished Searching.")
	KWatch.PageLabel:SetText("1")
	LocalPlayer().KWatchPage = 1
	if (query == "Empty Table") then
		KWatch.List:Clear()
		return
	end

	query = util.JSONToTable(query)

	if (not istable(query)) then LocalPlayer():ChatPrint("[KWatch] An Error has Occured") return end

	KWatch.List:Clear()
	for k,v in pairs(query) do
		KWatch.List:AddLine(v.Name, v.SteamID, v.Reason, v.Date, v.Admin)
	end
	for k,v in pairs(KWatch.List:GetLines()) do
		for id, pnl in pairs(v.Columns) do
			if not pnl.SetFont then continue end
			pnl:SetContentAlignment(5)        
		end
	end
end)

local function RequestSearchData(search, category, page)


	-- TODO: Pages for searched information.
	-- TODO: Pages for general information.
end
