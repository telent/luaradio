---
-- Wait for a preamble 
--

local block = require('radio.core.block')
local types = require('radio.types')

local ReplaceBitsBlock = block.factory("ReplaceBitsBlock")

function ReplaceBitsBlock:instantiate(pattern, replacement)
    self.pattern = pattern
    self.replacement = replacement
    self.matched = {}

    self:add_type_signature({block.Input("in", types.Bit)}, {block.Output("out", types.Bit)})
end

function ReplaceBitsBlock:initialize()
    self.out = types.Bit.vector()
end


function ReplaceBitsBlock:process(x)
    print(x.length)
    local out = self.out:resize(0)
    for i = 0, x.length-1 do
    	v = x.data[i].value
        if #self.matched < #self.pattern then
	    table.insert(self.matched, v)
        elseif table.concat(self.matched) == table.concat(self.pattern)  then
--	    print("match! **", table.concat(self.matched))
	    for j = 1, #self.replacement do
	        out:append(types.Bit(self.replacement[j]))
	    end
            self.matched = {v}
	else
	    out:append(types.Bit(self.matched[1]))
	    self.matched = table.slice(self.matched, 2)
	    table.insert(self.matched, v) 
        end
    end
    return out
    -- FIXME there may also be data in self.matched that needs output
    -- but only at the end of processing, not at the end of each block
end

return ReplaceBitsBlock

