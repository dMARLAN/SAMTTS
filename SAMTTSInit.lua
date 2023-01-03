
SAMTTS.googleTTS = true
SAMTTS.debug = true

local freqs = "257,251,255,262,259,268"
local modulation = "AM,AM,AM,AM,AM,AM"

SAMTTS.addSAM("CSGAD-N", "KILO", "BLUE", freqs, modulation)
SAMTTS.addSAM("CSGAD-S", "LIMA", "BLUE", freqs, modulation)
SAMTTS.addSAM("BLUE-SAM Patriot (Papa)-1", "PAPA", "BLUE", freqs, modulation)
SAMTTS.addSAM("BLUE-SAM NASAMS Hatay (Hotel)-1", "HOTEL", "BLUE", freqs, modulation)
SAMTTS.addSAM("BLUE-SAM Patriot (Charlie)-1", "CHARLIE", "BLUE", freqs, modulation)

SAMTTS.addWarningController("DSEA1", "DEEP SEA", "BLUE", freqs, modulation)
