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

-- reduce value of teams with promo item redundancies and unbalanced join times
function auctionStateObj:adjustedBids()
	local adjBids = {}
	for player_i = 1, self.players.count do
		adjBids[player_i] = {}
	end
	
	local teams = self:teams()
		
	for player_i = 1, self.players.count do
		for member_i = 1, self.maxTeamSize do
			local member = teams[player_i][member_i]
		
			--get num predecessors with same promo type (competitors)
			local numCompetitors = 0
			for member_j = 1, member_i - 1 do
				if self.units[teams[player_i][member_j]][3] == 
					self.units[member][3] then
					numCompetitors = numCompetitors + 1
				end
			end
			
			for player_i = 1, self.players.count do
				adjBids[player_i][member] = self.bids[player_i][member] 
					* self.latePromoFactor[member][numCompetitors]
			end
		end
	end
	
	return adjBids
end

-- the vMatrix shows how player i values player j's team for all i,j
function auctionStateObj:teamValueMatrix(bids)
	bids = bids or self:adjustedBids()

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
				+ bids[player_i][unit_i]
		end
	end
	
	return vMatrix
end

-- finds prices that produce equalized satisfaction
-- A's satisfaction equals Handicapped Team Value - average opponent HTV
-- (from A's subjective perspective)
function auctionStateObj:paretoPrices(vMatrix)	
	vMatrix = vMatrix or self:teamValueMatrix()
	
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
function auctionStateObj:allocationScore(vMatrix)
	vMatrix = vMatrix or self:teamValueMatrix()
	
	local netSpiteValue = 0	
	for player_i = 1, self.players.count do
		netSpiteValue = netSpiteValue + spiteValue(vMatrix[player_i],player_i)
	end
	
	return netSpiteValue
end