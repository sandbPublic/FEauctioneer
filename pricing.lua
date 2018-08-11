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

function auctionStateObj:maxUnrestrictedSat()
	local maxUnSat = 0
	
	for unit_i = 1, self.gameData.units.count do
		local uBids = {}
		local maxBid = 0
		local maxBid_i = 1
		for player_i = 1, self.players.count do
			uBids[player_i] = self.bids[player_i][unit_i]
			
			if maxBid < uBids[player_i] then
				maxBid = uBids[player_i]
				maxBid_i = player_i
			end
		end
		
		maxUnSat = maxUnSat + spiteValue(uBids, maxBid_i)
	end
	
	return maxUnSat
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
local function R(V, M, PFactor)
	if M == 0 then
		return 0	
	end
	
	return V*M/(V+M*PFactor)
end

-- the vMatrix shows how player i values player j's team for all i,j
-- raw, unadjusted values
function auctionStateObj:teamValueMatrix()
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
				+ self.bids[player_i][unit_i]
		end
	end
	
	return vMatrix
end

-- PxCh array of M totals by chapter, includes sums
-- adjusted for promo items
function auctionStateObj:createMC_Matrix()
	local MC_Matrix = {}
	
	for player_i = 1, self.players.count do
		MC_Matrix[player_i] = {}
		for chapter_i = 1, self.gameData.chapters.count do
			MC_Matrix[player_i][chapter_i] = 0
		end
		MC_Matrix[player_i].sum = 0
	
		for unit_i = 1, self.gameData.units.count do
			local LPF = self.gameData.units[unit_i].LPFactor
			local unitValue = self.bids[player_i][unit_i] / 
					self.gameData.units[unit_i].availability
			
			for chapter_i = self.gameData.units[unit_i].joinChapter, 
				self.gameData.units[unit_i].lastChapter do
				
				local unitValueThisChapter = unitValue
				-- adjust for maximal promo item competition
				if LPF.adjusted then
					unitValueThisChapter = unitValueThisChapter * LPF[LPF.count][chapter_i]
				end
				
				MC_Matrix[player_i][chapter_i] = MC_Matrix[player_i][chapter_i] + unitValueThisChapter
				MC_Matrix[player_i].sum = MC_Matrix[player_i].sum + unitValueThisChapter
			end
		end
	end
	
	return MC_Matrix
end

-- PxPxCh array of subjective team values by chapter
function auctionStateObj:createVC_Matrix()
	local VC_Matrix = {}	
	local teams = self:teams()
	
	for player_i = 1, self.players.count do -- player i's perspective (bids)
		VC_Matrix[player_i] = {}
		for player_j = 1, self.players.count do -- player j's team
			VC_Matrix[player_i][player_j] = {}
			
			for chapter_i = 1, self.gameData.chapters.count do
				VC_Matrix[player_i][player_j][chapter_i] = 0
			end
		
			for team_i = 1, self.maxTeamSize do
				local unit = teams[player_j][team_i]
				local incValue = self.bids[player_i][unit] / self.gameData.units[unit].availability
				
				local LPF = self.gameData.units[unit].LPFactor
				
				local predec = 0
				if LPF.adjusted then
					for team_j = 1, team_i - 1 do
						if self.gameData:sharePI(teams[player_j][team_j], unit) then
							predec = predec + 1
						end
					end
				end
				
				if predec > 0 then -- only check once to reduce innermost loop
					for chapter_i = self.gameData.units[unit].joinChapter, 
						self.gameData.units[unit].lastChapter do
						
						VC_Matrix[player_i][player_j][chapter_i] = 
							VC_Matrix[player_i][player_j][chapter_i] + incValue*LPF[predec][chapter_i]
					end
				else
					for chapter_i = self.gameData.units[unit].joinChapter, 
						self.gameData.units[unit].lastChapter do
						
						VC_Matrix[player_i][player_j][chapter_i] = 
							VC_Matrix[player_i][player_j][chapter_i] + incValue
					end
				end
			end
		end
	end
	
	return VC_Matrix
end

-- PxPxCh array of R values by chapter
function auctionStateObj:createRC_Matrix(VC_Matrix, MC_Matrix)
	VC_Matrix = VC_Matrix or self:createVC_Matrix()
	MC_Matrix = MC_Matrix or self.MC_Matrix

	local RC_Matrix = {}
	
	for player_i = 1, self.players.count do -- player i's perspective (M)
		RC_Matrix[player_i] = {}
		for player_j = 1, self.players.count do -- player j's team
			RC_Matrix[player_i][player_j] = {}
			RC_Matrix[player_i][player_j].sum = 0
			
			for chapter_i = 1, self.gameData.chapters.count do
				RC_Matrix[player_i][player_j][chapter_i] = 
					R(VC_Matrix[player_i][player_j][chapter_i], 
					MC_Matrix[player_i][chapter_i], 
					self.players.count)
					
				RC_Matrix[player_i][player_j].sum = RC_Matrix[player_i][player_j].sum +
					RC_Matrix[player_i][player_j][chapter_i]
			end
		end
	end
	
	return RC_Matrix
end

-- after computing raw V(i,j), feeds into R(), not chapter-wise
function auctionStateObj:adjustedValueMatrix(vMatrix)
	vMatrix = vMatrix or self:teamValueMatrix()

	local adjVMatrix = {}
	local PFactor = 1 - 1/self.players.count
	
	for player_i = 1, self.players.count do
		adjVMatrix[player_i] = {}
		for player_j = 1, self.players.count do
			adjVMatrix[player_i][player_j] = 
				R(vMatrix[player_i][player_j], self.bidSums[player_i], PFactor)
		end
	end
	
	return adjVMatrix
end

-- split V into VC, run VC and MC through R(), then sum results together again
-- eg sum(R(V_C)), not R(sum(V_C))
function auctionStateObj:adjustedVC_Sum_Matrix()
	local adjVMatrix = {}
	
	VC_Matrix = self:createVC_Matrix()
	local PFactor = 1 - 1/self.players.count
	
	for player_i = 1, self.players.count do -- player i's perspective (M)
		adjVMatrix[player_i] = {}
		for player_j = 1, self.players.count do -- player j's team
			adjVMatrix[player_i][player_j] = 0
			
			for chapter_i = 1, self.gameData.chapters.count do	
				adjVMatrix[player_i][player_j] = adjVMatrix[player_i][player_j] +
					R(VC_Matrix[player_i][player_j][chapter_i], 
					self.MC_Matrix[player_i][chapter_i], 
					PFactor)
			end
		end
	end
	
	return adjVMatrix
end

-- finds prices that produce equalized satisfaction
-- A's satisfaction equals Handicapped Team Value - average opponent HTV
-- (from A's subjective perspective)
function auctionStateObj:paretoPrices(vMatrix)	
	vMatrix = vMatrix or self:adjustedVC_Sum_Matrix()
	
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
-- anti-brittle feature, add some fraction of V(i,i)
-- accept some loss of satisfaction for a large gain in team quality
-- helps avoid promo redundancies, highly redundant teams, etc
function auctionStateObj:allocationScore(vMatrix)
	vMatrix = vMatrix or self:adjustedVC_Sum_Matrix()
	
	local netSpiteValue = 0	
	for player_i = 1, self.players.count do
		netSpiteValue = netSpiteValue + spiteValue(vMatrix[player_i],player_i) 
			+ vMatrix[player_i][player_i] / 8
	end
	
	return netSpiteValue
end