---
-- Decode a BiphaseMark encoded bit stream.
--

local block = require('radio.core.block')
local types = require('radio.types')

local BiphaseMarkDecoderBlock = block.factory("BiphaseMarkDecoderBlock")

function BiphaseMarkDecoderBlock:instantiate(invert)
    self.mark_token = (invert and 0 or 1 )
    self.space_token = 1 - self.mark_token

    self:add_type_signature({block.Input("in", types.Bit)}, {block.Output("out", types.Bit)})
end

function BiphaseMarkDecoderBlock:initialize()
    self.prev_value = 0
    self.out = types.Bit.vector()
end

function BiphaseMarkDecoderBlock:process(x)
    local out = self.out:resize(0)

    for i = 0, x.length-1, 2 do
        local bit1 = x.data[i]	
        local bit2 = x.data[i+1]

	if self.prev_value ~= bit1.value then
	    -- can't be biphase encoding if there was no transition on
	    -- even-numbered clock edge
	    if bit1.value == bit2.value then
		out:append(types.Bit(self.space_token))
	    else
		out:append(types.Bit(self.mark_token))
	    end
	end
	self.prev_value = bit2.value
    end

    return out
end

return BiphaseMarkDecoderBlock
