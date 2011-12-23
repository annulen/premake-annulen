--
-- tests/base/test_action.lua
-- Automated test suite for the action list.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	T.action = { }


--
-- Setup/teardown
--

	local fake = {
		trigger = "fake",
		description = "Fake action used for testing",
	}
	local a = {
		trigger = "a",
		description = "Fake action used for testing",
		depends = { "fake" }
	}
	local b = {
		trigger = "b",
		description = "Fake action used for testing"
	}
	local c = {
		trigger = "c",
		description = "Fake action used for testing",
		depends = { "a" }
	}
	local d = {
		trigger = "d",
		description = "Fake action used for testing"
	}
	local e = {
		trigger = "e",
		description = "Fake action used for testing",
		depends = { "a", "b", "c", "d" }
	}

	local function triggers(chain)
		local out = {}
		for _, a in ipairs(chain) do
			out[#out + 1] = a.trigger
		end
		return out
	end

	
	function T.action.setup()
		premake.action.list["fake"] = fake
		premake.action.list["a"] = a
		premake.action.list["b"] = b
		solution "MySolution"
		configurations "Debug"
		project "MyProject"
		premake.bake.buildconfigs()
	end

	function T.action.teardown()
		premake.action.list["fake"] = nil
		premake.action.list["a"] = nil
		premake.action.list["b"] = nil
		a.depends = { "fake" }
		b.depends = nil
		fake.depends = nil
		premake.action.globaldepends = {}
	end



--
-- Tests for call()
--

	function T.action.CallCallsExecuteIfPresent()
		local called = false
		fake.execute = function () called = true end
		premake.action.call("fake")
		test.istrue(called)
	end

	function T.action.CallCallsOnSolutionIfPresent()
		local called = false
		fake.onsolution = function () called = true end
		premake.action.call("fake")
		test.istrue(called)
	end

	function T.action.CallCallsOnProjectIfPresent()
		local called = false
		fake.onproject = function () called = true end
		premake.action.call("fake")
		test.istrue(called)
	end
	
	function T.action.CallSkipsCallbacksIfNotPresent()
		test.success(premake.action.call, "fake")
	end


--
-- Tests for set()
--

	function T.action.set_SetsActionOS()
		local oldos = _OS
		_OS = "linux"
		premake.action.set("vs2008")
		test.isequal(_OS, "windows")
		_OS = oldos
	end

--
-- Test action dependencies
--

	function T.action.test_buildactionchain()
		local chain = premake.action.buildactionchain("fake")
		test.isequal(1, #chain)
		test.isequal("fake", chain[1].trigger)
	end

	function T.action.SimpleDepends()
		premake.action.list["a"] = a
		local chain = premake.action.buildactionchain("a")
		test.isequal({"fake", "a"}, triggers(chain))
	end

	function T.action.test_adddependency()
		premake.action.adddependency("b", "a")
		local chain = premake.action.buildactionchain("b")
		test.isequal({"fake", "a", "b"}, triggers(chain))
	end

	function T.action.CircularDependency()
		premake.action.adddependency("b", "a")
		premake.action.adddependency("a", "b")
		test.isfalse(premake.action.buildactionchain("b"))
	end

	function T.action.TopologicalSort()
		premake.action.list["c"] = c
		premake.action.list["d"] = d
		premake.action.list["e"] = e

		premake.action.adddependency("b", "c")
		premake.action.adddependency("b", "d")

		local chain = premake.action.buildactionchain("e")
		test.isequal({"fake", "a", "c", "d", "b", "e"},
			triggers(chain))

		premake.action.list["c"] = nil
		premake.action.list["d"] = nil
		premake.action.list["e"] = nil
	end

	function T.action.GlobalDepends()
		premake.action.adddependency("*", "b")
		local chain = premake.action.buildactionchain("a")
		test.isequal({"b", "fake", "a"}, triggers(chain))
	end

	function T.action.GlobalDepends2()
		premake.action.adddependency("*", "a")
		premake.action.adddependency("*", "fake")
		local chain = premake.action.buildactionchain("b")
		test.isequal({"fake", "a", "b"}, triggers(chain))
	end

	function T.action.MissingDependency()
		premake.action.adddependency("b", "foo")
		local chain = premake.action.buildactionchain("b")
		test.isequal({"b"}, triggers(chain))
	end

	function T.action.MissingGlobalDependency()
		premake.action.adddependency("*", "foo")
		local chain = premake.action.buildactionchain("b")
		test.isequal({"b"}, triggers(chain))
	end

