local P = {}
gameDataObj = P

local promo_NO = 0 -- can't promote
local promo_KC = 1 -- knight crest
local promo_HC = 2 -- hero crest
local promo_OB = 3 -- orion's bolt
local promo_EW = 4 -- elysian whip
local promo_GR = 5 -- guiding ring
local promo_HS = 6 -- heaven seal
local promo_OS = 7 -- ocean seal
local promo_FC = 8 -- fell contract
local promo_ES = 9 -- earth seal, item only

function gameDataObj:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	o.units = {}
	-- array of tables of .name .joinChapter .lastChapter .availability .promoItem .LPFactor
	-- units[1].name is more intuitive than units.names[1]	
	o.units.count = 0
	
	-- index from 1
	o.chapters = {}
	o.chapters.count = 0
	
	-- #chapter x #itemTypes array of total items available
	o.PICount = {}	
	return o
end

function gameDataObj:construct()
	-- count chapters
	self.chapters.count = 0
	while self.chapters[self.chapters.count + 1] do	
		self.chapters.count = self.chapters.count + 1
	end

	local unit_i = 0
	while self.unitData[unit_i + 1] do
		unit_i = unit_i + 1
	
		self.units[unit_i] = {}
	
		self.units[unit_i].name = self.unitData[unit_i][1]
		self.units[unit_i].joinChapter = self.unitData[unit_i][2]
		self.units[unit_i].promoItem = self.unitData[unit_i][3]
		
		if not self.unitData[unit_i].lastChapter then
			self.units[unit_i].lastChapter = self.chapters.count
		else
			self.units[unit_i].lastChapter = self.unitData[unit_i].lastChapter
		end
		self.units[unit_i].availability = self.units[unit_i].lastChapter -
			self.units[unit_i].joinChapter + 1
		
	end
	self.units.count = unit_i
	
	self:constructPICount()
	self:constructLPFactor()
end

-- returns a #chapter x #itemTypes array of total items available
function gameDataObj:constructPICount()
	local runningTotal = {}
	self.PICount = {}
	self.PICount[0] = {}	
	
	for itemT_i = promo_KC, promo_ES do
		runningTotal[itemT_i] = 0
		self.PICount[0][itemT_i] = 0 -- first chapter, no promo items
	end
	
	local entry_i = 1
	while self.pIAcqTime[entry_i] do
		local chapter = self.pIAcqTime[entry_i][1]
		local itemType = self.pIAcqTime[entry_i][2]
		local numItems = self.pIAcqTime[entry_i][3]
		
		-- increment running total by 1 if single item, 9 if shop
		runningTotal[itemType] = runningTotal[itemType] + numItems
		
		-- insert running total into count for this chapter
		self.PICount[chapter] = {}
		for itemT_i = promo_KC, promo_ES do
			self.PICount[chapter][itemT_i] = runningTotal[itemT_i]
		end
		
		entry_i = entry_i + 1
	end
	
	-- now that sparse entries are inserted, fill in the rest from prev chapters
	for chapter_i = 1, self.chapters.count do
		if not self.PICount[chapter_i] then
			self.PICount[chapter_i] = {}
			
			for itemT_i = promo_KC, promo_ES do
				self.PICount[chapter_i][itemT_i] = self.PICount[chapter_i - 1][itemT_i]
			end
		end
	end
end

-- U x maxTeamSize
-- for each unit, array of how the bid values 
-- should be scaled down depending on how many
-- earlier units in the same team will use the
-- same item (assume team will not use more than
-- one earth seal). if first unit, then PVF == 1
function gameDataObj:constructLPFactor()
	local maxPredec = {}
	for PIType_i = 0, promo_FC do
		maxPredec[PIType_i] = 0
	end

	for unit_i = 1, self.units.count do
		local function getEarliestPromoChapter(PIType, priorItemsNeeded)
			if PIType == promo_NO then
				return self.units[unit_i].joinChapter
			end
			
			for chapter_i = 1, self.chapters.count do
				local itemSurplus = self.PICount[chapter_i][PIType] - priorItemsNeeded
			
				if (itemSurplus > 0) or 
					(itemSurplus + self.PICount[chapter_i][promo_ES] > 0 and PIType < promo_HS) then		
					-- can use an earth seal if PIType < promo_HS
					-- assume more than one eSeal will not be needed
				
					return math.max(chapter_i, self.units[unit_i].joinChapter)
				end
			end

			return self.chapters.count + 1 -- never promotes
		end
		
		-- find earliestPromoChapter if after join time
		-- ignore any levels needed to promote (for now?)
		-- for each number of predecessors possible,
		-- compute the LatePromoFactor
		
		local PIType = self.units[unit_i].promoItem
		local earliestPromoChapter = getEarliestPromoChapter(PIType, 0)
		self.units[unit_i].LPFactor = {}
		self.units[unit_i].LPFactor[0] = 1
		for predec_i = 1, maxPredec[PIType] do
			local underPromotedTime = getEarliestPromoChapter(PIType, predec_i) - earliestPromoChapter
			
			-- lose 1/8 more value each chapter underpromoted until value reaches 0
			-- this method is arbitrary
			
			local lostValue = 0 -- in units of "chapters available"
			for i = 1, underPromotedTime do
				lostValue = lostValue + math.min(1, i/8)
			end
			
			-- scale to 1
			self.units[unit_i].LPFactor[predec_i] = 1 - (lostValue / self.units[unit_i].availability)
		end
		
		maxPredec[PIType] = maxPredec[PIType] + 1
	end
end

-- FE6 Normal Mode, chapters from 0
P.sixNM = {
	--chapter 1/0
	--{"Roy", 0, promo_HS},
	--{"Marcus", 0, promo_NO},
	{"Lance", 0, promo_KC},
	{"Alan", 0, promo_KC},
	{"Wolt", 0, promo_OB},
	{"Bors", 0, promo_KC},
	--2/1
	--{"Merlinus", 1, promo_NO},
	{"Ellen", 1, promo_GR},
	{"Shanna", 1, promo_EW},
	{"Dieck", 1, promo_HC},
	{"Lott", 1, promo_HC},
	{"Wade", 1, promo_HC},
	--3/2
	{"Lugh", 2, promo_GR},
	{"Chad", 2, promo_NO},
	--4/3
	{"Rutger", 3, promo_HC},
	{"Clarine", 3, promo_GR},
	--5/4
	--6/5
	{"Saul", 5, promo_GR},
	{"Dorothy", 5, promo_OB},
	{"Sue", 5, promo_OB},
	--7/6
	{"Zealot", 6, promo_NO},
	{"Noah", 6, promo_KC},
	{"Treck", 6, promo_KC},
	--8/7
	{"Astohl", 7, promo_NO},
	{"Oujay", 7, promo_HC},
	{"Barth", 7, promo_KC},
	{"Wendy", 7, promo_KC},
	{"Lilina", 7, promo_GR},
	--8x/8
	--9/9
	{"Fir", 9, promo_HC},
	{"Shin", 9, promo_OB},
	--10a/10
	{"Gonzales", 10, promo_HC}, -- 10a/10b
	{"Geese", 10, promo_HC}, -- 10a/11b
	--11a/11
	--{"Lalum", 11, promo_NO}, -- 11a	
	{"Echidna", 11, promo_NO}, -- 11a	
	--10b/10
	{"Tate", 10, promo_EW}, -- 11a/10b
	{"Klein", 10, promo_NO}, -- 11a/10b
	--11b/11
	--{"Elphin", 11, promo_NO}, --11b
	{"Bartre", 11, promo_NO}, --11b
	--12/12
	{"Ray", 12, promo_GR},
	{"Cath", 12, promo_NO}, -- recruitable in 4 chapters
	--12x/13
	--13/14
	{"Miledy", 14, promo_EW},
	{"Perceval", 14, promo_NO}, -- 13 or 15
	--14/15
	{"Cecelia", 15, promo_NO},
	{"Sophia", 15, promo_GR},
	--14x/16
	--15/17
	{"Igrene", 17, promo_NO},
	{"Garret", 17, promo_NO},
	--16/18
	--{"Fa", 18, promo_NO},
	{"Ziess", 18, promo_EW},
	{"Hugh", 18, promo_GR},
	--16x/19
	{"Douglas", 19, promo_NO},
	--17ab/20
	--18ab/21
	--19a/22
	{"Niime", 22, promo_NO}, -- 19a/20b
	--19b/22
	--20a/23
	{"Juno", 23, promo_NO}, -- 20a
	--20b/23
	{"Dayan", 23, promo_NO}, -- 20b
	--20abx/24
	--21/25
	{"Yodel", 25, promo_NO},
	--21x/26
	--22/27
	--23/28
	{"Karel", 28, promo_NO}
	--24/29
	--25/30
}

P.sevenHNM = gameDataObj:new()

-- FE7 Hector Normal Mode
P.sevenHNM.unitData = {
	--chapter 11 /1
	--12 /2
	{"Matthew", 2, promo_FC}, -- free for 11/1
	{"Serra", 2, promo_GR},
	{"Oswin", 2, promo_KC},
	{"Eliwood", 2, promo_HS},
	{"Lowen", 2, promo_KC},
	{"Rebecca", 2, promo_OB},
	{"Dorcas", 2, promo_HC},
	{"Bartre&Karla", 2, promo_HC},
	{"Marcus<=19x", 2, promo_NO},
	--13 /3
	{"Guy", 3, promo_HC},
	--13x/4
	--14 /5
	{"Erk", 5, promo_GR},
	{"Priscilla", 6, promo_GR}, -- can't really help in join chapter
	--15 /6
	--16 /7
	{"Florina", 7, promo_EW},
	{"Lyn", 8, promo_HS}, -- free during join chapter
	{"Sain", 8, promo_KC},
	{"Kent", 8, promo_KC},
	{"Wil", 8, promo_OB},
	--17 /8
	{"Raven", 8, promo_HC}, -- can they help during join chapter?
	{"Lucius", 8, promo_GR},
	--17x/9
	{"Canas", 9, promo_GR},
	--18 /10
	--19 /11
	{"Dart", 11, promo_OS},
	{"Fiora", 11, promo_EW},
	--19x/12
	--20 /13
	{"Marcus>=20", 13, promo_NO},
	{"Legault", 13, promo_FC}, -- can't really help during join chapter?	
	--21 /14
	--22 /15
	{"Isadora", 15, promo_NO},
	{"Heath", 15, promo_EW},
	{"Rath", 15, promo_OB},
	--23 /16
	{"Hawkeye", 16, promo_NO},
	--23x/17
	--24 /18
	--{"Wallace", 17, promo_NO},
	--{"Gietz", 17, promo_NO},
	--25 /19
	{"Farina", 19, promo_EW},
	--26 /20
	{"Pent", 20, promo_NO},
	{"Louise", 20, promo_NO},
	--27 /21
	--{"Harken", 20, promo_NO},
	--{"Karel", 20, promo_NO},
	--28 /22
	{"Nino", 22, promo_GR},
	--28x/23
	{"Jaffar", 23, promo_NO},
	--29 /24
	{"Vaida", 24, promo_NO},
	--30 /25
	--31 /26
	--31x/27
	--32 /28
	{"Renault", 28, promo_NO}
	--32x/29
	--33 /30
	--{"Athos", 30, promo_NO}
}

P.sevenHNM.unitData[9].lastChapter = 12 -- split Marcus

P.sevenHNM.chapters = {
"11  Another Journey",
"12  Birds of a Feather",
"13  In Search of Truth",
"13x The Peddler Merlinus",
"14  False Friends",
"15  Talons Alight",
"16  Noble Lady of Caelin",
"17  Whereabouts Unknown",
"17x The Port of Badon",
"18  Pirate Ship",
"19  The Dread Isle",
"19x Imprisoner of Magic",
"20  Dragon's Gate",
"21  New Resolve",
"22  Kinship's Bond",
"23  Living Legend",
"23x Genesis",
"24  Four-Fanged Offense",
"25  Crazed Beast",
"26  Unfulfilled Heart",
"27  Pale Flower of Darkness",
"28  Battle Before Dawn",
"28x Night of Farewells",
"29  Cog of Destiny",
"30  The Berserker",
"31  Sands of Time",
"31x Battle Preparations",
"32  Victory or Death",
"32x The Value of Life",
"33  Light"
}

-- promo Item Acquire Time
-- sparse array of {chapter, item type, # of items}
-- most items are not convenient to use mid chapter
-- assume they are used at start of next chapter
P.sevenHNM.pIAcqTime = {
	--chapter 11 /1
	--12 /2
	--13 /3
	--13x/4
	--14 /5
	--15 /6
	--16 /7
	--17 /8
	
	{09, promo_KC, 1}, -- chest
	{09, promo_HC, 1}, -- chest
	--17x/9
	--18 /10
	
	{11, promo_GR, 1}, -- shaman
	--19 /11
	
	{12, promo_OB, 1}, -- Uhai
	--19x/12
	--20 /13
	
	{14, promo_HC, 1}, -- chest
	--21 /14
	
	{15, promo_EW, 1}, -- village
	{15, promo_HC, 1}, -- steal Oleg
	--22 /15
	
	{16, promo_KC, 1}, -- cavalier
	--23 /16
	{16, promo_OS, 1}, -- sand (can get from shops later but never need more than 1)
	
	{17, promo_HC, 1}, -- sand
	{17, promo_GR, 1}, -- steal Jasmine
	--23x/17
	--24 /18
	
	{19, promo_ES, 1}, -- village
	{19, promo_OB, 1}, -- Village A, Sniper B
	{19, promo_OS, 9}, -- A ONLY secret shop
	--25 /19
	
	{20, promo_EW, 1}, -- village
	--26 /20
	{20, promo_HS, 1}, -- auto
	
	--27 /21
	
	{22, promo_GR, 1}, -- A ONLY, chest
	{22, promo_HC, 1}, -- B ONLY, chest
	--28 /22
	
	{23, promo_EW, 1}, -- bishop
	{23, promo_HS, 1}, -- auto, chapter end
	--28x/23
	{23, promo_FC, 1}, -- Sonia, free chapter
	
	--29 /23
	
	{25, promo_GR, 1}, -- steal sniper
	--30 /25
	--31 /26
	{26, promo_KC, 9}, -- secret shop, survive chapter
	{26, promo_HC, 9},
	{26, promo_OB, 9},
	{26, promo_EW, 9},
	{26, promo_GR, 9},
	
	--31x/27
	--32 /28
	{28, promo_ES, 1}, -- nils start
	
	{29, promo_OS, 9}, -- secret shop @ end
	{29, promo_FC, 9}, 
	{29, promo_ES, 9}
	--32x/29
	--33 /30
}

-- FE8 Hard Mode, chapters from 0 (prologue, 5x=8 as they are not available for 6&7)
P.eightHM = {
	--{"Eirika", 0, promo_HS},
	--{"Seth", 0, promo_NO},
	{"Franz", 1, promo_KC},
	{"Gilliam", 1, promo_KC},
	{"Vanessa", 2, promo_EW},
	{"Moulder", 2, promo_GR},
	{"Ross", 2, promo_OS}, -- can HC
	{"Garcia", 2, promo_HC},
	{"Neimi", 3, promo_OB},
	{"Colm", 3, promo_OS},
	{"Artur", 4, promo_GR},
	{"Lute", 4, promo_GR},
	{"Natasha", 5, promo_GR},
	{"Joshua", 5, promo_HC},
	{"Ephraim", 8, promo_HS}, --5x
	{"Forde", 8, promo_KC},
	{"Kyle", 8, promo_KC},
	--{"Orson", 5.5, promo_NO},
	{"Tana", 9, promo_EW}, -- same in both routes, mostly unuseable in eph9
	{"Amelia", 9, promo_KC}, -- returns in eir 13
	{"Gerik", 10, promo_HC}, -- 13 eph
	--{"Tethys", 10, promo_NO}, -- 13 eph
	{"Innes", 10, promo_NO}, -- 15 eph
	{"Marisa", 10, promo_HC}, -- 12 eph
	{"Dozla", 11, promo_NO},
	{"L'Arachel", 11, promo_GR},
	{"Saleh", 12, promo_NO}, -- 15 eph 
	{"Ewan", 12, promo_GR},
	{"Cormag", 13, promo_EW}, -- 10 eph
	{"Rennac", 14, promo_NO},
	{"Duessel", 15, promo_NO}, -- 10 eph
	{"Knoll", 15, promo_GR},
	--{"Myrrh", 16, promo_NO},
	{"Syrene", 17, promo_NO}
}

return gameDataObj