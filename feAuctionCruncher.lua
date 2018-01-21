local auctionStateObj = {}
function auctionStateObj:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	o.numOf_players = 0
	o.players = {} -- strings
	o.numOf_units = 0
	o.units = {} -- strings
	o.chapters = {} -- chapter the unit appears
	o.promoItems = {} -- item unit uses to promote, if any
	o.promoItemTotals = {}
	
	o.bids = {} -- PxU array of numbers
	o.assignedTo = {} -- PxU array of bools. 
	-- units can temporarily be assigned to more than one player if ties exist
	o.wasAssignedTo = {} -- PxU array of bools. 
	-- don't reassign to past assignment, avoid cycles with ties
	o.prefViolationFactor = 0 -- compute in initialize, for averagePreferenceViolation()
	
	return o
end

-- promo items
local promo_NO = 0 -- can't promote
local promo_HC = 1 -- hero crest
local promo_KC = 2 -- knight crest
local promo_OB = 3 -- orion's bolt
local promo_EW = 4 -- elysian whip
local promo_GR = 5 -- guiding ring
local promo_FC = 6 -- fell contract
local promo_OS = 7 -- ocean seal
local promo_HS = 8 -- heaven seal

local promoStrings = {"hC", "kC", "oB", "eW", "gR", "fC", "oS", "hS"}
promoStrings[0] = "No"

function auctionStateObj:initialize()
	local totalBids = 0
	for player_i = 1, self.numOf_players do
		self.assignedTo[player_i] = {}
		self.wasAssignedTo[player_i] = {}
		for unit_i = 1, self.numOf_units do
			totalBids = totalBids + self.bids[player_i][unit_i]
			self.assignedTo[player_i][unit_i] = false
			self.wasAssignedTo[player_i][unit_i] = false
		end
	end
	
	for promoItem_i = 0, 8 do
		self.promoItemTotals[promoItem_i] = 0
	end
	for unit_i = 1, self.numOf_units do
		self.promoItemTotals[self.promoItems[unit_i]] = 
			self.promoItemTotals[self.promoItems[unit_i]] + 1
	end
	
	self.prefViolationFactor = self.numOf_players/totalBids
end

-- can make unbalanced teams
-- assign each unit to the player(s) with the greatest bid for them
function auctionStateObj:initialAssign()	
	for unit_i = 1, self.numOf_units do
		local maxBid = -1
		for player_i = 1, self.numOf_players do
			if self.bids[player_i][unit_i] >= maxBid then
				maxBid = self.bids[player_i][unit_i]
			end
		end
		
		for player_i = 1, self.numOf_players do
			self.assignedTo[player_i][unit_i] = (self.bids[player_i][unit_i] == maxBid)
		end
	end
end

function auctionStateObj:printBids()
	print("")
	print("-BIDS-")
	local str = "           "
	for player_i = 1, self.numOf_players do
		str = str .. string.format("%-10.10s ", self.players[player_i])
	end
	print(str)
	
	for unit_i = 1, self.numOf_units do
		str = string.format("%-10.10s ", self.units[unit_i])
		for player_i = 1, self.numOf_players do
			str = str ..  string.format("%-10.10s ", 
				string.format("%05.2f", self.bids[player_i][unit_i]))
		end
		
		print(str)
	end
end

function auctionStateObj:findOwner(unit_i)
	for player_i = 1, self.numOf_players do
		if self.assignedTo[player_i][unit_i] then
			return player_i
		end
	end
	return 0
end

-- this function ensures that the expected value of over or underbidding
-- is strictly non-positive (i.e. strategically dominated by true bidding)
function auctionStateObj:handicapPrice(unit_i)
	local ownerBid = self.bids[self:findOwner(unit_i)][unit_i]
	
	-- find largest bid not greater than that, from player not assigned to, at least 0
	-- bids from past owners should be larger than current, hence not considered again
	local secondPrice = -1
	for player_i = 1, self.numOf_players do
		if (self.bids[player_i][unit_i] <= ownerBid and
		   self.bids[player_i][unit_i] >= secondPrice and
		   not self.assignedTo[player_i][unit_i]) then
		
			secondPrice = self.bids[player_i][unit_i]
		end
	end
	
	if secondPrice >= 0 then
		return secondPrice + (ownerBid - secondPrice)/self.numOf_players
	else -- owner(s) in last place, special behavior, pay 2nd-to-last price
	
		local secondLastPrice = 999
		for player_i = 1, self.numOf_players do
			if (self.bids[player_i][unit_i] <= secondLastPrice and
			   not self.assignedTo[player_i][unit_i]) then
			   
				secondLastPrice = self.bids[player_i][unit_i]
			end
		end
		if secondLastPrice == 999 then
			return self.bids[1][unit_i] -- assigned to all players
		end
		
		return ownerBid + (secondLastPrice - ownerBid)/self.numOf_players
	end
end

function auctionStateObj:totalHandicap(player_i)
	local hc = 0
	for unit_i = 1, self.numOf_units do
		if self.assignedTo[player_i][unit_i] then
			hc = hc + self:handicapPrice(unit_i)
		end
	end
	return hc
end

-- determines tiebreaks, give to team with lowest total value
function auctionStateObj:totalValue(player_i)
	local value = 0
	for unit_i = 1, self.numOf_units do
		if self.assignedTo[player_i][unit_i] then
			value = value + self.bids[player_i][unit_i]
		end
	end
	return value
end

function auctionStateObj:printTeams()
	local smallestHCtotal = 999
	for player_i = 1, self.numOf_players do
		if self:totalHandicap(player_i) < smallestHCtotal then
			smallestHCtotal = self:totalHandicap(player_i)
		end
	end
	
	for player_i = 1, self.numOf_players do
		print("")
		print(string.format("%-10.10s price | bid", self.players[player_i]))
		
		for unit_i = 1, self.numOf_units do
			if self.assignedTo[player_i][unit_i] then
				local str = string.format("%-10.10s %05.2f | %05.2f", 
					self.units[unit_i], self:handicapPrice(unit_i), self.bids[player_i][unit_i])			
				print(str)
			end
		end
		print(string.format("TOTAL      %05.2f, relative hc %05.2f", 
			self:totalHandicap(player_i), self:totalHandicap(player_i)-smallestHCtotal))		
	end
end

-- actually should be "multipleAssignmentExistsFor"
function auctionStateObj:tieExistsFor(unit_i)
	-- find unit assigned to multiple teams
	local alreadyAssigned = false
	for player_i = 1, self.numOf_players do
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
	for unit_i = 1, self.numOf_units do
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
		for player_i = 1, self.numOf_players do
			if self.assignedTo[player_i][tie_i] and
				self:totalValue(player_i) <= lowestValue then
				
				lowestValue = self:totalValue(player_i)
				lowestValue_i = player_i
			end
		end
		
		-- unassign unit from every other player, assign to player
		for player_i = 1, self.numOf_players do
			if self.assignedTo[player_i][tie_i] then
				if player_i ~= lowestValue_i then
					str = str .. string.format("%-10.10s ", self.players[player_i])
				end
			end
			self.assignedTo[player_i][tie_i] = (player_i == lowestValue_i)
		end
		str = str .. "->" .. string.format("%-10.10s ", self.units[tie_i])
		
		-- print to player
		for player_i = 1, self.numOf_players do
			if self.assignedTo[player_i][tie_i] then
				str = str .. "->" .. string.format("%-10.10s ", self.players[player_i])
			end
		end
	end
	if printV then
		print(str)
	end
end

function auctionStateObj:teamSize(player_i)
	local ret = 0
	for unit_i = 1, self.numOf_units do
		if self.assignedTo[player_i][unit_i] then
			ret = ret + 1
		end
	end
	return ret
end

function auctionStateObj:filledNum()
	return self.numOf_units/self.numOf_players
end

function auctionStateObj:teamOverfilled(player_i)
	return self:teamSize(player_i) >= self:filledNum() + 1
end

function auctionStateObj:existOverfilledTeam()
	for player_i = 1, self.numOf_players do
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
	for player_i = 1, self.numOf_players do
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
	
	for player_i = 1, self.numOf_players do
		if (overfilled and self:teamOverfilled(player_i)) -- moving from overfilled
			or (not overfilled and not self:teamUnderfilled(player_i))then -- moving from filled
			
			for unit_i = 1, self.numOf_units do
				if self.assignedTo[player_i][unit_i] then
					-- found a player/unit combo that can move					
					if self.bids[player_i][unit_i] <= leastDesired_value then
						leastDesired_i = unit_i
						leastDesired_value = self.bids[player_i][unit_i]
					end
					
					-- check other players for differential
					for player_j = 1, self.numOf_players do
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
	for player_i = 1, self.numOf_players do
		if self.assignedTo[player_i][reassign_i] then
			self.assignedTo[player_i][reassign_i] = false
			self.wasAssignedTo[player_i][reassign_i] = true
			
			str = str .. string.format("%-10.10s ->%-10.10s ->", 
				self.players[player_i], self.units[reassign_i])
		end
	end
	
	-- reassign to team that desires most, that hasn't had
	local mostDesire = -99
	local mostDesire_players = {}
	for player_i = 1, self.numOf_players do	
		if self.bids[player_i][reassign_i] >= mostDesire and 
			not self.wasAssignedTo[player_i][reassign_i] then
			
			mostDesire = self.bids[player_i][reassign_i]	
		end
	end
	
	for player_i = 1, self.numOf_players do
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
		print(string.format("Swapping: %-10.10s %-10.10s <-> %-10.10s %-10.10s",
				self.players[player_i], self.units[unit_i],
				self.players[player_j], self.units[unit_j]))
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
	
	for unit_i = 1, self.numOf_units do
		local player_i = self:findOwner(unit_i)
		for unit_j = 1, self.numOf_units do
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

-- scale to average bid
-- preference violation is a measure of how much the owner's bid differs from the highest bid.
-- with no other considerations, the unit should go to highest bidder.
-- however, team balance and chapter gap smoothing provide an incentive to violate that principle.
function auctionStateObj:averagePreferenceViolation()
	local violations = 0
	for unit_i = 1, self.numOf_units do
		local highestBid = 0
		for player_i = 1, self.numOf_players do
			if highestBid < self.bids[player_i][unit_i] then
				highestBid = self.bids[player_i][unit_i]
			end
		end
		violations = violations + highestBid - self.bids[self:findOwner(unit_i)][unit_i]
	end
	
	return violations*self.prefViolationFactor
end

-- takes 2D array, eg first dimension players, second dimension value
local function sumOfSquares(array)
	local sum = 0
	local i = 1 -- starting at 1 correctly skips non-promoters
	while array[i] do
		local sumOfSquares = 0
		local j = 1
		while array[i][j] do
			sumOfSquares = sumOfSquares + array[i][j]*array[i][j]
			j = j + 1
			if j > 10000 then print("BAD J") end
		end
		sum = sum + sumOfSquares
		i = i + 1
		
		if i > 10000 then print("BAD I") end
	end
	return sum
end

-- gaps between drafted units appearing, numOf_player X (teamSize + 1) array
-- values normalized
function auctionStateObj:chapterGaps(printV)
	local ret = {}
	local totalGap = self.chapters[self.numOf_units] - self.chapters[1]
	
	if printV then
		print()
		print("Chapter gaps")
	end
	for player_i = 1, self.numOf_players do
		if printV then 
			print() 
			print(self.players[player_i]) 
		end
		
		ret[player_i] = {}
		local lastChapter = self.chapters[1] -- first chapter a unit can be available
		local gap_i = 1
		local gap = 0
		local normalized = 0
		for unit_i = 1, self.numOf_units do
			if self.assignedTo[player_i][unit_i] then
			
				gap = self.chapters[unit_i] - lastChapter
				normalized = gap/totalGap
				
				if printV then
					print(string.format("%-10.10s %2d %2d/%2d=%4.2f %4.2f", 
						self.units[unit_i], self.chapters[unit_i], gap, totalGap,
						normalized, normalized*normalized))
				end				
				ret[player_i][gap_i] = normalized
				lastChapter = self.chapters[unit_i]
				gap_i = gap_i + 1
			end	
		end
		
		-- gap to end
		gap = self.chapters[self.numOf_units] - lastChapter
		normalized = gap/totalGap
		
		ret[player_i][gap_i] = normalized
		
		if printV then
			print(string.format("-end-      %2d %2d/%2d=%4.2f %4.2f",
				self.chapters[self.numOf_units], gap, totalGap,
				normalized, normalized*normalized))
		
			local sumOfSq = 0
			for gap_i2 = 1, gap_i do
				sumOfSq = sumOfSq + ret[player_i][gap_i2]*ret[player_i][gap_i2]
			end
			print(string.format("sum of squares:          %4.2f", sumOfSq))
		end
	end
	
	if printV then
		print()
		print("total " .. tostring(sumOfSquares(ret)))
	end
	
	return ret
end

-- number of each promo type, numOf_player X 8 array
-- values normalized
function auctionStateObj:promoClasses(printV)
	local ret = {} -- normalized values
	local count = {} -- raw counts
	
	if printV then
		print()
		print("Promo classes")
	end
	for player_i = 1, self.numOf_players do
		if printV then 
			print() 
			print(self.players[player_i]) 
		end
		
		ret[player_i] = {}
		count[player_i] = {}
		for promoItem_i = 0, 8 do
			count[player_i][promoItem_i] = 0
		end
		
		for unit_i = 1, self.numOf_units do
			if self.assignedTo[player_i][unit_i] then
				count[player_i][self.promoItems[unit_i]] = 
					count[player_i][self.promoItems[unit_i]] + 1
			end	
		end
		
		local sumOfSq = 0
		for promoItem_i = 0, 8 do
			local normalized = count[player_i][promoItem_i]/self.promoItemTotals[promoItem_i]
			ret[player_i][promoItem_i] = normalized
			
			local square = 0
			if promoItem_i > 0 then -- don't count non promotions
				square = normalized*normalized
			end
			sumOfSq = sumOfSq + square
			
			if printV and count[player_i][promoItem_i] > 0 then
				print(string.format("%s %d/%d=%4.2f %4.2f", 
					promoStrings[promoItem_i], count[player_i][promoItem_i], 
					self.promoItemTotals[promoItem_i], normalized, square))
			end
		end
		if printV then print(string.format("sum of squares:  %4.2f", sumOfSq)) end
	end
	
	if printV then
		print()
		print(string.format("total %4.2f", sumOfSquares(ret)))
	end
	
	return ret
end

-- see how each swap affects preference violation, chapterGap sum of squares, and promoClasses SoS
-- if favorable, swap them and return true, else return false
function auctionStateObj:finesseTeams(threshold, printV)	
	local bestSwapValue = -1
	-- if no PrefVio loss, then just gain, don't divide by 0
	local noPrefVioLoss = false
	
	local maxSwap_i = 0
	local maxSwap_j = 0
	
	local savedPrefViolation = self:averagePreferenceViolation()
	local savedCGSoS = sumOfSquares(self:chapterGaps())
	local savedPCSoS = sumOfSquares(self:promoClasses())
	
	for unit_i = 1, self.numOf_units do
		local player_i = self:findOwner(unit_i) 
		
		for unit_j = unit_i+1, self.numOf_units do
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
						if prefVioLoss == 0 and weightedGain > 0 then
							noPrefVioLoss = true						
							bestSwapValue = -1 -- reset standards							
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
		print(string.format("old CGSoS %8.6f, old PCSoS %8.6f, old prefVio %8.6f",
			savedCGSoS, savedPCSoS, savedPrefViolation*100) .. "%")
		
		self:swapUnits(maxSwap_i, maxSwap_j, true)
		
		print(string.format("new CGSoS %8.6f, new PCSoS %8.6f, new prefVio %8.6f",
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

function auctionStateObj:standardProcess()		
	self:initialize()
	self:printBids()
	self:initialAssign()
	
	print()
	print("Unbalanced teams")
	
	self:printTeams()

	print()
	print("Balancing")
	
	while (self:existUnderfilledTeam() 
		or self:existOverfilledTeam() 
		or self:tieExists()) do
		
		while (self:existOverfilledTeam() or self:tieExists()) do
			while self:tieExists() do
				self:resolveTie(true)
			end
			
			if self:existOverfilledTeam() then
				self:reassignFrom(true, true)
			end
		end
		
		if self:existUnderfilledTeam() then
			self:reassignFrom(false, true)
		end
	end

	self:printTeams()
	
	print()
	print(string.format("average preference violation: %8.6f",
		self:averagePreferenceViolation()*100) .. "%")
	
	print("cleaning up preference violations")	
	while(self:cleanupPrefViolation(true)) do end
	
	print(string.format("average preference violation: %8.6f",
		self:averagePreferenceViolation()*100) .. "%")
	
	self:chapterGaps(true)
	self:promoClasses(true)
	
	print()
	print("Attempting to balance chapter gaps and promotion classes")	
	while self:finesseTeams(40, true) do 
		emu.frameadvance() -- prevent unresponsiveness
	end
	
	print()
	print("--Final teams--")
	self:printTeams()
	
	print()
	print("END")
end

--"Franz", "Gilliam", "Moulder", "Vanessa", "Ross", "Garcia","Neimi", "Colm", "Artur", "Lute", "Natasha", "Joshua", "Forde", "Kyle", "Tana", "Amelia", "Innes", "Gerik", "Marisa", "L'Arachel", "Dozla", "Cormag", "Saleh", "Ewan", "Rennac", "Duessel", "Knoll", "Syrene"

-- no Wallace/Geitz or Harken/Karel
local FE7auction2 = auctionStateObj:new()
FE7auction2.numOf_players = 5
FE7auction2.players = {"P1", "P2", "P3", "P4", "P5"}
FE7auction2.numOf_units = 35
FE7auction2.units = {
"Matthew", "Serra", "Oswin", "Eliwood", "Lowen", "Rebecca", "Dorcas", "Bartre&Karla", 
"Marcus<=19x", "Guy", "Erk", "Priscilla", "Florina", "Lyn", "Sain", "Kent", "Wil", "Raven", 
"Lucius", "Canas", "Dart", "Fiora", "Legault", "Marcus>=20", "Isadora", "Heath", "Rath", 
"Hawkeye", "Farina", "Pent", "Louise", "Nino", "Jaffar", "Vaida", "Renault"}

-- indexed from 0, not 11, gaidens count as normal
FE7auction2.chapters = { -- Matthew is free for ch 11, Lyn~Wil for ch 16
1, 1, 1, 1, 1, 1, 1, 1,
1, 2, 4, 4, 6, 7, 7, 7, 7, 7,
7, 8, 10, 10, 12, 12, 14, 14, 14,
15, 18, 19, 19, 21, 22, 23, 27
}

FE7auction2.promoItems = {
promo_FC, promo_GR, promo_KC, promo_HS, promo_KC, promo_OB, promo_HC, promo_HC,
promo_NO, promo_HC, promo_GR, promo_GR, promo_EW, promo_HS, promo_KC, promo_KC, promo_OB, promo_HC,
promo_GR, promo_GR, promo_OS, promo_EW, promo_FC, promo_NO, promo_NO, promo_EW, promo_OB,
promo_NO, promo_EW, promo_NO, promo_NO, promo_GR, promo_NO, promo_NO, promo_NO
}

FE7auction2.bids = {
{5.07, 3.65, 4.28, 6.32, 9.88, 3.02, 3.95, 3.02, 
7.0, 1.2, 9.07, 6.07, 11.38, 1.58, 8.3, 8.2, 2.27, 2.2, 
6.82, 8.32, 2.9, 7.78, 1.18, 7.0, 2.88, 11.38, 5.7, 
2.45, 0.82, 7, 1.13, 4.42, 1.2, 2.95, 0},
{},
{},
{},
{}
}

for player_i = 2, 5 do
	local playerWeight = (1 + 0.2*(math.random()-0.5)) -- simulate players bidding higher/lower overall
	for unit_i = 1, FE7auction2.numOf_units do
		FE7auction2.bids[player_i][unit_i] = 
			FE7auction2.bids[1][unit_i] 
				* playerWeight * (1 + 0.6*(math.random()-0.5))
	end
end

print("FE7auction2")
FE7auction2:standardProcess()

local asObj_FE7fourPlayer = auctionStateObj:new()
asObj_FE7fourPlayer.numOf_players = 4
asObj_FE7fourPlayer.players = {"Wargrave", "Carmine", "Horace", "Baldrick"}
asObj_FE7fourPlayer.numOf_units = 32
asObj_FE7fourPlayer.units = {
"Matthew", "Serra", "Oswin", "Eliwood", "Lowen", "Rebecca", "Dorcas", "Bartre+K", "Guy", "Erk", 
"Priscilla", "Florina", "Lyn", "Sain", "Kent", "Wil", "Raven", "Lucius", "Canas", "Dart", "Fiora", 
"Legault", "Isadora", "Heath", "Rath", "Hawkeye", "Farina", "Pent", "Louise", "Nino", "Jaffar", 
"Vaida"}

-- indexed from 0, not 11, gaidens count as normal
asObj_FE7fourPlayer.chapters = { -- Matthew is free for ch 11, Lyn~Wil for ch 16
1, 1, 1, 1, 1, 1, 1, 1, 2, 4, 
4, 6, 7, 7, 7, 7, 7, 7, 8, 10, 10, 
12, 14, 14, 14, 15, 18, 19, 19, 21, 22, 
23
}

asObj_FE7fourPlayer.promoItems = {
promo_FC, promo_GR, promo_KC, promo_HS, promo_KC, promo_OB, promo_HC, promo_HC, promo_HC, promo_GR, 
promo_GR, promo_EW, promo_HS, promo_KC, promo_KC, promo_OB, promo_HC, promo_GR, promo_GR, promo_OS, promo_EW, 
promo_FC, promo_NO, promo_EW, promo_OB, promo_NO, promo_EW, promo_NO, promo_NO, promo_GR, promo_NO, 
promo_NO
}

asObj_FE7fourPlayer.bids = {
{3.2, 3.5, 3.5, 3.5, 9.8, 1.7, 2.3, 1.9, 1.8, 5.5, 4.5, 12.5, 1.4, 9.2, 8.8, 1.6, 2.5, 3.3, 2.7, 2.2, 6.5, 1.7, 2, 5.2, 2.8, 1.8, 3.1, 3.1, 1.5, 0.9, 1.5, 2.6},
{3, 2, 4, 4.5, 12, 0.5, 6.5, 3, 1, 12, 5, 13, 0.5, 8, 8, 0.5, 2, 9, 12, 1, 7, 1, 5.5, 10.5, 7.5, 3.5, 4, 7, 1, 0, 2.25, 4},
{4.1, 4.1, 5.1, 5.1, 10.1, 3.1, 3.1, 3.1, 0, 8.1, 5.1, 0, 2.1, 6.1, 6.1, 3.1, 2.1, 6.1, 7.1, 2.1, 10.1, 0, 1.1, 10.1, 5.1, 2.1, 0.1, 2.1, 0.1, 0.2, 1.1, 1.1},
{8, 5, 6, 10, 12, 3, 1, 1, 1, 8, 9, 11, 4, 10, 10, 2, 1, 4, 4, 5, 7, 2, 6, 14, 4, 4, 3, 7, 2, 15, 2, 2}}

--print("FE7auction1")
--asObj_FE7fourPlayer:standardProcess()