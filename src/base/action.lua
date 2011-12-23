--
-- action.lua
-- Work with the list of registered actions.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	premake.action = { }


--
-- The list of registered actions.
--

	premake.action.list = { }
	

	premake.action.globaldepends = { }

--
-- Register a new action.
--
-- @param a
--    The new action object.
-- 

	function premake.action.add(a)
		local required = { "trigger" }
		if not a.isinternal then
			required[#required + 1] = "description"
		end

		-- validate the action object, at least a little bit
		local missing
		for _, field in ipairs(required) do
			if (not a[field]) then
				missing = field
			end
		end

		if (missing) then
			error("action needs a " .. missing, 3)
		end

		-- add it to the master list
		premake.action.list[a.trigger] = a		
	end

	local function adddepends(chain, cur)
		if not chain[cur.trigger] then
			table.insert(chain, cur)
			chain[cur.trigger] = true
			for _, dep in ipairs(cur.depends or {}) do
				local depaction = premake.action.list[dep]
				if depaction then
					adddepends(chain, depaction)
				else
					print("Warning: cannot resolve action dependency \'" .. dep .. "\'")
				end
			end
		end
	end

	-- Depth-first search
	-- Vertex colors:
	--   nil - white (non-visited)
	--    1  - gray (visited)
	--    2  - black (completed)
	-- Returns true if cycle detected
	local function dfs(v, chain, stack)
		if v.dfs_color == 1 then
			return true
		end
		if v.dfs_color == 2 then
			return false
		end
		v.dfs_color = 1
		for i, act in ipairs(v.depends or {}) do
			local vertex = premake.action.get(act)
			if vertex and dfs(vertex, chain, stack) then
				return true
			end
		end
		table.insert(stack, v)
		v.dfs_color = 2
		return false
	end

	-- Returns false if cycle detected
	local function topological_sort(chain)
		local stack = {}
		for _, v in ipairs(chain) do
			v.dfs_color = nil
		end
		for _, v in ipairs(chain) do
			if dfs(v, chain, stack) then
				return false
			end
		end
		return stack
	end

	function premake.action.buildactionchain(name)
		local chain = {}
		local a = premake.action.list[name]
		if not a then
			return chain
		end

		-- a and its dependencies, recursively
		adddepends(chain, a)

		-- Then global dependencies
		for _, actname in ipairs(premake.action.globaldepends) do
			local act = premake.action.list[actname]
			if not act then
				print("Warning: cannot resolve global action dependency \'" .. actname .. "\'")
			elseif not chain[act.trigger] then
				table.insert(chain, act)
				chain[act.trigger] = true
			end
		end
		for _, act in ipairs(chain) do
			for _, actname in ipairs(premake.action.globaldepends) do
				if act.trigger ~= actname and
						(not table.contains(premake.action.globaldepends, act.trigger)) then
					act.depends = act.depends or {}
					table.insert(act.depends, actname)
				end
			end
		end

		return topological_sort(chain)
	end

--
-- Trigger an action.
--
-- @param name
--    The name of the action to be triggered.
-- @returns
--    None.
--

	function premake.action.call(name)
		printf("Running action '%s' ...", name)
		local a = premake.action.list[name]
		for sln in premake.solution.each() do
			if a.onsolution then
				a.onsolution(sln)
			end
			for prj in premake.solution.eachproject(sln) do
				if a.onproject then
					a.onproject(prj)
				end
			end
		end
		
		if a.execute then
			a.execute()
		end
	end


--
-- Retrieve the current action, as determined by _ACTION.
--
-- @return
--    The current action, or nil if _ACTION is nil or does not match any action.
--

	function premake.action.current()
		return premake.action.get(_ACTION)
	end
	
	
--
-- Retrieve an action by name.
--
-- @param name
--    The name of the action to retrieve.
-- @returns
--    The requested action, or nil if the action does not exist.
--

	function premake.action.get(name)
		return premake.action.list[name]
	end


--
-- Iterator for the list of actions.
--

	function premake.action.each()
		-- sort the list by trigger
		local keys = { }
		for _, action in pairs(premake.action.list) do
			table.insert(keys, action.trigger)
		end
		table.sort(keys)
		
		local i = 0
		return function()
			i = i + 1
			return premake.action.list[keys[i]]
		end
	end


--
-- Activates a particular action.
--
-- @param name
--    The name of the action to activate.
--

	function premake.action.set(name)
		_ACTION = name
		-- Some actions imply a particular operating system
		local action = premake.action.get(name)
		if action then
			_OS = action.os or _OS
		end
	end


--
-- Determines if an action supports a particular language or target type.
--
-- @param action
--    The action to test.
-- @param feature
--    The feature to check, either a programming language or a target type.
-- @returns
--    True if the feature is supported, false otherwise.
--

	function premake.action.supports(action, feature)
		if not action then
			return false
		end
		if action.valid_languages then
			if table.contains(action.valid_languages, feature) then
				return true
			end
		end
		if action.valid_kinds then
			if table.contains(action.valid_kinds, feature) then
				return true
			end
		end
		return false
	end

--
-- Adds a dependecy of action1 on action2
-- action1 needs to exist and be added when this function is called
-- If action1 is "*", all actions will depend on action2, including those added after
-- call of this function
--
-- @param action1
--     Name of dependent action
-- @param action2
--     Name of dependency
--
	function premake.action.adddependency(action1, action2)
		assert(action1 ~= action2, "Action cannot depend on itself")
		if action1 == "*" then
			table.insert(premake.action.globaldepends, action2)
		else
			local act = premake.action.get(action1) or error("Invalid action name", 2)
			act.depends = act.depends or {}
			if not table.contains(act.depends, action2) then
				table.insert(act.depends, action2)
			end
		end
	end

