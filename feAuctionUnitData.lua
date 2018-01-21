local P = {}
unitData = P

local promo_NO = 0 -- can't promote
local promo_HC = 1 -- hero crest
local promo_KC = 2 -- knight crest
local promo_OB = 3 -- orion's bolt
local promo_EW = 4 -- elysian whip
local promo_GR = 5 -- guiding ring
local promo_FC = 6 -- fell contract
local promo_OS = 7 -- ocean seal
local promo_HS = 8 -- heaven seal

-- FE6 Normal Mode
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

-- FE7 Hector Normal Mode
P.sevenHNM = {
	-- chapter 11/0
	-- 12/1
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

return unitData