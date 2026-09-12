local function target_path(source_path, file)
	if file == "" or not vim.startswith(vim.fs.normalize(file), vim.fs.normalize(source_path) .. "/") then
		return nil
	end

	local result = vim.system({ "chezmoi", "target-path", file }, { cwd = source_path, text = true }):wait()
	if result.code ~= 0 then
		return nil
	end

	local target = vim.trim(result.stdout or "")
	return target ~= "" and target or nil
end

return {
	generator = function(opts)
		if vim.fn.executable("chezmoi") == 0 then
			return nil
		end

		local source_path = vim.trim(vim.fn.system("chezmoi source-path"))
		if opts.dir ~= source_path then
			return nil
		end

		local definitions = {
			{
				name = "chezmoi",
				builder = function()
					return { cmd = { "chezmoi", "apply" }, cwd = source_path }
				end,
			},
		}

		local target = target_path(source_path, opts.file)
		if target then
			for _, value in ipairs({ "add", "diff", "destroy" }) do
				local command = value
				table.insert(definitions, {
					name = "chezmoi " .. command,
					builder = function()
						return { cmd = { "chezmoi", command, target }, cwd = source_path }
					end,
				})
			end
		end

		return definitions
	end,
}
