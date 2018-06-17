-- format a string into 10 chars with an extra space
function tenChar(str)
	return string.format("%-10.10s ", str)
end

function auctionStateObj:printBids(bids, str)
	bids = bids or self.bids
	str = str or "-BIDS-"
	
	print()
	print(str)
	local str = tenChar("")
	for player_i = 1, self.players.count do
		str = str .. tenChar(self.players[player_i])
	end
	print(str)
	
	for unit_i = 1, self.units.count do
		str = tenChar(self.units[unit_i][name_I])
		for player_i = 1, self.players.count do
			str = str ..  tenChar(string.format(" %5.2f", bids[player_i][unit_i]))
		end
		
		print(str)
	end
	
	str = "-----------"
	for player_i = 1, self.players.count do
		str = str ..  "-----------"
	end
	print(str)
	
	str = tenChar("raw sums ")
	for player_i = 1, self.players.count do
		str = str ..  tenChar(string.format("%06.2f", self.bidSums[player_i]))
	end
	print(str)
end

function auctionStateObj:printTeams()
	local teams = self:teams()

	local adjBids = self:adjustedBids()
	
	for player_i = 1, self.players.count do
		print()
		print(tenChar(self.players[player_i]) .. "bids   item   adjusted bid")
		
		for teamMember_i = 1, self.maxTeamSize do
			local unit_i = teams[player_i][teamMember_i]
			local str = tenChar(self.units[unit_i][name_I])
		
			str = str .. string.format("%5.2f  ", self.bids[player_i][unit_i]) ..
				self.promoStrings[self.units[unit_i][promo_I]] .. "  "
			
			if self.bids[player_i][unit_i] ~= adjBids[player_i][unit_i] then
				str = str .. string.format("%5.2f  ", adjBids[player_i][unit_i])
			end
			print(str)
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
	local rawVMatrix = self:teamValueMatrix(self.bids)
	local vMatrix = rawVMatrix
	
	local function printMatrix(header)
		print()
		print(header)
		local str = tenChar("")
		for player_i = 1, self.players.count do
			str = str .. tenChar(self.players[player_i])
		end
		str = str .. "satisfaction"
		print(str)
		
		for player_i = 1, self.players.count do
			str = tenChar(self.players[player_i])
			for player_j = 1, self.players.count do
				str = str .. string.format("%6.2f     ", vMatrix[player_i][player_j])
			end
			str = str .. string.format("%6.2f     ", spiteValue(vMatrix[player_i],player_i))
			print(str)
		end
	end

	printMatrix("Raw Team Value Matrix")
	
	vMatrix = self:teamValueMatrix()
	printMatrix("Promo Item Adjusted Team Value Matrix")
	
	vMatrix = self:adjustedValueMatrix()
	printMatrix("Promo Item & Redundancy Adjusted Team Value Matrix")
		
	for player_i = 1, self.players.count do
		for player_j = 1, self.players.count do
			vMatrix[player_i][player_j] = rawVMatrix[player_i][player_j] - vMatrix[player_i][player_j]
		end
	end
	printMatrix("Net Adjustment Matrix (Raw - PI&RAdj matrices, satisfaction NA)")
	
	vMatrix = self:adjustedValueMatrix()
	local paretoPrices = self:paretoPrices(vMatrix)
	print()
	local str = "HANDICAPS  "
	for player_i = 1, self.players.count do
		str = str .. string.format("%6.2f     ", paretoPrices[player_i])
	end
	print(str)
	
	-- now subtract relevant prices and print again
	for player_i = 1, self.players.count do
		for player_j = 1, self.players.count do
			vMatrix[player_i][player_j] = vMatrix[player_i][player_j] - paretoPrices[player_j]
		end
	end
	printMatrix("Team Value - Handicap Matrix")
	
	-- subtract max from each row and print again
	for player_i = 1, self.players.count do
		local maxValue = -999
		for player_j = 1, self.players.count do
			if maxValue < vMatrix[player_i][player_j] then
				maxValue = vMatrix[player_i][player_j]
			end
		end
		
		for player_j = 1, self.players.count do
			vMatrix[player_i][player_j] = vMatrix[player_i][player_j] - maxValue
		end
	end
	printMatrix("Expected Victory Margin Matrix")
end

function auctionStateObj:printLatePromotionFactor()
	print()
	print("Late Promotion Factors")

	for unit_i = 1, self.units.count do
		local str = tenChar(self.units[unit_i][1])
	
		local itemReq_i = 1
		while self.latePromoFactor[unit_i][itemReq_i] do
			str = str .. string.format("%6.3f ", self.latePromoFactor[unit_i][itemReq_i])
			itemReq_i = itemReq_i + 1
		end
		print(str)
	end
end

function auctionStateObj:printTeamPopPerChapter(tPPC)
	tPPC = tPPC or self:teamPopPerChapter(29)

	print()
	print("Team Population Per Chapter")

	local str = tenChar("")
	for player_i = 1, self.players.count do
		str = str .. tenChar(self.players[player_i])
	end
	print(str)
	
	local chapter_i = 0
	while tPPC[chapter_i] do
		local str = tenChar(chapter_i)
		for player_i = 1, self.players.count do
			str = str .. tenChar(tPPC[chapter_i][player_i])
		end
		print(str)
	
		chapter_i = chapter_i + 1
	end
end