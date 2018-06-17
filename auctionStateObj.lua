local P = {}
auctionStateObj = P

-- using indexes instead of named table fields allows for more organized gameData
name_I = 1
chapter_I = 2
promo_I = 3

--todo store vMatrix etc, only recompute when swaps occur?
function P:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
		
	o.players = {} -- strings
	o.players.count = 0
	o.units = {} -- names, chapter, promo_item
	o.units.count = 0
	
	o.bids = {} -- PxU array of numbers
	o.bidSums = {} -- P array, used for redundancy adjusted team values
	
	o.owner = {} -- U array of player ids.
	o.maxTeamSize = 0
	o.teamSizes = {} -- for allocations
	
	o.latePromoFactor = {}
	-- U x maxTeamSize-1
	-- for each unit, array of how the bid values 
	-- should be scaled down depending on how many
	-- earlier units in the same team will use the
	-- same item (assume team will not use more than
	-- one earth seal). if first unit, then PVF == 1
	
	return o
end

-- takes in a table from gameData
function P:initialize(version, bidFile, numPlayers)
	-- load data
	self.units = {}
	self.units.count = 0
	while version[self.units.count+1] do
		self.units.count = self.units.count + 1		
		self.units[self.units.count] = version[self.units.count]
	end
	
	-- load bids
	self:readBids(bidFile, numPlayers)
	
	self.maxTeamSize = self.units.count/self.players.count
	
	self.latePromoFactor = version.LPFactor
end

function P:readBids(bidFile, numPlayers)
	numPlayers = numPlayers or self.players.count -- allow simulated auctions with incomplete bids

	io.input(bidFile)
	self.bids = {}
	self.bidSums = {}
	for player_i = 1, self.players.count do
		self.bids[player_i] = {}
		self.bidSums[player_i] = 0
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
			
			self.bidSums[player_i] = self.bidSums[player_i] + self.bids[player_i][unit_i]
		end
	end
	
	io.input():close()
end

-- PxTeamsize array of unit_ids
function P:teams()
	local teams = {}
	
	for player_i = 1, self.players.count do
		teams[player_i] = {}
		local teamNextSlot = 1
		
		for unit_i = 1, self.units.count do
			if self.owner[unit_i] == player_i then	
				teams[player_i][teamNextSlot] = unit_i
				teamNextSlot = teamNextSlot + 1
			end
		end
	end
	
	return teams
end

-- gaps between drafted units appearing, player.count X (teamSize + 1) array
-- values normalized
-- assumes units are sorted by chapter join time
function P:chapterGaps(printV)
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
			if self.owner[unit_i] == player_i then
			
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
P.promoStrings = {"kCrst", "hCrst",  "oBolt", "eWhip", "gRing", "hSeal", "oSeal", "FellC", "eSeal"}
P.promoStrings[0] = "None "

return auctionStateObj