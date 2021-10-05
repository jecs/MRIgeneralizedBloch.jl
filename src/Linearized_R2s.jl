"""
    precompute_R2sl(TRF_min, TRF_max, T2s_min, T2s_max, α_min, α_max, B1_min, B1_max[; greens=greens_superlorentzian])

Pre-compute and interpolate the linearized `R2sl(TRF, α, B1, T2s)` and its derivatives `dR2sldB1(TRF, α, B1, T2s)` and `R2sldT2s(TRF, α, B1, T2s)` in the range specified by the arguments.

The function solves the generalized Bloch equations of an isolated semi-solid pool for values in the specified range, calulates the linearized R2sl that minimizes the error of `zs` at the end of the RF-pulse, and interpolates between the different samples. 

# Arguemnts
- `TRF_min::Number`: lower bound of the RF-pulse duration range in seconds
- `TRF_max::Number`: upper bound of the RF-pulse duration range in seconds
- `T2s_min::Number`: lower bound of the `T2s` range in seconds
- `T2s_max::Number`: upper bound of the `T2s` range in seconds
- `α_min::Number`: lower bound of the flip angle range in radians
- `α_max::Number`: upper bound of the flip angle range in radians
- `B1_min::Number`: lower bound of the B1 range, normalized so that `B1 = 1` corresponds to a perfectly calibrated RF field
- `B1_max::Number`: upper bound of the B1 range, normalized so that `B1 = 1` corresponds to a perfectly calibrated RF field

Optional:
- `greens=greens_superlorentzian`: Greens function in the form `G(κ) = G((t-τ)/T2s)`. This package supplies the three Greens functions `greens=greens_superlorentzian` (default), `greens=greens_lorentzian`, and `greens=greens_gaussian`

# Examples
```jldoctest
julia> (R2sl, dR2sldB1, R2sldT2s) = precompute_R2sl(100e-6, 1e-3, 5e-6, 15e-6, 0, π, 0.7, 1.3);


julia> (R2sl, dR2sldB1, R2sldT2s) = precompute_R2sl(100e-6, 1e-3, 5e-6, 15e-6, 0, π, 0.7, 1.3; greens=greens_gaussian);

```
"""
function precompute_R2sl(TRF_min, TRF_max, T2s_min, T2s_max, α_min, α_max, B1_min, B1_max; greens=greens_superlorentzian)

    # interpolate super-Lorentzian Green's function for speed purposes
    if greens == greens_superlorentzian
        G = interpolate_greens_function(greens, 0, TRF_max / T2s_min)
    else
        G = greens
    end
    mfun(p, t) = [1.0]

    function hamiltonian_1D!(du, u, mfun, p::NTuple{3,Any}, t)
        ω1, T2s, g = p
        du[1] = -ω1^2 * quadgk(x -> g((t - x) / T2s) * mfun(p, x)[1], 0.0, t)[1]
    end

    function calculate_R2sl(τ, α)
        z = solve(DDEProblem(hamiltonian_1D!, [1.0], mfun, (0, τ), (α / τ, 1, G)), MethodOfSteps(DP8()))[end][1]
    
        function f!(F, ρv)
            ρ = ρv[1]
            s = sqrt(Complex((ρ * τ)^2 - (2α)^2))
            x = exp(-ρ * τ / 2) * (cosh(s / 2) + ρ * τ / s * sinh(s / 2))
            F[1] = real(x) - z
        end
        function j!(J, ρv)
            ρ = ρv[1]
            s = sqrt(Complex((ρ * τ)^2 - (2α)^2))
            J[1] = 2τ * α^2 * exp(-ρ * τ / 2) * (s * cosh(s / 2) - 2sinh(s / 2)) / s^3
        end
    
        sol = nlsolve(f!, j!, [1.0])
        return sol.zero[1]
    end

    τv = range(TRF_min / T2s_max, TRF_max / T2s_min; length=2^6)
    αv = range(B1_min * α_min, B1_max * α_max; length=2^6)
    # A = [calculate_R2sl(τ, α) for τ in τv, α in αv]
    A = Matrix{Float64}(undef, length(τv), length(αv))
    Threads.@threads for i in CartesianIndices(A)
        A[i] = calculate_R2sl(τv[i[1]], αv[i[2]])
    end

    f = CubicSplineInterpolation((τv, αv), A)
    dfdτ(τ, α) = Interpolations.gradient(f, τ, α)[1]
    dfdα(τ, α) = Interpolations.gradient(f, τ, α)[2]
    d2fdτ2(τ, α) = Interpolations.hessian(f, τ, α)[1,1]
    d2fdα2(τ, α) = Interpolations.hessian(f, τ, α)[2,2]
    d2fdτdα(τ, α) = Interpolations.hessian(f, τ, α)[2,1]
                                            
    R2sl(TRF, α, B1, T2s) = f(TRF / T2s, B1 * α) / T2s
    
    dR2sldT2s(TRF, α, B1, T2s) = -dfdτ(TRF / T2s, B1 * α) * TRF / T2s^3 - f(TRF / T2s, B1 * α) / T2s^2
    dR2sldB1(TRF, α, B1, T2s)  = dfdα(TRF / T2s, B1 * α) * α / T2s
    
    dR2sldω1(TRF, α, B1, T2s)  = dfdα(TRF / T2s, B1 * α) * B1 * TRF / T2s
    dR2sldTRF(TRF, α, B1, T2s) = dfdτ(TRF / T2s, B1 * α) / T2s^2 + dfdα(TRF / T2s, B1 * α) * B1 * α/TRF / T2s
    

    dR2sldT2sdω1(TRF, α, B1, T2s) = -d2fdτdα(TRF / T2s, B1 * α) * B1 * TRF^2 / T2s^3 - dfdα(TRF / T2s, B1 * α) * B1 * TRF / T2s^2
    dR2sldB1dω1(TRF, α, B1, T2s) = dfdα(TRF / T2s, B1 * α) * TRF / T2s + d2fdα2(TRF / T2s, B1 * α) * B1 * TRF * α / T2s

    dR2sldT2sTRF(TRF, α, B1, T2s) = -d2fdτ2(TRF / T2s, B1 * α) * TRF / T2s^4 - d2fdτdα(TRF / T2s, B1 * α) * B1 * α / T2s^3 - dfdτ(TRF / T2s, B1 * α) / T2s^3 - dfdτ(TRF / T2s, B1 * α) / T2s^3 - dfdα(TRF / T2s, B1 * α) * B1 * α / TRF / T2s^2
    dR2sldB1dTRF(TRF, α, B1, T2s)  = d2fdτdα(TRF / T2s, B1 * α) * α / T2s^2 + d2fdα2(TRF / T2s, B1 * α) * B1 * α^2 / TRF / T2s + dfdα(TRF / T2s, B1 * α) * α / TRF / T2s

    return (R2sl, dR2sldT2s, dR2sldB1, dR2sldω1, dR2sldTRF, dR2sldT2sdω1, dR2sldB1dω1, dR2sldT2sTRF, dR2sldB1dTRF)
end


function evaluate_R2sl_vector(α, TRF, B1, T2s, R2slT, grad_list)
    _R2s = similar(α)
    _dR2sdT2s = similar(α)
    _dR2sdB1 = similar(α)

    for i = 1:length(α)
        _R2s[i] = R2slT[1](TRF[i], α[i], B1, T2s)
    end
    if any(isa.(grad_list, grad_T2s))
        for i = 1:length(α)
            _dR2sdT2s[i] = R2slT[2](TRF[i], α[i], B1, T2s)
        end
    end
    if any(isa.(grad_list, grad_B1))
        for i = 1:length(α)
            _dR2sdB1[i] = R2slT[3](TRF[i], α[i], B1, T2s)
        end
    end
    return (_R2s, _dR2sdT2s, _dR2sdB1)
end

function evaluate_R2sl_vector_OCT(α, TRF, B1, T2s, R2slT, grad_list)
    (_R2s, _dR2sdT2s, _dR2sdB1) = evaluate_R2sl_vector(α, TRF, B1, T2s, R2slT, grad_list)

    _dR2sldω1      = similar(α)
    _dR2sldTRF     = similar(α)
    _dR2sldT2sdω1  = similar(α)
    _dR2sldB1dω1   = similar(α)
    _dR2sldT2sdTRF = similar(α)
    _dR2sldB1dTRF  = similar(α)

    for i = 1:length(α)
        _dR2sldω1[i]      = R2slT[4](TRF[i], α[i], B1, T2s)
        _dR2sldTRF[i]     = R2slT[5](TRF[i], α[i], B1, T2s)
        _dR2sldT2sdω1[i]  = R2slT[6](TRF[i], α[i], B1, T2s)
        _dR2sldB1dω1[i]   = R2slT[7](TRF[i], α[i], B1, T2s)
        _dR2sldT2sdTRF[i] = R2slT[8](TRF[i], α[i], B1, T2s)
        _dR2sldB1dTRF[i]  = R2slT[9](TRF[i], α[i], B1, T2s)
    end
    return (_R2s, _dR2sdT2s, _dR2sdB1, _dR2sldω1, _dR2sldTRF, _dR2sldT2sdω1, _dR2sldB1dω1, _dR2sldT2sdTRF, _dR2sldB1dTRF)
end