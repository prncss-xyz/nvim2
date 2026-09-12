return {
	generator = function(opts)
		local definitions = {}
		local agents = opts.agents or {}

		for index, agent in ipairs(agents) do
			if vim.fn.executable(agent) == 1 then
				local priority = #agents - index + 1
				table.insert(definitions, {
					name = agent,
					tags = { "agent" },
					builder = function()
						return {
							cmd = agent,
							priority = priority,
						}
					end,
				})
			end
		end

		return definitions
	end,
}
