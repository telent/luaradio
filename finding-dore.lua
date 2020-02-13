local radio = require('radio')

top = radio.CompositeBlock()

local src = radio.IQFileSource(arg[1],'u8', 1e6)
local lpf = radio.LowpassFilterBlock(25, 800)
local slicer = radio.SlicerBlock(0)
local clock_recoverer = radio.ZeroCrossingClockRecoveryBlock(4800)
local mag = radio.ComplexMagnitudeBlock()
local shift = radio.AddConstantBlock(-0.5)
local sampler = radio.SamplerBlock()

top:connect(src, lpf)
top:connect(lpf, mag)
top:connect(mag, shift)

top:connect(shift, 'out', clock_recoverer, 'in')
top:connect(shift, 'out', sampler, 'data')
top:connect(clock_recoverer, 'out', sampler, 'clock')
top:connect(sampler,  slicer)
top:connect(sampler, 'out', radio.WAVFileSink('/tmp/1.wav', 1), 'in')
decoder = radio.BiphaseMarkDecoderBlock()
top:connect(slicer,  decoder)
--top:connect(decoder, radio.PrintSink())
top:connect(decoder, radio.SaveBitsSink("/tmp/dat"))

top:run()