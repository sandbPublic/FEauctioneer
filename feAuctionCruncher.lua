require("feAuctionUnitData")

local auctionStateObj = {}
function auctionStateObj:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
		
	o.players = {} -- strings
	o.players.count = 0	
	o.units = {} -- names, chapter, promo
	o.units.count = 0
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
local promoStrings = {"kCrst", "hCrst",  "oBolt", "eWhip", "gRing", "hSeal", "oSeal", "FellC"}
promoStrings[0] = "None "

-- using indexes instead of named table fields allows for more organized unitData
local name_I = 1
local chapter_I = 2
local promo_I = 3

-- takes in a table from unitData
function auctionStateObj:initialize(version, bidFile, numPlayers)
	-- load data
	self.units = {}
	self.units.count = 0
	while version[self.units.count+1] do
		self.units.count = self.units.count + 1		
		self.units[self.units.count] = 
			version[self.units.count]
	end
	
	-- load bids
	self:readBids(bidFile, numPlayers)
	
	local totalBids = 0
	for player_i = 1, self.players.count do
		self.assignedTo[player_i] = {}
		self.wasAssignedTo[player_i] = {}
		for unit_i = 1, self.units.count do
			totalBids = totalBids + self.bids[player_i][unit_i]
			self.assignedTo[player_i][unit_i] = false
			self.wasAssignedTo[player_i][unit_i] = false
		end
	end
	
	for promoItem_i = 0, 8 do
		self.promoItemTotals[promoItem_i] = 0
	end
	for unit_i = 1, self.units.count do
		self.promoItemTotals[self.units[unit_i][promo_I]] = 
			self.promoItemTotals[self.units[unit_i][promo_I]] + 1
	end
	
	self.prefViolationFactor = self.players.count/totalBids
end

function auctionStateObj:readBids(bidFile, numPlayers)
	numPlayers = numPlayers or self.players.count -- allow simulated auctions with incomplete bids

	io.input(bidFile)
	self.bids = {}
	for player_i = 1, self.players.count do
		self.bids[player_i] = {}
	end
		
	local playerWeight = {} 
	if numPlayers < self.players.count then
		for player_i = numPlayers+1, self.players.count do
			print(string.format("Randomizing player %d", player_i))
			playerWeight[player_i] = (1 + 0.2*(math.random()-0.5)) -- simulate players bidding higher/lower overall
		end
	end
	
	local bidTotal = {}
	for unit_i = 1, self.units.count do
		bidTotal[unit_i] = 0
		for player_i = 1, self.players.count do
			if player_i <= numPlayers then
				self.bids[player_i][unit_i] = io.read("*number")
				bidTotal[unit_i] = bidTotal[unit_i] + self.bids[player_i][unit_i]
			else
				self.bids[player_i][unit_i] = (bidTotal[unit_i]/numPlayers)
					* playerWeight[player_i] * (1 + 0.6*(math.random()-0.5))
			end
		end
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

function auctionStateObj:printBids()
	print("")
	print("-BIDS-")
	local str = "           "
	for player_i = 1, self.players.count do
		str = str .. string.format("%-10.10s ", self.players[player_i])
	end
	print(str)
	
	for unit_i = 1, self.units.count do
		str = string.format("%-10.10s ", self.units[unit_i][name_I])
		for player_i = 1, self.players.count do
			str = str ..  string.format("%-10.10s ", 
				string.format("%05.2f", self.bids[player_i][unit_i]))
		end
		
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

function auctionStateObj:printTeams()
	local smallestHCtotal = 999
	for player_i = 1, self.players.count do
		if self:totalHandicap(player_i) < smallestHCtotal then
			smallestHCtotal = self:totalHandicap(player_i)
		end
	end
	
	for player_i = 1, self.players.count do
		print("")
		print(string.format("%-10.10s price | bid", self.players[player_i]))
		
		for unit_i = 1, self.units.count do
			if self.assignedTo[player_i][unit_i] then
				local str = string.format("%-10.10s %05.2f | %05.2f", 
					self.units[unit_i][name_I], self:handicapPrice(unit_i), self.bids[player_i][unit_i])			
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

-- scale to average bid
-- preference violation is a measure of how much the owner's bid differs from the highest bid.
-- with no other considerations, the unit should go to highest bidder.
-- however, team balance and chapter gap smoothing provide an incentive to violate that principle.
function auctionStateObj:averagePreferenceViolation()
	local violations = 0
	for unit_i = 1, self.units.count do
		local highestBid = 0
		for player_i = 1, self.players.count do
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
	local i = 1 -- non-promoters are marked with 0 so they are correctly skipped
	while array[i] do
		local sumOfSquares = 0
		local j = 1
		while array[i][j] do
			sumOfSquares = sumOfSquares + array[i][j]*array[i][j]
			j = j + 1
		end
		sum = sum + sumOfSquares
		i = i + 1
	end
	return sum
end

-- gaps between drafted units appearing, player.count X (teamSize + 1) array
-- values normalized
-- assumes units are sorted by chapter join time
function auctionStateObj:chapterGaps(printV)
	local ret = {}
	local totalGap = self.units[self.units.count][chapter_I] - self.units[1][chapter_I]
	
	if printV then
		print()
		print("Chapter gaps")
	end
	for player_i = 1, self.players.count do
		if printV then 
			print() 
			print(self.players[player_i]) 
		end
		
		ret[player_i] = {}
		local prevChapter = self.units[1][chapter_I] -- first chapter a unit can be available
		local gap_i = 1
		local gap = 0
		local normalized = 0
		for unit_i = 1, self.units.count do
			if self.assignedTo[player_i][unit_i] then
			
				gap = self.units[unit_i][chapter_I] - prevChapter
				normalized = gap/totalGap
				
				if printV then
					print(string.format("%-10.10s %2d %2d/%2d=%5.3f %5.3f", 
						self.units[unit_i][name_I], self.units[unit_i][chapter_I], gap, totalGap,
						normalized, normalized*normalized))
				end				
				ret[player_i][gap_i] = normalized
				prevChapter = self.units[unit_i][chapter_I]
				gap_i = gap_i + 1
			end	
		end
		
		-- gap to end
		gap = self.units[self.units.count][chapter_I] - prevChapter
		normalized = gap/totalGap
		
		ret[player_i][gap_i] = normalized
		
		if printV then
			print(string.format("-end-      %2d %2d/%2d=%5.3f %5.3f",
				self.units[self.units.count][chapter_I], gap, totalGap,
				normalized, normalized*normalized))
		
			local sumOfSq = 0
			for gap_i2 = 1, gap_i do
				sumOfSq = sumOfSq + ret[player_i][gap_i2]*ret[player_i][gap_i2]
			end
			print(string.format("sum of squares:           %5.3f", sumOfSq))
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
	for player_i = 1, self.players.count do
		if printV then 
			print() 
			print(self.players[player_i]) 
		end
		
		ret[player_i] = {}
		count[player_i] = {}
		for promoItem_i = 0, 8 do
			count[player_i][promoItem_i] = 0
		end
		
		for unit_i = 1, self.units.count do
			if self.assignedTo[player_i][unit_i] then
				count[player_i][self.units[unit_i][promo_I]] = 
					count[player_i][self.units[unit_i][promo_I]] + 1
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
				print(string.format("%s %d/%d=%5.3f  %5.3f", 
					promoStrings[promoItem_i], count[player_i][promoItem_i], 
					self.promoItemTotals[promoItem_i], normalized, square))
			end
		end
		if printV then print(string.format("sum of squares:  %5.3f", sumOfSq)) end
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

function auctionStateObj:standardProcess()
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

local FE7auction2 = auctionStateObj:new()
FE7auction2.players = {"Wargrave", "Athena", "P3", "P4", "P5"}
FE7auction2.players.count = 5

FE7auction2.bids = {
	{3.10, 4.20, 1.90, 4.10, 11.80,
	1.00, 3.40, 3.20, 6.70, 1.10,
	5.90, 4.60, 12.90, 1.60, 8.20,
	8.10, 0.80, 2.10, 5.10, 4.70,
	2.00, 8.60, 6.20, 1.00, 4.20,
	7.30, 2.70, 1.50, 0.50, 3.30,
	0.30, 0.30, 0.00, 1.00, 0.20},
	{3.00, 3.50, 3.00, 5.00, 14.00,
	1.00, 4.00, 2.00, 10.00, 1.00,
	8.00, 5.00, 16.00, 0.50, 8.40,
	8.30, 0.00, 3.00, 6.00, 7.00,
	1.00, 8.00, 4.00, 0.50, 4.20,
	8.00, 3.00, 2.00, 2.00, 5.00,
	0.50, 0.00, 0.50, 3.00, 0.50},
{},
{},
{}
}

print("FE7auction2")
FE7auction2:initialize(unitData.sevenHNM, "FE7auction2.txt", 2)
FE7auction2:standardProcess()