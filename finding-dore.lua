local radio = require('radio')

function basename(str)
    local name = string.gsub(str, "(.*/)(.*)", "%2")
    return name
end

top = radio.CompositeBlock()

local filename = basename(arg[1])
local src = radio.IQFileSource(arg[1],'u8', 1e6)
local lpf = radio.LowpassFilterBlock(5, 500)
local slicer = radio.SlicerBlock(0)
local clock_recoverer = radio.ZeroCrossingClockRecoveryBlock(4800)
local delayed_clock = radio.DelayBlock(64)
local mag = radio.ComplexMagnitudeBlock()
local shift = radio.AddConstantBlock(-0.5)
local clip = radio.ClipBlock(-0.3, 0.2)
local sampler = radio.SamplerBlock()

top:connect(src, lpf)
top:connect(lpf, mag)
top:connect(mag, shift)
top:connect(shift, clip)
top:connect(clip, radio.WAVFileSink('/tmp/'..filename..'_0.wav', 1))
	    
top:connect(clip, 'out', clock_recoverer, 'in')
top:connect(clip, 'out', sampler, 'data')
top:connect(clock_recoverer, delayed_clock)

top:connect(delayed_clock, 'out', sampler, 'clock')
top:connect(sampler, 'out',
            radio.WAVFileSink('/tmp/'..filename..'_1.wav', 1), 'in')
top:connect(sampler,  slicer)
decoder = radio.BiphaseMarkDecoderBlock()
top:connect(slicer,  decoder)
--top:connect(decoder, radio.PrintSink())
top:connect(decoder, radio.SaveBitsSink("/tmp/dat"))

top:run()