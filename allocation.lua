-- for testing convergence
function auctionStateObj:randomAssign()
	local teamSize = {}
	for player_i = 1, self.players.count do
		teamSize[player_i] = 0
	end
	
	for unit_i = 1, self.units.count do
		local player_i = math.random(self.players.count)
		while (teamSize[player_i] >= self.teamSize) do
			player_i = player_i + 1
			if player_i > self.players.count then
				player_i = 1
			end
		end
	
		self.owner[unit_i] = player_i	
		teamSize[self.owner[unit_i]] = teamSize[self.owner[unit_i]] + 1
	end
end

-- assign unit to highest bidder that doesn't have a full team yet
function auctionStateObj:quickAssign()
	local teamSize = {}
	for player_i = 1, self.players.count do
		teamSize[player_i] = 0
	end
	
	for unit_i = 1, self.units.count do
		local maxBid = -1
		for player_i = 1, self.players.count do
			if teamSize[player_i] < self.teamSize then 
				if maxBid < self.bids[player_i][unit_i] then
					maxBid = self.bids[player_i][unit_i]
					self.owner[unit_i] = player_i
				end
			end
		end
		teamSize[self.owner[unit_i]] = teamSize[self.owner[unit_i]] + 1
	end
end

-- returns true if at least one swap was made
-- otherwise returns false
function auctionStateObj:improveAllocationSwaps(printV)	
	local currentValue = self:allocationScore()
	local swapped = false
	
	for unit_i = 1, self.units.count do
		for unit_j = unit_i+1, self.units.count do
			-- attempt swap
			self.owner[unit_i], self.owner[unit_j] = self.owner[unit_j], self.owner[unit_i]
			
			if currentValue < self:allocationScore() then
				currentValue = self:allocationScore()
				swapped = true
				
				if printV then
					print()
				
					-- use name of owner before swap
					print(string.format("Swapping: %-10.10s %-10.10s <-> %-10.10s %-10.10s",
						self.players[self.owner[unit_j]], self.units[unit_i][name_I],
						self.players[self.owner[unit_i]], self.units[unit_j][name_I]))
						
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

perms = {}
perms.count = 0
function permgen (a, n)
	if n == 0 then
		perms.count = perms.count + 1
		perms[perms.count] = {}
		
		local a_i = 1
		while a[a_i] do
			perms[perms.count][a_i] = a[a_i]
			a_i = a_i + 1
		end		
	else
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
print("permutations")
permgen({1,2,3,4,5}, 5)
for perm_i = 1, perms.count do
	--print(perms[perm_i])
end

-- todo allow for variable number of players
function auctionStateObj:improveAllocationPermute(printV)	
	local currentValue = self:allocationScore()
	local permuted = false
	
	-- PxTeamsize array of unit_ids
	local teams = self:teams()
	local pUnits = {} -- units currently permuting
	
	for team_A = 1, self.teamSize do
	pUnits[1] = teams[1][team_A]
	print("A" .. team_A)
	
	for team_B = 1, self.teamSize do
	pUnits[2] = teams[2][team_B]
	print(team_B)
	
	for team_C = 1, self.teamSize do
	pUnits[3] = teams[3][team_C]
	emu.frameadvance()
	
	for team_D = 1, self.teamSize do
	pUnits[4] = teams[4][team_D]
	
	for team_E = 1, self.teamSize do
	pUnits[5] = teams[5][team_E]
	
		for perm_i = 1, perms.count do
			for player_i = 1, self.players.count do
				self.owner[pUnits[player_i]] = perms[perm_i][player_i]
			end
			
			if currentValue < self:allocationScore() then
				currentValue = self:allocationScore()
				permuted = true
				
				if printV then
					print()
					for player_i = 1, self.players.count do
						if player_i ~= perms[perm_i][player_i] then
							print(string.format("Swapping: %d %-10.10s %-10.10s -> %d %-10.10s",
								player_i,
								self.players[player_i],
								self.units[pUnits[player_i]][name_I], 
								perms[perm_i][player_i],
								self.players[perms[perm_i][player_i]]))
						end
					end
					
					print(string.format("new score: %-6.2f", self:allocationScore()))
				end
				
				teams = self:teams()
				pUnits[1] = teams[1][team_A]
				pUnits[2] = teams[2][team_B]
				pUnits[3] = teams[3][team_C]
				pUnits[4] = teams[4][team_D]
				pUnits[5] = teams[5][team_E]
			else
				for player_i = 1, self.players.count do
					self.owner[pUnits[player_i]] = player_i
				end
			end
		end
	end
	end
	end
	end
	end
	
	if printV and not permuted then
		print()
		print("couldn't improve allocation")
	end
	return permuted
end