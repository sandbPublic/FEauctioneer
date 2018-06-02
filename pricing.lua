-- zero-sum game, subtract average opponent's perceived value from own
-- a[i] - avg(a[j])|j~=j
function spiteValue(array, i)
	local spite = 0
	
	local j = 1
	while array[j] do
		if j ~= i then
			spite = spite + array[j]
		end
		j = j + 1
	end
	return array[i] - spite/(j-2) -- j-2 == #opponents
end

-- the vMatrix shows how player a values player j's team
function auctionStateObj:teamValueMatrix()
	local vMatrix = {}
	for player_i = 1, self.players.count do
		vMatrix[player_i] = {}
		for player_j = 1, self.players.count do
			vMatrix[player_i][player_j] = 0
		end
	end

	for unit_i = 1, self.units.count do
		local net = 0
	
		player_j = self:findOwner(unit_i)
		for player_i = 1, self.players.count do
			vMatrix[player_i][player_j] = vMatrix[player_i][player_j] 
				+ self.bids[player_i][unit_i]
		end
	end
	
	return vMatrix
end

-- satisfaction matrix, using teamValueMatrix and handicaps
function auctionStateObj:satMatrix()
	vMatrix = self:teamValueMatrix()
	
	local handicaps = {}
	for player_i = 1, self.players.count do
		handicaps[player_i] = self:totalHandicap(player_i)
	end
	
	local satMatrix = {}
	for player_i = 1, self.players.count do
		satMatrix[player_i] = 
			spiteValue(vMatrix[player_i],player_i) - spiteValue(handicaps, player_i)
	end
	
	return satMatrix
end

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
-- P_X = (Comp.V_X - Comp.V_A)n/(n+1)
function auctionStateObj:paretoPrices()	
	local vMatrix = self:teamValueMatrix()
	
	-- select A | Comp.V_A is minimal to automatically generate positive prices
	local spiteValues = {}
	local minSpite = 999
	local minSpite_i = 0	
	for player_i = 1, self.players.count do
		spiteValues[player_i] = spiteValue(vMatrix[player_i],player_i)
		
		if minSpite > spiteValues[player_i]  then
			minSpite = spiteValues[player_i]
			minSpite_i = player_i
		end
	end
	
	local paretoPrices = {}
	local nFactor = (self.players.count-1)/self.players.count
	for player_i = 1, self.players.count do
		paretoPrices[player_i] = (spiteValues[player_i] - spiteValues[minSpite_i])*nFactor
	end
	
	return paretoPrices
end

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
