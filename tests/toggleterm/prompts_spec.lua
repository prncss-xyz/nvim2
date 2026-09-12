local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["selected prompts run outside the selector callback"] = function()
	child.lua([[local scheduled = {}
		local selector_callback
		local input_callback
		local artifact

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.config"] = {
			prompts = { idea = require("plugins.toggleterm.prompt_utils").create_artifact("idea.md") },
		}
		package.loaded["plugins.toggleterm.harness"] = {
			create_artifact = function(input, filename, root)
				artifact = { input, filename, root }
			end,
		}
		vim.ui.select = function(_, _, callback)
			selector_callback = callback
		end
		vim.ui.input = function(opts, callback)
			assert(type(opts.prompt) == "string", "input prompt must be a string")
			input_callback = callback
		end
		vim.schedule = function(callback)
			table.insert(scheduled, callback)
		end

		require("plugins.toggleterm.prompts").prompt()
		selector_callback("idea")
		assert(not input_callback, "prompt ran directly in the selector callback")
		assert(#scheduled == 1, "prompt was not scheduled")
		scheduled[1]()
		assert(input_callback, "scheduled prompt did not run")
		input_callback("captured idea")
		assert(vim.deep_equal(artifact, { "captured idea", "idea.md", vim.fn.getcwd() }), "prompt context was not used")
	]])
end

T["artifact prompts use the project of the current artifact"] = function()
	child.lua([[local artifact

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.terms.artifact_cwd"] = {
			resolve = function(path)
				assert(path == "/artifacts/neomux/topic/index.md")
				return "/projects/neomux/main"
			end,
		}
		package.loaded["plugins.toggleterm.harness"] = {
			create_artifact = function(input, filename, root)
				artifact = { input, filename, root }
			end,
		}
		vim.api.nvim_buf_set_name(0, "/artifacts/neomux/topic/index.md")

		local prompt = require("plugins.toggleterm.prompt_utils").create_artifact("idea.md")
		prompt(function(_, callback)
			callback("captured idea")
		end, "idea")
		result = artifact
	]])

	assert.same({ "captured idea", "idea.md", "/projects/neomux/main" }, child.lua_get("result"))
end

T["artifact prompts can remove their source selection"] = function()
	child.lua([[local deleted = false
		local artifact

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.harness"] = {
			create_artifact = function(input, filename, root)
				artifact = { input, filename, root }
			end,
		}
		vim.cmd.normal = function(command)
			assert(vim.deep_equal(command, { 'gv"_d', bang = true }))
			deleted = true
		end

		local prompt = require("plugins.toggleterm.prompt_utils").create_artifact("idea.md", true)
		prompt(function(_, callback)
			callback("selected text", true)
		end, "idea")
		result = { deleted = deleted, artifact = artifact }
	]])

	local result = child.lua_get("result")
	assert(result.deleted)
	assert.same("selected text", result.artifact[1])
	assert.same("idea.md", result.artifact[2])
end

T["artifact prompts keep typed input when removal is enabled"] = function()
	child.lua([[local deleted = false

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.harness"] = { create_artifact = function() end }
		vim.cmd.normal = function() deleted = true end

		local prompt = require("plugins.toggleterm.prompt_utils").create_artifact("idea.md", true)
		prompt(function(_, callback)
			callback("typed text")
		end, "idea")
		result = deleted
	]])

	assert(not child.lua_get("result"))
end

return T
