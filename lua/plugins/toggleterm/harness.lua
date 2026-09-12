local M = {}

local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
local config = require("plugins.toggleterm.config")

local function summary_prompt(input)
	return [==[
Your task is to describe the goal of the following prompt.
You must use at most 4 words. Only lowercase except for proper names. No punctuation.
Do not describe completion critaira.
Do not describe methodology or intermediate results.
Only describe the goal.

<task>
]==] .. input .. "</task>"
end

local function sanitize_branch(summary)
	local branch = summary:lower():gsub("[^%w._-]", "-")
	return branch:gsub("^-+", ""):gsub("-+$", "")
end

local function existing_branches(callback)
	vim.system({ "git", "branch", "-a" }, { text = true }, function(result)
		if result.code ~= 0 then
			callback({})
			return
		end

		local seen = {}
		for line in result.stdout:gmatch("[^\n]+") do
			local name = line:sub(3) -- strip leading 2-char marker ('* ', '  ')
			name = name:gsub("^remotes/[^/]+/", "") -- strip remotes/<remote>/
			if name ~= "" and not name:match(" -> ") then
				seen[name] = true
			end
		end
		callback(seen)
	end)
end

local function find_free_branch(branch, seen)
	if not seen[branch] then
		return branch
	end
	for n = 0, 999 do
		local candidate = string.format("%s-%03d", branch, n)
		if not seen[candidate] then
			return candidate
		end
	end
	return branch
end

local function branch_name(input, callback, root)
	root = root or vim.fs.root(0, ".git") or vim.uv.cwd()
	vim.notify("Naming branch...", vim.log.levels.INFO)
	local command = vim.split(config.ai_query, "%s+", { trimempty = true })
	vim.system(command, { cwd = root, text = true, stdin = summary_prompt(input) }, function(result)
		vim.schedule(function()
			assert(result.code == 0, result.stderr)
			local branch = sanitize_branch(result.stdout)
			assert(branch ~= "", "create-branch-name returned an empty name")
			existing_branches(vim.schedule_wrap(function(seen)
				callback(find_free_branch(branch, seen), root)
			end))
		end)
	end)
end

function M.create_artifact(input, filename, root)
	branch_name(input, function(branch, project_root)
		local artifact_root = artifact_cwd.for_project(project_root)
		local path = vim.fs.joinpath(artifact_root, branch, filename)
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile(vim.split(input, "\n", { plain = true }), path)
		vim.cmd.edit(vim.fn.fnameescape(path))
	end, root)
end

function M.artifact_to_worktree(branch, opts)
	vim.notify("Creating worktree " .. branch .. "...", vim.log.levels.INFO)
	require("plugins.toggleterm.terms.git").create_worktree(branch, function(_, worktree_path)
		opts.dir = worktree_path
		require("plugins.toggleterm.terms").focus(opts)
	end)
end

function M.input_to_worktree(input, prompt, opts)
	branch_name(input, function(branch)
		opts.cmd = opts.cmd .. prompt
		M.artifact_to_worktree(branch, opts)
	end)
end

local function pi_prompt(command)
	return function(file, dir)
		return {
			key = "pi",
			dir = dir,
			cmd = string.format("p /%s @%q", command, file),
		}
	end
end

local prompts = {
	plan = pi_prompt("implement"),
}

local function with_worktree(path)
	local project_dir = artifact_cwd.resolve(path)
	local artifact_root = project_dir and artifact_cwd.for_project(project_dir) or nil
	local relative_path = artifact_root and vim.fs.relpath(artifact_root, path) or nil
	if not relative_path then
		vim.notify("Current buffer is not inside the project's artifacts", vim.log.levels.ERROR)
		return
	end

	local branch, task = relative_path:match("^([^/]+)/([^/]+)%.md$")
	if not branch or not task then
		vim.notify("Artifact filename must match {artifacts}/{branch}/{task}.md", vim.log.levels.ERROR)
		return
	end
	local prompt = prompts[task]
	if not prompt then
		vim.notify("This task is not configured")
		return
	end

	local current_branch = vim.trim(vim.fn.system({ "git", "-C", project_dir, "branch", "--show-current" }))
	assert(vim.v.shell_error == 0 and current_branch ~= "", "Failed to determine current Git branch")

	local terms = require("plugins.toggleterm.terms")
	if branch == current_branch then
		terms.focus(prompt(path, project_dir))
		return
	end

	vim.notify("Creating worktree " .. branch .. "...", vim.log.levels.INFO)
	require("plugins.toggleterm.terms.git").create_worktree(branch, function(_, worktree_path)
		terms.focus(prompt(path, worktree_path))
	end)
end

function M.with_worktree()
	with_worktree(vim.api.nvim_buf_get_name(0))
end

function M.pick_with_worktree(include_dirty)
	local dirs = require("my.parameters").dirs
	local files = vim.fs.find(function(name, path)
		if not name:match("%.md$") then
			return false
		end
		local relative = vim.fs.relpath(dirs.artifacts, vim.fs.joinpath(path, name))
		if relative == nil then
			return false
		end
		local project, branch, task = relative:match("^([^/]+)/([^/]+)/([^/]+)%.md$")
		if task == nil or prompts[task] == nil then
			return false
		end
		return include_dirty or vim.fn.isdirectory(vim.fs.joinpath(dirs.projects, project, branch)) == 0
	end, { path = dirs.artifacts, type = "file", limit = math.huge })
	table.sort(files)

	vim.ui.select(files, {
		prompt = "Artifact Worktree",
		format_item = function(path)
			return assert(vim.fs.relpath(dirs.artifacts, path))
		end,
	}, function(path)
		if path then
			with_worktree(path)
		end
	end)
end

return M
