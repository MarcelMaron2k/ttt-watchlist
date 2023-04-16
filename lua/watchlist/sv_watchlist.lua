util.AddNetworkString("KWatch_WatchPlayer")
util.AddNetworkString("KWatch_WatchID")
util.AddNetworkString("KWatch_UnWatchPlayer")
util.AddNetworkString("KWatch_OpenMenu")
util.AddNetworkString("KWatch_ReceiveSearch")
util.AddNetworkString("KWatch_SendSearchQuery")
util.AddNetworkString("KWatch_UpdateList")
util.AddNetworkString("KWatch_RequestPageList")

local watchperms = {}
for _, v in ipairs(KWatch.WatchPerms) do
	watchperms[v] = true
end

local watchlistperms = {}
for k,v in ipairs(KWatch.ViewWatchPerms) do
    watchlistperms[v] = true
end

local unwatchperms = {}
for k,v in ipairs(KWatch.UnWatchPerms) do
    unwatchperms[v] = true
end

hook.Add("Initialize", "watchlist_Initialize", function()
    if not sql.TableExists(KWatch.DBName) then
        sql.Query("CREATE TABLE "..KWatch.DBName.."(SteamID TEXT, Name TEXT, Admin TEXT, Reason TEXT, Date TEXT)")
    end
end)

hook.Add("PlayerInitialSpawn", "watchlist_PlayerJoin", function(ply)
    local steamid = ply:SteamID()
    
    local reason = sql.QueryValue("SELECT Reason FROM "..KWatch.DBName.." WHERE SteamID = '"..steamid.."'")

    if (reason) then
        for _,v in ipairs(player.GetAll()) do
            if watchlistperms[v:GetUserGroup()] then
                v:ChatPrint("[KWatch] "..ply:Nick().." Is on the Watchlist for "..reason)
            end
        end
    end
    
    sql.Query("UPDATE "..KWatch.DBName.." SET Name = '"..ply:Nick().."' WHERE SteamID = '"..steamid.."'")
end)

function KWatch.Watch(ply, reason, admin)
    local steamid = ply:SteamID()
    local name = ply:Nick()
    local ad = admin:Nick()
    local date = os.date( "%H:%M:%S - %d/%m/%Y", os.time())

    local row = sql.Query("SELECT * FROM "..KWatch.DBName.." WHERE SteamID = '"..steamid.."'")
    if (not row) then
        sql.Query("INSERT INTO "..KWatch.DBName.."(SteamID, Name, Admin, Reason, Date) VALUES('"..steamid.."', '"..name.."', '"..ad.."', '"..reason.."', '"..date.."')")
    else
        sql.Query("UPDATE "..KWatch.DBName.." SET Admin = '"..ad.."', Reason = '"..reason.."', Date = '"..date.."' WHERE SteamID = '"..steamid.."'")
    end
    KWatch.NotifyStaff(name)
end

function KWatch.WatchID(steamid, reason, admin)
    local ad = admin:Nick()
    local date = os.date( "%H:%M:%S - %d/%m/%Y", os.time())
    local ply = player.GetBySteamID(steamid)
    local name = nil
    if (IsValid(ply)) then
        name = ply:Nick()
    else
        name = "N/A"
    end

    local row = sql.Query("SELECT * FROM "..KWatch.DBName.." WHERE SteamID = '"..steamid.."'")

    if (not row) then
        sql.Query("INSERT INTO "..KWatch.DBName.."(SteamID, Name, Admin, Reason, Date) VALUES('"..steamid.."', '"..name.."', '"..ad.."', '"..reason.."', '"..date.."')")
    else
        sql.Query("UPDATE "..KWatch.DBName.." SET Admin = '"..ad.."', Reason = '"..reason.."', Date = '"..date.."' WHERE SteamID = '"..steamid.."'")
    end
    KWatch.NotifyStaff(steamid)
end

function KWatch.UnWatch(steamid, admin)
    if (not string.StartWith(string.lower(steamid), "steam_")) then ply:ChatPrint("[KWatch] Invalid SteamID Entered.") return end
    
    sql.Query("DELETE FROM "..KWatch.DBName.." WHERE SteamID = '"..steamid.."'")
    admin:ChatPrint("[KWatch] Removed "..steamid.." From Watchlist.")
end

local function KWatch_UpdateList(ply)
    if (not IsValid(ply)) then return end
    local list = sql.Query("SELECT * FROM "..KWatch.DBName.." LIMIT "..KWatch.RowNum)
    if (not istable(list)) then ply:ChatPrint("[KWatch] An Error Has Occured When Updating List.") return end

    list = util.TableToJSON(list)
    list = util.Compress(list)

    net.Start("KWatch_UpdateList")
        net.WriteData(list, #list)
    net.Send(ply)
end

net.Receive("KWatch_WatchPlayer", function(len, ply)
    if (not watchperms[ply:GetUserGroup()]) then return end

    local target = net.ReadEntity()
    local reason = net.ReadString()

    if (IsValid(target) && isstring(reason)) then
        KWatch.Watch(target, reason, ply)
    end
end)

net.Receive("KWatch_WatchID", function(len, ply)
    if (not watchperms[ply:GetUserGroup()]) then return end

    local target = net.ReadString()
    local reason = net.ReadString()

    if (isstring(target) && isstring(reason)) then
        KWatch.WatchID(target, reason, ply)
    end
end)

net.Receive("KWatch_UnWatchPlayer", function(len, ply)
    if (not unwatchperms[ply:GetUserGroup()]) then return end

    local steamid = net.ReadString()
    KWatch.UnWatch(steamid, ply)
    KWatch_UpdateList(ply)
end)

net.Receive("KWatch_RequestPageList", function(len, ply)    
    if (not watchlistperms[ply:GetUserGroup()]) then return end

    local page = net.ReadUInt(8)
    ply.KWatchPage = page or 1
    if (not isnumber(page)) then ply:ChatPrint("[KWatch] An Error Has Occured While Switching Pages.") return end
    local query = nil
    local offset = KWatch.RowNum * (page - 1)
    if (ply.KWatchSearch && ply.KWatchCategory) then
        query = sql.Query("SELECT * FROM "..KWatch.DBName.." WHERE "..ply.KWatchCategory.." = '"..ply.KWatchSearch.."' LIMIT "..offset..","..KWatch.RowNum)
    else
        query = sql.Query("SELECT * FROM "..KWatch.DBName.." LIMIT "..offset..","..KWatch.RowNum)
    end

    if (not istable(query)) then ply:ChatPrint("[KWatch] An Error Has Occured While Requesting Page Data.") return end
    query = util.TableToJSON(query)
    query = util.Compress(query)

    net.Start("KWatch_UpdateList")
        net.WriteData(query, #query)
    net.Send(ply)
end)

net.Receive("KWatch_ReceiveSearch", function(len, ply)
    if (not watchlistperms[ply:GetUserGroup()]) then return end
    local category = net.ReadString()
    local search = net.ReadString()

    local query = sql.Query("SELECT * FROM "..KWatch.DBName.." WHERE "..category.." = '"..search.."'")

    if (not istable(query)) then 
        local str = util.Compress("Empty Table")
        net.Start("KWatch_SendSearchQuery")
            net.WriteData(str, #str)
        net.Send(ply)
        return
    end

    query = util.TableToJSON(query)
    query = util.Compress(query)

    net.Start("KWatch_SendSearchQuery")
        net.WriteData(query, #query)
    net.Send(ply)
    ply.KWatchSearch = search
    ply.KWatchCategory = category
end)

concommand.Add("Watchlist", function(ply, cmd)
    if not watchlistperms[ply:GetUserGroup()] then return end

    local query = sql.Query("SELECT * FROM "..KWatch.DBName.." LIMIT "..KWatch.RowNum)
    if (not istable(query)) then ply:ChatPrint("[KWatch] Could Not Open Watchlist.") return end
    query = util.TableToJSON(query)
    query = util.Compress(query)

    net.Start("KWatch_OpenMenu")
        net.WriteData(query, #query)
    net.Send(ply)
    ply.KWatchSearch = nil
    ply.KWatchCategory = nil
end)

hook.Add("PlayerSay", "KWatch_ChatCommand", function(ply, text)
    if (string.lower(text) == "!watchlist") then
        if not watchlistperms[ply:GetUserGroup()] then return end

        local query = sql.Query("SELECT * FROM "..KWatch.DBName.." LIMIT "..KWatch.RowNum)
        if (istable(query)) then query = util.TableToJSON(query) end
        if (isstring(query)) then query = util.Compress(query) end
    
        net.Start("KWatch_OpenMenu")
            net.WriteData(query, #query)
        net.Send(ply)
        ply.KWatchSearch = nil
        ply.KWatchCategory = nil
        return ""
    end
end)

function KWatch.NotifyStaff(name)
    for k,v in ipairs(player.GetAll()) do
        if (not watchlistperms[v:GetUserGroup()]) then continue end

        v:ChatPrint("[KWatch] "..name.." was added to the WatchList!")
    end
end

-- OLD WATCHLIST TO NEW WATCHLIST FROM THIS POINT ON.
local function OldToNew(name, sid, reason, admin, date, key)
    local row = sql.Query("SELECT * FROM "..KWatch.DBName.." WHERE SteamID = '"..sid.."'")

    if (not row) then
        sql.Query("INSERT INTO "..KWatch.DBName.."(SteamID, Name, Admin, Reason, Date) VALUES('"..sid.."', '"..name.."', '"..admin.."', '"..reason.."', '"..date.."')")
    else
        sql.Query("UPDATE "..KWatch.DBName.." SET Admin = '"..admin.."', Reason = '"..reason.."', Date = '"..date.."' WHERE SteamID = '"..sid.."'")
    end
end

local function GetOldFiles()
    local files = file.Find("watchlist/*","DATA")

    for k,v in pairs(files) do
        local fileinfo = file.Read("watchlist/"..v, "DATA")
        local exp = string.Explode( "\n", fileinfo )

        local name = exp[1]
        local admin = exp[2]
        local reason = exp[3]
        local date = exp[4]

        local steamid = string.StripExtension(v)
        steamid = string.Replace( steamid, "x", ":" )
        steamid = string.upper(steamid)

        if (not name || not admin || not reason || not date || not steamid) then continue end -- make sure we don't have any nils
        if (string.StartWith(name, "STEAM_")) then name = "N/A" end

        OldToNew(name, steamid, reason, admin, date, k)
    end
end
concommand.Add("kwatch_portold", function(ply, cmd)
    if (not (ply:GetUserGroup() == "owner")) then return end
	GetOldFiles()
end)

