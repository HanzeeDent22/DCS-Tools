-- DPI Reader
--
-- Intended to quickly pull Desired Points of Impact (DPIs) from DCS into briefings and kneeboards by placing trigger zones in the ME.
-- You can then copy the DPIs from the log file or take screen shots of the user marks on the F10 map.
--
-- How to
-- 1. Script file. Add the name(s) for your trigger zones where marked below. You can use one or as many as you like.
-- 2. Mission editor. Create a trigger that executes this file after mission start. Best practice is to use a "Time More" condition with the "DO Script File" action. 
-- 3. Mission editor. Create a trigger zone with one of the zone names you added. Copy and paste zones to your DPI locations. DCS will add a "-" and number to the DPIs. The script ignores the initial zone without a number.
-- 4. Run the mission. A message will show when the script is executed.
-- 5. You can now see the marks on the F10 map. There is an option in the top bar to show the text of all marks.
-- 6. You can copy the DPIs from the dcs.log file in your saved games folder at Saved Games\DCS\Logs. You have to re-open the DCS.log file to see new logs after running the script again.
--
-- The elevation is always ground level. DCS might return incorrect MGRS grids for the script.


local names = { "DPI", "Data" } -- <<< add zone names here <<<


-- Dont touch from here

local DPIReader = {}
DPIReader.DPIs = {}
DPIReader.zoneNr = 1

-- https://stackoverflow.com/a/50082540
function DPIReader.round(number, decimals)
    local power = 10 ^ decimals
    return math.floor(number * power) / power
end

function DPIReader.mToft(m)
    local ft = m / 0.3048
    return ft
end

function DPIReader.LLtoString(lat, long)
    local latDir = "N"
    local longDir = "E"

    if lat < 0 then
        latDir = "S"
    end
    if long < 0 then
        longDir = "W"
    end

    if lat < 0 then
        lat = lat * -1
    end

    if long < 0 then
        long = long * -1
    end

    local lat_d = math.floor(lat)
    local long_d = math.floor(long)

    local lat_decM = DPIReader.round((lat - lat_d) * 60, 3)   
    local long_decM = DPIReader.round((long - long_d) * 60, 3)
  
    local decMstring = latDir .. tostring(lat_d) .. "°" .. tostring(lat_decM) .. "' " .. longDir .. tostring(long_d) .. "°" .. tostring(long_decM) .. "'"

    local lat_M = math.floor(lat_decM)
    local long_M = math.floor(long_decM)

    local lat_decS = DPIReader.round((lat_decM - lat_M) * 60, 3)  
    local long_decS = DPIReader.round((long_decM - long_M) * 60, 3)  

    local decSstring = latDir .. tostring(lat_d) .. "°" .. tostring(lat_M) .. "'" .. tostring(lat_decS) .. "\"" .. longDir .. tostring(long_d) .. "°" .. tostring(long_M) .. "'" .. tostring(long_decS) .. "\"" 

    return decMstring, decSstring
end

function DPIReader.record(names)
    local textOutString = ""
    local logString = ""
    for _, name in pairs(names) do
        local number = 0
        local zoneNameValid = true

        while zoneNameValid do
            number = number + 1
            local searchName = name .. "-" .. tostring(number)
            local zone = trigger.misc.getZone(searchName)

            if zone then
                local latitude, longitude, _ = coord.LOtoLL(zone.point)
                local elevation = math.floor(DPIReader.mToft(land.getHeight({ x = zone.point.x, y = zone.point.z })))
                local decMstring, decSstring = DPIReader.LLtoString(latitude, longitude)
                

                local mgrs = coord.LLtoMGRS(latitude, longitude)
                local mgrs_line = mgrs.UTMZone .. " " .. mgrs.MGRSDigraph .. " " .. mgrs.Easting .. mgrs.Northing

                trigger.action.markToAll(DPIReader.zoneNr, searchName .. " " .. elevation .. "ft" .. "\n" .. decMstring .. "\n" .. mgrs_line .. "\n" .. decSstring, zone.point)
                DPIReader.zoneNr = DPIReader.zoneNr + 1

                textOutString = textOutString .. searchName .. " " .. elevation .. "ft" .. "\n| " .. decMstring .. "\n| " .. mgrs_line .. "\n| " .. decSstring .. "\n"
                logString = logString .. searchName .. " " .. elevation .. "ft" .. " " .. decMstring .. " " .. mgrs_line .. " " .. decSstring .. "\n"
            end

            if not zone then
                zoneNameValid = false
                textOutString = textOutString .. "\n"
                logString = logString .. "\n"
            end
        end

        trigger.action.outText("DPIs logged in the DCS.log file in Saved Games\\DCS\\Logs: \n\n" .. textOutString, 10, true)
        env.info("\n" .. logString )
    end
end

DPIReader.record(names)

