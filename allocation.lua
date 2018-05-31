require("auctionStateObj")

-- assigns unit 1 to player 1, unit 2 to player 2, etc, looping
function auctionStateObj:regularAssign()
	for unit_i = 1, self.units.count do
		player_i = unit_i % self.players.count
		if player_i == 0 then player_i = 5 end
		self.assignedTo[player_i][unit_i] = true
	end
end

-- can make unbalanced teams
-- assign each unit to the player(s) with the greatest bid for them
function auctionStateObj:initialAssign()
	for unit_i = 1, self.units.count do
		local maxBid = -1
		for player_i = 1, self.players.count do
			if self.bids[player_i][unit_i] >= maxBid then
				maxBid = self.bids[player_i][unit_i]
			end
		end
		
		for player_i = 1, self.players.count do
			self.assignedTo[player_i][unit_i] = (self.bids[player_i][unit_i] == maxBid)
		end
	end
end

-- actually should be "multipleAssignmentExistsFor"
function auctionStateObj:tieExistsFor(unit_i)
	-- find unit assigned to multiple teams
	local alreadyAssigned = false
	for player_i = 1, self.players.count do
		if self.assignedTo[player_i][unit_i] then
			if alreadyAssigned then
				return true
			else
				alreadyAssigned = true
			end
		end
	end
	return false
end

-- returns earliest index of a tie if true, false if not
function auctionStateObj:tieExists()
	for unit_i = 1, self.units.count do
		if self:tieExistsFor(unit_i) then 
			return unit_i
		end
	end
	return false
end

-- break ties in order of list (recruitment?)
-- unit goes to team with lower total valuation, or reverse player list order
-- DO NOT add to hasBeenAssignedTo, don't want underfilled teams losing access by ties with 
-- filled/overfilled teams, thereby "leaking" units that become impossible to assign
function auctionStateObj:resolveTie(printV)
	local str = "Tiebreak:     "
	local tie_i = self:tieExists()
	
	if tie_i then 
		-- who among tied players has lowest total value?
		local lowestValue = 999
		local lowestValue_i = 0
		for player_i = 1, self.players.count do
			if self.assignedTo[player_i][tie_i] and
				self:totalValue(player_i) <= lowestValue then
				
				lowestValue = self:totalValue(player_i)
				lowestValue_i = player_i
			end
		end
		
		-- unassign unit from every other player, assign to player
		for player_i = 1, self.players.count do
			if self.assignedTo[player_i][tie_i] then
				if player_i ~= lowestValue_i then
					str = str .. string.format("%-10.10s ", self.players[player_i])
				end
			end
			self.assignedTo[player_i][tie_i] = (player_i == lowestValue_i)
		end
		str = str .. "->" .. string.format("%-10.10s ", self.units[tie_i][name_I])
		
		-- print to player
		for player_i = 1, self.players.count do
			if self.assignedTo[player_i][tie_i] then
				str = str .. "->" .. string.format("%-10.10s ", self.players[player_i])
			end
		end
	end
	if printV then
		print(str)
	end
end
function auctionStateObj:findOwner(unit_i)
	for player_i = 1, self.players.count do
		if self.assignedTo[player_i][unit_i] then
			return player_i
		end
	end
	return 0
end

-- determines tiebreaks, give to team with lowest total value
function auctionStateObj:totalValue(player_i)
	local value = 0
	for unit_i = 1, self.units.count do
		if self.assignedTo[player_i][unit_i] then
			value = value + self.bids[player_i][unit_i]
		end
	end
	return value
end

function auctionStateObj:teamSize(player_i)
	local ret = 0
	for unit_i = 1, self.units.count do
		if self.assignedTo[player_i][unit_i] then
			ret = ret + 1
		end
	end
	return ret
end

function auctionStateObj:filledNum()
	return self.units.count/self.players.count
end

function auctionStateObj:teamOverfilled(player_i)
	return self:teamSize(player_i) >= self:filledNum() + 1
end

function auctionStateObj:existOverfilledTeam()
	for player_i = 1, self.players.count do
		if self:teamOverfilled(player_i) then
			return true
		end
	end
	return false
end

function auctionStateObj:teamUnderfilled(player_i)
	return self:teamSize(player_i) <= self:filledNum() - 1
end

function auctionStateObj:existUnderfilledTeam()
	for player_i = 1, self.players.count do
		if self:teamUnderfilled(player_i) then
			return true
		end
	end
	return false
end

function auctionStateObj:reassignFrom(overfilled, printV)	
	local str = "Underfilled:  "
	if overfilled then str = "Overfilled:   " end

	-- find least desired unit from overfilled/filled
	local leastDesired_i = 0
	local leastDesired_value = 999
	
	-- find lowest differential from current to next
	-- minimize preference violation
	local lowestDif_i = 0
	local lowestDif = 999
	
	for player_i = 1, self.players.count do
		if (overfilled and self:teamOverfilled(player_i)) -- moving from overfilled
			or (not overfilled and not self:teamUnderfilled(player_i))then -- moving from filled
			
			for unit_i = 1, self.units.count do
				if self.assignedTo[player_i][unit_i] then
					-- found a player/unit combo that can move					
					if self.bids[player_i][unit_i] <= leastDesired_value then
						leastDesired_i = unit_i
						leastDesired_value = self.bids[player_i][unit_i]
					end
					
					-- check other players for differential
					for player_j = 1, self.players.count do
						if not self.wasAssignedTo[player_j][unit_i] and 
							not self.assignedTo[player_j][unit_i] then
							
							local dif = self.bids[player_i][unit_i] - self.bids[player_j][unit_i]
							
							if dif <= lowestDif then
								lowestDif = dif
								lowestDif_i = unit_i
							end
						end
					end
				end
			end
		end
	end
		
	local reassign_i = lowestDif_i
	
	-- remove from teams that have, and mark as previously had
	for player_i = 1, self.players.count do
		if self.assignedTo[player_i][reassign_i] then
			self.assignedTo[player_i][reassign_i] = false
			self.wasAssignedTo[player_i][reassign_i] = true
			
			str = str .. string.format("%-10.10s ->%-10.10s ->", 
				self.players[player_i], self.units[reassign_i][name_I])
		end
	end
	
	-- reassign to team that desires most, that hasn't had
	local mostDesire = -99
	local mostDesire_players = {}
	for player_i = 1, self.players.count do	
		if self.bids[player_i][reassign_i] >= mostDesire and 
			not self.wasAssignedTo[player_i][reassign_i] then
			
			mostDesire = self.bids[player_i][reassign_i]	
		end
	end
	
	for player_i = 1, self.players.count do
		if self.bids[player_i][reassign_i] >= mostDesire and 
			not self.wasAssignedTo[player_i][reassign_i] then
			
			self.assignedTo[player_i][reassign_i] = true
			
			str = str .. string.format("%-10.10s ",self.players[player_i])
		end
	end
	str = str .. string.format("%04.2f pref violation", lowestDif)
	
	if printV then
		print(str)
	end
end

-- can leave suboptimal preference violation in the following way:
-- unit A drops from overfilled player 1 to player 2
-- player 2 is now overfilled and drops A to player 3
-- player 3 is now overfilled and drops unit B to player 2
-- player 2 is overfilled again and drops unit C to player 4
-- now no one is overfilled: 1-D, 2-B, 3-A, 4-C
-- however, it might be that 2 bid more on A than 3 did, and 3 bid more on B than 2 did
-- so swapping would reduce the preference violation

function auctionStateObj:swapUnits(unit_i, unit_j, printV)
	local player_i = self:findOwner(unit_i)
	local player_j = self:findOwner(unit_j)

	if printV then
		if unit_i == 0 or unit_j == 0 then print(tostring(unit_i) .. tostring(unit_j)) end
	
		print(string.format("Swapping: %-10.10s %-10.10s <-> %-10.10s %-10.10s",
				self.players[player_i], self.units[unit_i][name_I],
				self.players[player_j], self.units[unit_j][name_I]))
	end
	
	self.assignedTo[player_i][unit_i] = false
	self.assignedTo[player_j][unit_i] = true
	
	self.assignedTo[player_j][unit_j] = false
	self.assignedTo[player_i][unit_j] = true
end

-- returns true if a swap was made
-- otherwise returns false
-- makes max swap first so as to not be subject to recruitment order, player order etc
function auctionStateObj:cleanupPrefViolation(printV)	
	local bestSwapValue = 0
	local maxSwap_i = 0
	local maxSwap_j = 0
	
	for unit_i = 1, self.units.count do
		local player_i = self:findOwner(unit_i)
		for unit_j = 1, self.units.count do
			local player_j = self:findOwner(unit_j)
			
			local swapValue = (self.bids[player_i][unit_j] + self.bids[player_j][unit_i]) -- swapped bid sum
				- (self.bids[player_i][unit_i] + self.bids[player_j][unit_j]) -- current bid
			
			if bestSwapValue < swapValue then
				bestSwapValue = swapValue
				maxSwap_i = unit_i
				maxSwap_j = unit_j
			end
		end
	end
	
	if maxSwap_i ~= 0 then		
		self:swapUnits(maxSwap_i, maxSwap_j, printV)
		return true
	end
	return false
end

-- see how each swap affects preference violation, chapterGap sum of squares, and promoClasses SoS
-- if favorable, swap them and return true, else return false
function auctionStateObj:finesseTeams(threshold, printV)	
	local bestSwapValue = -1
	-- if no PrefVio loss, then just gain, don't divide by 0
	local noPrefVioLoss = false
	
	local maxSwap_i = 1 -- default to 1, defaulting to 0 causes an issue when all bids are tied, possibly in other situations
	local maxSwap_j = 1
	
	local savedPrefViolation = self:averagePreferenceViolation()
	local savedCGSoS = sumOfSquares(self:chapterGaps())
	local savedPCSoS = sumOfSquares(self:promoClasses())
	
	for unit_i = 1, self.units.count do
		local player_i = self:findOwner(unit_i) 
		
		for unit_j = unit_i+1, self.units.count do
			local player_j = self:findOwner(unit_j)
			
			-- try swap
			if player_j ~= player_i then
				self:swapUnits(unit_i, unit_j)
				
				local prefVioLoss = self:averagePreferenceViolation() - savedPrefViolation
				
				-- note that even after cleanup, this function will violate the preferences
				-- so prefVioLoss will become negative, and the function will try to 
				-- switch back unless we check
				if prefVioLoss >= 0 then
					local CGSoSgain = savedCGSoS - sumOfSquares(self:chapterGaps())
					local PCSoSgain = savedPCSoS - sumOfSquares(self:promoClasses())
					
					local weightedGain = CGSoSgain + PCSoSgain
					
					local swapValue = -1
					if noPrefVioLoss then
						if prefVioLoss == 0 then
							swapValue = weightedGain
						end
					else
						if prefVioLoss == 0 then
							if weightedGain > 0 then
								noPrefVioLoss = true						
								bestSwapValue = -1 -- reset standards
							end
							swapValue = weightedGain
						else
							swapValue = weightedGain/prefVioLoss
						end
					end
					
					if bestSwapValue < swapValue then
						bestSwapValue = swapValue
						maxSwap_i = unit_i
						maxSwap_j = unit_j
					end
				end
				
				self:swapUnits(unit_i, unit_j)
			end
		end
	end
	
	local function printChange()
		print(string.format("old CGSoS %8.6f, PCSoS %8.6f, prefVio %8.6f",
			savedCGSoS, savedPCSoS, savedPrefViolation*100) .. "%")
		
		self:swapUnits(maxSwap_i, maxSwap_j, true)
		
		print(string.format("new CGSoS %8.6f, PCSoS %8.6f, prefVio %8.6f",
			sumOfSquares(self:chapterGaps()), sumOfSquares(self:promoClasses()),
			self:averagePreferenceViolation()*100) .. "%")
			
		print(string.format("value %f", bestSwapValue))
	end
	
	if (threshold <= bestSwapValue) or noPrefVioLoss then
		if printV then
			print()
			printChange() -- includes swap
		else
			self:swapUnits(maxSwap_i, maxSwap_j, false)
		end
		return true
	end

	if printV then 
		print()
		print("no acceptable swap, best candidate") 
		printChange()
		
		self:swapUnits(maxSwap_i, maxSwap_j, false) -- swap back, printChange makes swap
	end
	return false
end
