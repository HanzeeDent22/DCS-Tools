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
--
-- Example out put in dcs.log:
-- DPI-1 N35°7.363' E36°41.555' 984ft 37S BU 8974089089
-- DPI-2 N35°7.38' E36°41.754' 984ft 37S BU 9004489112
-- DPI-3 N35°7.404' E36°41.781' 984ft 37S BU 9008689157
-- DPI-4 N35°7.35' E36°41.86' 984ft 37S BU 9020389054
-- DPI-5 N35°7.358' E36°41.875' 984ft 37S BU 9022589068
-- DPI-6 N35°7.137' E36°41.671' 984ft 37S BU 8990688666
-- DPI-7 N35°7.117' E36°41.615' 984ft 37S BU 8982188631
-- DPI-8 N35°7.313' E36°42.203' 984ft 37S BU 9072388973
-- DPI-9 N35°7.309' E36°42.549' 984ft 37S BU 9124788953
-- DPI-10 N35°7.25' E36°42.785' 984ft 37S BU 9160388837

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

function DPIReader.LLtoDecMinString(lat, long)
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
    local lat_m = DPIReader.round((lat - lat_d) * 60, 3)


    local str_lat = latDir .. tostring(lat_d) .. "°" .. tostring(lat_m) .. "'"

    local long_d = math.floor(long)
    local long_m = DPIReader.round((long - long_d) * 60, 3)



    local str_long = longDir .. tostring(long_d) .. "°" .. tostring(long_m) .. "'"

    return str_lat, str_long
end

function DPIReader.record(names)
    local str = ""

    for _, name in pairs(names) do
        local number = 0
        local zoneNameValid = true

        while zoneNameValid do
            number = number + 1
            local searchName = name .. "-" .. tostring(number)
            local zone = trigger.misc.getZone(searchName)

            if zone then
                local latitude, longitude, altitude = coord.LOtoLL(zone.point)
                altitude = math.floor(DPIReader.mToft(land.getHeight({ x = zone.point.x, y = zone.point.z })))
                local latstr, longstr = DPIReader.LLtoDecMinString(latitude, longitude)
                local line = searchName .. " " .. latstr .. " " .. longstr .. " " .. altitude .. "ft"

                local mgrs = coord.LLtoMGRS(latitude, longitude)
                local mgrs_line = mgrs.UTMZone .. " " .. mgrs.MGRSDigraph .. " " .. mgrs.Easting .. mgrs.Northing

                trigger.action.markToAll(DPIReader.zoneNr, line .. "\n" .. mgrs_line, zone.point)
                DPIReader.zoneNr = DPIReader.zoneNr + 1

                str = str .. line .. " " .. mgrs_line .. "\n"
            end

            if not zone then
                zoneNameValid = false
                str = str .. "\n"
            end
        end

        trigger.action.outText("DPIs logged in the DCS.log file in Saved Games\\DCS\\Logs: \n\n" .. str, 10, true)
        env.info("\n\n" .. str )
    end
end

DPIReader.record(names)
