
--------------
-- Abstract --
--------------

-- Get currency name/description
function towny.eco.get_currency() return "" end

-- Format the number appropriately
function towny.eco.format_number(number) return number end

-- Get player's balance
function towny.eco.get_player_balance(player) return 0 end

-- Charge a player
function towny.eco.charge_player(player, amount) return 0 end

-- Pay a player
function towny.eco.pay_player(player, amount) return false end
