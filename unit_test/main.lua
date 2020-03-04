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

local timerNew = require("timer")

local executions1, executions2 = 0, 0
local timer1 = timerNew.performWithDelay( "red", 1000, function() executions1 = executions1 + 1; print ("timer1, tag=\"red\",  executed", executions1) end,2)
local timer2 = timerNew.performWithDelay( "blue", 1000, function() executions2 = executions2 + 1; print ("timer2, tag=\"blue\", executed", executions2) end,2)


local buttonSize = display.contentWidth/3

local buttonRed = display.newRect( display.contentCenterX-buttonSize, display.contentCenterY, buttonSize, buttonSize )
buttonRed:setFillColor( 0.9, 0, 0 )
buttonRed.id = "red"
buttonRed.isPaused = false
local labelRed = display.newText( "tag: \"red\"", buttonRed.x, buttonRed.y, native.systemFont, 40 )

local buttonBlue = display.newRect( display.contentCenterX, display.contentCenterY, buttonSize, buttonSize )
buttonBlue:setFillColor( 0, 0, 0.9 )
buttonBlue.id = "blue"
buttonBlue.isPaused = false
local labelBlue = display.newText( "tag: \"blue\"", buttonBlue.x, buttonBlue.y, native.systemFont, 40 )

-- Purple, as in both red and blue.
local buttonPurple = display.newRect( display.contentCenterX+buttonSize, display.contentCenterY, buttonSize, buttonSize )
buttonPurple:setFillColor( 0.3, 0, 0.5 )
buttonPurple.id = "all"
buttonPurple.isPaused = false
local labelPurple = display.newText( "all", buttonPurple.x, buttonPurple.y, native.systemFont, 40 )

local buttonTimer1 = display.newRect( display.contentCenterX-buttonSize*0.5, display.contentCenterY+buttonSize, buttonSize, buttonSize )
buttonTimer1:setFillColor( 0.25 )
buttonTimer1.id = "timer1"
buttonTimer1.timer = timer1
buttonTimer1.isPaused = false
local labelTimer1 = display.newText( "timer1", buttonTimer1.x, buttonTimer1.y, native.systemFont, 40 )

local buttonTimer2 = display.newRect( display.contentCenterX+buttonSize*0.5, display.contentCenterY+buttonSize, buttonSize, buttonSize )
buttonTimer2:setFillColor( 0.4 )
buttonTimer2.id = "timer2"
buttonTimer2.timer = timer2
buttonTimer2.isPaused = false
local labelTimer2 = display.newText( "timer2", buttonTimer2.x, buttonTimer2.y, native.systemFont, 40 )


function touchHandler (event)
	if (event.phase == "began") then
		local target
		if event.target.id == "timer1" or event.target.id == "timer2" then
			target = event.target.timer
		elseif event.target.id ~= "all" then
			target = event.target.id
		end

		--[[
			Due to the nature of how the buttons are programmed in this unit test, it isn't possible to, for instance,
			pause tag: "red" and then press "all" to resume them because .isPaused state is button specific. So, first
			tap of "all" would try to pause all timers, then second tap would resume them, etc.
		]]
		if (event.target.isPaused) then
			timerNew.resume(target)
		else
			timerNew.pause(target)
		end

		-- Lazy conditional statement to manage the buttons' pause states.
		if event.target.id == "timer1" or event.target.id == "red" then
			buttonRed.isPaused = not buttonRed.isPaused
			buttonTimer1.isPaused = not buttonTimer1.isPaused
		elseif event.target.id == "timer2" or event.target.id == "blue" then
			buttonBlue.isPaused = not buttonBlue.isPaused
			buttonTimer2.isPaused = not buttonTimer2.isPaused
		else
			buttonRed.isPaused = not buttonRed.isPaused
			buttonBlue.isPaused = not buttonBlue.isPaused
			buttonPurple.isPaused = not buttonPurple.isPaused
			buttonTimer1.isPaused = not buttonTimer1.isPaused
			buttonTimer2.isPaused = not buttonTimer2.isPaused
		end
	end
end

buttonRed:addEventListener("touch", touchHandler)
buttonBlue:addEventListener("touch", touchHandler)
buttonPurple:addEventListener("touch", touchHandler)
buttonTimer1:addEventListener("touch", touchHandler)
buttonTimer2:addEventListener("touch", touchHandler)
