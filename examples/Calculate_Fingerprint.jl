using LinearAlgebra
using BenchmarkTools
using MAT
using Revise
using Plots
plotlyjs(ticks=:native)
theme(:lime);

using MT_generalizedBloch

## set parameters
ω0 = 0.0
B1 = 1.0
m0s = 0.15
R1 = 1.0
R2f = 1 / 65e-3
T2s = 10e-6
Rx = 30.0
TR = 3.5e-3

file = matopen(expanduser("~/mygs/20200806_MT_inVivo/control_MT_v3p2_TR3p5ms_discretized.mat"))
control = read(file, "control")
TRF = [500e-6; control[1:end - 1,2]]
α = [π; control[1:end - 1,1] .+ control[2:end,1]]
ω1 = α ./ TRF

## IDE solution (no Gradients)
s = gBloch_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, [], 2)
plot(TR * 1:length(TRF), s[1,:] ./ (1 - m0s), label="xf / m0f", legend=:topleft)
plot!(TR * 1:length(TRF), s[2,:] ./ (1 - m0s), label="yf / m0f")
plot!(TR * 1:length(TRF), s[3,:] ./ (1 - m0s), label="zf / m0f")
plot!(TR * 1:length(TRF), s[4,:] ./ m0s, label="zs / m0s")

## Graham's solution
s = Graham_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, [], 2)
plot!(TR * 1:length(TRF), s[1,:] ./ (1 - m0s), label="G: xf / m0f")
plot!(TR * 1:length(TRF), s[2,:] ./ (1 - m0s), label="G: yf / m0f")
plot!(TR * 1:length(TRF), s[3,:] ./ (1 - m0s), label="G: zf / m0f")
plot!(TR * 1:length(TRF), s[4,:] ./ m0s, label="G: zs / m0s")

##
s = Graham_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, 2)
plot(TR * 1:length(TRF), real(s), label="real(s)", legend=:topleft)
plot!(TR * 1:length(TRF), imag(s), label="imag(s)", legend=:topleft)