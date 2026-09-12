local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["screen status events"] = MiniTest.new_set()

T["screen status events"]["notify only for unseen status transitions"] = function()
	child.lua([[local notifications = {}
		local send
		local visible = true
		local item = {
			key = "agent",
			display_name = "agent",
			dir = "/tmp",
		}

		package.loaded["plugins.toggleterm.terms.history"] = {
			create_history = function()
				return {
					insert = function() end,
					find = function() return nil end,
					purge = function() end,
					filter = function() return {} end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			new = function(_, _, callback)
				send = callback
				return {
					focus = function() end,
					is_in_view = function() return visible end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_status = function(instance)
				table.insert(notifications, instance.status)
			end,
		}
		package.loaded["plugins.toggleterm.terms.get_query_fn"] = {
			get_query_fn = function() return function() return true end end,
		}
		package.loaded["plugins.toggleterm.terms.utils"] = {
			compose_gt = function() return function() return false end end,
			gt_field = function() return function() return false end end,
			lt_field = function() return function() return false end end,
			max_of = function() return item end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function() return "agent" end end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").focus({})
		send({ type = "status", value = "working", visible = true })
		local visible_status = item.status
		send({ type = "status", value = "working", visible = false })
		visible = true
		send({ type = "status", value = "blocked", visible = false })
		send({ type = "status", value = "blocked", visible = false })
		visible = false
		send({ type = "status", value = "success", visible = false })
		send({ type = "status", value = "success", visible = false })

		result = {
			visible_status = visible_status,
			status = item.status,
			notifications = notifications,
		}
	]])

	assert.same({
		visible_status = "working",
		status = "success",
		notifications = { "success" },
	}, child.lua_get("result"))
end

T["put"] = MiniTest.new_set()

T["pseudo terminal"] = MiniTest.new_set()

T["pseudo terminal"]["toggles the artifact index without querying terminals"] = function()
	child.lua([[local toggled = 0
		package.loaded["my.parameters"] = {
			dirs = {
				projects = vim.fs.dirname(vim.fs.dirname(vim.fn.getcwd())),
				artifacts = vim.fn.tempname(),
			},
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			new = function() error("artifact must not create a terminal") end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_status = function() end,
			create = function() toggled = toggled + 1 end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() error("artifact must not query terminal commands") end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").toggle({ key = "artifact", dir = "/does/not/matter" })
		result = toggled
	]])

	assert.same(1, child.lua_get("result"))
end

T["pseudo terminal"]["focuses the latest artifact for the current project"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local project = vim.fs.joinpath(projects, "alpha", "main")
		local artifact = vim.fs.joinpath(artifacts, "alpha", "notes.md")
		local source = vim.fs.joinpath(project, "src.lua")
		vim.fn.mkdir(project, "p")
		vim.fn.mkdir(vim.fs.dirname(artifact), "p")
		vim.fn.writefile({ "source" }, source)
		vim.fn.writefile({ "artifact" }, artifact)

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.loaded["plugins.toggleterm.terms.create_term"] = { new = function() end }
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() error("artifact must not query terminal commands") end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		vim.o.hidden = true
		vim.cmd.cd(vim.fn.fnameescape(project))
		vim.cmd.edit(vim.fn.fnameescape(artifact))
		vim.cmd.edit(vim.fn.fnameescape(source))
		require("plugins.toggleterm.terms").focus({ key = "artifact" })
		result = { expected = artifact, actual = vim.api.nvim_buf_get_name(0) }
	]])

	local result = child.lua_get("result")
	assert.same(result.expected, result.actual)
end

T["pseudo terminal"]["inserts text at the artifact cursor"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local project = vim.fs.joinpath(projects, "alpha", "main")
		local artifact = vim.fs.joinpath(artifacts, "alpha", "notes.md")
		vim.fn.mkdir(project, "p")
		vim.fn.mkdir(vim.fs.dirname(artifact), "p")
		vim.fn.writefile({ "before after" }, artifact)

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.loaded["plugins.toggleterm.terms.create_term"] = { new = function() end }
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() error("artifact must not query terminal commands") end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		vim.o.hidden = true
		vim.cmd.cd(vim.fn.fnameescape(project))
		vim.cmd.edit(vim.fn.fnameescape(artifact))
		vim.api.nvim_win_set_cursor(0, { 1, 7 })
		require("plugins.toggleterm.terms").put({ key = "artifact" }, "inserted ")
		result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	]])

	assert.same({ "before inserted after" }, child.lua_get("result"))
end

T["pseudo terminal"]["participates in history only when explicitly included"] = function()
	child.lua([[local sent = {}
		local created = {}
		local events = {}
		package.loaded["plugins.toggleterm.terms.pseudo_terminal"] = {
			create = function(touch)
				local item = {
					key = "artifact",
					tag = "agent",
					restart = function() end,
					start = function() end,
				}
				local term = {
					focus = function()
						table.insert(sent, "artifact:focus")
						touch()
					end,
					put = function(_, str)
						table.insert(sent, "artifact:" .. str)
						touch()
					end,
				}
				item.term = term
				setmetatable(term, { __index = function() return function() end end })
				return item
			end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			new = function(_, item, callback)
				table.insert(created, item.instance_count)
				return {
					focus = function() callback({ type = "focus" }) end,
					put = function(_, str) table.insert(sent, "terminal:" .. str) end,
					is_in_view = function() return true end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return {} end,
		}
		package.loaded["my.ui_toggle"] = { activate = function(_, action) action() end }
		package.loaded["plugins.toggleterm.terms.panel"] = {
			toggle = function(_, _, subscribe)
				subscribe(function(event) table.insert(events, event.type) end)
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		terms.toggle_panel({})
		terms.focus({ key = "agent", dir = "/tmp" })
		terms.put({ artifact = true, dir = "/tmp" }, "latest-terminal")
		terms.focus({ key = "artifact" })
		terms.put({ artifact = true, dir = "/tmp" }, "latest-artifact")
		terms.put({ dir = "/tmp" }, "artifact-excluded")
		terms.focus({ instance_count = 1 })
		result = { sent = sent, created = created, events = events }
	]])

	assert.same({
		created = { 2 },
		events = { "create", "focus" },
		sent = {
			"terminal:latest-terminal",
			"artifact:focus",
			"artifact:latest-artifact",
			"terminal:artifact-excluded",
			"artifact:focus",
		},
	}, child.lua_get("result"))
end

T["put"]["leaves the terminal in insert mode"] = function()
	child.lua([[local sent
		local item = { key = "agent", dir = "/tmp" }
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			new = function()
				return {
					put = function(_, str, start_insert)
						sent = { str, start_insert }
					end,
					is_in_view = function() return true end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.get_query_fn"] = {
			get_query_fn = function() return function() return true end end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").put({ key = "agent", dir = "/tmp" }, "hello")
		result = sent
	]])

	assert.same({ "hello", true }, child.lua_get("result"))
end

T["put"]["formats the current project buffer for the latest artifact"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local project = vim.fs.joinpath(projects, "alpha", "main")
		local artifact = vim.fs.joinpath(artifacts, "alpha", "notes.md")
		local source = vim.fs.joinpath(project, "src.lua")
		vim.fn.mkdir(project, "p")
		vim.fn.mkdir(vim.fs.dirname(artifact), "p")
		vim.fn.writefile({ "source" }, source)
		vim.fn.writefile({ "artifact" }, artifact)

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.loaded["plugins.toggleterm.terms.create_term"] = { new = function() end }
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() error("artifact must not create a terminal") end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		vim.o.hidden = true
		vim.cmd.cd(vim.fn.fnameescape(project))
		vim.cmd.edit(vim.fn.fnameescape(artifact))
		vim.cmd.edit(vim.fn.fnameescape(source))
		terms.put({ key = "artifact" }, require("plugins.toggleterm.put.position").row)
		focused = vim.api.nvim_buf_get_name(0)
		expected = artifact
		vim.cmd.write()
		result = vim.fn.readfile(artifact)[1]
	]])

	assert.same("@src.lua:L1 artifact", child.lua_get("result"))
	assert.same(child.lua_get("expected"), child.lua_get("focused"))
end

T["put"]["uses the last project buffer from a terminal"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local project = vim.fs.joinpath(projects, "alpha", "main")
		local artifact = vim.fs.joinpath(artifacts, "alpha", "notes.md")
		local source = vim.fs.joinpath(project, "src.lua")
		vim.fn.mkdir(project, "p")
		vim.fn.mkdir(vim.fs.dirname(artifact), "p")
		vim.fn.writefile({ "source" }, source)
		vim.fn.writefile({ "artifact" }, artifact)

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.loaded["toggleterm.terminal"] = {
			identify = function() return nil, { dir = project } end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = { new = function() end }
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() error("artifact must not create a terminal") end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		vim.o.hidden = true
		vim.cmd.cd(vim.fn.fnameescape(project))
		vim.cmd.edit(vim.fn.fnameescape(artifact))
		vim.cmd.edit(vim.fn.fnameescape(source))
		vim.cmd.terminal()
		terms.put({ key = "artifact" }, require("plugins.toggleterm.put.position").row)
		focused = vim.api.nvim_buf_get_name(0)
		expected = artifact
		vim.cmd.write()
		result = vim.fn.readfile(artifact)[1]
	]])

	assert.same("@src.lua:L1 artifact", child.lua_get("result"))
	assert.same(child.lua_get("expected"), child.lua_get("focused"))
end

T["instance numbers"] = MiniTest.new_set()

T["instance numbers"]["are globally unique and reuse the smallest available number"] = function()
	child.lua([[local created = {}
		local callbacks = {}
		local focused = {}
		local notifications = {}
		vim.notify = function(message, level)
			table.insert(notifications, { message, level })
		end

		local key_by_cwd = {
			["/one"] = "shell",
			["/two"] = "agent",
			["/ignored"] = "ignored",
			["/three"] = "repl",
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			new = function(_, opts, callback)
				local key = key_by_cwd[opts.cwd]
				table.insert(created, { key = key, instance_count = opts.instance_count })
				callbacks[key] = callback
				return {
					focus = function() table.insert(focused, key) end,
					is_in_view = function() return false end,
					kill = function() end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_status = function() end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return {} end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		terms.focus({ key = "shell", dir = "/one" })
		terms.focus({ key = "agent", dir = "/two" })
		local next_query = { key = "ignored", dir = "/ignored" }
		vim.keymap.set("n", "<F5>", function()
			terms.focus(next_query)
		end)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("2<F5>5<F5>", true, false, true), "x", false)
		vim.wait(10)
		callbacks.shell({ type = "detach" })
		vim.wait(10)
		next_query = { key = "repl", dir = "/three" }
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<F5>", true, false, true), "x", false)
		vim.keymap.set("n", "<F6>", function()
			terms.start({ key = "shell", dir = "/one" })
		end)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("2<F6><F6>", true, false, true), "x", false)
		result = { created = created, focused = focused, notifications = notifications }
	]])

	assert.same({
		created = {
			{ key = "shell", instance_count = 2 },
			{ key = "agent", instance_count = 3 },
			{ key = "ignored", instance_count = 5 },
			{ key = "repl", instance_count = 2 },
			{ key = "shell", instance_count = 4 },
		},
		focused = { "shell", "agent", "shell", "ignored", "repl", "shell" },
		notifications = {
			{ "Terminal instance 2 already exists", vim.log.levels.ERROR },
		},
	}, child.lua_get("result"))
end

T["artifact cwd"] = MiniTest.new_set()

T["artifact cwd"]["resolves explicit and default branches without git"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		vim.fn.mkdir(vim.fs.joinpath(projects, "alpha", "feature"), "p")
		vim.fn.mkdir(vim.fs.joinpath(projects, "alpha", "main"), "p")
		vim.fn.mkdir(vim.fs.joinpath(projects, "beta"), "p")
		vim.fn.mkdir(vim.fs.joinpath(artifacts, "alpha", "feature"), "p")
		vim.fn.mkdir(vim.fs.joinpath(artifacts, "beta"), "p")

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		local resolve = require("plugins.toggleterm.terms.artifact_cwd").resolve
		result = {
			explicit = resolve(vim.fs.joinpath(artifacts, "alpha", "feature", "issue.md")),
			missing_branch = resolve(vim.fs.joinpath(artifacts, "alpha", "missing", "issue.md")),
			default_nested = resolve(vim.fs.joinpath(artifacts, "alpha", "issue.md")),
			default_flat = resolve(vim.fs.joinpath(artifacts, "beta", "issue.md")),
			missing_project = resolve(vim.fs.joinpath(artifacts, "missing", "issue.md")),
			outside = resolve(vim.fs.joinpath(root, "issue.md")),
		}
	]])

	local root = child.lua_get("root")
	assert.same({
		explicit = vim.fs.joinpath(root, "projects", "alpha", "feature"),
		missing_branch = vim.fs.joinpath(root, "projects", "alpha", "main"),
		default_nested = vim.fs.joinpath(root, "projects", "alpha", "main"),
		default_flat = vim.fs.joinpath(root, "projects", "beta"),
	}, child.lua_get("result"))
end

T["artifact cwd"]["maps a checkout to its project artifacts"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local checkout = vim.fs.joinpath(projects, "alpha", "main")

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		result = require("plugins.toggleterm.terms.artifact_cwd").for_project(checkout)
	]])

	local root = child.lua_get("root")
	assert.same(vim.fs.joinpath(root, "artifacts", "alpha"), child.lua_get("result"))
end

T["artifact cwd"]["maps feature checkouts to branch artifact paths"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local checkout = vim.fs.joinpath(projects, "alpha", "feature")
		vim.fn.mkdir(checkout, "p")
		vim.fn.system({ "git", "-C", checkout, "init", "-b", "feature/topic" })
		assert(vim.v.shell_error == 0)

		package.loaded["my.parameters"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main", "master" },
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		result = require("plugins.toggleterm.terms.artifact_cwd").for_checkout(checkout)
	]])

	local root = child.lua_get("root")
	assert.same(vim.fs.joinpath(root, "artifacts", "alpha", "feature-topic"), child.lua_get("result"))
end

T["artifact cwd"]["maps default and unidentified branches to project artifacts"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local default_checkout = vim.fs.joinpath(projects, "alpha", "main")
		local plain_checkout = vim.fs.joinpath(projects, "beta")
		vim.fn.mkdir(default_checkout, "p")
		vim.fn.mkdir(plain_checkout, "p")
		vim.fn.system({ "git", "-C", default_checkout, "init", "-b", "main" })
		assert(vim.v.shell_error == 0)

		package.loaded["my.parameters"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main", "master" },
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		local for_checkout = require("plugins.toggleterm.terms.artifact_cwd").for_checkout
		result = {
			default_branch = for_checkout(default_checkout),
			without_git = for_checkout(plain_checkout),
		}
	]])

	local root = child.lua_get("root")
	assert.same({
		default_branch = vim.fs.joinpath(root, "artifacts", "alpha"),
		without_git = vim.fs.joinpath(root, "artifacts", "beta"),
	}, child.lua_get("result"))
end

T["directory queries"] = MiniTest.new_set()

T["directory queries"]["matches HOME exactly"] = function()
	local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
	local filter = get_query_fn({ dir = vim.env.HOME })

	assert(filter({ dir = vim.env.HOME }))
	assert(not filter({ dir = vim.fs.joinpath(vim.env.HOME, "unrelated") }))
end

T["directory queries"]["matches descendants of other directories"] = function()
	local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
	local parent = vim.fs.joinpath(vim.env.HOME, "project")
	local filter = get_query_fn({ dir = parent })

	assert(filter({ dir = vim.fs.joinpath(parent, "worktree") }))
end

T["terminal panel integration"] = MiniTest.new_set()

T["terminal panel integration"]["forwards make_item lifecycle changes"] = function()
	child.lua([[local sent
		local listener
		local events = {}
		local item = {
			key = "agent",
			display_name = "agent",
			dir = "/tmp",
		}
		local stored = {}

		package.loaded["plugins.toggleterm.terms.history"] = {
			create_history = function()
				return {
					insert = function(value) stored = { value } end,
					find = function(cb) return vim.tbl_filter(cb, stored)[1] end,
					purge = function() stored = {} end,
					filter = function(cb) return vim.tbl_filter(cb, stored) end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			new = function(_, _, callback)
				sent = callback
				return {
					focus = function() callback({ type = "focus" }) end,
					is_in_view = function() return false end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			min_runtime = 0,
			on_status = function() end,
			panel = { width = 24 },
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function(value) return value.key end end,
		}
		package.loaded["plugins.toggleterm.terms.panel"] = {
			toggle = function(query, history, subscribe)
				listener = subscribe(function(event)
					table.insert(events, event.type)
				end)
				result_items = history.filter(require("plugins.toggleterm.terms.get_query_fn").get_query_fn(query))
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		terms.focus({ key = "agent" })
		terms.toggle_panel({ key = "agent", dir = require("plugins.toggleterm.terms.get_query_fn").any })
		sent({ type = "dir", value = "/project" })
		sent({ type = "status", value = "working" })
		sent({ type = "detach" })

		result = {
			dir = item.dir,
			item_count = #result_items,
			events = events,
		}
	]])

	assert.same({
		dir = "/project",
		item_count = 1,
		events = { "dir", "status", "detach" },
	}, child.lua_get("result"))
end

return T
