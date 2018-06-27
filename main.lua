require("auctionStateObj")
require("pricing")
require("output")
require("allocation")
require("gameData")

function auctionStateObj:standardProcess()
	--self:printBids()
	
	print()
	print("Initial unoptimized teams")
	
	--self:printTeams()
	
	self:exhaustiveSwaps(true)
	
	--print()
	--print(string.format("current score: %-6.2f", self:allocationScore()))
	--print("optimizing permutations")
	--local timeStarted = os.clock()
	--while(self:improveAllocationPermute(true)) do 
	--	emu.frameadvance()
	--	print("permute pass")
	--end
	--print(string.format("Time taken: %.2f seconds", os.clock() - timeStarted))
		
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
FE7auction2:initialize(gameData.sevenHNM, "FE7auction2.bids.txt", 5)
--FE7auction2:printLatePromotionFactor()

FE7auction2:maxSatAssign()
FE7auction2:standardProcess()