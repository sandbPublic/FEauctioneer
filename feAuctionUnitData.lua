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

-- Hector Normal Mode
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
	{"Lyn", 7, promo_HS}, -- can't really help during join chapter
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
	--25/18
	{"Farina", 18, promo_EW},
	--26/19
	{"Pent", 19, promo_NO},
	{"Louise", 19, promo_NO},
	--27/20
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