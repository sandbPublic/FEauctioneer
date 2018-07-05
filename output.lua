local promoStrings = {"kCrst", "hCrst",  "oBolt", "eWhip", "gRing", "hSeal", "oSeal", "FellC", "eSeal"}
promoStrings[0] = "     "

-- format a string into 10 chars with an extra space
local function tenChar(str)
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
	
	for unit_i = 1, self.gameData.units.count do
		str = tenChar(self.gameData.units[unit_i].name)
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
	
	print("max unrestricted satisfaction: " .. tostring(self.maxUSat))
end

function auctionStateObj:printTeams()
	local teams = self:teams()
	
	for player_i = 1, self.players.count do
		print()
		
		local str = tenChar(self.players[player_i])
		for player_j = 1, self.players.count do
			if player_i == player_j then
				str = str .. "   V   "
			else
				str = str .. "       "
			end
		end
		str = str .. " item"
		print(str)
		
		for teamMember_i = 1, self.maxTeamSize do
			local unit_i = teams[player_i][teamMember_i]
			
			local str = tenChar(self.gameData.units[unit_i].name)
			for player_j = 1, self.players.count do
				if player_i == player_j then
					str = str .. string.format("~%5.2f~", self.bids[player_j][unit_i])
				else
					str = str .. string.format(" %5.2f ", self.bids[player_j][unit_i])
				end
			end
			str = str .. " " .. promoStrings[self.gameData.units[unit_i].promoItem]
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
	
	for unit_i = 1, self.gameData.units.count do
		averageBid[unit_i] = 0
		for player_i = 1, self.players.count do
			averageBid[unit_i] = averageBid[unit_i] + self.bids[player_i][unit_i]
		end
		averageBid[unit_i] = averageBid[unit_i]/self.players.count
	end
	
	local deviationCount = 0
	local misorderingCount = 0
	for player_i = 1, self.players.count do
		for unit_i = 1, self.gameData.units.count do
			for unit_j = unit_i+1, self.gameData.units.count do
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
						deviationCount, 
						self.gameData.units[unit_i].name, 
						self.gameData.units[unit_j].name))
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
	
	local function printMatrix(header, noSat)
		print()
		print(header)
		local str = tenChar("")
		for player_i = 1, self.players.count do
			str = str .. tenChar(self.players[player_i])
		end
		if not noSat then
			str = str .. "satisfaction"
		end
		print(str)
		
		for player_i = 1, self.players.count do
			str = tenChar(self.players[player_i])
			for player_j = 1, self.players.count do
				str = str .. string.format("%6.2f     ", vMatrix[player_i][player_j])
			end
			if not noSat then
				str = str .. string.format("%6.2f     ", spiteValue(vMatrix[player_i],player_i))
			end
			print(str)
		end
	end

	printMatrix("Raw Team Value Matrix")
	
	vMatrix = self:adjustedVC_Sum_Matrix()
	printMatrix("R-by-chapter Team Value Matrix")
	
	local paretoPrices = self:paretoPrices(vMatrix)
	print()
	local str = "HANDICAPS  "
	for player_i = 1, self.players.count do
		str = str .. string.format("%6.2f     ", paretoPrices[player_i])
	end
	print(str)
		
	-- now subtract relevant prices and print again
	vMatrix = self:adjustedVC_Sum_Matrix()
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

	for unit_i = 1, self.gameData.units.count do
		print(self.gameData.units[unit_i].name)
	
		if self.gameData.units[unit_i].LPFactor.adjusted then
			local itemReq_i = 1
			while self.gameData.units[unit_i].LPFactor[itemReq_i] do
				local str = tostring(itemReq_i) .. "  "
				
				for chapter_i = self.gameData.units[unit_i].joinChapter, 
					self.gameData.units[unit_i].lastChapter do
				
					str = str .. string.format("%d ", 
						self.gameData.units[unit_i].LPFactor[itemReq_i][chapter_i] * 8)
				end
				
				print(str)
				itemReq_i = itemReq_i + 1
			end
		end
	end
end

-- print M, V, or R(V,M)C_Matrix
function auctionStateObj:printXC_Matrix(XC_Matrix, vStr)
	vStr = vStr or "M"
	XC_Matrix = XC_Matrix or self.MC_Matrix
	
	print()
	print(vStr .. " values by chapter")
	
	local sumCheck = {}
	local str = "    "
	for player_i = 1, self.players.count do
		str = str .. tenChar(self.players[player_i])
		sumCheck[player_i] = 0
	end
	print(str)
	
	for chapter_i = 1, self.gameData.chapters.count do
		str = string.format("%-.3s ", self.gameData.chapters[chapter_i])
		for player_i = 1, self.players.count do
			str = str .. string.format("  %7.5f  ", XC_Matrix[player_i][chapter_i])
			sumCheck[player_i] = sumCheck[player_i] + XC_Matrix[player_i][chapter_i]
		end
		print(str)
	end
	str = "sum "
	for player_i = 1, self.players.count do
		str = str .. string.format("%9.5f  ", sumCheck[player_i])
	end
	print(str)
end

