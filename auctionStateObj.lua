local P = {}
auctionStateObj = P

-- using indexes instead of named table fields allows for more organized unitData
name_I = 1
chapter_I = 2
promo_I = 3

function P:new()
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

-- takes in a table from unitData
function P:initialize(version, bidFile, numPlayers)
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

function P:readBids(bidFile, numPlayers)
	numPlayers = numPlayers or self.players.count -- allow simulated auctions with incomplete bids

	io.input(bidFile)
	self.bids = {}
	for player_i = 1, self.players.count do
		self.bids[player_i] = {}
	end
		
	local playerWeight = {} 
	if numPlayers < self.players.count then
		for player_i = numPlayers+1, self.players.count do
			--playerWeight[player_i] = (1 + 0.2*(math.random()-0.5)) -- simulate players bidding higher/lower overall
			--print(string.format("Randomizing player %d, x%4.2f", player_i, playerWeight[player_i]))
			print(string.format("Creating player %d", player_i))
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
				--	* playerWeight[player_i] * (1 + 0.6*(math.random()-0.5))
			end
		end
	end
	
	io.input():close()
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
function sumOfSquares(array)
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

-- promo items
local promoStrings = {"kCrst", "hCrst",  "oBolt", "eWhip", "gRing", "hSeal", "oSeal", "FellC"}
promoStrings[0] = "None "

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

return auctionStateObj