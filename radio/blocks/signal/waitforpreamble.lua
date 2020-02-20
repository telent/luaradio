---
-- Wait for a preamble 
--

local block = require('radio.core.block')
local types = require('radio.types')

function table.slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

local WaitForPreambleBlock = block.factory("WaitForPreambleBlock")

function WaitForPreambleBlock:instantiate(pattern)
    self.pattern = pattern
    self.matched = {}
    self.found = false
    self:add_type_signature({block.Input("in", types.Bit)}, {block.Output("out", types.Bit)})
end

function WaitForPreambleBlock:initialize()
    self.out = types.Bit.vector()
end

function WaitForPreambleBlock:process(x)
    local out = self.out:resize(0)
    for i = 0, x.length-1 do
        if self.found then
	    out:append(types.Bit(x.data[i].value))	
        elseif table.concat(self.matched) == table.concat(self.pattern)  then
	    self.found = true
	elseif self.pattern[1 + #self.matched] == x.data[i].value then
	    table.insert(self.matched, x.data[i].value)
	else
	    self.matched = table.slice(self.matched, 2)
        end
    end
    return out
end

return WaitForPreambleBlock
