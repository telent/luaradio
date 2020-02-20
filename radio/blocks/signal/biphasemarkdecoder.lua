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
    self.bit1 = false
    self.bit0 = false
    self.skip = 0
    self.out = types.Bit.vector()
end

function BiphaseMarkDecoderBlock:process(x)
    local out = self.out:resize(0)
    for i = 0, x.length-1 do
        local v = x.data[i].value
        if not self.bit0 then
	     self.bit0 = v
	elseif not self.bit1 then
	     self.bit1 = v
	else
	     if self.bit0 ~= self.bit1 then -- valid encoding => transition 0->1
	         local outv = (self.bit1 == v) and 0 or 1
	         out:append(types.Bit(outv))
   	         self.bit0 = v
  	         self.bit1 = false
	     else
    	         self.bit0 = self.bit1
    	         self.bit1 = v
	     end
	end
    end
    return out
end

return BiphaseMarkDecoderBlock
