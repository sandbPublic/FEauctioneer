function auctionStateObj:clearAssign()
	for unit_i = 1, self.gameData.units.count do
		self.owner[unit_i] = 0
	end
	
	-- index 0 refers to unassigned units
	self.teamSizes[0] = self.gameData.units.count
	
	for player_i = 1, self.players.count do
		self.teamSizes[player_i] = 0
	end
end

function auctionStateObj:assign(unit_i, player_i)
	self.teamSizes[self.owner[unit_i]] = self.teamSizes[self.owner[unit_i]] - 1

	self.owner[unit_i] = player_i
	
	self.teamSizes[player_i] = self.teamSizes[player_i] + 1
end

function auctionStateObj:fullTeam(player_i)
	return self.teamSizes[player_i] >= self.maxTeamSize
end

-- for testing convergence
function auctionStateObj:randomAssign()
	self:clearAssign()
	
	for unit_i = 1, self.gameData.units.count do
		local player_i = math.random(self.players.count)
		while self:fullTeam(player_i) do
			player_i = player_i + 1
			if player_i > self.players.count then
				player_i = 1
			end
		end
	
		self:assign(unit_i, player_i)
	end
end

function auctionStateObj:moduloAssign(startOffset)
	self:clearAssign()

	startOffset = startOffset or 0

	for unit_i = 1, self.gameData.units.count do
		local player_i = ((unit_i - 1 + startOffset) % self.players.count) + 1
		-- player_i(1) = 1, player_i(self.players.count) = self.players.count, not 0
	
		self:assign(unit_i, player_i)
	end
end

-- assign unit to highest bidder that doesn't have a full team yet
function auctionStateObj:quickAssign()
	self:clearAssign()
	
	for unit_i = 1, self.gameData.units.count do
		local maxBid = -1
		for player_i = 1, self.players.count do
			if not self:fullTeam(player_i) then 
				if maxBid < self.bids[player_i][unit_i] then
					maxBid = self.bids[player_i][unit_i]
					
					self:assign(unit_i, player_i)
				end
			end
		end
	end
end

-- max sat assign, not in unit order
function auctionStateObj:maxSatAssign()
	self:clearAssign()	
	
	while self.teamSizes[0] > 0 do -- while units are unassigned
		local maxSat = -999
		local maxSat_unit_i = 0
		local maxSat_player_i = 0
	
		--find max sat gain assignment remaining and assign
		for unit_i = 1, self.gameData.units.count do
			if self.owner[unit_i] == 0 then
				local bidArray = {} -- self.bids indexes first by player, so won't work for spiteValue
				for player_i = 1, self.players.count do
					bidArray[player_i] = self.bids[player_i][unit_i]
				end
				
				for player_i = 1, self.players.count do
					if not self:fullTeam(player_i) then
						local sat = spiteValue(bidArray, player_i)
						
						if (maxSat < sat) or 
						-- if tied, break tie using playerID + unitID modulo
						-- avoids assigning units in recruit order if all tied
							(maxSat == sat and 
							(unit_i + player_i) % self.players.count < 
							(maxSat_unit_i + maxSat_player_i) % self.players.count)
						then
							maxSat = sat
							maxSat_unit_i = unit_i
							maxSat_player_i = player_i
						end
					end
				end
				
				self:assign(maxSat_unit_i, maxSat_player_i)
			end
		end
	end
end

-- returns true if at least one swap was made
-- otherwise returns false
function auctionStateObj:improveAllocationSwaps(printV)	
	local currentValue = self:allocationScore()
	local swapped = false
	
	for unit_i = 1, self.gameData.units.count do
		for unit_j = unit_i+1, self.gameData.units.count do
			-- attempt swap
			self.owner[unit_i], self.owner[unit_j] = self.owner[unit_j], self.owner[unit_i]
			
			if currentValue < self:allocationScore() then
				currentValue = self:allocationScore()
				swapped = true
				
				if printV then
					print()
				
					-- use name of owner before swap
					print(string.format("Swapping: %-10.10s %-21.21s %-10.10s",
						self.players[self.owner[unit_j]], 
						self.gameData.units[unit_i].name .. " <-> " .. self.gameData.units[unit_j].name,
						self.players[self.owner[unit_i]]))
						
					print(string.format("new score: %-6.2f", self:allocationScore()))
				end
			else
				self.owner[unit_i], self.owner[unit_j] = self.owner[unit_j], self.owner[unit_i]
			end
		end
	end
	
	if printV and not swapped then
		print()
		print("couldn't improve allocation")
	end
	return swapped
end

function auctionStateObj:exhaustiveSwaps(printV)
	if printV then
		print()
		print(string.format("current score: %-6.2f", self:allocationScore()))	
		print("optimizing swaps")
	end
	
	while(self:improveAllocationSwaps(printV)) do
		if printV then
			print("one swap pass")
		end
		emu.frameadvance()
	end
end

-- takes a permutation and counts how many loops there are
-- "loops" of size one are not counted
-- used to eliminate permutations that contain multiple loops
-- because they are redundant with the permutations corresponding
-- to each individual loop
-- also returns lowestLoopMember
local function loopCount(perm, size)
	local lowestLoopMember = {} -- identify loops this way
	
	local function nextLoopMember(i)
		if not lowestLoopMember[i] then
			lowestLoopMember[i] = i -- start loop
		else
			if lowestLoopMember[i] == i then
				return -- reached start of loop
			end
		end
		
		lowestLoopMember[perm[i]] = lowestLoopMember[i]	
		nextLoopMember(perm[i])
	end
	
	for i = 1, size do
		nextLoopMember(i)
	end
	
	local loopDetected = {} -- detects unique loops
	local loopingMembers = size
	for i = 1, size do
		if lowestLoopMember[i] ~= i then
			loopDetected[lowestLoopMember[i]] = true
		end
		
		if perm[i] == i then
			loopingMembers = loopingMembers - 1
		end
	end
	
	local loopCount = 0
	for i = 1, size do
		if loopDetected[i] then
			loopCount = loopCount + 1
		end
	end
	
	return loopCount, loopingMembers, lowestLoopMember
end

perms = {}
perms.count = 0
nonPerms = {} -- check identity, swap, disconnected rotations
-- these are not needed because identity changes nothing, swaps are already done in O(n^2),
-- and net+ disconnected rotations can be accomplished by multiple net+ connected rotations
nonPerms.count = 0
local function permgen (a, n) -- a is an arrangement
	if not a.size then
		a.size = n
	end 

	if n == 0 then
		local listToUpdate = nonPerms
	
		-- check if permutation is a swap or identity
		local count, loopingMembers, lLM = loopCount(a, a.size)
		if count == 1 and loopingMembers > 2 then -- exactly one loop of size > 2
			listToUpdate = perms
		end
		
		listToUpdate.count = listToUpdate.count + 1
		listToUpdate[listToUpdate.count] = {}
		for a_i = 1, a.size do
			listToUpdate[listToUpdate.count][a_i] = a[a_i]
		end
	else -- recursive case
		for i = 1, n do
			-- put i-th element as the last one
			a[n], a[i] = a[i], a[n]

			-- generate all permutations of the other elements
			permgen(a, n - 1)

			-- restore i-th element
			a[n], a[i] = a[i], a[n]
		end
	end
end

local function printPerms(perms)
	local size = 0
	while perms[1][size+1] do
		size = size+1
	end

	print(perms.count)
	for perm_i = 1, perms.count do
		local count
		local lLM
		
		count, lMem, lLM = loopCount(perms[perm_i], size)
		
		print(tostring(perms[perm_i]) .. " " .. count .. " " .. lMem .. " " .. tostring(lLM))
	end
end

function auctionStateObj:improveAllocationPermute(printV)
	local timeStarted = os.clock()

	local currentValue = self:allocationScore()
	local permuted = false
	
	local permGenTable = {}
	for player_i = 1, self.players.count do
		permGenTable[player_i] = player_i
	end
	permgen(permGenTable, self.players.count)
	
	-- PxTeamsize array of unit_ids
	local teams = self:teams()
	local pUnits = {} -- units currently permuting
	local teamIndexes = {} -- for correcting current units up for rotation to match new teams
	
	local indentation = {}
	indentation[1] = " "
	for player_i = 2, self.players.count do
		indentation[player_i] = indentation[player_i-1] .. " "
	end
	
	-- implicitly construct self.players.count loops over each team
	local function recursive(player_i)
		if player_i <= self.players.count then
			for team_i = 1, self.maxTeamSize do
				pUnits[player_i] = teams[player_i][team_i]
				teamIndexes[player_i] = team_i
				
				if player_i + 1 < self.players.count then
					print(indentation[player_i] ..player_i .. indentation[player_i] .. 
						teamIndexes[player_i]-1 .. "/" .. self.maxTeamSize .. 
						string.format(" Time taken: %.2f minutes", (os.clock() - timeStarted)/60))
				elseif player_i + 1 == self.players.count then
					emu.frameadvance()
				end
				
				recursive(player_i + 1)
			end
		else -- base case, try all rotations of selected P units
			local permutedThisLeaf = false
		
			for perm_i = 1, perms.count do
				-- set to rotation
				for player_i = 1, self.players.count do
					self.owner[pUnits[player_i]] = perms[perm_i][player_i]
				end
				
				if currentValue < self:allocationScore() then
					currentValue = self:allocationScore()
					permuted = true
					permutedThisLeaf = true
					
					if printV then
						print()
						for player_i = 1, self.players.count do
							
							-- only print player that actually exchange in the rotation
							if player_i ~= perms[perm_i][player_i] then
								print(string.format("Swapping: %d %-10.10s %-10.10s -> %d %-10.10s",
									player_i,
									self.players[player_i],
									self.gameData.units[pUnits[player_i]].name, 
									perms[perm_i][player_i],
									self.players[perms[perm_i][player_i]]))
							end
						end
						
						print(string.format("new score: %-6.2f", self:allocationScore()))
					end
					
					self:exhaustiveSwaps(printV)
					
					-- reset to new teams
					teams = self:teams()
					
					-- correct current units up for rotation to match new teams
					for player_i = 1, self.players.count do
						pUnits[player_i] = teams[player_i][teamIndexes[player_i]]
					end
				end
			end
			
			if not permutedThisLeaf then -- unrotate
				for player_i = 1, self.players.count do
					self.owner[pUnits[player_i]] = player_i
				end
			end
		end
	end

	recursive(1)
	
	if printV and not permuted then
		print()
		print("couldn't improve allocation by rotation")
	end
	return permuted
end