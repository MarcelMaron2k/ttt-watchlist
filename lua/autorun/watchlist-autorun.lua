KWatch = {}

if SERVER then
    include("watchlist/watchlist_config.lua")
    include("watchlist/sv_watchlist.lua")
    
    AddCSLuaFile("watchlist/watchlist_config.lua")
    AddCSLuaFile("watchlist/cl_watchlist.lua")
elseif CLIENT then
    include("watchlist/watchlist_config.lua")
    include("watchlist/cl_watchlist.lua")
end