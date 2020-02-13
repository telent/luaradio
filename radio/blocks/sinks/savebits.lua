local ffi = require('ffi')

local block = require('radio.core.block')
local types = require('radio.types')

local SaveBitsSink = block.factory("SaveBitsSink")

function SaveBitsSink:instantiate(file)
    if type(file) == "number" then
        self.fd = file
    elseif type(file) == "string" then
        self.filename = file
    elseif file == nil then
        -- Default to io.stdout
        self.file = io.stdout
    end
    self:add_type_signature({block.Input("in", function (type) return type.__tostring ~= nil end)}, {})
--    self:add_type_signature({block.Input("in", types.Bit)}, {})
end

function SaveBitsSink:initialize()
    if self.filename then
        self.file = ffi.C.fopen(self.filename, "wb")
        if self.file == nil then
            error("fopen(): " .. ffi.string(ffi.C.strerror(ffi.errno())))
        end
    elseif self.fd then
        self.file = ffi.C.fdopen(self.fd, "wb")
        if self.file == nil then
            error("fdopen(): " .. ffi.string(ffi.C.strerror(ffi.errno())))
        end
    end

    -- Register open file
    self.files[self.file] = true
end

function SaveBitsSink:process(x)
    for i = 0, x.length-1, 8 do
        local acc = 0
        for j = 0, 7 do
	    acc = acc * 2
	    acc = acc + x.data[i+j].value
         end
	 s = string.char(acc)
        -- Write to file
        if ffi.C.fwrite(s, 1, #s, self.file) ~= #s then
            error("fwrite(): " .. ffi.string(ffi.C.strerror(ffi.errno())))
        end
    end

    -- Flush file
    if ffi.C.fflush(self.file) ~= 0 then
        error("fflush(): " .. ffi.string(ffi.C.strerror(ffi.errno())))
    end
end

function SaveBitsSink:cleanup()
    if self.filename then
        if ffi.C.fclose(self.file) ~= 0 then
            error("fclose(): " .. ffi.string(ffi.C.strerror(ffi.errno())))
        end
    elseif self.fd then
        if ffi.C.fflush(self.file) ~= 0 then
            error("fflush(): " .. ffi.string(ffi.C.strerror(ffi.errno())))
        end
    else
        self.file:flush()
    end
end

return SaveBitsSink
