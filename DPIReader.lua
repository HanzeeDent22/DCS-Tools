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

function DPIReader.fillZeros(str, len, before)
    while string.len(str) < len do
        if before then
            str = tostring(0) .. str
        else
            str = str .. tostring(0)
        end
    end
    return str
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

    -- degrees dd/ddd
    local lat_d_floor = math.floor(lat)
    local long_d_floor = math.floor(long)

    -- minutes mm.mmm
    local lat_M = DPIReader.round((lat - lat_d_floor) * 60, 3)
    local long_M = DPIReader.round((long - long_d_floor) * 60, 3)

    -- minutes mm
    local lat_M_floor = math.floor(lat_M)
    local long_M_floor = math.floor(long_M)

    -- seconds ss.sss
    local lat_S = DPIReader.round((lat_M - lat_M_floor) * 60, 3)
    local long_S = DPIReader.round((long_M - long_M_floor) * 60, 3)

    -- seconds ss
    local lat_S_floor = math.floor(lat_S)
    local long_S_floor =  math.floor(long_S)

    
    
    -- tostring
    -- seconds 0.sss
    local lat_Sdec =  DPIReader.round( lat_S - lat_S_floor, 3)
    lat_Sdec = string.sub(tostring(lat_Sdec), 3)
    lat_Sdec = DPIReader.fillZeros(lat_Sdec, 3, false)

    local long_Sdec =  DPIReader.round( long_S - long_S_floor, 3)
    long_Sdec = string.sub(tostring(long_Sdec), 3)
    long_Sdec = DPIReader.fillZeros(long_Sdec, 3, false)
    
    -- seconds ss
    lat_S_floor = tostring(lat_S_floor)
    lat_S_floor = DPIReader.fillZeros(lat_S_floor, 2, true)

    long_S_floor = tostring(long_S_floor)
    long_S_floor = DPIReader.fillZeros(long_S_floor, 2, true)

    -- minutes 0.mmm
    local lat_Mdec = DPIReader.round( lat_M - lat_M_floor, 3)
    lat_Mdec = string.sub(tostring(lat_Mdec), 3)
    lat_Mdec = DPIReader.fillZeros(lat_Mdec, 3, false)

    local long_Mdec =  DPIReader.round( long_M - long_M_floor, 3)
    long_Mdec = string.sub(tostring(long_Mdec), 3)
    long_Mdec = DPIReader.fillZeros(long_Mdec, 3, false)

    -- minutes mm
    lat_M_floor = tostring(lat_M_floor)
    lat_M_floor = DPIReader.fillZeros(lat_M_floor, 2, true)

    long_M_floor = tostring(long_M_floor)
    long_M_floor = DPIReader.fillZeros(long_M_floor, 2, true)

    --degrees
    lat_d_floor = tostring(lat_d_floor)
    lat_d_floor = DPIReader.fillZeros(lat_d_floor, 2, true)

    long_d_floor = tostring(long_d_floor)
    long_d_floor = DPIReader.fillZeros(long_d_floor, 3, true)
    
    local decMstring = latDir .. lat_d_floor .. "°" .. lat_M_floor .. "." .. lat_Mdec .. "' " .. longDir .. long_d_floor .. "°" .. long_M_floor .. "." .. long_Mdec .. "' "
    local decSstring = latDir ..  lat_d_floor.. "°" .. lat_M_floor ..  "'" .. lat_S_floor .. "." .. lat_Sdec .. "\" " .. longDir ..  long_d_floor.. "°" .. long_M_floor ..  "'" .. long_S_floor .. "." .. long_Sdec .. "\" "

    return decMstring, decSstring
end

function DPIReader.MGRStoString(mgrs)
    mgrs.Easting = DPIReader.fillZeros(tostring(mgrs.Easting),5,true)
    mgrs.Northing = DPIReader.fillZeros(tostring(mgrs.Northing),5,true)
    local mgrs_line = mgrs.UTMZone .. " " .. mgrs.MGRSDigraph .. " " .. mgrs.Easting .. mgrs.Northing
    return mgrs_line
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
                local mgrs_line = DPIReader.MGRStoString(mgrs)

                trigger.action.markToAll(DPIReader.zoneNr,
                    searchName ..
                    " " .. elevation .. "ft" .. "\n" .. decMstring .. "\n" .. mgrs_line .. "\n" .. decSstring, zone
                    .point)
                DPIReader.zoneNr = DPIReader.zoneNr + 1

                textOutString = textOutString ..
                    searchName ..
                    " " ..
                    elevation .. "ft" .. "\n| " .. decMstring .. "\n| " .. mgrs_line .. "\n| " .. decSstring .. "\n"
                logString = logString ..
                    searchName ..
                    " " .. elevation .. "ft" .. " " .. decMstring .. " " .. mgrs_line .. " " .. decSstring .. "\n"
            end

            if not zone then
                zoneNameValid = false
                textOutString = textOutString .. "\n"
                logString = logString .. "\n"
            end
        end

        trigger.action.outText("DPIs logged in the DCS.log file in Saved Games\\DCS\\Logs: \n\n" .. textOutString, 10,
            true)
        env.info("\n" .. logString)
    end
end

DPIReader.record(names)
