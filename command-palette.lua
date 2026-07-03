local M = {}

local entries = {}

function M.reset()
  entries = {}
end

function M.add(entry)
  table.insert(entries, entry)
end

function M.entries()
  return entries
end

return M
