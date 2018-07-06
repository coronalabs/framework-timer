-------------------------------------------------------------------------------
-- Code is MIT licensed; see https://www.coronalabs.com/links/code/license
-- File: main.lua
-- 
-- Change the package.path and make it so we can require the "timer.lua" file from the root directory
-------------------------------------------------------------------------------

local path = package.path

-- get index of first semicolon
local i = string.find( path, ';', 1, true )
if ( i > 0 ) then
	-- first path (before semicolon) is project dir
	local projDir = string.sub( path, 1, i )

	-- assume dir is parent to projDir
	local dir = string.gsub( projDir, '(.*)/([^/]?/\?\.lua)', '%1/../%2' )
	package.path = dir .. path
end

-- Nil out anything loaded from the core so we use the local versions of the files.
timer = nil
package.loaded.timer = nil
package.preload.timer = nil

-------------------------------------------------------------------------------

local isPause = false
local timerNew = require("timer")

local buttonrect = display.newRect(1,1,display.contentWidth,display.contentHeight)
buttonrect:setFillColor(255,0,0)
local executions = 0
local timer1 = timerNew.performWithDelay(1000, function() executions = executions + 1; print ("executed", executions) end,2)

function touchHandler (event)
	if (event.phase == "began") then
		if (isPause) then
			timerNew.resume(timer1)
		else
			timerNew.pause(timer1)
		end
		isPause = not isPause
	end
end


buttonrect:addEventListener("touch", touchHandler)