local M = {}

function M.with_prompt(cb)
	return function(input, prompt)
		input(prompt, function(contents)
			cb(contents, prompt)
		end)
	end
end

function M.create_artifact(filename, remove)
	return function(input, prompt)
		local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
		local root = artifact_cwd.resolve(vim.api.nvim_buf_get_name(0)) or vim.fs.root(0, ".git") or vim.uv.cwd()
		input(prompt, function(contents, using_selection)
			if remove and using_selection then
				vim.cmd.normal({ 'gv"_d', bang = true })
			end
			require("plugins.toggleterm.harness").create_artifact(contents, filename, root)
		end)
	end
end

function M.create_task(remove)
	return function(input, prompt)
		local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
		local current = vim.api.nvim_buf_get_name(0)
		local root = artifact_cwd.resolve(current) or vim.fs.root(0, ".git") or vim.uv.cwd()
		input(prompt, function(contents, using_selection)
			if remove and using_selection then
				vim.cmd.normal({ 'gv"_d', bang = true })
			end
			local harness = require("plugins.toggleterm.harness")
			if artifact_cwd.contains(current) then
				harness.create_task(contents, current)
			else
				harness.create_artifact(contents, "index.md", root)
			end
		end)
	end
end

function M.sender(prefix)
	return M.with_prompt(function(contents, prompt)
		require("plugins.toggleterm.terms").put({ tag = "agent" }, (prefix or prompt) .. " " .. contents)
	end)
end

return M
