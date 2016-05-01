local ffi = require('ffi')

local platform = require('radio.core.platform')
local block = require('radio.core.block')
local class = require('radio.core.class')
local vector = require('radio.core.vector')
local types = require('radio.types')

local FIRFilterBlock = block.factory("FIRFilterBlock")

function FIRFilterBlock:instantiate(taps)
    if class.isinstanceof(taps, vector.Vector) and taps.type == types.Float32 then
        self.taps = taps
    elseif class.isinstanceof(taps, vector.Vector) and taps.type == types.ComplexFloat32 then
        self.taps = taps
    else
        self.taps = types.Float32.vector_from_array(taps)
    end

    if self.taps.type == types.ComplexFloat32 then
        self:add_type_signature({block.Input("in", types.ComplexFloat32)}, {block.Output("out", types.ComplexFloat32)}, FIRFilterBlock.process_complex_complex)
        self:add_type_signature({block.Input("in", types.Float32)}, {block.Output("out", types.ComplexFloat32)}, FIRFilterBlock.process_real_complex)
    else
        self:add_type_signature({block.Input("in", types.ComplexFloat32)}, {block.Output("out", types.ComplexFloat32)}, FIRFilterBlock.process_complex_real)
        self:add_type_signature({block.Input("in", types.Float32)}, {block.Output("out", types.Float32)}, FIRFilterBlock.process_real_real)
    end
end

function FIRFilterBlock:initialize()
    self.data_type = self:get_input_types()[1]
    self.state = self.data_type.vector(self.taps.length)

    -- Reverse taps
    local reversed_taps = self.taps.type.vector(self.taps.length)
    for i = 0, self.taps.length-1 do
        reversed_taps.data[i] = self.taps.data[self.taps.length-1-i]
    end
    self.taps = reversed_taps
end

ffi.cdef[[
void *memmove(void *dest, const void *src, size_t n);
void *memcpy(void *dest, const void *src, size_t n);
]]

if platform.features.volk then

    ffi.cdef[[
    void (*volk_32fc_x2_dot_prod_32fc)(complex_float32_t* result, const complex_float32_t* input, const complex_float32_t* taps, unsigned int num_points);
    void (*volk_32fc_32f_dot_prod_32fc)(complex_float32_t* result, const complex_float32_t* input, const float32_t* taps, unsigned int num_points);
    void (*volk_32f_x2_dot_prod_32f)(float32_t* result, const float32_t* input, const float32_t* taps, unsigned int num_points);
    ]]
    local libvolk = platform.libs.volk

    function FIRFilterBlock:process_complex_complex(x)
        local out = types.ComplexFloat32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            libvolk.volk_32fc_x2_dot_prod_32fc(out.data[i], self.state.data[i], self.taps.data, self.taps.length)
        end

        return out
    end

    function FIRFilterBlock:process_real_complex(x)
        local out = types.ComplexFloat32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            libvolk.volk_32fc_32f_dot_prod_32fc(out.data[i], self.taps.data, self.state.data[i], self.taps.length)
        end

        return out
    end

    function FIRFilterBlock:process_complex_real(x)
        local out = types.ComplexFloat32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            libvolk.volk_32fc_32f_dot_prod_32fc(out.data[i], self.state.data[i], self.taps.data, self.taps.length)
        end

        return out
    end

    function FIRFilterBlock:process_real_real(x)
        local out = types.Float32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            libvolk.volk_32f_x2_dot_prod_32f(out.data[i], self.state.data[i], self.taps.data, self.taps.length)
        end

        return out
    end

else

    function FIRFilterBlock:process_complex_complex(x)
        local out = types.ComplexFloat32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            for j = 0, self.taps.length-1 do
                out.data[i] = out.data[i] + self.state.data[i+j] * self.taps.data[j]
            end
        end

        return out
    end

    function FIRFilterBlock:process_real_complex(x)
        local out = types.ComplexFloat32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            for j = 0, self.taps.length-1 do
                out.data[i] = out.data[i] + self.taps.data[j]:scalar_mul(self.state.data[i+j].value)
            end
        end

        return out
    end

    function FIRFilterBlock:process_complex_real(x)
        local out = types.ComplexFloat32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            for j = 0, self.taps.length-1 do
                out.data[i] = out.data[i] + self.state.data[i+j]:scalar_mul(self.taps.data[j].value)
            end
        end

        return out
    end

    function FIRFilterBlock:process_real_real(x)
        local out = types.Float32.vector(x.length)

        -- Shift last taps_length-1 state samples to the beginning of state
        ffi.C.memmove(self.state.data, self.state.data[self.state.length - (self.taps.length - 1)], (self.taps.length-1)*ffi.sizeof(self.state.data[0]))
        -- Adjust state vector length for the input
        self.state:resize(self.taps.length - 1 + x.length)
        -- Shift input into state
        ffi.C.memcpy(self.state.data[self.taps.length-1], x.data, x.length*ffi.sizeof(self.state.data[0]))

        for i = 0, x.length-1 do
            -- Inner product of state and taps
            for j = 0, self.taps.length-1 do
                out.data[i].value = out.data[i].value + self.state.data[i+j].value * self.taps.data[j].value
            end
        end

        return out
    end

end

return FIRFilterBlock
