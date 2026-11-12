local M = {}

local function helper(x)
  return x + 1
end

function M.compact(tbl)
  local out = {}
  for _, v in ipairs(tbl) do
    table.insert(out, helper(v))
  end
  return out
end

function M:method()
  return self
end

return M
