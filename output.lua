require("auctionStateObj")

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

-- if unit A is on average rated above unit B by X turns, 
-- but player 1 deviates from this by at least threshold, print it
function auctionStateObj:findLargeBidComparisonDeviations(threshold)
	local averageBid = {}
	local function avgBidDif(unit_i, unit_j)
		return averageBid[unit_i] - averageBid[unit_j]
	end
	
	for unit_i = 1, self.units.count do
		averageBid[unit_i] = 0
		for player_i = 1, self.players.count do
			averageBid[unit_i] = averageBid[unit_i] + self.bids[player_i][unit_i]
		end
		averageBid[unit_i] = averageBid[unit_i]/self.players.count
	end
	
	local deviationCount = 0
	local misorderingCount = 0
	for player_i = 1, self.players.count do
		for unit_i = 1, self.units.count do
			for unit_j = unit_i+1, self.units.count do
				local deviation = (self.bids[player_i][unit_i] - self.bids[player_i][unit_j]) 
					- avgBidDif(unit_i, unit_j)
				
				if math.abs(deviation) >= threshold then
					deviationCount = deviationCount + 1
					print()
					if (self.bids[player_i][unit_i] - self.bids[player_i][unit_j])*avgBidDif(unit_i, unit_j) < 0 then
						misorderingCount = misorderingCount + 1
						print(string.format("%03d Misordering", misorderingCount))
					end
					
					print(string.format("%03d preference deviation noted, comparing: %-10.10s %-10.10s", 
						deviationCount, self.units[unit_i][name_I], self.units[unit_j][name_I]))
					print(string.format("Average: %05.2f  %-10.10s: %05.2f  Deviation: %05.2f", 
						avgBidDif(unit_i, unit_j), self.players[player_i], 
						(self.bids[player_i][unit_i] - self.bids[player_i][unit_j]),
						deviation))
				end
			end
		end
		emu.frameadvance() -- prevent unresponsiveness
	end
end