-- format a string into 10 chars with an extra space
function tenChar(str)
	return string.format("%-10.10s ", str)
end

function auctionStateObj:printBids()
	print()
	print("-BIDS-")
	local str = tenChar("")
	for player_i = 1, self.players.count do
		str = str .. tenChar(self.players[player_i])
	end
	print(str)
	
	for unit_i = 1, self.units.count do
		str = tenChar(self.units[unit_i][name_I])
		for player_i = 1, self.players.count do
			str = str ..  tenChar(string.format("%05.2f", self.bids[player_i][unit_i]))
		end
		
		print(str)
	end
end

function auctionStateObj:printTeams()
	for player_i = 1, self.players.count do
		print()
		print(self.players[player_i])
		
		for unit_i = 1, self.units.count do
			if self.owner[unit_i] == player_i then		
				print(tenChar(self.units[unit_i][name_I]) .. 
					string.format("%05.2f", self.bids[player_i][unit_i]))
			end
		end
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

-- also print handicaps and satisfaction
function auctionStateObj:printTeamValueMatrix()
	vMatrix = self:teamValueMatrix()
	
	print()
	print("Raw Team Value Matrix")
	local str = tenChar("")
	for player_i = 1, self.players.count do
		str = str .. tenChar(self.players[player_i])
	end
	str = str .. "spite value"
	print(str)
	
	for player_i = 1, self.players.count do
		str = tenChar(self.players[player_i])
		for player_j = 1, self.players.count do
			str = str .. string.format("%6.2f     ", vMatrix[player_i][player_j])
		end
		str = str .. string.format("%6.2f     ", spiteValue(vMatrix[player_i],player_i))
		print(str)
	end
	
	local paretoPrices = self:paretoPrices()
	print()
	str = "handicaps  "
	for player_i = 1, self.players.count do
		str = str .. string.format("%6.2f     ", paretoPrices[player_i])
	end
	print(str)
	
	-- now subtract relevant prices and print again
	print()
	print("Adjusted Team Value Matrix")
	str = tenChar("")
	for player_i = 1, self.players.count do
		str = str .. tenChar(self.players[player_i])
	end
	str = str .. "satisfaction"
	print(str)
	
	for player_i = 1, self.players.count do
		str = tenChar(self.players[player_i])
		for player_j = 1, self.players.count do
			vMatrix[player_i][player_j] = vMatrix[player_i][player_j] - paretoPrices[player_j]
		
			str = str .. string.format("%6.2f     ", vMatrix[player_i][player_j])
		end
		str = str .. string.format("%6.2f     ", spiteValue(vMatrix[player_i],player_i))
		print(str)
	end
end
