require("auctionStateObj")
require("gameDataObj")
require("pricing")
require("output")
require("allocation")

function auctionStateObj:standardProcess()
	self:printBids()
		
	self:maxSatAssign()
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
	
	print()
	print("--Final teams--")
	self:printTeams()
	
	self:printRawHandicapImpacts()
	self:printTeamValueMatrix()
	
	
	print()
	print("END")
end

--[[
local FE8auction1 = auctionStateObj:new()
FE8auction1.players = {"Wargrave", "Eggclipse", "Horace", "Carmine"}
FE8auction1.players.count = 4

print("FE8auction1")
FE8auction1:initialize(gameDataObj.eightHM, "FE8auction1.bids.txt")
--FE8auction1:printLatePromotionFactor()
FE8auction1:standardProcess()
]]

local FE8auction2 = auctionStateObj:new()
FE8auction2.players = {"p1", "p2", "p3", "p3"}
FE8auction2.players.count = 4

print("FE8auction1")
FE8auction2:initialize(gameDataObj.eightHM2, "FE8auction2.bids.txt", 1)
--FE8auction1:printLatePromotionFactor()
FE8auction2:standardProcess()

--[[
local FE7auction1 = auctionStateObj:new()
FE7auction1.players = {"Wargrave", "Carmine", "Horace", "Baldrick"}
FE7auction1.players.count = 4

print("FE7auction1")
FE7auction1:initialize(gameDataObj.sevenHNMold, "FE7auction1.bids.txt")
--FE7auction1:findLargeBidComparisonDeviations(5)
FE7auction1:standardProcess()
]]
--[[
local FE7auction2 = auctionStateObj:new()
FE7auction2.players = {"Wargrave", "Athena", "Sturm", "amg", "GentleWind"}
FE7auction2.players.count = 5

print("FE7auction2")
FE7auction2:initialize(gameDataObj.sevenHNM, "FE7auction2.bids.txt")
FE7auction2:standardProcess()
]]