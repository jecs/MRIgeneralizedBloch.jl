##
function gBloch_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter)

    # Define g(τ) and its derivative as ApproxFuns
    g = (τ) -> quadgk(ct -> exp(- τ^2 * (3 * ct^2 - 1)^2 / 8), 0.0, 1.0)[1]
    x = Fun(identity, 0..(maximum(TRF) / T2s))
    ga = g(x)
    if any(isa.(grad_list, grad_T2s))
        dg_oT2 = (τ) -> quadgk(ct -> exp(- τ^2 * (3.0 * ct^2 - 1)^2 / 8.0) * (τ^2 * (3.0 * ct^2 - 1)^2 / 4.0), 0.0, 1.0)[1]
        dg_oT2_a = dg_oT2(x)
    else
        dg_oT2_a = []
    end

    # initialization and memory allocation
    N_s = 5 * (1 + length(grad_list))
    h(p, t; idxs=nothing) = typeof(idxs) <: Number ? 0.0 : zeros(N_s)
    alg = MethodOfSteps(DP8())
    s = zeros(N_s, length(TRF))
    u0 = zeros(N_s)
    u0[3] = (1 - m0s)
    u0[4] = m0s
    u0[5] = 1.0

    # prep pulse 
    sol = solve(DDEProblem(gBloch_Hamiltonian_ApproxFun!, u0, h, (0.0, TRF[2]), (-ω1[2] / 2, B1, ω0, m0s, R1, R2f, T2s, Rx, ga, dg_oT2_a, grad_list)), alg)  
    u0 = sol[end]
    
    T_FP = (TR - TRF[2]) / 2 - TRF[1] / 2
    sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6())
    u0 = sol[end]
    
    for ic = 0:(Niter - 1)
        # free precession for TRF/2
        sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, TRF[1] / 2), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6())
        u0 = sol[end]
        
        # inversion pulse with crusher gradients (assumed to be instantanious)
        u00 = u0[1:3]
        u0[1:5:end] .*= -sin(B1 * ω1[1] * TRF[1] / 2)^2
        u0[2:5:end] .*= sin(B1 * ω1[1] * TRF[1] / 2)^2
        u0[3:5:end] .*= cos(B1 * ω1[1] * TRF[1])

        # calculate saturation of RF pulse
        sol = solve(DDEProblem(gBloch_Hamiltonian_ApproxFun!, u0[1:5], h, (0.0, TRF[1]), ((-1)^(1 + ic) * ω1[1], B1, ω0, m0s, 0.0, 0.0, T2s, 0.0, 4, ga)), alg)
        u0[4] = sol[end][4]

        for i in eachindex(grad_list)
            if isa(grad_list[i], grad_B1)
                u0[5i + 1] -= u00[1] * sin(B1 * ω1[1] * TRF[1] / 2) * cos(B1 * ω1[1] * TRF[1] / 2) * ω1[1] * TRF[1]
                u0[5i + 2] += u00[2] * sin(B1 * ω1[1] * TRF[1] / 2) * cos(B1 * ω1[1] * TRF[1] / 2) * ω1[1] * TRF[1]
                u0[5i + 3] -= u00[3] * sin(B1 * ω1[1] * TRF[1]) * ω1[1] * TRF[1]
            end

            sol = solve(DDEProblem(gBloch_Hamiltonian_ApproxFun!, u0[5i + 1:5i + 5], h, (0.0, TRF[1]), ((-1)^(1 + ic) * ω1[1], B1, ω0, m0s, 0.0, 0.0, T2s, 0.0, 4, ga)), alg)
            u0[5i + 4] = sol[end][4]
        end

        # free precession
        T_FP = TR - TRF[2] / 2
        TE = TR / 2
        sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6(), save_everystep=false, saveat=TE)
        s[:,1] = sol[2]
        s[1:5:end,1] .*= (-1)^(1 + ic)
        s[2:5:end,1] .*= (-1)^(1 + ic)
        u0 = sol[end]

        for ip = 2:length(TRF)
            sol = solve(DDEProblem(gBloch_Hamiltonian_ApproxFun!, u0, h, (0.0, TRF[ip]), ((-1)^(ip + ic) * ω1[ip], B1, ω0, m0s, R1, R2f, T2s, Rx, ga, dg_oT2_a, grad_list)), alg)
            u0 = sol[end]
    
            T_FP = TR - TRF[ip] / 2 - TRF[mod(ip, length(TRF)) + 1] / 2
            # if ip < length(TRF)
            #     T_FP -= TRF[ip + 1] / 2
            # end
            TE = TR / 2 - TRF[ip] / 2
            sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6(), save_everystep=false, saveat=TE)
            if sol.t[2] / TE - 1 > 1e-10
                throw(DimensionMismatch("sol.t[2] is not equal to TE"))
            end
            s[:,ip] = sol[2]
            s[1:5:end,ip] .*= (-1)^(ip + ic)
            s[2:5:end,ip] .*= (-1)^(ip + ic)
            u0 = sol[end]
        end
    end
    return s
end

function gBloch_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, Niter)
    s = gBloch_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, [], Niter)
    s = s[1,:] + 1im * s[2,:]
    return s
end

function gBloch_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter)
    s = gBloch_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter)
    s = s[1:5:end,:] + 1im * s[2:5:end,:]
    return s
end

function Graham_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter)
    # initialization and memory allocation 
    N_s = 5 * (1 + length(grad_list))
    s = zeros(N_s, length(TRF))
    u0 = zeros(N_s)
    u0[3] = (1 - m0s)
    u0[4] = m0s
    u0[5] = 1.0

    # prep pulse 
    sol = solve(ODEProblem(Graham_Hamiltonian!, u0, (0.0, TRF[2]), (-ω1[2] / 2, B1, ω0, TRF[2], m0s, R1, R2f, T2s, Rx, grad_list)), Vern6(), save_everystep=false)    
    u0 = sol[end]
    
    T_FP = TR / 2 - TRF[2] / 2 - TRF[1] / 2
    sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6(), save_everystep=false)
    u0 = sol[end]
    
    # TODO: Implement inversion pulse with crusher gradients
    for ic = 0:(Niter - 1)
        # free precession for TRF/2
        sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, TRF[1] / 2), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6(), save_everystep=false)
        u0 = sol[end]

        # inversion pulse with crusher gradients (assumed to be instantanious)
        u00 = u0[1:3]
        u0[1:5:end] .*= -sin(B1 * ω1[1] * TRF[1] / 2)^2
        u0[2:5:end] .*= sin(B1 * ω1[1] * TRF[1] / 2)^2
        u0[3:5:end] .*= cos(B1 * ω1[1] * TRF[1])

        # calculate saturation of RF pulse
        sol = solve(ODEProblem(Graham_Hamiltonian!, u0[1:5], (0.0, TRF[2]), ((-1)^(1 + ic) * ω1[1], B1, ω0, TRF[1], m0s, 0.0, 0.0, T2s, 0.0)), Vern6(), save_everystep=false)  
        u0[4] = sol[end][4]

        for i in eachindex(grad_list)
            if isa(grad_list[i], grad_B1)
                u0[5i + 1] -= u00[1] * sin(B1 * ω1[1] * TRF[1] / 2) * cos(B1 * ω1[1] * TRF[1] / 2) * ω1[1] * TRF[1]
                u0[5i + 2] += u00[2] * sin(B1 * ω1[1] * TRF[1] / 2) * cos(B1 * ω1[1] * TRF[1] / 2) * ω1[1] * TRF[1]
                u0[5i + 3] -= u00[3] * sin(B1 * ω1[1] * TRF[1]) * ω1[1] * TRF[1]
            end

            sol = solve(ODEProblem(Graham_Hamiltonian!, u0[5i + 1:5i + 5], (0.0, TRF[2]), ((-1)^(1 + ic) * ω1[1], B1, ω0, TRF[1], m0s, 0.0, 0.0, T2s, 0.0)), Vern6(), save_everystep=false)  
            u0[5i + 4] = sol[end][4]
        end

        # free precession
        T_FP = TR - TRF[2] / 2
        TE = TR / 2
        sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), alg, save_everystep=false, saveat=TE)
        s[:,1] = sol[2]
        s[1:5:end,1] .*= (-1)^(1 + ic)
        s[2:5:end,1] .*= (-1)^(1 + ic)
        u0 = sol[end]

        for ip = 2:length(TRF)
            sol = solve(ODEProblem(Graham_Hamiltonian!, u0, (0.0, TRF[ip]), ((-1)^(ip + ic) * ω1[ip], B1, ω0, TRF[ip], m0s, R1, R2f, T2s, Rx, grad_list)), Vern6(), save_everystep=false)
            u0 = sol[end]
    
            T_FP = TR - TRF[ip] / 2 - TRF[mod(ip, length(TRF)) + 1] / 2
            TE = TR / 2 - TRF[ip] / 2
            sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), Vern6(), save_everystep=false, saveat=TE)
            if sol.t[2] / TE - 1 > 1e-10
                throw(DimensionMismatch("sol.t[2] is not equal to TE"))
            end
            s[:,ip] = sol[2]
            s[1:5:end,ip] .*= (-1)^(ip + ic)
            u0 = sol[end]
        end
    end
    return s
end

function Graham_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, Niter)
    s = Graham_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, [], Niter)
    s = s[1,:] + 1im * s[2,:]
    return s
end

function Graham_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter)
    s = Graham_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter)
    s = s[1:5:end,:] + 1im * s[2:5:end,:]
    return s
end

function PreCompute_Saturation_gBloch(TRF_min, TRF_max, T2s_min, T2s_max, ω1_min, ω1_max, B1_min, B1_max)

    # approximate saturation
    g_SL = (τ) -> quadgk(ct -> exp(- τ^2 * (3 * ct^2 - 1)^2 / 8), 0.0, sqrt(1 / 3), 1.0)[1]
    x = Fun(identity, 0..(TRF_max / T2s_min))
    g_SLa = g_SL(x)
    h(p, t) = [1.0]

    function gBloch_Hamiltonian_ApproxFun!(du, u, h, p::NTuple{3,Any}, t)
        ωy, T2s, g = p
        du[1] = -ωy^2 * quadgk(x -> g((t - x) / T2s) * h(p, x)[1], 0.0, t)[1]
    end
    
    S = Chebyshev((TRF_min / T2s_max)..(TRF_max / T2s_min)) * Chebyshev((B1_min * ω1_min * T2s_min)..(B1_max * ω1_max * T2s_max))
    _points = points(S, 10^3) 
    fDDE(xy) = solve(DDEProblem(gBloch_Hamiltonian_ApproxFun!, [1.0], h, (0.0, xy[1]), (xy[2], 1.0, g_SLa)), MethodOfSteps(DP8()))[end][1]
    fapprox = Fun(S, transform(S, fDDE.(_points)))
    dfd1 = Derivative(S, [1,0]) * fapprox
    dfd2 = Derivative(S, [0,1]) * fapprox

    function Rrf(TRF, ω1, B1, T2s)
        return -log(fapprox([TRF / T2s, B1 * ω1 * T2s])) / TRF
    end

    function Rrf_dB1(TRF, ω1, B1, T2s)
        _fapprox = fapprox([TRF / T2s, B1 * ω1 * T2s])
        _dfd2 = dfd2(TRF / T2s, B1 * ω1 * T2s)
        _Rrf = -log(_fapprox) / TRF
        _dRrfdB1 = - _dfd2 * ω1 * T2s / (TRF * _fapprox)
        return (_Rrf, _dRrfdB1)
    end

    function Rrf_dB1_dT2s(TRF, ω1, B1, T2s)
        _fapprox = fapprox([TRF / T2s, B1 * ω1 * T2s])
        _dfd1 = dfd1(TRF / T2s, B1 * ω1 * T2s)
        _dfd2 = dfd2(TRF / T2s, B1 * ω1 * T2s)
        _Rrf = -log(_fapprox) / TRF
        _dRrfdT2s = (_dfd1 * TRF / T2s^2 - _dfd2 * B1 * ω1) / (TRF * _fapprox)
        _dRrfdB1 = - _dfd2 * ω1 * T2s / (TRF * _fapprox)
        return (_Rrf, _dRrfdB1, _dRrfdT2s)
    end

    return (Rrf, Rrf_dB1, Rrf_dB1_dT2s)
end

function PreCompute_Saturation_Graham(TRF_min, TRF_max, T2s_min, T2s_max)

    f_PSD = (τ) -> quadgk(ct -> 1.0 / abs(1 - 3 * ct^2) * (4 / τ / abs(1 - 3 * ct^2) * (exp(- τ^2 / 8 * (1 - 3 * ct^2)^2) - 1) + sqrt(2π) * erf(τ / 2 / sqrt(2) * abs(1 - 3 * ct^2))), 0.0, 1.0)[1]

    x = Fun(identity, (TRF_min / T2s_max)..(TRF_max / T2s_min))
    f_PSD_a = f_PSD(x)
    df_PSD_a = f_PSD_a'
    println("gonna be fast...")
    Rrf(ω1, TRF, B1, T2s) = f_PSD_a(TRF / T2s) * B1^2 * ω1^2 * T2s
    
    function Rrf_dB1(TRF, ω1, B1, T2s)
        _f_PSD_a = f_PSD_a(TRF / T2s)
        _Rrf = _f_PSD_a * B1^2 * ω1^2 * T2s
        _dRrfdB1 = _f_PSD_a * 2 * B1 * ω1^2 * T2s
        return (_Rrf, _dRrfdB1)
    end

    function Rrf_dB1_dT2s(TRF, ω1, B1, T2s)
        _f_PSD_a = f_PSD_a(TRF / T2s)
        _Rrf = _f_PSD_a * B1^2 * ω1^2 * T2s
        _dRrfdB1 = _f_PSD_a * 2 * B1 * ω1^2 * T2s
        _RrfdT2s = (_f_PSD_a - df_PSD_a(TRF / T2s) * TRF / T2s) * B1^2 * ω1^2
        return (_Rrf, _dRrfdB1, _RrfdT2s)
    end
    return (Rrf, Rrf_dB1, Rrf_dB1_dT2s)
end

function LinearApprox_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter, Rrf_T)
    # initialization and memory allocation
    N_s = 5 * (1 + length(grad_list))
    alg = Vern6()
    s = zeros(N_s, length(TRF))
    u0 = zeros(N_s)
    u0[3] = (1 - m0s)
    u0[4] = m0s
    u0[5] = 1.0

    # prep pulse 
    _dRrf = Rrf_T[3](TRF[2], ω1[2] / 2, B1, T2s)
    sol = solve(ODEProblem(Linear_Hamiltonian!, u0, (0.0, TRF[2]), (-ω1[2] / 2, B1, ω0, m0s, R1, R2f, Rx, _dRrf, grad_list)), alg, save_everystep=false)
    u0 = sol[end]

    T_FP = TR / 2 - TRF[2] / 2 - TRF[1] / 2
    sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), alg, save_everystep=false)
    u0 = sol[end]
    
    for ic = 0:(Niter - 1)
        # free precession for TRF/2
        sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, TRF[1] / 2), (ω0, m0s, R1, R2f, Rx, grad_list)), alg, save_everystep=false)
        u0 = sol[end]

        # inversion pulse with crusher gradients (assumed to be instantanious)
        u00 = u0[1:3]
        u0[1:5:end] .*= -sin(B1 * ω1[1] * TRF[1] / 2)^2
        u0[2:5:end] .*= sin(B1 * ω1[1] * TRF[1] / 2)^2
        u0[3:5:end] .*= cos(B1 * ω1[1] * TRF[1])

        # calculate saturation of RF pulse
        _dRrf = Rrf_T[1](TRF[1], ω1[1], B1, T2s)
        sol = solve(ODEProblem(Linear_Hamiltonian!, u0[1:5], (0.0, TRF[1]), ((-1)^(1 + ic) * ω1[1], B1, ω0, m0s, 0.0, 0.0, 0.0, _dRrf)), alg, save_everystep=false)
        u0[4] = sol[end][4]

        for i in eachindex(grad_list)
            if isa(grad_list[i], grad_B1)
                u0[5i + 1] -= u00[1] * sin(B1 * ω1[1] * TRF[1] / 2) * cos(B1 * ω1[1] * TRF[1] / 2) * ω1[1] * TRF[1]
                u0[5i + 2] += u00[2] * sin(B1 * ω1[1] * TRF[1] / 2) * cos(B1 * ω1[1] * TRF[1] / 2) * ω1[1] * TRF[1]
                u0[5i + 3] -= u00[3] * sin(B1 * ω1[1] * TRF[1]) * ω1[1] * TRF[1]
            end

            _dRrf = Rrf_T[1](TRF[1], ω1[1], B1, T2s)
            sol = solve(ODEProblem(Linear_Hamiltonian!, u0[5i + 1:5i + 5], (0.0, TRF[1]), ((-1)^(1 + ic) * ω1[1], B1, ω0, m0s, 0.0, 0.0, 0.0, _dRrf)), alg, save_everystep=false)
            u0[5i + 4] = sol[end][4]
        end

        # free precession
        T_FP = TR - TRF[2] / 2
        TE = TR / 2
        sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), alg, save_everystep=false, saveat=TE)
        s[:,1] = sol[2]
        s[1:5:end,1] .*= (-1)^(1 + ic)
        s[2:5:end,1] .*= (-1)^(1 + ic)
        u0 = sol[end]

        for ip = 2:length(TRF)
            _dRrf = Rrf_T[3](TRF[ip], ω1[ip], B1, T2s)
            sol = solve(ODEProblem(Linear_Hamiltonian!, u0, (0.0, TRF[ip]), ((-1)^(ip + ic) * ω1[ip], B1, ω0, m0s, R1, R2f, Rx, _dRrf, grad_list)), alg, save_everystep=false)
            u0 = sol[end]
    
            T_FP = TR - TRF[ip] / 2 - TRF[mod(ip, length(TRF)) + 1] / 2
            TE = TR / 2 - TRF[ip] / 2
            sol = solve(ODEProblem(FreePrecession_Hamiltonian!, u0, (0.0, T_FP), (ω0, m0s, R1, R2f, Rx, grad_list)), alg, save_everystep=false, saveat=TE)
            if sol.t[2] / TE - 1 > 1e-10
                throw(DimensionMismatch("sol.t[2] is not equal to TE"))
            end
            s[:,ip] = sol[2]
            s[1:5:end,ip] .*= (-1)^(ip + ic)
            s[2:5:end,ip] .*= (-1)^(ip + ic)
            u0 = sol[end]
        end
    end
    return s
end

function LinearApprox_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, Niter, Rrf_T)
    s = LinearApprox_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, [], Niter, Rrf_T)
    s = s[1,:] + 1im * s[2,:]
    return s
end

function LinearApprox_calculate_signal(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter, Rrf_T)
    s = LinearApprox_calculate_magnetization(ω1, TRF, TR, ω0, B1, m0s, R1, R2f, Rx, T2s, grad_list, Niter, Rrf_T)
    s = s[1:5:end,:] + 1im * s[2:5:end,:]
    return s
end