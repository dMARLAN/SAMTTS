--- @author: dMARLAN
--- @version: 1.4.1
--- @date: 2022-11-12
--- DEPENDENCY: DCS-SimpleTextToSpeech.lua by CiriBob -- https://github.com/ciribob/DCS-SimpleTextToSpeech

SAMTTS = {}
SAMTTS.googleTTS = false
SAMTTS.debug = false

local function selectRandomVoice()
    local voices = {
        "en-US-Standard-A",
        "en-US-Standard-B",
        "en-US-Standard-H",
        "en-US-Standard-I",
        "en-US-Standard-J",
        "en-US-Wavenet-G",
        "en-US-Wavenet-H",
        "en-US-Wavenet-I",
        "en-US-Wavenet-J",
        "en-US-Wavenet-B",
        "en-US-Wavenet-E",
        "en-US-Wavenet-F",
        "en-AU-Wavenet-B",
        "en-AU-Wavenet-C",
        "en-AU-Wavenet-D",
        "en-GB-Standard-B",
        "en-GB-Standard-F",
        "en-GB-Wavenet-B",
        "en-IN-Wavenet-B",
        "en-IN-Wavenet-C"
    }
    return voices[math.random(1, #voices)]
end

local function parseCoalitionString(string)
    if (string == "RED") then
        return coalition.side.RED
    else
        return coalition.side.BLUE
    end
end

local speaker = {}
speaker[coalition.side.RED] = {}
speaker[coalition.side.BLUE] = {}
function SAMTTS.addSAM(unitName, callsign, pCoalition, freqs, modulation)
    if not (Unit.getByName(unitName)) then
        return
    end
    pCoalition = parseCoalitionString(pCoalition)
    speaker[pCoalition][unitName] = { unitName = unitName, callsign = callsign, voice = selectRandomVoice(), freqs = freqs, modulation = modulation }
end

local coalitionWarningController = {}
function SAMTTS.addWarningController(unitName, callsign, pCoalition, freqs, modulation)
    pCoalition = parseCoalitionString(pCoalition)
    coalitionWarningController[pCoalition] = { unitName = unitName, callsign = callsign }
    speaker[pCoalition][unitName] = { unitName = unitName, callsign = callsign, voice = selectRandomVoice(), freqs = freqs, modulation = modulation }
end

local function isASpecifiedSAM(samToCheck, pCoalition)
    local samNameToCheck = Unit.getGroup(samToCheck):getName()
    for unitName, _ in pairs(speaker[pCoalition]) do
        if (samNameToCheck == speaker[pCoalition][unitName]["unitName"]) then
            return true
        end
    end
    return false
end

local function getDistanceFromTwoPoints(p1, p2)
    return math.sqrt(math.pow(p2.x - p1.x, 2) + math.pow(p2.z - p1.z, 2))
end

local function bearingToSingleDigits(bearing)
    local bearingString = ""
    if (bearing < 100) then
        bearingString = bearingString .. "ZERO "
    end
    if (bearing < 10) then
        bearingString = bearingString .. "ZERO ZERO "
    end
    for i = 1, string.len(bearing) do
        if (string.sub(bearing, i, i) == "0") then
            bearingString = bearingString .. "ZERO "
        else
            bearingString = bearingString .. string.sub(bearing, i, i) .. " "
        end
    end
    return bearingString:sub(1, -2)
end

local function getBearingFromTwoPoints(p1, p2)
    local p1Lat, p1Lon, _ = coord.LOtoLL(p1)
    local p2Lat, p2Lon, _ = coord.LOtoLL(p2)
    local lat1 = math.rad(p1Lat)
    local lon1 = math.rad(p1Lon)
    local lat2 = math.rad(p2Lat)
    local lon2 = math.rad(p2Lon)

    local dLon = lon2 - lon1
    local y = math.sin(dLon) * math.cos(lat2)
    local x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon)
    return (math.deg(math.atan2(y, x)) + 360) % 360
end

local function getMagneticDeclination()
    local theatre = env.mission.theatre
    if theatre == "Caucasus" then
        return 6
    end
    if theatre == "Nevada" then
        return 12
    end
    if theatre == "Normandy" or theatre == "TheChannel" then
        return -10
    end
    if theatre == "PersianGulf" then
        return 2
    end
    if theatre == "Syria" then
        return 5
    end
    if theatre == "MarianaIslands" then
        return 2
    end
    return 0
end

local function getBullseye(unit, groupCoalition)
    local bullsLO = coalition.getMainRefPoint(groupCoalition)
    local distanceNm = math.floor(getDistanceFromTwoPoints(bullsLO, unit:getPoint()) / 1852)

    if (distanceNm < 5) then
        return ", AT BULLSEYE.."
    end

    local bearing = (math.floor(getBearingFromTwoPoints(bullsLO, unit:getPoint()) - getMagneticDeclination() * 2) + 360) % 360
    local bearingString = bearingToSingleDigits(bearing)

    return "BULLSEYE, " .. bearingString .. ", " .. distanceNm .. ","
end

local function dot(b, c)
    return b.x * c.x + b.y * c.y
end

local function magnitude(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

local function angleBetween(b, c)
    return math.acos(dot(b, c) / (magnitude(b) * magnitude(c)))
end

local function vecMinus(a, b)
    return { x = a.x - b.x, y = a.z - b.z }
end

local function timeToImpact(targetPos, targetVel, interceptorPos, interceptorSpeed)
    targetVel = { x = targetVel.x, y = targetVel.z }
    local k = magnitude(targetVel) / interceptorSpeed
    local distanceToTarget = magnitude(vecMinus(interceptorPos, targetPos))

    local bHat = targetVel
    local cHat = vecMinus(interceptorPos, targetPos)

    local CAB = angleBetween(bHat, cHat)
    local ABC = math.asin(k * math.sin(CAB))
    local ACB = math.pi - CAB - ABC

    local j = distanceToTarget / math.sin(ACB)
    local b = j * math.sin(ABC)

    local timeToGo = b / magnitude(targetVel)
    -- local impactPoint = targetPos + (targetVel * timeToImpact)

    return timeToGo + 10
end

local function timeToEnglish(time)
    time = math.floor(time)
    if (time < 60) then
        return "ZERO PLUS " .. time
    end
    if (time > 60 and time < 120) then
        return "ONE PLUS " .. (time - 60)
    end
    if (time > 120 and time < 180) then
        return "TWO PLUS " .. (time - 120)
    end
    if (time > 180 and time < 240) then
        return "THREE PLUS " .. (time - 180)
    end
    return time
end

local function getImpact(interceptor, target)
    return " IMPACT, " .. timeToEnglish(timeToImpact(target:getPoint(), target:getVelocity(), interceptor:getPoint(), 1000))
end

local function callsignNumberFix(callsign)
    return callsign:sub(1, -3):upper() .. " " .. callsign:sub(-2, -2) .. " " .. callsign:sub(-1, -1)
end

local engagedTargets = {}
local function resetEngagedTarget(target)
    engagedTargets[target:getName()] = false
end

local liftedGroups = {}
local function resetLiftedGroup(group)
    liftedGroups[group:getName()] = false
end

local messagePlaying = {}
messagePlaying[coalition.side.BLUE] = false
messagePlaying[coalition.side.RED] = false
local function messagePlayingFalse(groupCoalition)
    messagePlaying[groupCoalition] = false
end

local function oppositeCoalition(pCoalition)
    if (pCoalition == coalition.side.BLUE) then
        return coalition.side.RED
    else
        return coalition.side.BLUE
    end
end

local function playMessage(message, unitName, callsign, initiatorPoint, pCoalition)
    if (SAMTTS.debug) then
        trigger.action.outText("DEBUG: " .. message, 20)
        trigger.action.outText("DEBUG: " .. speaker[pCoalition][unitName]["voice"], 20)
    end
    if (SAMTTS.googleTTS) then
        STTS.TextToSpeech(
                message,
                speaker[pCoalition][unitName]["freqs"],
                speaker[pCoalition][unitName]["modulation"],
                "1.0",
                callsign,
                pCoalition,
                initiatorPoint,
                1,
                "male",
                "en-US",
                speaker[pCoalition][unitName]["voice"],
                true
        )
    else
        STTS.TextToSpeech(
                message,
                speaker[pCoalition][unitName]["freqs"],
                speaker[pCoalition][unitName]["modulation"],
                "1.0",
                callsign,
                pCoalition
        )
    end
end

local messages = {}
messages[coalition.side.BLUE] = {}
messages[coalition.side.RED] = {}
local function checkMessagesToSend(groupCoalition)
    if (#messages[groupCoalition] == 0) or messagePlaying[groupCoalition] then
        return
    end

    -- setup
    messagePlaying[groupCoalition] = true

    playMessage(
            messages[groupCoalition][1]["message"],
            messages[groupCoalition][1]["unitName"],
            messages[groupCoalition][1]["callsign"],
            messages[groupCoalition][1]["initiatorPoint"],
            messages[groupCoalition][1]["groupCoalition"]
    )

    -- teardown
    local speechTime = STTS.getSpeechTime(messages[groupCoalition][1]["message"], 1, true)
    table.remove(messages[groupCoalition], 1)
    timer.scheduleFunction(messagePlayingFalse, groupCoalition, timer.getTime() + speechTime)
    timer.scheduleFunction(checkMessagesToSend, groupCoalition, timer.getTime() + speechTime)
end

local function addMessageToQueue(params)
    table.insert(messages[params["pCoalition"]], { message = params["message"], unitName = params["unitName"], callsign = params["callsign"], params["initiatorPoint"], groupCoalition = params["pCoalition"] })
    checkMessagesToSend(params["pCoalition"])
end

local function buildSamMessage(samCallsign, bullseye, impact)
    local msg = {}
    msg[#msg + 1] = samCallsign
    msg[#msg + 1] = ", BIRDS AWAY, TARGETED, " .. bullseye .. impact
    return table.concat(msg)
end

local function buildPilotDownMessage(wcCallsign, pilotCallsign, bullseye, ejected)
    if (ejected == true) then
        ejected = ", EJECTED, "
    else
        ejected = ", IS DOWN, LAST KNOWN "
    end
    local msg = {}
    msg[#msg + 1] = wcCallsign
    msg[#msg + 1] = ", RIGHT GUARD, " .. pilotCallsign
    msg[#msg + 1] = ejected .. bullseye
    return table.concat(msg)
end

local function buildLiftingMessage(wcCallsign, airbaseName, bullseye, size)
    if (size == 1) then
        size = "SINGLE"
    elseif (size > 2) then
        size = "HEAVY " .. size
    end
    local msg = {}
    msg[#msg + 1] = wcCallsign
    msg[#msg + 1] = ", GROUP LIFTING AT " .. airbaseName
    msg[#msg + 1] = ", " .. bullseye .. " "
    msg[#msg + 1] = size .. " CONTACTS"
    return table.concat(msg)
end

local shotHandler = {}
function shotHandler:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT and event.weapon:getTarget() and isASpecifiedSAM(event.initiator, event.initiator:getCoalition()) and speaker[event.initiator:getCoalition()][event.initiator:getGroup():getName()] ~= nil then
        local target = event.weapon:getTarget()
        local iPoint = event.initiator:getPoint()
        local iCoalition = event.initiator:getCoalition()
        local iCallsign = speaker[iCoalition][event.initiator:getGroup():getName()]["callsign"]
        local tBullseye = getBullseye(target, iCoalition)
        local impact = getImpact(event.initiator, target)
        local message = buildSamMessage(iCallsign, tBullseye, impact)

        if (engagedTargets[target:getName()] == nil or engagedTargets[target:getName()] == false) then
            engagedTargets[target:getName()] = true
            table.insert(messages[iCoalition], { message = message, unitName = event.initiator:getGroup():getName(), callsign = iCallsign, initiatorPoint = iPoint, groupCoalition = iCoalition })
            checkMessagesToSend(iCoalition)
            timer.scheduleFunction(resetEngagedTarget, target, timer.getTime() + timeToImpact(target:getPoint(), target:getVelocity(), iPoint, 1000) + 20)
        end
    end
end

local pilotDownHandler = {}
function pilotDownHandler:onEvent(event)
    if (event.id == world.event.S_EVENT_EJECTION or event.id == world.event.S_EVENT_PILOT_DEAD) and coalitionWarningController[event.initiator:getCoalition()] ~= nil then
        local pilotCallsign = callsignNumberFix(event.initiator:getCallsign())
        local iCoalition = event.initiator:getCoalition()
        local wcCallsign = coalitionWarningController[iCoalition]["callsign"]
        local iBullseye = getBullseye(event.initiator, iCoalition)

        local delay = 1
        local ejected = false
        if (event.id == world.event.S_EVENT_EJECTION) then
            delay = 10
            ejected = true
        else
            delay = 30
        end

        local message = buildPilotDownMessage(wcCallsign, pilotCallsign, iBullseye, ejected)

        local params = {
            message = message,
            unitName = coalitionWarningController[iCoalition]["unitName"],
            callsign = wcCallsign,
            initiatorPoint = nil,
            pCoalition = iCoalition
        }
        timer.scheduleFunction(addMessageToQueue, params, timer.getTime() + delay)
    end
end

local liftingHandler = {}
function liftingHandler:onEvent(event)
    if event.id == world.event.S_EVENT_TAKEOFF and coalitionWarningController[oppositeCoalition(event.initiator:getCoalition())] ~= nil then
        local liftedGroup = event.initiator:getGroup()
        local oppositeICoalition = oppositeCoalition(event.initiator:getCoalition())
        local wcCallsign = coalitionWarningController[oppositeICoalition]["callsign"]
        local pName = event.place:getName()
        local pBullseye = getBullseye(event.place, oppositeICoalition)
        local message = buildLiftingMessage(wcCallsign, pName, pBullseye, liftedGroup:getSize())

        if (liftedGroups[liftedGroup:getName()] == nil or liftedGroups[liftedGroup:getName()] == false) then
            liftedGroups[liftedGroup:getName()] = true
            local params = {
                message = message,
                unitName = coalitionWarningController[oppositeICoalition]["unitName"],
                callsign = wcCallsign,
                initiatorPoint = event.place:getPoint(),
                pCoalition = oppositeICoalition
            }
            timer.scheduleFunction(addMessageToQueue, params, timer.getTime() + 20)
            timer.scheduleFunction(resetLiftedGroup, liftedGroup, timer.getTime() + 300)
        end
    end
end

local function main()
    world.addEventHandler(shotHandler)
    world.addEventHandler(pilotDownHandler)
    world.addEventHandler(liftingHandler)
end
main()
