-------------------------------------------------------------------------------
--
-- timer.lua
--
-- Copyright (C) 2013 Corona Labs Inc. All Rights Reserved.
--
-------------------------------------------------------------------------------

-- NOTE: timer is assigned to the global var "timer" in init.lua.
-- This file should follos standard Lua module conventions
local timer = { _runlist = {} }

function timer.performWithDelay( delay, listener, iterations )
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

		timer._insert( timer, entry, fireTime )

	end

	return entry
end

-- returns (time left until fire), (number of iterations left)
function timer.cancel( entry )
	if type(entry) ~= "table" then
		error("timer.cancel(): invalid timer (expected a table but got a "..type(entry)..")", 2)
	end

	-- flag for removal from runlist
	entry._cancelled = true

	-- prevent from being resumed
	entry._expired = true

	local fireTime = entry._time
	local baseTime = entry._pauseTime
	if ( not baseTime ) then
		baseTime = system.getTimer()
	end
	
	return ( fireTime - baseTime ), ( entry._iterations or 0 ) + 1
end

function timer.pause( entry )
	local msg
	
	if type(entry) ~= "table" then
		error("timer.pause(): invalid timer (expected a table but got a "..type(entry)..")", 2)
	end

	if ( not entry._expired ) then
		if ( not entry._pauseTime ) then
			-- store pause time
			local pauseTime = system.getTimer()
			entry._pauseTime = pauseTime
			timer._remove( entry )

			-- return the time left
			return ( entry._time - pauseTime )
		else
			msg = "WARNING: timer.pause( timerId ) ignored because timerId is already paused."
		end
	else
		msg = "WARNING: timer.pause() cannot pause a timerId that is already expired."
	end

	print( msg )

	return 0
end

function timer.resume( entry )
	if type(entry) ~= "table" then
		error("timer.resume(): invalid timer (expected a table but got a "..type(entry)..")", 2)
	end

	if ( not entry._expired ) then
		if ( entry._pauseTime ) then
			local timeLeft = entry._time - entry._pauseTime
			local fireTime = system.getTimer() + timeLeft
			entry._time = fireTime
			entry._pauseTime = nil

			if ( entry._removed ) then
				timer._insert( timer, entry, fireTime )
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

						local fireTime = currentTime + entry._delay
						entry._time = fireTime
						timer._insert( timer, entry, fireTime )
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
	end
end

return timer
