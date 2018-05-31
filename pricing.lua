require("auctionStateObj")

-- for any assignment, a player A's satisfaction will be:
-- A's valuation of A's team - A's price + avg(Opp's price - A's value of Opp's team)
-- setting these equal for all players and arbitrarily setting one price to 0
-- (handicaps are relative) yield a system of N-1 equations and N-1 unknowns
--
-- solving this will produce prices that equalizes sat (and maximize minimum)
-- this level of sat is the score for that assignment
-- then simply find the assignment with the highest sat 

-- let:
-- # players = n+1
-- a = A's team
-- V_Ax = A's valuation of X's team
-- P_A = the price A pays
-- Comp.f(A) = competitive version of f: f(A) - avg(f(i))|{i~=A}
-- S_A = A's satisfaction = Comp.V_A - Comp.P_A
-- changing price does not change sum(S)
-- pareto optimum when S_A = S_X for all X
-- wlg let P_A = 0 and S_A = S_X. then
-- 

-- this price maximizes the minimum satisfaction among players
-- winner's sat = W_val - Price
-- loser's sat = (Price - L_val)/(#opponents)
-- only highest bidding loser (1st or 2nd place) can have minimum sat
-- min is maximized when W_sat = 1st_L_sat
-- solving: 
-- #opp*Wv - #opp*P = P - Lv
-- P*(#opp+1) = (#opp+1-1)*Wv + Lv
-- P = (#players*Wv + Lv - Wv)/#players
-- P = Wv + (Lv - Wv)/#players
function auctionStateObj:maxMinSatPrice(unit_i)
	local winnerBid = self.bids[self:findOwner(unit_i)][unit_i]
	local highestLoserBid = 0
	for player_i = 1, self.players.count do
		if highestLoserBid < self.bids[player_i][unit_i] then
			highestLoserBid = self.bids[player_i][unit_i]
		end
	end
	
	return winnerBid + (highestLoserBid - winnerBid) / self.players.count
end

-- this function ensures that the expected value of over or underbidding
-- is strictly non-positive (i.e. strategically dominated by true bidding)
function auctionStateObj:handicapPrice(unit_i)
	local ownerBid = self.bids[self:findOwner(unit_i)][unit_i]
	
	-- find largest bid not greater than that, from player not assigned to, at least 0
	-- bids from past owners should be larger than current, hence not considered again
	local secondPrice = -1
	for player_i = 1, self.players.count do
		if (self.bids[player_i][unit_i] <= ownerBid and
		   self.bids[player_i][unit_i] >= secondPrice and
		   not self.assignedTo[player_i][unit_i]) then
		
			secondPrice = self.bids[player_i][unit_i]
		end
	end
	
	if secondPrice >= 0 then
		return secondPrice + (ownerBid - secondPrice)/self.players.count
	else -- owner(s) in last place, special behavior, pay 2nd-to-last price
	
		local secondLastPrice = 999
		for player_i = 1, self.players.count do
			if (self.bids[player_i][unit_i] <= secondLastPrice and
			   not self.assignedTo[player_i][unit_i]) then
			   
				secondLastPrice = self.bids[player_i][unit_i]
			end
		end
		if secondLastPrice == 999 then
			return self.bids[1][unit_i] -- assigned to all players
		end
		
		return ownerBid + (secondLastPrice - ownerBid)/self.players.count
	end
end

function auctionStateObj:totalHandicap(player_i)
	local hc = 0
	for unit_i = 1, self.units.count do
		if self.assignedTo[player_i][unit_i] then
			hc = hc + self:handicapPrice(unit_i)
		end
	end
	return hc
end
