-- Clip the amplitudes in a real valued signal to be within lower and
-- upper limits
--

local block = require('radio.core.block')
local class = require('radio.core.class')
local types = require('radio.types')

local ClipBlock = block.factory("ClipBlock")

function ClipBlock:instantiate(lower, upper)
    self.lower = lower
    self.upper = upper
    self:add_type_signature({block.Input("in", types.Float32)}, {block.Output("out", types.Float32)})
end

function ClipBlock:initialize()
    self.out = self:get_output_type().vector()
end

function ClipBlock:process(x)
    local out = self.out:resize(x.length)
    local v
    for i = 0, x.length - 1 do
        v = x.data[i].value
        if v > self.upper then
	    v = self.upper
	elseif v < self.lower then
	    v = self.lower
	end
        out.data[i].value = v
    end

    return out
end

return ClipBlock
