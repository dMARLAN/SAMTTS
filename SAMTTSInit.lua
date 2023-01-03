
SAMTTS.googleTTS = true
SAMTTS.debug = true

local freqs = "257,251,255,262,259,268"
local modulation = "AM, AM, AM, AM, AM, AM"

SAMTTS.addSAM("CSGAD NORTH (Kilo)", "KILO", "BLUE", freqs, modulation)
SAMTTS.addSAM("CSGAD SOUTH (Lima)", "LIMA", "BLUE", freqs, modulation)
SAMTTS.addSAM("BLUE-SAM Patriot (Papa)", "PAPA", "BLUE", freqs, modulation)
SAMTTS.addSAM("BLUE-SAM NASAMS Hatay (Hotel)", "HOTEL", "BLUE", freqs, modulation)
SAMTTS.addSAM("BLUE-SAM Patriot (Charlie)", "CHARLIE", "BLUE", freqs, modulation)

SAMTTS.addWarningController("DSEA1", "DEEP SEA", "BLUE", freqs, modulation)
