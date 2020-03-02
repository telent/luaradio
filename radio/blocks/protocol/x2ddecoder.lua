local ffi = require('ffi')
local bit = require('bit')

local block = require('radio.core.block')
local debug = require('radio.core.debug')
local types = require('radio.types')

-- X2D Related Constants

local X2D_PREAMBLE = { 0,0,0,0 };
local X2D_FRAME_START = { 1,1,1, 1,1,1, 0 };
local X2D_FRAME_END = { 1,1,1, 1,1,1,1, 1,0 };

local X2DFramerState = {
    SEARCHING = 1,
    IN_FRAME_START = 3,
    IN_FRAME_BODY = 4,
    IN_FRAME_END = 5,
}

-- X2D Frame Type

local X2DFrameType = types.ObjectType.factory()

function sum(table)
    local s = 0
    for i = 1, #table do
        s = s + table[i]
    end
    return s
end

function X2DFrameType.new(payload)
    local self = setmetatable({}, X2DFrameType)
    local pl = (table.concat(payload)):gsub("111110", "11111")
    local bytes = {}
    for i = 1, #pl-1, 8 do
        local b=0
        for j = 7 , 0, -1 do
	    b = b*2 + (pl:byte(i+j) - 48)
	end
        table.insert(bytes, b)
    end
    local h = bytes[#bytes-1]
    local l = bytes[#bytes]
    self.payload = table.slice(bytes, 1, #bytes - 2)
    local expectedChecksum = (h*256) + l
    local actualChecksum = bit.bxor(sum(self.payload) - 1, 0xffff)
    self.checksum = { actual = actualChecksum, expected = expectedChecksum }
    self.isValid = (actualChecksum == expectedChecksum)
    return self
end

-- X2D Decoder Block

local X2DDecoderBlock = block.factory("X2DDecoderBlock")

X2DDecoderBlock.X2DFrameType = X2DFrameType

function X2DDecoderBlock:instantiate()
    self:add_type_signature({block.Input("in", types.Bit)}, {block.Output("out", X2DFrameType)})
end

function table_append(a,b)
    for i = 1, #b do
        table.insert(a, b[i])
    end
end    

function table_matches(a,b)
    return table.concat(a) == table.concat(b)
end

function set_state(self, state)
    self.state = state
    self.candidate = {}
    if state == X2DFramerState.SEARCHING then
        local pat = {}
	table_append(pat, X2D_PREAMBLE)
	table_append(pat, X2D_FRAME_START)
        self.pattern = pat
    elseif state == X2DFramerState.IN_FRAME_START then
        self.pattern = X2D_FRAME_START
    elseif state == X2DFramerState.IN_FRAME_BODY then
        self.payload = {}
        self.pattern = X2D_FRAME_END
    end
    return self
end
    
function X2DDecoderBlock:initialize()
    set_state(self, X2DFramerState.SEARCHING)

    self.out = X2DFrameType.vector()
end

function X2DDecoderBlock:process(x)
    local out = self.out:resize(0)
    local i = 0
    while i < x.length do
        v = x.data[i].value
	if self.state == X2DFramerState.SEARCHING then
            if #self.candidate < #self.pattern then
   	        table.insert(self.candidate, v)
		i = i+1
	    elseif table_matches(self.candidate, self.pattern) then
	        set_state(self, X2DFramerState.IN_FRAME_BODY)
	    else
		self.candidate = table.slice(self.candidate, 2)
		table.insert(self.candidate, v) 
		i = i+1
 	    end
	elseif self.state == X2DFramerState.IN_FRAME_START then
            if #self.candidate < #self.pattern then
		i = i+1
   	        table.insert(self.candidate, v)
	    elseif table_matches(self.candidate, self.pattern) then
	        set_state(self, X2DFramerState.IN_FRAME_BODY)
	    else
		print("expecting frame preamble, got something else",
		      table.concat(self.candidate) , v)
	        set_state(self, X2DFramerState.SEARCHING)
	    end
	elseif self.state == X2DFramerState.IN_FRAME_BODY then
            if #self.candidate < #self.pattern then
		i = i+1
   	        table.insert(self.candidate, v)
	    elseif table_matches(self.candidate, self.pattern) then
	        set_state(self, X2DFramerState.IN_FRAME_START)
		table_append(self.payload, self.candidate)
		out:append(X2DFrameType.new(self.payload))
	    else
	        table.insert(self.payload, self.candidate[1])
		self.candidate = table.slice(self.candidate, 2)
		table.insert(self.candidate, v) 
		i = i+1
	    end
       end
   end
   return out
end

return X2DDecoderBlock
