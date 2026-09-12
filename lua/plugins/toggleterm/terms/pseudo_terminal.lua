local M = {}
local window = require("plugins.toggleterm.terms.window")

local function noop() end

local function project_dir()
	return require("plugins.toggleterm.terms.artifact_cwd").context_dir() or vim.fn.getcwd()
end

local function latest_artifact(dir)
	local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
	return artifact_cwd.latest_in(artifact_cwd.for_checkout(dir))
end

local function source_context(dir, invocation)
	local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
	local ctx = window.get_ctx(invocation)
	if ctx == nil then
		return
	end
	local path = vim.api.nvim_buf_get_name(ctx.bufnr)
	if path == "" or artifact_cwd.contains(path) or vim.fs.relpath(dir, path) == nil then
		return
	end
	return vim.tbl_extend("force", ctx, {
		path = vim.fs.relpath(dir, path) or path,
	})
end

---@param touch fun()
function M.create(touch)
	local artifact = {
		key = "artifact",
		display_name = "artifact",
		tag = "agent",
		restart = noop,
		start = noop,
		toggle_panel = noop,
	}
	local term = {}

	local function focus_artifact()
		local target = latest_artifact(project_dir())
		if target == nil then
			return
		end
		if target.bufnr ~= vim.api.nvim_get_current_buf() then
			vim.cmd.buffer(target.bufnr)
		end
		touch()
	end

	local function toggle_artifact()
		local current = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
		local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
		local from_artifact = artifact_cwd.contains(current)
		local dir = artifact_cwd.resolve(current) or assert(vim.uv.fs_realpath(vim.fn.getcwd()))

		if from_artifact then
			local target = require("my.project_file").find(dir, { require("my.parameters").dirs.artifacts })
			if target == nil then
				target = vim.fs.joinpath(dir, "README.md")
			end
			require("plugins.toggleterm.config").create(vim.fn.fnameescape(target))
			touch()
			return
		end

		local target_dir = artifact_cwd.for_checkout(dir)
		local target = artifact_cwd.latest_in(target_dir)
		if target then
			vim.cmd.buffer(target.bufnr)
		else
			vim.fn.mkdir(target_dir, "p")
			require("plugins.toggleterm.config").create(vim.fn.fnameescape(vim.fs.joinpath(target_dir, "index.md")))
		end
		touch()
	end

	local function send_to_artifact(str)
		local dir = project_dir()
		local target = latest_artifact(dir)
		if target == nil then
			return
		end
		if type(str) == "function" then
			local ctx = source_context(dir)
			if ctx == nil then
				return
			end
			str = str(ctx, artifact)
		end
		if type(str) ~= "string" then
			return
		end
		vim.fn.bufload(target.bufnr)
		local target_windows = vim.fn.win_findbuf(target.bufnr)
		local current_window = vim.api.nvim_get_current_win()
		local target_window = vim.api.nvim_win_get_buf(current_window) == target.bufnr and current_window or target_windows[1]
		local row, col
		if target_window then
			row, col = unpack(vim.api.nvim_win_get_cursor(target_window))
		else
			row, col = unpack(vim.api.nvim_buf_get_mark(target.bufnr, '"'))
		end
		row = math.max(row, 1)
		local line = vim.api.nvim_buf_get_lines(target.bufnr, row - 1, row, false)[1] or ""
		col = math.min(col, #line)
		vim.api.nvim_buf_set_text(target.bufnr, row - 1, col, row - 1, col, vim.split(str, "\n", { plain = true }))
		if target.bufnr ~= vim.api.nvim_get_current_buf() then
			vim.cmd.buffer(target.bufnr)
		end
		touch()
	end

	term.focus = function()
		focus_artifact()
	end
	term.toggle = function()
		toggle_artifact()
	end
	term.get_ctx = function(_, invocation)
		return source_context(project_dir(), invocation)
	end
	term.put = function(_, str)
		send_to_artifact(str)
	end
	artifact.term = term

	setmetatable(term, {
		__index = function()
			return function() end
		end,
	})

	return artifact
end

return M
