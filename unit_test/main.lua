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
local timer1 = timerNew.performWithDelay( 1000, function() executions1 = executions1 + 1; print ("timer1, tag=\"red\",  executed", executions1) end, 2, "red" )
local timer2 = timerNew.performWithDelay( 1500, function() executions2 = executions2 + 1; print ("timer2, tag=\"blue\", executed", executions2) end, 2, "blue" )

local buttonSize = display.contentWidth/5-8
local buttonX =  display.contentWidth/5
local buttonY =  display.contentCenterY
local button = {}

local function touchHandler( event )
	if event.phase == "began" then
		local target = event.target
		local id = target.id
		
		local whichTimer
		if id == "timer1" or id == "timer2" then
			whichTimer = id == "timer1" and timer1 or timer2
		else
			whichTimer = id
		end
		
		if whichTimer == "all" then
			if target.isResume then
				timerNew.resumeAll()
			elseif target.isPause then
				timerNew.pauseAll()
			else
				timerNew.cancelAll()
			end
		else		
			if target.isResume then
				timerNew.resume( whichTimer )
			elseif target.isPause then
				timerNew.pause( whichTimer )
			else
				timerNew.cancel( whichTimer )
			end
		end
	end
	return true
end

local n = 1
local function createButtons( tag, colors )
	button[tag] = {}
	button[tag].isPaused = false
	
	button[tag].resume = display.newRect( buttonX*(n-0.5), buttonY, buttonSize, buttonSize )
	button[tag].resume:setFillColor( unpack( colors ) )
	button[tag].resume.isResume = true
	button[tag].resume.id = tag
	button[tag].resume:addEventListener("touch", touchHandler)
	button[tag].startLabel = display.newText( "resume", button[tag].resume.x, button[tag].resume.y, native.systemFont, 28 )
	
	button[tag].pause = display.newRect( buttonX*(n-0.5), buttonY + buttonX, buttonSize, buttonSize )
	button[tag].pause:setFillColor( unpack( colors ) )
	button[tag].pause.isPause = true
	button[tag].pause.id = tag
	button[tag].pause:addEventListener("touch", touchHandler)
	button[tag].stopLabel = display.newText( "pause", button[tag].pause.x, button[tag].pause.y, native.systemFont, 28 )
	
	button[tag].cancel = display.newRect( buttonX*(n-0.5), button[tag].pause.y + buttonX, buttonSize, buttonSize )
	button[tag].cancel:setFillColor( unpack( colors ) )
	button[tag].cancel.id = tag
	button[tag].cancel:addEventListener("touch", touchHandler)
	button[tag].stopLabel = display.newText( "cancel", button[tag].cancel.x, button[tag].cancel.y, native.systemFont, 28 )
	
	local label = tag
	if tag == "red" or tag == "blue" then
		label = "tag: \"" .. label .. "\""
	end
	button[tag].label = display.newText( label, button[tag].resume.x, button[tag].resume.y - buttonSize, native.systemFont, 28 )
	button[tag].label.rotation = -15
	n = n+1
end

createButtons( "timer1", {0.25} )
createButtons( "timer2", {0.4} )
createButtons( "red", {0.9, 0, 0} )
createButtons( "blue", {0, 0, 0.9} )
createButtons( "all", {0.3, 0, 0.5} )