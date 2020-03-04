-------------------------------------------------------------------------------
--
-- Corona Labs
--
-- timer.lua
--
-- Code is MIT licensed; see https://www.coronalabs.com/links/code/license
--
-------------------------------------------------------------------------------

-- NOTE: timer is assigned to the global var "timer" on startup.
-- This file should follow standard Lua module conventions
local timer = {
	_runlist = {},
	_pausedTimers = {},
	allowIterationsWithinFrame = false,
}

-- Parameters are: [tag,] delay, listener, iterations.
function timer.performWithDelay( ... )
	local tag, delay, listener, iterations
	local args = {...}
	-- Check whether optional parameter, tag, was included or not.
	if "string" == type(args[1]) then
		tag, delay, listener, iterations = args[1], args[2], args[3], args[4]
	else
		tag, delay, listener, iterations = "", args[1], args[2], args[3]
	end

	local entry
	local t = type(listener)
	if "function" == t or ( "table" == t and "function" == type( listener.timer ) ) then
		-- faster to access a local timer var than a global one
		local timer = timer

		local fireTime = system.getTimer() + delay

		entry = { _listener = listener, _time = fireTime }

		if nil ~= iterations and type(iterations) == "number" then
			-- pre-subtract out one iteration, so for an initial value of...
			--   ...1, it's a no-op b/c we always fire at least once
			--   ...0, it become -1 which we will interpret as forever
			iterations = iterations - 1
			if iterations ~= 0 then
				entry._delay = delay
				entry._iterations = iterations
			end
		end

		entry._count = 1
		entry._tag = tag
		entry._inFrameIterations = timer.allowIterationsWithinFrame

		timer._insert( timer, entry, fireTime )

	end

	return entry
end

-- returns (time left until fire), (number of iterations left)
function timer.cancel( whatToCancel )
	local t = type(whatToCancel)
	if nil ~= whatToCancel and ("string" ~= t and "table" ~= t) then
		error("timer.cancel(): invalid timerId or tag (table or string expected, got "..t..")", 2)
	end

	-- Cancel a specific timerId.
	if "table" == t then
		-- flag for removal from runlist
		whatToCancel._cancelled = true

		-- prevent from being resumed
		whatToCancel._expired = true

		local fireTime = whatToCancel._time
		local baseTime = whatToCancel._pauseTime
		if ( not baseTime ) then
			baseTime = system.getTimer()
		end

		return ( fireTime - baseTime ), ( whatToCancel._iterations or 0 ) + 1
	else-- Cancel all timers or all timers with a specific tag if whatToCancel is a string.
	   	local runlist = timer._runlist
	   	local isTag = ("string" == t)

	   	for i,v in ipairs( runlist ) do
	   		if (not isTag or whatToCancel == v._tag) then
				-- flag for removal from runlist
				v._cancelled = true
				-- prevent from being resumed
				v._expired = true
	   		end
	   	end
	   	-- No times remaining will be returned if all timers or all timers with a specific tag are cancelled.
	end
end

function timer.pause( whatToPause )
	local t, msg = type(whatToPause)

	-- Pause a specific timerId.
	if "table" == t then
		if ( not whatToPause._expired ) then
			if ( not whatToPause._pauseTime ) then
				-- store pause time
				local pauseTime = system.getTimer()
				whatToPause._pauseTime = pauseTime
				timer._remove( whatToPause )

				-- return the time left
				return ( whatToPause._time - pauseTime )
			else
				msg = "WARNING: timer.pause( timerId ) ignored because timerId is already paused."
			end
		else
			msg = "WARNING: timer.pause( timerId ) cannot pause a timerId that is already expired."
		end

		print( msg )
		return 0
	else -- Pause all timers or all timers with a specific tag if whatToPause is a string.
		local runlist, pausedTimers = timer._runlist, timer._pausedTimers
		local isTag = ("string" == t)
		local index = #pausedTimers + 1

		-- Create a list of references for all timers that are to be paused using this way.
		for i,v in ipairs( runlist ) do
			if (not isTag or whatToPause == v._tag) and not v._expired and not v._pauseTime then
				v._pauseTime = system.getTimer()
				pausedTimers[#pausedTimers+1] = v
			end
		end
		for i = index, #pausedTimers do
			timer._remove( pausedTimers[i] )
		end
		-- No times remaining will be returned if all timers or all timers with a specific tag are paused.
	end
end

function timer.resume( whatToResume )
	local t = type(whatToResume)
	if nil ~= whatToResume and ("string" ~= t and "table" ~= t) then
		error("timer.resume(): invalid timerId or tag (table or string expected, got "..t..")", 2)
	end

	-- Resume a specific timerId.
	if "table" == t then
		if ( not whatToResume._expired ) then
			if ( whatToResume._pauseTime ) then
				local timeLeft = whatToResume._time - whatToResume._pauseTime
				local fireTime = system.getTimer() + timeLeft
				whatToResume._time = fireTime
				whatToResume._pauseTime = nil

				if ( whatToResume._removed ) then
					timer._insert( timer, whatToResume, fireTime )
				end

				-- return the time left
				return timeLeft
			else
				msg = "WARNING: timer.resume( timerId ) ignored because timerId was not paused."
			end
		else
			msg = "WARNING: timer.resume() cannot resume a timerId that is already expired."
		end

		print( msg )
		return 0
	else -- Resume all timers or all timers with a specific tag if whatToResume is a string.
	   	local runlist, pausedTimers = timer._runlist, timer._pausedTimers
	   	local isTag = ("string" == t)

	   	for i = #timer._pausedTimers, 1, -1 do
			local v = pausedTimers[i]
	   		if (not isTag or whatToResume == v._tag) and not v._expired and v._pauseTime then
				local timeLeft = v._time - v._pauseTime
				local fireTime = system.getTimer() + timeLeft
				v._time = fireTime
				v._pauseTime = nil

				if ( v._removed ) then
					timer._insert( timer, v, fireTime )
				end
				table.remove( pausedTimers, i )
	   		end
	   	end
	   	-- No times remaining will be returned if all timers or all timers with a specific tag are resumed.
	end
end

function timer._updateNextTime()
	local runlist = timer._runlist

	if #runlist > 0 then
		if timer._nextTime == nil then
			Runtime:addEventListener( "enterFrame", timer )
		end
		timer._nextTime = runlist[#runlist]._time
	else
		timer._nextTime = nil
		Runtime:removeEventListener( "enterFrame", timer )
	end
end

function timer._insert( timer, entry, fireTime )
	local runlist = timer._runlist

	-- sort in decreasing fireTime
	local index = #runlist + 1
	for i,v in ipairs( runlist ) do
		if v._time < fireTime then
			index = i
			break
		end
	end
	table.insert( runlist, index, entry )
	entry._removed = nil

	--print( "inserting entry firing at: "..fireTime.." at index: "..index )

	-- last element is the always the next to fire
	-- cache its fire time
	timer._updateNextTime()
end

function timer._remove( entry )
	local runlist = timer._runlist

	-- If no entry is provided, we pop the soonest-expiring one off.
	if ( entry == nil ) then
		entry = runlist[#runlist]
	end

	for i,v in ipairs( runlist ) do
		if v == entry then
			entry._removed = true
			table.remove( runlist, i )
			break
		end
	end

	timer._updateNextTime()

	return entry
end

function timer:enterFrame( event )
	-- faster to access a local timer var than a global one
	local timer = timer

	local runlist = timer._runlist

	-- If the listener throws an error and the runlist was empty, then we may
	-- not have cleaned up properly. So check that we have a non-empty runlist.
	if #runlist > 0 then
		local currentTime = event.time
		local timerEvent = { name="timer", time=currentTime }

		--print( "T(cur,fire) = "..currentTime..","..timer._nextTime )
		-- fire all expired timers
		local toInsert = {}
		while currentTime >= timer._nextTime do
			local entry = timer._remove()

			-- we cannot modify the runlist array, so we use _cancelled and _pauseTime
			-- flags to ensure that listeners are not called.
			if not entry._expired and not entry._cancelled and not entry._pauseTime then
				local iterations = entry._iterations

				timerEvent.source = entry
				local count = entry._count
				if count then
					timerEvent.count = count
					entry._count = count + 1
				end

				local listener = entry._listener
				if type( listener ) == "function" then
					listener( timerEvent )
				else
					-- must be a table b/c we only add when type is table or function
					local method = listener.timer
					method( listener, timerEvent )
				end

				if iterations then
					if iterations == 0 then
						entry._iterations = nil
						entry._delay = nil

						-- We need to expire the entry here if we don't want the extra trigger [Alex]
						iterations = nil
						entry._expired = true
					else
						if iterations > 0 then
							entry._iterations = iterations - 1
						end

						local fireTime = entry._time + entry._delay
						entry._time = fireTime
						if entry._inFrameIterations then
							timer._insert( timer, entry, fireTime )
						else
							toInsert[#toInsert+1] = {timer, entry, fireTime}
						end
					end
				else
					-- mark timer entry so we know it's finished
					entry._expired = true
				end
			end

			if ( timer._nextTime == nil ) then
				break;
			end
		end
		for i,v in ipairs(toInsert) do
			timer._insert(unpack(v))
		end
	end
end

return timer
