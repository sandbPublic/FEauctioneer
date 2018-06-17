local P = {}
gameData = P

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

-- returns a #chapter x #itemTypes array of total items available
local function constructPIcount(pIAcqTime, numChapters)
	local runningTotal = {}
	local pICount = {}
	pICount[0] = {}	
	
	for itemT_i = promo_KC, promo_ES do
		runningTotal[itemT_i] = 0
		pICount[0][itemT_i] = 0 -- first chapter, no promo items
	end
	
	local entry_i = 1
	while pIAcqTime[entry_i] do
		local chapter = pIAcqTime[entry_i][1]
		local itemType = pIAcqTime[entry_i][2]
		local numItems = pIAcqTime[entry_i][3]
		
		-- increment running total by 1 if single item, 9 if shop
		runningTotal[itemType] = runningTotal[itemType] + numItems
		
		-- insert running total into count for this chapter
		pICount[chapter] = {}
		for itemT_i = promo_KC, promo_ES do
			pICount[chapter][itemT_i] = runningTotal[itemT_i]
		end
		
		entry_i = entry_i + 1
	end
	
	-- now that sparse entries are inserted, fill in the rest from prev chapters
	for chapter_i = 1, numChapters do
		if not pICount[chapter_i] then
			pICount[chapter_i] = {}
			
			for itemT_i = promo_KC, promo_ES do
				pICount[chapter_i][itemT_i] = pICount[chapter_i - 1][itemT_i]
			end
		end
	end
	
	return pICount
end

-- U x maxTeamSize
-- for each unit, array of how the bid values 
-- should be scaled down depending on how many
-- earlier units in the same team will use the
-- same item (assume team will not use more than
-- one earth seal). if first unit, then PVF == 1
local function constructLatePFactor(mode, teamSize, numChapters)
	local unit_i = 1
	mode.LPFactor = {}
	while mode[unit_i] do
		mode.LPFactor[unit_i] = {}
		local joinChapter = mode[unit_i][chapter_I] -- join chapter
		local totalUnitAvail = numChapters - mode[unit_i][chapter_I] + 1
		-- #chapters this unit is available
		
		local function getEarliestPromoChapter(pIType, priorItemsNeeded)
			if pIType == promo_NO then
				return joinChapter
			end
		
			for chapter_i = 0, numChapters do
				local itemSurplus = mode.promoItemCount[chapter_i][pIType] - priorItemsNeeded
			
				if (itemSurplus > 0) or 
					(itemSurplus + mode.promoItemCount[chapter_i][promo_ES] > 0 and pIType < promo_HS) then		
					-- can use an earth seal if pIType < promo_HS
				
					return math.max(chapter_i, joinChapter)
				end
			end

			return numChapters
		end
		
		-- find earliestPromoChapter if after join time
		-- ignore any levels needed to promote (for now?)
		-- for each number of predecessors possible,
		-- compute the LatePromoFactor
		
		local pIType = mode[unit_i][promo_I]
		local earliestPromoChapter = getEarliestPromoChapter(pIType, 0)
		mode.LPFactor[unit_i][0] = 1
		for predec_i = 1, teamSize - 1 do
			local underPromotedTime = getEarliestPromoChapter(pIType, predec_i) - earliestPromoChapter
			
			-- lose 1/8 more value each chapter underpromoted until value reaches 0
			-- this method is arbitrary
			
			local lostValue = 0 -- in units of "chapters available"
			for i = 1, underPromotedTime do
				lostValue = lostValue + math.min(1, i/8)
			end
			
			-- scale to 1
			mode.LPFactor[unit_i][predec_i] = (totalUnitAvail - lostValue) / totalUnitAvail
		end
		
		unit_i = unit_i + 1
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

-- FE7 Hector Normal Mode, chapters from 0
P.sevenHNM = {
	--chapter 11/0
	--12/1
	{"Matthew", 1, promo_FC}, -- free for 11/0
	{"Serra", 1, promo_GR},
	{"Oswin", 1, promo_KC},
	{"Eliwood", 1, promo_HS},
	{"Lowen", 1, promo_KC},
	{"Rebecca", 1, promo_OB},
	{"Dorcas", 1, promo_HC},
	{"Bartre&Karla", 1, promo_HC},
	{"Marcus<=19x", 1, promo_NO},
	--13/2
	{"Guy", 2, promo_HC},
	--13x/3
	--14/4
	{"Erk", 4, promo_GR},
	{"Priscilla", 4, promo_GR},
	--15/5
	--16/6
	{"Florina", 6, promo_EW},
	{"Lyn", 7, promo_HS}, -- free during join chapter
	{"Sain", 7, promo_KC},
	{"Kent", 7, promo_KC},
	{"Wil", 7, promo_OB},
	--17/7
	{"Raven", 7, promo_HC}, -- can they help during join chapter?
	{"Lucius", 7, promo_GR},
	--17x/8
	{"Canas", 8, promo_GR},
	--18/9
	--19/10
	{"Dart", 10, promo_OS},
	{"Fiora", 10, promo_EW},
	--19x/11
	--20/12
	{"Marcus>=20", 12, promo_NO},
	{"Legault", 12, promo_FC}, -- can't really help during join chapter?	
	--21/13
	--22/14
	{"Isadora", 14, promo_NO},
	{"Heath", 14, promo_EW},
	{"Rath", 14, promo_OB},
	--23/15
	{"Hawkeye", 15, promo_NO},
	--23x/16
	--24/17
	--{"Wallace", 17, promo_NO},
	--{"Gietz", 17, promo_NO},
	--25/18
	{"Farina", 18, promo_EW},
	--26/19
	{"Pent", 19, promo_NO},
	{"Louise", 19, promo_NO},
	--27/20
	--{"Harken", 20, promo_NO},
	--{"Karel", 20, promo_NO},
	--28/21
	{"Nino", 21, promo_GR},
	--28x/22
	{"Jaffar", 22, promo_NO},
	--29/23
	{"Vaida", 23, promo_NO},
	--30/24
	--31/25
	--31x/26
	--32/27
	{"Renault", 27, promo_NO}
	--32x/28
	--33/29
	--{"Athos", 29, promo_NO}
}

-- promo Item Acquire Time
-- sparse array of {chapter, item type, # of items}
-- most items are not convenient to use mid chapter
-- assume they are used at start of next chapter
P.sevenHNM.pIAcqTime = {
	--chapter 11/0
	--12/1
	--13/2
	--13x/3
	--14/4
	--15/5
	--16/6
	--17/7
	
	{08, promo_KC, 1}, -- chest
	{08, promo_HC, 1}, -- chest
	--17x/8
	--18/9
	
	{10, promo_GR, 1}, -- shaman
	--19/10
	
	{11, promo_OB, 1}, -- Uhai
	--19x/11
	--20/12
	
	{13, promo_HC, 1}, -- chest
	--21/13
	
	{14, promo_EW, 1}, -- village
	{14, promo_HC, 1}, -- steal Oleg
	--22/14
	
	{15, promo_KC, 1}, -- cavalier
	--23/15
	{15, promo_OS, 1}, -- sand (can get from shops later but never need more than 1)
	
	{16, promo_HC, 1}, -- sand
	{16, promo_GR, 1}, -- steal Jasmine
	--23x/16
	--24/17
	
	{18, promo_ES, 1}, -- village
	{18, promo_OB, 1}, -- Village A, Sniper B
	{18, promo_OS, 9}, -- A ONLY secret shop
	--25/18
	
	{19, promo_EW, 1}, -- village
	--26/19
	{19, promo_HS, 1}, -- auto
	
	--27/20
	
	{21, promo_GR, 1}, -- A ONLY, chest
	{21, promo_HC, 1}, -- B ONLY, chest
	--28/21
	
	{22, promo_EW, 1}, -- bishop
	{22, promo_HS, 1}, -- auto, chapter end
	--28x/22
	{22, promo_FC, 1}, -- Sonia, survive chapter
	
	--29/23
	
	{24, promo_GR, 1}, -- steal sniper
	--30/24
	--31/25
	{25, promo_KC, 9}, -- secret shop, survive chapter
	{25, promo_HC, 9},
	{25, promo_OB, 9},
	{25, promo_EW, 9},
	{25, promo_GR, 9},
	
	--31x/26
	--32/27
	{27, promo_ES, 1}, -- nils start
	
	{28, promo_OS, 9}, -- secret shop @ end
	{28, promo_FC, 9}, 
	{28, promo_ES, 9}
	--32x/28
	--33/29
}

P.sevenHNM.promoItemCount = constructPIcount(P.sevenHNM.pIAcqTime, 29)

constructLatePFactor(P.sevenHNM, 7, 29)

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

return gameData