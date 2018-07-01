local P = {}
auctionStateObj = P

--todo store vMatrix etc, only recompute when swaps occur?
function P:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
		
	o.players = {} -- strings
	o.players.count = 0
	
	o.gameData = {}
	
	o.bids = {} -- PxU array of numbers
	o.bidSums = {} -- P array, used for redundancy adjusted team values
	
	o.Mmatrix = {} -- PxCh array, bid sums up to chapter Ch
	
	o.owner = {} -- U array of player ids.
	o.maxTeamSize = 0
	o.teamSizes = {} -- for allocations
	
	return o
end

-- takes in a table from gameData
function P:initialize(version, bidFile, numPlayers)
	-- load data
	self.gameData = version
	self.gameData:construct()
	
	-- load bids
	self:readBids(bidFile, numPlayers)
	
	self.maxTeamSize = self.gameData.units.count/self.players.count
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
	for unit_i = 1, self.gameData.units.count do
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
		
		for unit_i = 1, self.gameData.units.count do
			if self.owner[unit_i] == player_i then	
				teams[player_i][teamNextSlot] = unit_i
				teamNextSlot = teamNextSlot + 1
			end
		end
	end
	
	return teams
end

-- promo items
P.promoStrings = {"kCrst", "hCrst",  "oBolt", "eWhip", "gRing", "hSeal", "oSeal", "FellC", "eSeal"}
P.promoStrings[0] = "None "

return auctionStateObj