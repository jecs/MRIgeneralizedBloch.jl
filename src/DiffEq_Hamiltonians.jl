###################################################
# generalized Bloch Hamiltonians that can take any
# Green's function as an argument.
###################################################
"""
    apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p, t)

Apply the generalized Bloch Hamiltonian to `m` and write the resulting derivative wrt. time into `∂m∂t`.

# Arguments
- `∂m∂t::Vector{<:Number}`: Vector describing to derivative of `m` wrt. time; this vector has to be of the same size as `m`, but can contain any value, which is replaced by `H * m`
- `m::Vector{<:Number}`: Vector the spin ensemble state of the form `[xf, yf, zf, zs, 1]` if now gradient is calculated or of the form `[xf, yf, zf, zs, 1, ∂xf/∂θ1, ∂yf/∂θ1, ∂zf/∂θ1, ∂zs/∂θ1, 0, ..., ∂xf/∂θn, ∂yf/∂θn, ∂zf/∂θn, ∂zs/∂θn, 0]` if n derivatives wrt. `θn` are calculated
- `mfun`: History function; can be initialized with `mfun(p, t; idxs=nothing) = typeof(idxs) <: Number ? 0.0 : zeros(5n + 5)` for n gradients, and is then updated by the delay differential equation solvers
- `p::NTuple{9,10, or 11, Any}`: `(ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g)`, with
    - `ω1::Number`: Rabi frequency in rad/s (rotation about the y-axis) or
    - `ω1(t)::Function`: Rabi frequency in rad/s as a function of time for shaped RF-pulses
    - `B1::Number`: B1 scaling normalized so that `B1=1` corresponds to a perfectly calibrated RF field
    - `ω0::Number`: Larmor or off-resonance frequency in rad/s or
    - `φ::Function`: RF-phase in rad as a function of time for frequency/phase-sweep pulses (works only in combination with `ω1(t)::Function`)
    - `m0s::Number`: Fractional semi-solid spin pool size in the range of 0 to 1
    - `R1f::Number`: Longitudinal spin relaxation rate of the free pool in 1/seconds
    - `R2f::Number`: Transversal spin relaxation rate of the free pool in 1/seconds
    - `Rx::Number`: Exchange rate between the two pools in 1/seconds
    - `R1s::Number`: Longitudinal spin relaxation rate of the semi-solid pool in 1/seconds
    - `T2s::Number`: Transversal spin relaxation time of the semi-solid pool in seconds
    - `g::Function`: Green's function of the form `G(κ) = G((t-τ)/T2s)`
    or `(ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, zs_idx, g)` with
    - `zs_idx::Integer`: Index to be used history function to be used in the Green's function; Default is 4 (zs), and for derivatives 9, 14, ... are used
    or `(ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s, grad_list)` with
    - `dG_o_dT2s_x_T2s::Function`: Derivative of the Green's function wrt. T2s, multiplied by T2s; of the form `dG_o_dT2s_x_T2s(κ) = dG_o_dT2s_x_T2s((t-τ)/T2s)`
    - `grad_list::Vector{<:grad_param}`: List of gradients to be calculated; any subset of `[grad_m0s(), grad_R1f(), grad_R2f(), grad_Rx(), grad_R1s(), grad_T2s(), grad_ω0(), grad_B1()]`; length of the vector must be n (cf. arguments `m` and `∂m∂t`); ; the derivative wrt. to apparent `R1a = R1f = R1s` can be calculated with `grad_R1a()`
- `t::Number`: Time in seconds

Optional:
- `pulsetype=:normal`: Use default for a regular RF-pulse; the option `pulsetype=:inversion` should be handled with care as it is only intended to calculate the saturation of the semi-solid pool and its derivative.

# Examples
```jldoctest
julia> using DifferentialEquations


julia> α = π/2;

julia> TRF = 100e-6;

julia> ω1 = α/TRF;

julia> B1 = 1;

julia> ω0 = 0;

julia> m0s = 0.2;

julia> R1f = 1/3;

julia> R2f = 15;

julia> R1s = 2;

julia> T2s = 10e-6;

julia> Rx = 30;

julia> G = interpolate_greens_function(greens_superlorentzian, 0, TRF / T2s);


julia> m0 = [0; 0; 1-m0s; m0s; 1];

julia> mfun(p, t; idxs=nothing) = typeof(idxs) <: Number ? 0.0 : zeros(5);

julia> sol = solve(DDEProblem(apply_hamiltonian_gbloch!, m0, mfun, (0, TRF), (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, G)))
retcode: Success
Interpolation: specialized 4th order "free" interpolation, specialized 2nd order "free" stiffness-aware interpolation
t: 9-element Vector{Float64}:
 0.0
 1.375006182301112e-7
 1.512506800531223e-6
 8.042561696923577e-6
 2.107848894861101e-5
 3.911414415070652e-5
 6.26879093553081e-5
 9.147705752659822e-5
 0.0001
u: 9-element Vector{Vector{Float64}}:
 [0.0, 0.0, 0.8, 0.2, 1.0]
 [0.0017278806030763402, 0.0, 0.7999981340131751, 0.19999953350448, 1.0]
 [0.019004717382235078, 0.0, 0.7997742277135814, 0.19994357804868362, 1.0]
 [0.10079111348917136, 0.0, 0.7936248122939504, 0.19842287240365722, 1.0]
 [0.26002578672576243, 0.0, 0.7565529666157937, 0.18981913039644657, 1.0]
 [0.4610419882566734, 0.0, 0.6537242214798688, 0.16937688382096108, 1.0]
 [0.6661738538876186, 0.0, 0.44261236945975563, 0.1358931514238721, 1.0]
 [0.7923116826717905, 0.0, 0.10713144280454787, 0.09390268562369869, 1.0]
 [0.7994211188440815, 0.0, 0.0004403374355099447, 0.08214809683848684, 1.0]

julia> using Plots

julia> plot(sol, labels=["xf" "yf" "zf" "zs" "1"], xlabel="t (s)", ylabel="m(t)");




julia> dG_o_dT2s_x_T2s = interpolate_greens_function(dG_o_dT2s_x_T2s_superlorentzian, 0, TRF / T2s);


julia> grad_list = [grad_R2f(), grad_m0s()];


julia> m0 = [0; 0; 1-m0s; m0s; 1; zeros(5*length(grad_list))];


julia> mfun(p, t; idxs=nothing) = typeof(idxs) <: Number ? 0.0 : zeros(5 + 5*length(grad_list));

julia> sol = solve(DDEProblem(apply_hamiltonian_gbloch!, m0, mfun, (0, TRF), (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, G, dG_o_dT2s_x_T2s, grad_list)));




julia> plot(sol);


```
"""
function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::NTuple{11,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, zs_idx, g = p

    ∂m∂t[1] = - R2f * m[1] - ω0  * m[2] + B1 * ω1 * m[3]
    ∂m∂t[2] =   ω0  * m[1] - R2f * m[2]
    ∂m∂t[3] = - B1 * ω1  * m[1] - (R1f + Rx * m0s) * m[3] + Rx * (1 - m0s) * m[4] + (1 - m0s) * R1f * m[5]

    if ω0 == 0
        xs = 0
        ys = quadgk(x -> g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
    else
        xs = sin(ω0 * t) * quadgk(x -> sin(ω0 * x) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
        ys = cos(ω0 * t) * quadgk(x -> cos(ω0 * x) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
    end

    ∂m∂t[4] = -B1^2 * ω1^2 * (xs + ys) + Rx * m0s  * m[3] - (R1s + Rx * (1 - m0s)) * m[4] + m0s * R1s * m[5]
    return ∂m∂t
end

function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::Tuple{Function,Any,Number,Any,Any,Any,Any,Any,Any,Any,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, zs_idx, g = p

    ∂m∂t[1] = - R2f * m[1] - ω0  * m[2] + B1 * ω1(t) * m[3]
    ∂m∂t[2] =   ω0  * m[1] - R2f * m[2]
    ∂m∂t[3] = - B1 * ω1(t)  * m[1] - (R1f + Rx * m0s) * m[3] + Rx * (1 - m0s) * m[4] + (1 - m0s) * R1f * m[5]

    if ω0 == 0
        xs = 0
        ys = quadgk(x -> ω1(x) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
    else
        xs = sin(ω0 * t) * quadgk(x -> ω1(x) * sin(ω0 * x) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
        ys = cos(ω0 * t) * quadgk(x -> ω1(x) * cos(ω0 * x) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
    end

    ∂m∂t[4] = -B1^2 * ω1(t) * (xs + ys) + Rx * m0s  * m[3] - (R1s + Rx * (1 - m0s)) * m[4] + m0s * R1s * m[5]
end

function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::Tuple{Function,Any,Function,Any,Any,Any,Any,Any,Any,Any,Any}, t)
    ω1, B1, φ, m0s, R1f, R2f, Rx, R1s, T2s, zs_idx, g = p

    ∂m∂t[1] = - R2f * m[1] + B1 * ω1(t) * cos(φ(t)) * m[3]
    ∂m∂t[2] = - R2f * m[2] - B1 * ω1(t) * sin(φ(t)) * m[3]
    ∂m∂t[3] = - B1 * ω1(t) * cos(φ(t)) * m[1] + B1 * ω1(t) * sin(φ(t)) * m[2] - (R1f + Rx * m0s) * m[3] + Rx * (1 - m0s) * m[4] + (1 - m0s) * R1f * m[5]

    xs = sin(φ(t)) * quadgk(x -> ω1(x) * sin(φ(x)) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]
    ys = cos(φ(t)) * quadgk(x -> ω1(x) * cos(φ(x)) * g((t - x) / T2s) * mfun(p, x; idxs=zs_idx), eps(), t, order=100)[1]

    ∂m∂t[4] = -B1^2 * ω1(t) * (xs + ys) + Rx * m0s  * m[3] - (R1s + Rx * (1 - m0s)) * m[4] + m0s * R1s * m[5]
end

function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::NTuple{10,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g = p
    return apply_hamiltonian_gbloch!(∂m∂t, m, mfun, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, 4, g), t)
end

# Version for an isolated semi-solid pool
function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::NTuple{6,Any}, t)
    ω1, B1, ω0, R1s, T2s, g = p

    if ω0 == 0
        xs = 0
        ys = quadgk(x -> g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
    else
        xs = sin(ω0 * t) * quadgk(x -> sin(ω0 * x) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
        ys = cos(ω0 * t) * quadgk(x -> cos(ω0 * x) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
    end

    ∂m∂t[1] = -B1^2 * ω1^2 * (xs + ys) + R1s * (1 - m[1])
end

function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::Tuple{Function,Any,Number,Any,Any,Any}, t)
    ω1, B1, ω0, R1s, T2s, g = p

    if ω0 == 0
        xs = 0
        ys = quadgk(x -> ω1(x) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
    else
        xs = sin(ω0 * t) * quadgk(x -> ω1(x) * sin(ω0 * x) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
        ys = cos(ω0 * t) * quadgk(x -> ω1(x) * cos(ω0 * x) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
    end

    ∂m∂t[1] = -B1^2 * ω1(t) * (xs + ys) + R1s * (1 - m[1])
end

function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::Tuple{Function,Any,Function,Any,Any,Any}, t)
    ω1, B1, φ, R1s, T2s, g = p

    xs = sin(φ(t)) * quadgk(x -> ω1(x) * sin(φ(x)) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]
    ys = cos(φ(t)) * quadgk(x -> ω1(x) * cos(φ(x)) * g((t - x) / T2s) * mfun(p, x)[1], 0, t, order=100)[1]

    ∂m∂t[1] = -B1^2 * ω1(t) * (xs + ys) + R1s * (1 - m[1])
end


function apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p::NTuple{12,Any}, t; pulsetype=:normal)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s, grad_list = p

    # Apply Hamiltonian to M
    u_v1 = @view m[1:5]
    du_v1 = @view ∂m∂t[1:5]
    apply_hamiltonian_gbloch!(du_v1, u_v1, mfun, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, 4, g), t)

    # Apply Hamiltonian to all derivatives and add partial derivatives
    for i = 1:length(grad_list)
        du_v = @view ∂m∂t[5 * i + 1:5 * (i + 1)]
        u_v  = @view m[5 * i + 1:5 * (i + 1)]
        apply_hamiltonian_gbloch!(du_v, u_v, mfun, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, (5i + 4), g), t)

        if pulsetype==:normal || isa(grad_list[i], grad_T2s) || isa(grad_list[i], grad_B1)
            add_partial_derivative!(du_v, u_v1, x -> mfun(p, x; idxs=4), (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s), t, grad_list[i])
        end
    end
    return ∂m∂t
end

function apply_hamiltonian_gbloch_inversion!(∂m∂t, m, mfun, p, t)
    apply_hamiltonian_gbloch!(∂m∂t, m, mfun, p, t; pulsetype=:inversion)
end

###################################################
# Bloch-McConnell model to simulate free precession
###################################################
function apply_hamiltonian_freeprecession!(∂m∂t, m, p::NTuple{6,Any}, t)
    ω0, m0s, R1f, R2f, Rx, R1s = p

    ∂m∂t[1] = - R2f * m[1] - ω0  * m[2]
    ∂m∂t[2] =   ω0  * m[1] - R2f * m[2]
    ∂m∂t[3] = - (R1f + Rx * m0s) * m[3] + Rx * (1 - m0s)  * m[4] + (1 - m0s) * R1f * m[5]
    ∂m∂t[4] =   Rx * m0s  * m[3] - (R1s + Rx * (1 - m0s)) * m[4] + m0s  * R1s * m[5]
    return ∂m∂t
end

function apply_hamiltonian_freeprecession!(∂m∂t, m, p::NTuple{7,Any}, t)
    ω0, m0s, R1f, R2f, Rx, R1s, grad_list = p

    # Apply Hamiltonian to M
    u_v1 = @view m[1:5]
    du_v1 = @view ∂m∂t[1:5]
    apply_hamiltonian_freeprecession!(du_v1, u_v1, (ω0, m0s, R1f, R2f, Rx, R1s), t)

    # Apply Hamiltonian to M and all its derivatives
    for i = 1:length(grad_list)
        du_v = @view ∂m∂t[5 * i + 1:5 * (i + 1)]
        u_v  = @view m[5 * i + 1:5 * (i + 1)]
        apply_hamiltonian_freeprecession!(du_v, u_v, (ω0, m0s, R1f, R2f, Rx, R1s), t)

        add_partial_derivative!(du_v, u_v1, undef, (0.0, 1.0, ω0, m0s, R1f, R2f, Rx, R1s, undef, undef, undef), t, grad_list[i])
    end
    return ∂m∂t
end

#########################################################################
# implementation of the partial derivatives for calculating the gradients
#########################################################################
function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_m0s)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, _, dG_o_dT2s_x_T2s = p

    ∂m∂t[3] -= Rx * m[3] + Rx * m[4] + R1f
    ∂m∂t[4] += Rx * m[3] + Rx * m[4] + R1s
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_R1a)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, _, dG_o_dT2s_x_T2s = p

    ∂m∂t[3] += - m[3] + (1 - m0s)
    ∂m∂t[4] += - m[4] + m0s
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_R1f)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, _, dG_o_dT2s_x_T2s = p

    ∂m∂t[3] += - m[3] + (1 - m0s)
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_R1s)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, _, dG_o_dT2s_x_T2s = p

    ∂m∂t[4] += - m[4] + m0s
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_R2f)
    ∂m∂t[1] -= m[1]
    ∂m∂t[2] -= m[2]
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_Rx)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, TRF, dG_o_dT2s_x_T2s = p

    ∂m∂t[3] += - m0s * m[3] + (1 - m0s) * m[4]
    ∂m∂t[4] +=   m0s * m[3] - (1 - m0s) * m[4]
    return ∂m∂t
end

# versions for gBloch
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Number,Any,Any,Any,Any,Any,Any,Any,Any,Function,Function}, t, grad_type::grad_T2s)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ys = cos(ω0 * t) * quadgk(x -> cos(ω0 * x) * dG_o_dT2s_x_T2s((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs = sin(ω0 * t) * quadgk(x -> sin(ω0 * x) * dG_o_dT2s_x_T2s((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= B1^2 * ω1^2 * (xs + ys)/T2s
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Function,Any,Number,Any,Any,Any,Any,Any,Any,Function,Function}, t, grad_type::grad_T2s)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ys = cos(ω0 * t) * quadgk(x -> ω1(x) * cos(ω0 * x) * dG_o_dT2s_x_T2s((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs = sin(ω0 * t) * quadgk(x -> ω1(x) * sin(ω0 * x) * dG_o_dT2s_x_T2s((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= B1^2 * ω1(t) * (xs + ys)/T2s
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Function,Any,Function,Any,Any,Any,Any,Any,Any,Function,Function}, t, grad_type::grad_T2s)
    ω1, B1, φ, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ys = cos(φ(t)) * quadgk(x -> ω1(x) * cos(φ(x)) * dG_o_dT2s_x_T2s((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs = sin(φ(t)) * quadgk(x -> ω1(x) * sin(φ(x)) * dG_o_dT2s_x_T2s((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= B1^2 * ω1(t) * (xs + ys)/T2s
    return ∂m∂t
end

# version for free precession (does nothing)
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Any,Any,Any,Any,Any,Any,Any,Any,Any,UndefInitializer,UndefInitializer}, t, grad_type::grad_T2s)
    return ∂m∂t
end

# version for Graham's model
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Number,Any,Any,Any,Any,Any,Any,Any,Any,Number,Any}, t, grad_type::grad_T2s)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, TRF, dG_o_dT2s_x_T2s = p

    df_PSD(τ) = quadgk(ct -> 8 / τ * (exp(-τ^2 / 8 * (3 * ct^2 - 1)^2) - 1) / (3 * ct^2 - 1)^2 + sqrt(2π) * erf(τ / sqrt(8) * abs(3 * ct^2 - 1)) / abs(3 * ct^2 - 1), 0.0, 1.0, order=100)[1]

    ∂m∂t[4] -= df_PSD(TRF / T2s) * B1^2 * ω1^2 * m[4]
    return ∂m∂t
end

# versions for gBloch model
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Number,Any,Number,Any,Any,Any,Any,Any,Any,Function,Function}, t, grad_type::grad_ω0)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ∂m∂t[1] -= m[2]
    ∂m∂t[2] += m[1]

    xs  = cos(ω0 * t) * t * quadgk(x -> sin(ω0 * x)     * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs += sin(ω0 * t)     * quadgk(x -> cos(ω0 * x) * x * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ys = -sin(ω0 * t) * t * quadgk(x -> cos(ω0 * x)     * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    ys -= cos(ω0 * t)     * quadgk(x -> sin(ω0 * x) * x * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= B1^2 * ω1^2 * (xs + ys)
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Function,Any,Number,Any,Any,Any,Any,Any,Any,Function,Function}, t, grad_type::grad_ω0)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ∂m∂t[1] -= m[2]
    ∂m∂t[2] += m[1]

    xs  = cos(ω0 * t) * t * quadgk(x -> ω1(x) * sin(ω0 * x)     * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs += sin(ω0 * t)     * quadgk(x -> ω1(x) * cos(ω0 * x) * x * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ys = -sin(ω0 * t) * t * quadgk(x -> ω1(x) * cos(ω0 * x)     * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    ys -= cos(ω0 * t)     * quadgk(x -> ω1(x) * sin(ω0 * x) * x * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= B1^2 * ω1(t) * (xs + ys)
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Function,Any,Function,Any,Any,Any,Any,Any,Any,Function,Function}, t, grad_type::grad_ω0)
    ω1, B1, φ, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ∂m∂t[1] -= m[2]
    ∂m∂t[2] += m[1]

    xs  = cos(φ(t)) * t * quadgk(x -> ω1(x) * sin(φ(x))     * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs += sin(φ(t))     * quadgk(x -> ω1(x) * cos(φ(x)) * x * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ys = -sin(φ(t)) * t * quadgk(x -> ω1(x) * cos(φ(x))     * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    ys -= cos(φ(t))     * quadgk(x -> ω1(x) * sin(φ(x)) * x * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= B1^2 * ω1(t) * (xs + ys)
    return ∂m∂t
end

# version for free precession & Graham's model
function add_partial_derivative!(∂m∂t, m, mfun, p::NTuple{11,Any}, t, grad_type::grad_ω0)
    ∂m∂t[1] -= m[2]
    ∂m∂t[2] += m[1]
    return ∂m∂t
end

# versions for gBloch (using ApproxFun)
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Number,Any,Number,Any,Any,Any,Any,Any,Any,Function,Any}, t, grad_type::grad_B1)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ∂m∂t[1] += ω1 * m[3]
    ∂m∂t[3] -= ω1 * m[1]

    ys = cos(ω0 * t) * quadgk(x -> cos(ω0 * x) * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs = sin(ω0 * t) * quadgk(x -> sin(ω0 * x) * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= 2 * B1 * ω1^2 * (xs + ys)
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Function,Any,Number,Any,Any,Any,Any,Any,Any,Function,Any}, t, grad_type::grad_B1)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ∂m∂t[1] += ω1(t) * m[3]
    ∂m∂t[3] -= ω1(t) * m[1]

    ys = cos(ω0 * t) * quadgk(x -> ω1(x) * cos(ω0 * x) * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs = sin(ω0 * t) * quadgk(x -> ω1(x) * sin(ω0 * x) * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= 2 * B1 * ω1(t) * (xs + ys)
    return ∂m∂t
end

function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Function,Any,Function,Any,Any,Any,Any,Any,Any,Function,Any}, t, grad_type::grad_B1)
    ω1, B1, φ, m0s, R1f, R2f, Rx, R1s, T2s, g, dG_o_dT2s_x_T2s = p

    ∂m∂t[1] += ω1(t) * m[3]
    ∂m∂t[3] -= ω1(t) * m[1]

    ys = cos(φ(t)) * quadgk(x -> ω1(x) * cos(φ(x)) * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]
    xs = sin(φ(t)) * quadgk(x -> ω1(x) * sin(φ(x)) * g((t - x) / T2s) * mfun(x), 0, t, order=100)[1]

    ∂m∂t[4] -= 2 * B1 * ω1(t) * (xs + ys)
    return ∂m∂t
end

# version for free precession (does nothing)
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Any,Any,Any,Any,Any,Any,Any,Any,Any,UndefInitializer,UndefInitializer}, t, grad_type::grad_B1)
    return ∂m∂t
end

# version for Graham
function add_partial_derivative!(∂m∂t, m, mfun, p::Tuple{Number,Any,Any,Any,Any,Any,Any,Any,Any,Number,Any}, t, grad_type::grad_B1)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, TRF, dG_o_dT2s_x_T2s = p

    f_PSD = (τ) -> quadgk(ct -> 1 / abs(1 - 3 * ct^2) * (4 / τ / abs(1 - 3 * ct^2) * (exp(- τ^2 / 8 * (1 - 3 * ct^2)^2) - 1) + sqrt(2π) * erf(τ / 2 / sqrt(2) * abs(1 - 3 * ct^2))), 0, 1, order=100)[1]

    ∂m∂t[1] += ω1 * m[3]
    ∂m∂t[3] -= ω1 * m[1]
    ∂m∂t[4] -= f_PSD(TRF / T2s) * 2 * B1 * ω1^2 * T2s * m[4]
    return ∂m∂t
end

##############################################################################
# Implementation for comparison: the super-Lorentzian Green's function
# is hard coded, which allows to use special solvers for the double integral
##############################################################################
function apply_hamiltonian_gbloch_superlorentzian!(∂m∂t, m, mfun, p::NTuple{11,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, zs_idx, N = p

    gt = (t, T2s, ct) -> exp(- (t / T2s)^2 * (3 * ct^2 - 1)^2 / 8)

    function fy!(x, y, gt, mfun, p, T2s, zs_idx, t)
        for i = 1:size(x, 2)
            y[i] = gt(t - x[2,i], T2s, x[1,i]) * mfun(p, x[2,i]; idxs=zs_idx)
        end
    end

    dy1 = Cubature.pcubature_v((x, y) -> fy!(x, y, gt, mfun, p, T2s, zs_idx, t), [0.0, max(0.0, t - N * T2s)], [1.0, t])[1]

    if t > (N * T2s)
        dy2 = T2s * sqrt(2π / 3) * Cubature.pcubature(x -> mfun(p, x[1]; idxs=zs_idx) / (t - x[1]), [0.0], [t - N * T2s])[1]

        ∂m∂t[4] = -B1^2 * ω1^2 * ((dy1) + (dy2))
    else
        ∂m∂t[4] = -B1^2 * ω1^2 * (dy1)
    end

    ∂m∂t[1] = - R2f * m[1] - ω0  * m[2] + B1 * ω1 * m[3]
    ∂m∂t[2] =   ω0  * m[1] - R2f * m[2]
    ∂m∂t[3] = - B1 * ω1  * m[1] - (R1f + Rx * m0s) * m[3] +       Rx * (1 - m0s)  * m[4] + (1 - m0s) * R1f * m[5]
    ∂m∂t[4] +=             +       Rx * m0s  * m[3] - (R1s + Rx * (1 - m0s)) * m[4] +      m0s  * R1s * m[5]
    ∂m∂t[5] = 0.0
    return ∂m∂t
end

function apply_hamiltonian_gbloch_superlorentzian!(∂m∂t, m, mfun, p::NTuple{10,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, N = p
    return apply_hamiltonian_gbloch_superlorentzian!(∂m∂t, m, mfun, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, 4, N), t)
end



###################################################
# Graham's spectral model
###################################################
function apply_hamiltonian_graham_superlorentzian!(∂m∂t, m, p::NTuple{10,Any}, t)
    ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s = p

    f_PSD(τ) = quadgk(ct -> 1 / abs(1 - 3 * ct^2) * (4 / τ / abs(1 - 3 * ct^2) * (exp(- τ^2 / 8 * (1 - 3 * ct^2)^2) - 1) + sqrt(2π) * erf(τ / 2 / sqrt(2) * abs(1 - 3 * ct^2))), 0, 1, order=100)[1]
    Rrf = f_PSD(TRF / T2s) * B1^2 * ω1^2 * T2s

    return apply_hamiltonian_linear!(∂m∂t, m, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, Rrf), t)
end

function apply_hamiltonian_graham_superlorentzian!(∂m∂t, m, p::NTuple{11,Any}, t)
    ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s, grad_list = p

    # Apply Hamiltonian to M
    u_v1 = @view m[1:5]
    du_v1 = @view ∂m∂t[1:5]
    apply_hamiltonian_graham_superlorentzian!(du_v1, u_v1, (ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s), t)

    # Apply Hamiltonian to M and all its derivatives
    for i = 1:length(grad_list)
        du_v = @view ∂m∂t[5 * i + 1:5 * (i + 1)]
        u_v  = @view m[5 * i + 1:5 * (i + 1)]
        apply_hamiltonian_graham_superlorentzian!(du_v, u_v, (ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s), t)

        add_partial_derivative!(du_v, u_v1, undef, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, TRF, undef), t, grad_list[i])
    end
    return ∂m∂t
end

function apply_hamiltonian_graham_superlorentzian_inversionpulse!(∂m∂t, m, p::NTuple{11,Any}, t)
    ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s, grad_list = p

    # Apply Hamiltonian to M
    u_v1 = @view m[1:5]
    du_v1 = @view ∂m∂t[1:5]
    apply_hamiltonian_graham_superlorentzian!(du_v1, u_v1, (ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s), t)

    # Apply Hamiltonian to M and all its derivatives
    for i = 1:length(grad_list)
        du_v = @view ∂m∂t[5 * i + 1:5 * (i + 1)]
        u_v  = @view m[5 * i + 1:5 * (i + 1)]
        apply_hamiltonian_graham_superlorentzian!(du_v, u_v, (ω1, B1, ω0, TRF, m0s, R1f, R2f, Rx, R1s, T2s), t)

        if isa(grad_list[i], grad_B1) || isa(grad_list[i], grad_T2s)
            add_partial_derivative!(du_v, u_v1, undef, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, TRF, undef), t, grad_list[i])
        end
    end
    return ∂m∂t
end


function apply_hamiltonian_linear!(∂m∂t, m, p::NTuple{9,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, Rrf = p

    apply_hamiltonian_freeprecession!(∂m∂t, m, (ω0, m0s, R1f, R2f, Rx, R1s), t)

    ∂m∂t[1] += B1 * ω1 * m[3]
    ∂m∂t[3] -= B1 * ω1 * m[1]
    ∂m∂t[4] -= Rrf * m[4]
    return ∂m∂t
end

function apply_hamiltonian_linear!(∂m∂t, m, p::NTuple{10,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, Rrf_d, grad_list = p
    Rrf = Rrf_d[1]

     # Apply Hamiltonian to M
    u_v1 = @view m[1:5]
    du_v1 = @view ∂m∂t[1:5]
    apply_hamiltonian_linear!(du_v1, u_v1, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, Rrf), t)

     # Apply Hamiltonian to M and all its derivatives
    for i = 1:length(grad_list)
        du_v = @view ∂m∂t[5 * i + 1:5 * (i + 1)]
        u_v  = @view m[5 * i + 1:5 * (i + 1)]
        apply_hamiltonian_linear!(du_v, u_v, (ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, Rrf), t)

        add_partial_derivative!(du_v, u_v1, undef, (ω1, B1, ω0, m0s, R1f, R2f, 0, Rx, R1s, Rrf_d, undef), t, grad_list[i])
    end
    return ∂m∂t
end

##################################################################
# Sled's model
##################################################################
"""
    apply_hamiltonian_sled!(∂m∂t, m, p, t)

Apply Sled's Hamiltonian to `m` and write the resulting derivative wrt. time into `∂m∂t`.

# Arguments
- `∂m∂t::Vector{<:Number}`: Vector of length 1 describing to derivative of `m` wrt. time; this vector can contain any value, which is replaced by `H * m`
- `m::Vector{<:Number}`: Vector of length 1 describing the `zs` magnetization
- `p::NTuple{6 or 10, Any}`: `(ω1, B1, ω0, R1s, T2s, g)` for a simulating an isolated semi-solid pool or `(ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g)` for simulating a coupled spin system; with
    -`ω1::Number`: Rabi frequency in rad/s (rotation about the y-axis)
    -`B1::Number`: B1 scaling normalized so that `B1=1` corresponds to a perfectly calibrated RF field
    -`ω0::Number`: Larmor or off-resonance frequency in rad/s
    -`R1f::Number`: Longitudinal spin relaxation rate of the free pool in 1/seconds
    -`R2f::Number`: Transversal spin relaxation rate of the free pool in 1/seconds
    -`R1s::Number`: Longitudinal spin relaxation rate of the semi-solid in 1/seconds
    -`Rx::Number`: Exchange rate between the two pools in 1/seconds
    -`T2s::Number`: Transversal spin relaxation time in seconds
    -`g::Function`: Green's function of the form `G(κ) = G((t-τ)/T2s)`
- `t::Number`: Time in seconds

# Examples
```jldoctest
julia> using DifferentialEquations


julia> α = π/2;

julia> TRF = 100e-6;

julia> ω1 = α/TRF;

julia> B1 = 1;

julia> ω0 = 0;

julia> R1s = 2;

julia> T2s = 10e-6;

julia> G = interpolate_greens_function(greens_superlorentzian, 0, TRF / T2s);

julia> m0 = [1];

julia> sol = solve(ODEProblem(apply_hamiltonian_sled!, m0, (0, TRF), (ω1, 1, ω0, R1s, T2s, G)), Tsit5())
retcode: Success
Interpolation: specialized 4th order "free" interpolation
t: 3-element Vector{Float64}:
 0.0
 7.475414666720001e-5
 0.0001
u: 3-element Vector{Vector{Float64}}:
 [1.0]
 [0.631392823181197]
 [0.48953654496619187]

julia> using Plots

julia> plot(sol, labels=["zs"], xlabel="t (s)", ylabel="m(t)");



```
"""
function apply_hamiltonian_sled!(d∂m∂t, m, p::NTuple{6,Any}, t)
    ω1, B1, ω0, R1s, T2s, g = p

    xs = sin(ω0 * t) * quadgk(x -> g((t - x) / T2s) * sin(ω0 * x), 0, t, order=100)[1]
    ys = cos(ω0 * t) * quadgk(x -> g((t - x) / T2s) * cos(ω0 * x), 0, t, order=100)[1]

    d∂m∂t[1] = -B1^2 * ω1^2 * (xs + ys) * m[1] + R1s * (1 - m[1])
end

function apply_hamiltonian_sled!(∂m∂t, m, p::NTuple{10,Any}, t)
    ω1, B1, ω0, m0s, R1f, R2f, Rx, R1s, T2s, g = p

    ∂m∂t[1] = - R2f * m[1] - ω0  * m[2] + B1 * ω1 * m[3]
    ∂m∂t[2] =   ω0  * m[1] - R2f * m[2]
    ∂m∂t[3] = - B1 * ω1  * m[1] - (R1f + Rx * m0s) * m[3] + Rx * (1 - m0s) * m[4] + (1 - m0s) * R1f * m[5]

    if ω0 == 0
        xs = 0
        ys = quadgk(x -> g((t - x) / T2s), 0, t, order=100)[1]
    else
        xs = sin(ω0 * t) * quadgk(x -> g((t - x) / T2s) * sin(ω0 * x), 0, t, order=100)[1]
        ys = cos(ω0 * t) * quadgk(x -> g((t - x) / T2s) * cos(ω0 * x), 0, t, order=100)[1]
    end

    ∂m∂t[4] = -B1^2 * ω1^2 * (xs + ys) * m[4] + Rx * m0s  * m[3] - (R1s + Rx * (1 - m0s)) * m[4] + m0s * R1s * m[5]
    return ∂m∂t
end