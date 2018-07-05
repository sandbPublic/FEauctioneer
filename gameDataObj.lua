local P = {}
gameDataObj = P

local promo_NO = 0 -- can't promote
local promo_KC = 1 -- knight crest
local promo_HC = 2 -- hero crest
local promo_OB = 3 -- orion's bolt
local promo_EW = 4 -- elysian whip
local promo_GR = 5 -- guiding ring
local promo_O8 = 6 -- ocean seal in FE8
local promo_ES = 7 -- earth seal, item only, leave room to insert ocean seal in FE8
local promo_OS = 8 -- ocean seal
local promo_FC = 9 -- fell contract
local promo_HS =10 -- heaven seal

P.promoStrings = {"Kgt C", "Hero ",  "oBolt", "eWhip", "gRing", "Ocean", 
"eSeal", "Ocean", "FellC", "Heven"} 
P.promoStrings[0] = "     "

function gameDataObj:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	o.units = {}
	-- array of tables of .name .joinChapter .lastChapter .availability .promoItem .LPFactor
	-- units[1].name is more intuitive than units.names[1]	
	o.units.count = 0
	
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

function gameDataObj:sharePI(unit_i, unit_j)
	return self.units[unit_i].promoItem == self.units[unit_j].promoItem
end

-- returns a #chapter x #itemTypes array of total items available
function gameDataObj:constructPICount()
	local runningTotal = {}
	self.PICount = {}
	self.PICount[0] = {}	
	
	for itemT_i = promo_KC, promo_HS do
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
		for itemT_i = promo_KC, promo_HS do
			self.PICount[chapter][itemT_i] = runningTotal[itemT_i]
		end
		
		entry_i = entry_i + 1
	end
	
	-- now that sparse entries are inserted, fill in the rest from prev chapters
	for chapter_i = 1, self.chapters.count do
		if not self.PICount[chapter_i] then
			self.PICount[chapter_i] = {}
			
			for itemT_i = promo_KC, promo_HS do
				self.PICount[chapter_i][itemT_i] = self.PICount[chapter_i - 1][itemT_i]
			end
		end
	end
end

-- U x maxPredec x chaptersAvailable
-- for each unit, array of how the bid values 
-- should be scaled down depending on how many
-- earlier units in the same team will use the
-- same item (assume team will not use more than
-- one earth seal). if first unit, then PVF == 1
function gameDataObj:constructLPFactor()
	local maxPredec = {}
	for PIType_i = 0, promo_HS do
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
					(itemSurplus + self.PICount[chapter_i][promo_ES] > 0 and PIType < promo_ES) then		
					-- can use an earth seal if PIType < promo_ES
					-- assume more than one eSeal will not be needed
				
					return math.max(chapter_i, self.units[unit_i].joinChapter)
				end
			end

			return self.chapters.count + 1 -- never promotes
		end
		
		-- find earliestPromoChapter if after join time
		-- ignore any level-ups needed to promote (for now?)
		-- for each number of predecessors possible,
		-- compute the LatePromoFactor
		
		local PIType = self.units[unit_i].promoItem
		local earliestPromoChapter = {}
		
		self.units[unit_i].LPFactor = {}
		self.units[unit_i].LPFactor.adjusted = false
		self.units[unit_i].LPFactor.count = maxPredec[PIType]
		
		for predec_i = 0, maxPredec[PIType] do
			earliestPromoChapter[predec_i] = getEarliestPromoChapter(PIType, predec_i)
			
			if earliestPromoChapter[predec_i] > earliestPromoChapter[0] then
				self.units[unit_i].LPFactor.adjusted = true
			end
		end
		
		if self.units[unit_i].LPFactor.adjusted then
		for predec_i = 1, maxPredec[PIType] do
			self.units[unit_i].LPFactor[predec_i] = {}
			
				for chapter_i = self.units[unit_i].joinChapter, self.units[unit_i].lastChapter do
					if (earliestPromoChapter[0] <= chapter_i) 
						and (chapter_i < earliestPromoChapter[predec_i]) then -- underpromoted
						
						-- lose 1/8 more value each chapter underpromoted until value reaches 0
						-- this method is arbitrary
						self.units[unit_i].LPFactor[predec_i][chapter_i] = 
							math.max(0, 1 - (1 + chapter_i - earliestPromoChapter[0])/8)
					else 
						self.units[unit_i].LPFactor[predec_i][chapter_i] = 1
					end
				end
			end
		end
		
		-- increment number of potential predecs of this type
		maxPredec[PIType] = maxPredec[PIType] + 1 
	end
end

-- FE6 Normal Mode, Good Ending
P.sixNM = gameDataObj:new()

P.sixNM.unitData = {
	--chapter 1
	--{"Roy",	1, promo_HS},
	--{"Marcus",1, promo_NO},
	{"Lance",	1, promo_KC},
	{"Alan",	1, promo_KC},
	{"Wolt",	1, promo_OB},
	{"Bors",	1, promo_KC},
	--2
	--{"Merlinus",	2, promo_NO},
	{"Ellen",	2, promo_GR},
	{"Shanna",	2, promo_EW},
	{"Dieck",	2, promo_HC},
	{"Lott",	2, promo_HC},
	{"Wade",	2, promo_HC},
	--3
	{"Lugh",	3, promo_GR},
	{"Chad",	3, promo_NO},
	--4
	{"Rutger",	4, promo_HC},
	{"Clarine",	4, promo_GR},
	--5
	--6
	{"Saul",	6, promo_GR},
	{"Dorothy",	6, promo_OB},
	{"Sue",		6, promo_OB},
	--7
	{"Zealot",	7, promo_NO},
	{"Noah",	7, promo_KC},
	{"Treck",	7, promo_KC},
	--8
	{"Astohl",	8, promo_NO},
	{"Oujay",	8, promo_HC},
	{"Barth",	8, promo_KC},
	{"Wendy",	8, promo_KC},
	{"Lilina",	8, promo_GR},
	-- 8x / 9
	-- 9  /10
	{"Fir",		10, promo_HC},
	{"Shin",	10, promo_OB},
	--10ab/11
	{"Gonzales",	11, promo_HC}, -- 10a/10b
	{"Geese",	11, promo_HC}, -- 10a/11b
	{"Tate",	11, promo_EW}, -- 11a/10b
	{"Klein",	11, promo_NO}, -- 11a/10b
	--11ab/12
	--{"Lalum/Elphin",	11, promo_NO},
	{"Echidna",	12, promo_NO}, -- 11a only
	{"Bartre",	12, promo_NO}, --11b only
	--12  /13
	{"Ray",		13, promo_GR},
	{"Cath",	13, promo_NO}, -- recruitable in 4 chapters
	--12x /14
	--13  /15
	{"Miledy",	15, promo_EW},
	{"Perceval",	15, promo_NO}, -- Ch13 or 15
	--14  /16
	{"Cecelia",	16, promo_NO},
	{"Sophia",	16, promo_GR},
	--14x /17
	--15  /18
	{"Igrene",	18, promo_NO},
	{"Garret",	18, promo_NO},
	--16  /19
	--{"Fa",	19, promo_NO},
	{"Ziess",	19, promo_EW},
	{"Hugh",	19, promo_GR},
	--16x /20
	{"Douglas",	20, promo_NO},
	--17ab/21
	--18ab/22
	--19ab/23
	{"Niime",	23, promo_NO}, -- 19a/20b
	--20ab/24
	{"Juno",	24, promo_NO}, -- 20a only
	{"Dayan",	24, promo_NO}, -- 20b only
	--20abx/25
	--21  /26
	{"Yodel",	26, promo_NO},
	--21x /27
	--22  /28
	--23  /29
	{"Karel",	29, promo_NO}
	--24  /30
	--25  /31
}

P.sixNM.chapters = {
	" 1  Dawn of Destiny",
	" 2  Princess of Bern",
	" 3  Late Arrival",
	" 4  Collapse of the Alliance",
	" 5  Fire Emblem",
	" 6  Trap",
	" 7  Rebellion of Ostia",
	" 8  Reunion",
	" 8x The Blazing Sword",
	" 9  Misty Isles",
	"10A Resistance Forces, 10B Caught in the Middle",
	"11A Hero of the Western Isles, 11B Escape to Freedom",
	"12  True Enemy",
	"12x The Axe of Thunder",
	"13  Rescue Plan",
	"14  Arcadia",
	"14x The Infernal Element",
	"15  Dragon Girl",
	"16  Retaking the Capital",
	"16x The Pinnacle of Light",
	"17A Path Through the Ocean, 17B Bishop's Teachings",
	"18A Frozen River, 18B Laws of Sacae",
	"19A Bitter Cold, 19B Battle in Bulgar",
	"20A Liberation of Ilia, 20B The Silver Wolf",
	"20AxThe Spear of Ice, 20BxThe Bow of the Winds",
	"21  The Binding Blade",
	"21x The Silencing Darkness",
	"22  Neverending Dream",
	"23  Ghost of Bern",
	"24  Truth of the Legend",
	"25  Beyond the Darkness"
}

-- promo Item Acquire Time
-- sparse array of {chapter, item type, # of items}
-- most items are not convenient to use mid chapter
-- assume they are used at start of next chapter
P.sixNM.pIAcqTime = {
	--chapter 1
	-- 2
	-- 3
	-- 4
	-- 5
	-- 6
	-- 7
	{07, promo_HC, 1}, -- village
	-- 8
	{08, promo_KC, 1}, -- chest
	{08, promo_EW, 1}, -- chest
	{08, promo_GR, 1}, -- chest
	-- 8x / 9
	-- 9  /10
	--10ab/11
	{11, promo_OB, 1}, -- 10b or 11a village
	
	{12, promo_HC, 1}, -- 10b or 11a, all villages
	{12, promo_OB, 1}, -- 10b or 11a, klein recruited and archers survive
	{12, promo_EW, 1}, -- 10b or 11a, tate recruited and pegasi survive
	--11ab/12
	--12  /13
	{13, promo_EW, 1}, -- chest
	--12x /14
	--13  /15
	
	{15, promo_KC, 1}, -- perc recruited and knights survive
	--14  /16
	{16, promo_GR, 1}, -- sand, sophia
	
	--14x /17
	--15  /18
	--{18, promo_KC, 1}, -- perc recruited and knights survive
	--16  /19
	{19, promo_KC, 1}, -- chest
	{19, promo_HC, 1}, -- chest
	
	{20, promo_KC, 9}, -- secret shop, may cost turns to access
	{20, promo_HC, 9}, -- secret shop
	{20, promo_OB, 9}, -- secret shop
	{20, promo_EW, 9}, -- secret shop
	{20, promo_GR, 9}, -- secret shop
	--16x /20
	--17ab/21
	--18ab/22
	{22, promo_GR, 1}, -- 18a or 20b, village
	--19ab/23
	{23, promo_KC, 1}, -- a ONLY, steal
	--20ab/24
	{24, promo_EW, 1}, -- a ONLY, steal
	{24, promo_OB, 1}, -- b ONLY, steal
	--20abx/25
	--21  /26
	{26, promo_KC, 2}, -- village, steal
	
	{27, promo_KC, 9}, -- secret shop
	{27, promo_HC, 9}, -- secret shop
	{27, promo_OB, 9}, -- secret shop
	{27, promo_EW, 9}, -- secret shop
	{27, promo_GR, 9}, -- secret shop
	--21x /27
	--22  /28
	{28, promo_HC, 1}, -- steal
	--23  /29
	{23, promo_GR, 1} -- steal
	--24  /30
	--25  /31
}

-- FE7 Hector Normal Mode
P.sevenHNM = gameDataObj:new()

P.sevenHNMold = gameDataObj:new()

P.sevenHNM.unitData = {
	--chapter
	--11 / 1
	--12 / 2
	{"Matthew",		2, promo_FC}, -- free for 11/1
	{"Serra",		2, promo_GR},
	{"Oswin",		2, promo_KC},
	{"Eliwood",		2, promo_HS},
	{"Lowen",		2, promo_KC},
	{"Rebecca",		2, promo_OB},
	{"Dorcas",		2, promo_HC},
	{"Bartre&Karla",	2, promo_HC},
	{"Marcus<=19x",	2, promo_NO},
	--13 / 3
	{"Guy",			3, promo_HC},
	--13x/ 4
	--14 / 5
	{"Erk",			5, promo_GR},
	
	{"Priscilla",	6, promo_GR}, -- can't really help in join chapter
	--15 / 6
	--16 / 7
	{"Florina",		7, promo_EW},
	
	{"Lyn",			8, promo_HS}, -- free during join chapter
	{"Sain",		8, promo_KC},
	{"Kent",		8, promo_KC},
	{"Wil",			8, promo_OB},
	--17 / 8
	{"Raven",		8, promo_HC}, -- can they help during join chapter?
	{"Lucius",		8, promo_GR},
	--17x/ 9
	{"Canas",		9, promo_GR},
	--18 /10
	--19 /11
	{"Dart",		11, promo_OS},
	{"Fiora",		11, promo_EW},
	--19x/12
	--20 /13
	{"Marcus>=20",	13, promo_NO},
	{"Legault",		13, promo_FC}, -- can't really help during join chapter?	
	--21 /14
	--22 /15
	{"Isadora",		15, promo_NO},
	{"Heath",		15, promo_EW},
	{"Rath",		15, promo_OB},
	--23 /16
	{"Hawkeye",		16, promo_NO},
	--23x/17
	--24 /18
	--{"Wallace/Geitz",	18, promo_NO},
	--25 /19
	{"Farina",		19, promo_EW},
	--26 /20
	{"Pent",		20, promo_NO},
	{"Louise",		20, promo_NO},
	--27 /21
	--{"Harken",	20, promo_NO},
	--{"Karel",		20, promo_NO},
	--28 /22
	{"Nino",		22, promo_GR},
	--28x/23
	{"Jaffar",		23, promo_NO},
	--29 /24
	{"Vaida",		24, promo_NO},
	--30 /25
	--31 /26
	--31x/27
	--32 /28
	{"Renault",		28, promo_NO}
	--32x/29
	--33 /30
	--{"Athos",		30, promo_NO}
}

P.sevenHNMold.unitData = {
	--chapter
	--11 / 1
	--12 / 2
	{"Matthew",		2, promo_FC}, -- free for 11/1
	{"Serra",		2, promo_GR},
	{"Oswin",		2, promo_KC},
	{"Eliwood",		2, promo_HS},
	{"Lowen",		2, promo_KC},
	{"Rebecca",		2, promo_OB},
	{"Dorcas",		2, promo_HC},
	{"Bartre&Karla",	2, promo_HC},
	--{"Marcus<=19x",	2, promo_NO},
	--13 / 3
	{"Guy",			3, promo_HC},
	--13x/ 4
	--14 / 5
	{"Erk",			5, promo_GR},
	
	{"Priscilla",	6, promo_GR}, -- can't really help in join chapter
	--15 / 6
	--16 / 7
	{"Florina",		7, promo_EW},
	
	{"Lyn",			8, promo_HS}, -- free during join chapter
	{"Sain",		8, promo_KC},
	{"Kent",		8, promo_KC},
	{"Wil",			8, promo_OB},
	--17 / 8
	{"Raven",		8, promo_HC}, -- can they help during join chapter?
	{"Lucius",		8, promo_GR},
	--17x/ 9
	{"Canas",		9, promo_GR},
	--18 /10
	--19 /11
	{"Dart",		11, promo_OS},
	{"Fiora",		11, promo_EW},
	--19x/12
	--20 /13
	--{"Marcus>=20",	13, promo_NO},
	{"Legault",		13, promo_FC}, -- can't really help during join chapter?	
	--21 /14
	--22 /15
	{"Isadora",		15, promo_NO},
	{"Heath",		15, promo_EW},
	{"Rath",		15, promo_OB},
	--23 /16
	{"Hawkeye",		16, promo_NO},
	--23x/17
	--24 /18
	--{"Wallace/Geitz",	18, promo_NO},
	--25 /19
	{"Farina",		19, promo_EW},
	--26 /20
	{"Pent",		20, promo_NO},
	{"Louise",		20, promo_NO},
	--27 /21
	--{"Harken/Karel",	20, promo_NO},
	--28 /22
	{"Nino",		22, promo_GR},
	--28x/23
	{"Jaffar",		23, promo_NO},
	--29 /24
	{"Vaida",		24, promo_NO},
	--30 /25
	--31 /26
	--31x/27
	--32 /28
	--{"Renault",		28, promo_NO}
	--32x/29
	--33 /30
	--{"Athos",		30, promo_NO}
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

P.sevenHNMold.chapters = P.sevenHNM.chapters

P.sevenHNM.pIAcqTime = {
	--chapter 
	--11 /1
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

P.sevenHNMold.pIAcqTime = P.sevenHNM.pIAcqTime

-- FE8 Hard Mode, assume Eirika route?
P.eightHM = gameDataObj:new()

P.eightHM.unitData = {
	-- P/ 1
	--{"Eirika",	1, promo_HS},
	--{"Seth",		1, promo_NO},
	-- 1/ 2
	{"Franz",		2, promo_KC},
	{"Gilliam",		2, promo_KC},
	-- 2/ 3
	{"Vanessa",		3, promo_EW},
	{"Moulder",		3, promo_GR},
	{"Ross",		3, promo_O8}, -- can promo_HC
	{"Garcia",		3, promo_HC},
	-- 3/ 4
	{"Neimi",		4, promo_OB},
	{"Colm",		4, promo_O8},
	-- 4/ 5
	{"Artur",		5, promo_GR},
	{"Lute",		5, promo_GR},
	-- 5/ 6
	{"Natasha",		6, promo_GR},
	{"Joshua",		6, promo_HC},
	--5x/ 7
	--{"Orson",		7, promo_NO},
	-- 6/ 8
	-- 7/ 9
	-- 8/10
	{"Forde",		10, promo_KC},
	{"Kyle",		10, promo_KC},
	-- 9/11
	{"Tana",		11, promo_EW}, -- same in both routes, mostly unuseable in eph9
	{"Amelia",		11, promo_KC}, -- returns in eir 13
	--10/12
	{"Gerik",		12, promo_HC}, -- 13/15 +3 eph
	--{"Tethys",	12, promo_NO}, -- 13/15 +3 eph
	{"Innes",		12, promo_NO}, -- 15/17 +5 eph
	{"Marisa",		12, promo_HC}, -- 12/14 +2 eph
	--11/13
	{"Dozla",		13, promo_NO},
	{"L'Arachel",	13, promo_GR},
	--12/14
	{"Saleh",		14, promo_NO}, -- 15/17 +3 eph 
	{"Ewan",		14, promo_GR},
	--13/15
	{"Cormag",		15, promo_EW}, -- 10/12 -3 eph
	--14/16
	{"Rennac",		16, promo_NO},
	--15/17
	--{"2nd Lord",	17, promo_HS}, -- free Ch5x? Ch8?
	{"Duessel",		17, promo_NO}, -- 10/12 -5 eph
	{"Knoll",		17, promo_GR},
	--16/18
	--{"Myrrh",		18, promo_NO},
	--17/19
	{"Syrene",		19, promo_NO}
	--18/20
	--19/21
	--20/22
	--21/23
}

P.eightHM.chapters = {
	"Prologue: The Fall of Renais",
	" 1  Escape!",
	" 2  The Protected",
	" 3  The Bandits of Borgo",
	" 4  Ancient Horrors",
	" 5  The Empire's Reach",
	" 5x Unbroken Heart",
	" 6  Victims of War",
	" 7  Waterside Renvall",
	" 8  It's a Trap!",
	" 9A Distant Blade 9B Fort Rigwald",
	"10A Revolt at Carcino 10B Turning Traitor",
	"11A Creeping Darkness 11B Phantom Ship",
	"12A Village of Silence 12B Landing at Taizel",
	"13A Hamill Canyon 13B Fluorspar's Oath",
	"14A Queen of White Dunes 14B Father and Son",
	"15  Scorched Sand",
	"16  Ruled by Madness",
	"17  River of Regrets",
	"18  Two Faces of Evil",
	"19  Last Hope",
	"20  Darkling Woods",
	"21  Sacred Stones"
}

P.eightHM.pIAcqTime = {
	-- P/ 1
	-- 1/ 2
	-- 2/ 3
	-- 3/ 4
	-- 4/ 5
	-- 5/ 6
	
	{ 8, promo_GR, 1}, -- if all villages visited
	--5x/ 7
	-- 6/ 8
	
	{ 9, promo_OB, 1}, -- if civs survive
	-- 7/ 9
	
	{10, promo_KC, 1}, -- Murray
	-- 8/10
	
	{11, promo_EW, 1}, -- chest
	-- 9/11
	{11, promo_O8, 1}, -- a pirate, b chest
	
	--10/12	
	--{12, promo_HC, 1}, -- b ONLY, village
	{12, promo_HC, 1}, -- 10a or 13b, Gerik
	
	{13, promo_GR, 1}, -- a ONLY, Pablo
	--{13, promo_KC, 1}, -- b ONLY, if all npc cavs survive
	--11/13
	--12/14
	--{14, promo_GR, 1}, -- b ONLY, shaman
	
	--13/15
	{15, promo_EW, 1}, -- 13a or 10b, Cormag
	
	{16, promo_KC, 1}, -- a ONLY, Aias
	--14/16
	{16, promo_GR, 1}, -- chest
	
	{16, promo_HC, 1}, -- a ONLY, myrmidon
	
	--{17, promo_KC, 1}, -- b ONLY, Vigarde
	--15/17
	{17, promo_ES, 1}, -- village
	{17, promo_GR, 1}, -- steal shaman
	
	--16/18
	{18, promo_KC, 1}, -- chest
	{18, promo_HC, 1}, -- enemy
	
	--17/19
	{19, promo_GR, 1}, -- mage
	
	--18/20
	--19/21
	--20/22
	--21/23
}

return gameDataObj