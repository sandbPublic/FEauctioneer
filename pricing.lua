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
	
		player_j = self.owner[unit_i]
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

-- satisfaction is proportional to net spiteValue
function auctionStateObj:allocationScore()
	local vMatrix = self:teamValueMatrix()
	
	local netSpiteValue = 0	
	for player_i = 1, self.players.count do
		netSpiteValue = netSpiteValue + spiteValue(vMatrix[player_i],player_i)
	end
	
	return netSpiteValue
end