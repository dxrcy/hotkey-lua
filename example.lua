local hk = require("hk")
local bind = hk.bind

bind({ SUPER, SHIFT }, A,
    { "notify-send", "'Hello!'" }
)

bind({ SUPER }, { H, J, K, L },
    { "bspc", "node", "-f", { "west", "south", "north", "east" } }
)

hk.done()
