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

-- reduce value of teams with promo item redundancies
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
				if self.gameData.units[teams[player_i][member_j]].promoItem == 
					self.gameData.units[member].promoItem then
					numCompetitors = numCompetitors + 1
				end
			end
			
			for player_i = 1, self.players.count do
				adjBids[player_i][member] = self.bids[player_i][member] 
					* self.gameData.units[member].LPFactor[numCompetitors]
			end
		end
	end
	
	return adjBids
end

-- team roster size per each chapter
function auctionStateObj:teamPopPerChapter(lastChapter)
	local tPPC = {}
	tPPC[0] = {}
	
	local currPop = {}
	for player_i = 1, self.players.count do
		tPPC[0][player_i] = 0
		currPop[player_i] = 0
	end
	
	for unit_i = 1, self.gameData.units.count do
		currPop[self.owner[unit_i]] = currPop[self.owner[unit_i]] + 1
		local chapter = self.gameData.units[unit_i].joinChapter
	
		tPPC[chapter] = {}
		for player_i = 1, self.players.count do
			tPPC[chapter][player_i] = currPop[player_i]
		end
	end
	
	for chapter_i = 1, lastChapter do
		if not tPPC[chapter_i] then
			tPPC[chapter_i] = {}
			for player_i = 1, self.players.count do
				tPPC[chapter_i][player_i] = tPPC[chapter_i-1][player_i]
			end
		end
	end
	
	return tPPC
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

	for unit_i = 1, self.gameData.units.count do
		local net = 0
	
		player_j = self.owner[unit_i]
		for player_i = 1, self.players.count do
			vMatrix[player_i][player_j] = vMatrix[player_i][player_j] 
				+ bids[player_i][unit_i]
		end
	end
	
	return vMatrix
end

-- PxCh array of M totals by chapter
function auctionStateObj:createMC_Matrix()
	local MC_Matrix = {}
	
	for player_i = 1, self.players.count do
		MC_Matrix[player_i] = {}
		for chapter_i = 1, self.gameData.chapters.count do
			MC_Matrix[player_i][chapter_i] = 0
		end
	
		for unit_i = 1, self.gameData.units.count do
			for chapter_i = self.gameData.units[unit_i].joinChapter, 
				self.gameData.units[unit_i].lastChapter do
				
				MC_Matrix[player_i][chapter_i] = MC_Matrix[player_i][chapter_i] + 
					self.bids[player_i][unit_i] / self.gameData.units[unit_i].availability
			end
		end
	end
	
	return MC_Matrix
end

-- PxCh array of team values by chapter
function auctionStateObj:createVC_Matrix()
	local VC_Matrix = {}	
	local teams = self:teams()
	
	for player_i = 1, self.players.count do
		VC_Matrix[player_i] = {}
		for chapter_i = 1, self.gameData.chapters.count do
			VC_Matrix[player_i][chapter_i] = 0
		end
	
		for team_i = 1, self.maxTeamSize do
			local unit = teams[player_i][team_i]
		
			for chapter_i = self.gameData.units[unit].joinChapter, 
				self.gameData.units[unit].lastChapter do
				
				VC_Matrix[player_i][chapter_i] = VC_Matrix[player_i][chapter_i] + 
					self.bids[player_i][unit] / self.gameData.units[unit].availability
			end
		end
	end
	
	return VC_Matrix
end

--[[
-- reduce team value to compensate for redundancies
-- for example:
-- if the worst team can complete a chapter in 3 turns,
-- then no team can save more than 2 turns. nevertheless,
-- there may be three or more units that each individually
-- save one turn, yet all together cannot save 3 turns.
-- there is some max number of turns savable from the 
-- worst teams turncount, and we seek to reduce the value
-- of teams in relation to this max and the teams' unadjusted
-- values i.e. bid sums

-- the function f(value) = adjusted value should have the 
-- following properties:
-- f(0) = 0
-- f(infinity) -> M (max)
-- f(v) <= v
-- f(v) = Mv/(M+v) satisfies this
-- and has some mathematic motivation (ie not entirely arbitrary)
-- for now, let each player's bid sum = max for that player

-- also, should anchor to f(M/#p) = M/#p, not f(v) <= v
-- thus f(v) = Mv/(M(p-1)/p+v)
]]--
function auctionStateObj:adjustedValueMatrix(vMatrix)
	vMatrix = vMatrix or self:teamValueMatrix()

	local adjVMatrix = {}
	
	for player_i = 1, self.players.count do
		adjVMatrix[player_i] = {}
		local M = self.bidSums[player_i]
		local Mfactor = M*(self.players.count - 1)/self.players.count
		
		for player_j = 1, self.players.count do
			adjVMatrix[player_i][player_j] = M*vMatrix[player_i][player_j] 
				/(Mfactor+vMatrix[player_i][player_j])
		end
	end
	
	return adjVMatrix
end

-- finds prices that produce equalized satisfaction
-- A's satisfaction equals Handicapped Team Value - average opponent HTV
-- (from A's subjective perspective)
function auctionStateObj:paretoPrices(vMatrix)	
	vMatrix = vMatrix or self:adjustedValueMatrix()
	
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
	vMatrix = vMatrix or self:adjustedValueMatrix()
	
	local netSpiteValue = 0	
	for player_i = 1, self.players.count do
		netSpiteValue = netSpiteValue + spiteValue(vMatrix[player_i],player_i)
	end
	
	return netSpiteValue
end