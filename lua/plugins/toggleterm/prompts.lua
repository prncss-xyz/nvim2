local M = {}
local config = require("plugins.toggleterm.config")

local function input_for_current_mode()
	local mode = vim.fn.mode()
	local selection
	if mode:match("[vV\22]") then
		selection = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
		if vim.trim(selection) == "" then
			selection = nil
		end
	end

	return function(prompt, continuation)
		if selection then
			continuation(selection, true)
			return
		end
		vim.ui.input({ prompt = prompt }, function(input)
			if input ~= nil and vim.trim(input) ~= "" then
				continuation(input)
			end
		end)
	end
end

function M.prompt()
	local input = input_for_current_mode()
	local choices = vim.tbl_keys(config.prompts)
	vim.ui.select(choices, {
		prompt = "Select prompt: ",
	}, function(choice)
		if not choice then
			return
		end
		local contents = config.prompts[choice]
		if not contents then
			return
		end
		vim.schedule(function()
			if type(contents) == "string" then
				return require("plugins.toggleterm.terms").put({ tag = "agent" }, contents)
			end
			contents(input, choice)
		end)
	end)
end

return M
