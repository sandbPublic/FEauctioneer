require("auctionStateObj")
require("pricing")
require("output")
require("allocation")
require("unitData")

function auctionStateObj:standardProcess()
	--self:printBids()
	
	--self:quickAssign()
	
	print()
	print("Initial unoptimized teams")
	
	self:printTeams()

	self:exhaustiveSwaps(true)
	
	print()
	print(string.format("current score: %-6.2f", self:allocationScore()))
	print("optimizing permutations")	
	while(self:improveAllocationPermute(true)) do 
		emu.frameadvance()
		print("permute pass")
	end
	
	--self:chapterGaps()
	--self:promoClasses()
		
	print()
	print("--Final teams--")
	self:printTeams()
	self:printTeamValueMatrix()
	
	print()
	print("END")
end

local FE7auction2 = auctionStateObj:new()
FE7auction2.players = {"Wargrave", "Athena", "Sturm", "amg", "GentleWind"}
FE7auction2.players.count = 5

print("FE7auction2")
FE7auction2:initialize(unitData.sevenHNM, "FE7auction2.bids.txt", 5)

print("quick")
FE7auction2:quickAssign()
FE7auction2:standardProcess()

print("maxSat")
FE7auction2:maxSatAssign()
FE7auction2:standardProcess()
