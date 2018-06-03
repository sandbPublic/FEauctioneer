require("auctionStateObj")
require("pricing")
require("output")
require("allocation")
require("unitData")

function auctionStateObj:standardProcess(regAssign)
	--self:printBids()
	
	if not regAssign then
		self:quickAssign()
	else
		self:regularAssign()
	end
	
	print()
	print("Initial unoptimized teams")
	
	self:printTeams()

	print()
	print(string.format("current score: %-6.2f", self:allocationScore()))	
	print("optimizing")	
	while(self:cleanupPrefViolation(true)) do end
	
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
FE7auction2:standardProcess()

local FE7auction2r = auctionStateObj:new()
FE7auction2r.players = {"Wargrave", "Athena", "Sturm", "amg", "GentleWind"}
FE7auction2r.players.count = 5

print()
--print("FE7auction2 regAssign")
--FE7auction2r:initialize(unitData.sevenHNM, "FE7auction2.bids.txt", 5)
--FE7auction2r:standardProcess(true)

