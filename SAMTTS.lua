--- DEPENDS ON: DCS-SimpleTextToSpeech.lua
--- @author: dMARLAN
--- @version: 1.0
--- @date: 2022-11-08

SAMTTS = {}
local DEBUG = true

local samNames = {}
function SAMTTS.addSAM(name, callsign)
    samNames[name] = callsign
end

local warningControlCallsign = {}
function SAMTTS.setWarningControlCallsign(pCoalition, callsign)
    if (pCoalition == "RED") then
        pCoalition = coalition.side.RED
    else
        pCoalition = coalition.side.BLUE
    end
    warningControlCallsign[pCoalition] = callsign
end

local coalitionParams = {}
function SAMTTS.setCoalitionParams(pCoalition, freqs, freqMod, gender, locale, voice, googleTTS)
    if (pCoalition == "RED") then
        pCoalition = coalition.side.RED
    else
        pCoalition = coalition.side.BLUE
    end
    freqs = freqs or "251"
    freqMod = freqMod or "AM"
    gender = gender or "male"
    locale = locale or "en-US"
    voice = voice or "Microsoft Richard Desktop"
    googleTTS = googleTTS or false
    coalitionParams[pCoalition] = { freqs = freqs, freqMods = freqMod, locale = locale, voice = voice, googleTTS = googleTTS }
end

local function isASpecifiedSAM(samToCheck)
    if (not samToCheck) then
        return false
    end
    local samNameToCheck = Unit.getGroup(samToCheck):getName()
    for samName, _ in pairs(samNames) do
        if (samNameToCheck == samName) then
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
    return bearingString
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

local function buildSamMessage(samCallsign, bullseye, impact)
    local msg = {}
    msg[#msg + 1] = samCallsign
    msg[#msg + 1] = ", BIRDS AWAY, TARGETED, " .. bullseye .. impact
    return table.concat(msg)
end

local function buildPilotDownMessage(wcCallsign, pilotCallsign, bullseye)
    local msg = {}
    msg[#msg + 1] = wcCallsign
    msg[#msg + 1] = ", RIGHT GUARD, RIGHT GUARD, " .. pilotCallsign
    msg[#msg + 1] = ", IS DOWN, " .. bullseye
    return table.concat(msg)
end

local function playMessage(message, srsCallsign, initiatorPoint, groupCoalition)
    if (DEBUG) then
        trigger.action.outText("DEBUG: " .. message, 10)
    end
    STTS.TextToSpeech(message,
            coalitionParams[groupCoalition]["freqs"],
            coalitionParams[groupCoalition]["freqMods"],
            "1.0",
            srsCallsign,
            groupCoalition,
            initiatorPoint,
            1,
            coalitionParams[groupCoalition]["gender"],
            coalitionParams[groupCoalition]["locale"],
            coalitionParams[groupCoalition]["voice"],
            coalitionParams[groupCoalition]["googleTTS"]
    )
end

local messagePlaying = {}
local function messagePlayingFalse(groupCoalition)
    messagePlaying[groupCoalition] = false
end

local engagedTargets = {}
local function resetEngagedTarget(target)
    engagedTargets[target:getName()] = false
end

local messages = {}
messages[1] = {}
messages[2] = {}
local function checkMessagesToSend(groupCoalition)
    if (#messages[groupCoalition] == 0) or messagePlaying[groupCoalition] then
        return
    end
    -- setup
    messagePlaying[groupCoalition] = true
    local speechTime = STTS.getSpeechTime(messages[groupCoalition][1]["message"], 1, true)

    playMessage(messages[groupCoalition][1]["message"],
            messages[groupCoalition][1]["srsCallsign"],
            messages[groupCoalition][1]["initiatorPoint"],
            messages[groupCoalition][1]["groupCoalition"]
    )

    -- teardown
    table.remove(messages[groupCoalition], 1)
    timer.scheduleFunction(messagePlayingFalse, groupCoalition, timer.getTime() + speechTime)
    timer.scheduleFunction(checkMessagesToSend, groupCoalition, timer.getTime() + speechTime)
end

local shotHandler = {}
function shotHandler:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT and event.weapon:getTarget() and isASpecifiedSAM(event.initiator) then
        local target = event.weapon:getTarget()
        local iPoint = event.initiator:getPoint()
        local iCallsign = samNames[Unit.getGroup(event.initiator):getName()]
        local iCoalition = event.initiator:getCoalition()
        local tBullseye = getBullseye(target, iCoalition)
        local impact = getImpact(event.initiator, target)
        local message = buildSamMessage(iCallsign, tBullseye, impact)

        if (engagedTargets[target:getName()] == nil or engagedTargets[target:getName()] == false) then
            engagedTargets[target:getName()] = true
            table.insert(messages[iCoalition], { message = message, srsCallsign = iCallsign, initiatorPoint = iPoint, groupCoalition = iCoalition })
            checkMessagesToSend(iCoalition)
            timer.scheduleFunction(resetEngagedTarget, target, timer.getTime() + timeToImpact(target:getPoint(), target:getVelocity(), event.initiator:getPoint(), 1000) + 20)
        end
    end
end

local function callsignNumberFix(callsign)
    return callsign:sub(1, -3) .. " " .. callsign:sub(-2,-2) .. " " .. callsign:sub(-1,-1)
end

local pilotDownHandler = {}
function pilotDownHandler:onEvent(event)
    if event.id == world.event.S_EVENT_EJECTION or event.id == world.event.S_EVENT_PILOT_DEAD then
        local iCallsign = callsignNumberFix(event.initiator:getCallsign())
        local iCoalition = event.initiator:getCoalition()
        local iBullseye = getBullseye(event.initiator, iCoalition)
        local message = buildPilotDownMessage(warningControlCallsign[iCoalition], iCallsign, iBullseye)

        table.insert(messages[iCoalition], { message = message, srsCallsign = iCallsign, nil, groupCoalition = iCoalition })
        checkMessagesToSend(iCoalition)
    end
end

local function main()
    world.addEventHandler(shotHandler)
    world.addEventHandler(pilotDownHandler)
end
main()
