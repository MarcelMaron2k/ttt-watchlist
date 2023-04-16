# KWatch
A Watchlist Replacement for GMod


ULX's Watchlist is garbage. It's old, slow and has little to no features.
This is where KWatch comes in. KWatch will allow you to add Players to the watchlist with a simple console command like ULX.

This addon uses sqlite and GMod's original database system, so it's simply a drag and drop installation.

KWatch also has the added feature of letting you search in your watchlist for whatever reason.
It notifies your staff when a player on the watchlist has joined.

You can edit permissions in the Config of the addon.
This addon natively supports ULX. however I'm not sure whether it supports other addons. (Base Rule, If they detour GetUserGroup() then it should work.)

 I've also added a console command to let you port over the old watchlist data onto the new watchlist with the use of a simple console command.

Console Commands:

watch "player" "reason"
watchid "steamid" "reason"

kwatch_portold -- This command lets you port over your old watchlist to KWatch.

If you encounter any bugs, create an issue please and I'll have it fixed as soon as possible.
