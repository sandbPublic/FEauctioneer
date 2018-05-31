require("auctionStateObj")
require("pricing")
require("output")
require("allocation")
require("unitData")

function auctionStateObj:standardProcess(regAssign)
	--self:printBids()
	
	if not regAssign then
		self:initialAssign()
	else
		self:regularAssign()
	end
	
	print()
	print("Unbalanced teams")
	
	--self:printTeams()

	print()
	print("Balancing")
	
	while (self:existUnderfilledTeam() 
		or self:existOverfilledTeam() 
		or self:tieExists()) do
		
		while (self:existOverfilledTeam() or self:tieExists()) do
			while self:tieExists() do
				self:resolveTie(true)
			end
			
			if self:existOverfilledTeam() then
				self:reassignFrom(true, true)
			end
		end
		
		if self:existUnderfilledTeam() then
			self:reassignFrom(false, true)
		end
	end

	self:printTeams()
	
	print()
	print(string.format("average preference violation: %8.6f",
		self:averagePreferenceViolation()*100) .. "%")
	
	print("cleaning up preference violations")	
	while(self:cleanupPrefViolation(true)) do end
	
	print(string.format("average preference violation: %8.6f",
		self:averagePreferenceViolation()*100) .. "%")
	
	self:printTeams()
	
	self:chapterGaps()
	self:promoClasses()
	
	print()
	print("Attempting to balance chapter gaps and promotion classes")	
	while self:finesseTeams(40, false) do 
		emu.frameadvance() -- prevent unresponsiveness
	end
	
	print()
	print("--Final teams--")
	--self:printTeams()
	
	print()
	print("END")
end

local FE7auction2 = auctionStateObj:new()
FE7auction2.players = {"Wargrave", "Athena", "Sturm", "amg", "GentleWind"}
FE7auction2.players.count = 5

print("FE7auction2")
FE7auction2:initialize(unitData.sevenHNM, "FE7auction2.bids.txt", 5)
FE7auction2:standardProcess()

local FE7auction2r = auctionStateObj:new()
FE7auction2r.players = {"Wargrave", "Athena", "Sturm", "amg", "GentleWind"}
FE7auction2r.players.count = 5

print()
print("FE7auction2 regAssign")
FE7auction2r:initialize(unitData.sevenHNM, "FE7auction2.bids.txt", 5)
FE7auction2r:standardProcess(true)