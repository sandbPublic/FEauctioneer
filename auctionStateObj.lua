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
	
	o.MC_Matrix = {} -- PxCh array, M values (currently bid sums) by chapter
	
	o.owner = {} -- U array of player ids.
	o.maxTeamSize = 0
	o.teamSizes = {} -- for allocations
	
	o.maxUSat = 0 -- for anti-brittle adjustments
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
	
	self.MC_Matrix = self:createMC_Matrix()
	
	self.maxUSat = self:maxUnrestrictedSat()
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
			playerWeight[player_i] = (1 + 0.2*(math.random()-0.5)) -- simulate players bidding higher/lower overall
			print(string.format("Randomizing player %d, x%4.2f", player_i, playerWeight[player_i]))
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
					* playerWeight[player_i] * (1 + 0.6*(math.random()-0.5))
			end
			
			self.bidSums[player_i] = self.bidSums[player_i] + self.bids[player_i][unit_i]
		end
	end
	
	io.input():close()
end

-- PxTeamsize array of unit_ids
function P:teams()
	local teams = {}
	local next_i = {}
	for player_i = 1, self.players.count do
		teams[player_i] = {}
		next_i[player_i] = 1
	end
	
	for unit_i = 1, self.gameData.units.count do
		local owner = self.owner[unit_i]
	
		teams[owner][next_i[owner]] = unit_i
		next_i[owner] = next_i[owner] + 1
	end
	
	return teams
end

return auctionStateObj