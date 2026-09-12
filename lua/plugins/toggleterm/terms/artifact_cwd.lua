local M = {}

local parameters = require("my.parameters")
local dirs = parameters.dirs

local function is_directory(path)
	local stat = vim.uv.fs_stat(path)
	return stat ~= nil and stat.type == "directory"
end

local function project_name(project_dir)
	local project_path = assert(
		vim.fs.relpath(dirs.projects, vim.fs.abspath(project_dir)),
		"Project is outside projects directory"
	)
	return assert(vim.split(project_path, "/", { plain = true, trimempty = true })[1], "Project name not found")
end

local function branch_name(project_dir)
	local branch = vim.trim(vim.fn.system({ "git", "-C", project_dir, "branch", "--show-current" }))
	if vim.v.shell_error == 0 and branch ~= "" then
		return branch
	end
end

---@param paths table<string, boolean>
---@return table|nil
function M.latest_file(paths)
	local latest
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local path = vim.api.nvim_buf_get_name(bufnr)
		local info = vim.fn.getbufinfo(bufnr)[1]
		if paths[path] and (latest == nil or (info.lastused or 0) > latest.lastused) then
			latest = { bufnr = bufnr, path = path, lastused = info.lastused or 0 }
		end
	end
	return latest
end

---@param dir string
---@return table|nil
function M.latest_in(dir)
	local paths = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local path = vim.api.nvim_buf_get_name(bufnr)
		if path ~= "" and vim.fs.relpath(dir, vim.fs.abspath(path)) ~= nil then
			paths[path] = true
		end
	end
	return M.latest_file(paths)
end

---@param filename string
---@return boolean
function M.contains(filename)
	return vim.fs.relpath(dirs.artifacts, vim.fs.abspath(filename)) ~= nil
end

--- Resolve the project checkout for a file in the shared artifact directory.
--- Artifact paths are <project>/<branch>/....
--- Prefer an existing branch checkout, then main, then master, then <project>.
---@param filename string
---@return string|nil
function M.resolve(filename)
	local relative = vim.fs.relpath(dirs.artifacts, vim.fs.abspath(filename))
	if relative == nil then
		return nil
	end

	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local project = parts[1]
	if project == nil then
		return nil
	end

	local project_dir = vim.fs.joinpath(dirs.projects, project)
	local branch_dir = parts[2] and vim.fs.joinpath(project_dir, parts[2]) or nil
	if branch_dir and is_directory(branch_dir) then
		return branch_dir
	end

	for _, branch in ipairs(parameters.default_branches or { "main", "master" }) do
		local default_dir = vim.fs.joinpath(project_dir, branch)
		if is_directory(default_dir) then
			return default_dir
		end
	end
	if is_directory(project_dir) then
		return project_dir
	end
end

---@return string|nil
function M.context_dir()
	local dir = M.resolve(vim.api.nvim_buf_get_name(0))
	if dir then
		return dir
	end
	if vim.bo.buftype == "terminal" then
		local _, term = require("toggleterm.terminal").identify()
		return term and term.dir or nil
	end
end

--- Resolve the shared artifact directory for a project checkout.
--- Default branches and checkouts without an identifiable branch use the
--- project-level directory; other branches use a branch-specific directory.
---@param project_dir string
---@return string
function M.for_checkout(project_dir)
	local project = project_name(project_dir)
	local branch = branch_name(project_dir)
	if branch and not vim.tbl_contains(parameters.default_branches or { "main", "master" }, branch) then
		return vim.fs.joinpath(dirs.artifacts, project, (branch:gsub("/", "-")))
	end
	return vim.fs.joinpath(dirs.artifacts, project)
end

---@param project_dir string
---@return string
function M.for_project(project_dir)
	local project = project_name(project_dir)
	return vim.fs.joinpath(dirs.artifacts, project)
end

---@param path string
---@return string|nil
function M.project_file(path)
	local project_dir = M.resolve(path)
	if project_dir == nil then
		return nil
	end
	return require("my.project_file").find(project_dir)
end

return M
