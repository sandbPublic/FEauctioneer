-- assign unit to highest bidder that doesn't have a full team yet
function auctionStateObj:quickAssign()
	local maxTeamSize = self.units.count/self.players.count
	local teamSize = {}
	for player_i = 1, self.players.count do
		teamSize[player_i] = 0
	end
	
	for unit_i = 1, self.units.count do
		local maxBid = -1
		for player_i = 1, self.players.count do
			if teamSize[player_i] < maxTeamSize then 
				if maxBid < self.bids[player_i][unit_i] then
					maxBid = self.bids[player_i][unit_i]
					self.owner[unit_i] = player_i
				end
			end
		end
		teamSize[self.owner[unit_i]] = teamSize[self.owner[unit_i]] + 1
	end
end

-- returns true if a swap was made
-- otherwise returns false
function auctionStateObj:improveAllocation(printV)	
	local currentValue = self:allocationScore()
	
	for unit_i = 1, self.units.count do
		for unit_j = unit_i+1, self.units.count do
			self.owner[unit_i], self.owner[unit_j] = self.owner[unit_j], self.owner[unit_i]
			
			if self:allocationScore() > currentValue then
				if printV then
					print()
				
					-- use name of owner before swap
					print(string.format("Swapping: %-10.10s %-10.10s <-> %-10.10s %-10.10s",
						self.players[self.owner[unit_j]], self.units[unit_i][name_I],
						self.players[self.owner[unit_i]], self.units[unit_j][name_I]))
						
					print(string.format("new score: %-6.2f", self:allocationScore()))
				end
				
				return true
			end
			
			self.owner[unit_i], self.owner[unit_j] = self.owner[unit_j], self.owner[unit_i]
		end
	end
	
	if printV then
		print()
		print("couldn't improve allocation")
	end
	return false
end