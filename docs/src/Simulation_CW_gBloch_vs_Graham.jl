# # Continuous Wave Simulation
# The following code replicates the continuous wave simulation of Fig. 2 and is slightly more comprehensive in the sense that all discussed models are simulated. 

# For these simulations we need the following packages:

using MRIgeneralizedBloch
using DifferentialEquations
using QuadGK
using Plots
plotlyjs(bg = RGBA(31/255,36/255,36/255,1.0), ticks=:native); nothing #hide

# and we simulate an isolated semi-solid spin pool with the following parameters:
R1 = 1.0 # 1/s
T2s = 10e-6 # s
z0 = [1.0] # initial z-magnetization
z_fun(p, t) = [1.0] # initialize history function (will be populated with an interpolation by the differential equation solver)

#src version = "v1"
#src ω1 = 1e2 * 2π # rad/s
#src ω0 = 1e3 * 2π # rad/s
#src TRF = 1 # s
version = "v2" #src
ω1 = 2000π # rad/s
ω0 = 200π # rad/s
TRF = .002 # s

t = range(0, TRF, length=1001) # plot points
tspan = (0.0, TRF) # simulation range
nothing #hide

# These parameters corrspond to Fig. 2b, the parameters for replicating Fig. 2a are `ω1 = 200π`, `ω0 = 2000π`, and `TRF = 1`. 

# ## Lorentzian lineshape
# In this script, we simulate the three lineshapes separtely, starting with the Lorentzian lineshape for which the Bloch model provides a ground truth. 

# ### Bloch model
# We can formulate the Bloch model as 
# ```math
# \partial_t \begin{pmatrix} x \\ y \\ z \\ 1 \end{pmatrix} = \begin{pmatrix} 
# -R_2 & -ω_0 & ω_1 & 0 \\ 
# ω_0 & -R_2 & 0 & 0 \\  
# -ω_1 & 0 & -R_1 & R_1 \\ 
# 0 & 0 & 0 & 0
# \end{pmatrix} \begin{pmatrix} x \\ y \\ z \\ 1 \end{pmatrix} ,
# ```
# where the matrix is the Hamiltonian of the Bloch model. For a constant ``ω_0`` and ``ω_1``, we can evaluate the Bloch model by taking the  matrix exponential of its Hamiltonian:

H(ω1, ω0, R2, R1) = [-R2  -ω0  ω1  0; 
                       ω0 -R2   0  0;
                      -ω1   0 -R1 R1;
                        0   0   0  0]

z_Bloch = similar(t)
for i = 1:length(t)
    (_, _, z_Bloch[i], _) = exp(H(ω1, ω0, 1 / T2s, R1) * t[i]) * [0; 0; 1; 1]
end

# ### Henkelman's steady-state solution
# When assuming an isolated semi-solid pool, Eq. (9) in *Henkelman, R. Mark, et al. "Quantitative interpretation of magnetization transfer." Magnetic resonance in medicine 29.6 (1993): 759-766* reduces to

g_Lorentzian(ω0) = T2s / π / (1 + (T2s * ω0)^2)
z_steady_state_Lorentzian = R1 / (R1 + π * ω1^2 * g_Lorentzian(ω0))

# where `g_Lorentzian(ω0)` is the Lorentzian lineshape. 

# ### Graham's single frequency approximation
# The lineshape is also used to calculate Graham's single frequency approximation, which describes an exponential decay with the RF-induced saturation rate `Rrf`:

Rrf = π * ω1^2 * g_Lorentzian(ω0)
z_Graham_Lorentzian = @. (Rrf * exp(-t * (R1 + Rrf)) + R1) / (R1 + Rrf)
nothing #hide

# ### Sled's model
# Sled's model is given by the ordinary differential equation (ODE)
# ```math
# \partial_t z(t) = \left(-\pi \int_0^t G(t-τ) \omega_1(τ)^2 dτ \right) z(t)  + R_1 (1-z),
# ```
# where ``G(t-τ)`` is the Green's function. The Hamiltonian of this ODE is implemented in [`apply_hamiltonian_sled!`](@ref) and can be solve the ODE solver of the [DifferentialEquations.jl](https://diffeq.sciml.ai/stable/) package:

z_Sled_Lorentzian = solve(ODEProblem(apply_hamiltonian_sled!, z0, tspan, (ω1, 1, ω0, R1, T2s, greens_lorentzian)), Tsit5())
nothing #hide


# ### generalized Bloch model
# The generalized Bloch model is given by the intgro-differential equation (IDE)
# ```math
# \partial_t z(t) = - ω_y(t) \int_0^t G(t,τ) ω_y(τ) z(τ) dτ - ω_x(t) \int_0^t G(t,τ) ω_x(τ) z(τ) dτ + R_1 (1 - z(t)) ,
# ```
# where we explicitly denote the ``ω_x`` and ``ω_y`` components of the Rabi frequency. The Hamiltonian of the IDE is implemented in [`apply_hamiltonian_gbloch!`](@ref) and we can solve this IDE with the [delay-differential equation (DDE)](https://diffeq.sciml.ai/stable/tutorials/dde_example/) solver of the [DifferentialEquations.jl](https://diffeq.sciml.ai/stable/) package:

z_gBloch_Lorentzian = solve(DDEProblem(apply_hamiltonian_gbloch!, z0, z_fun, tspan, (ω1, 1, ω0, R1, T2s, greens_lorentzian)), MethodOfSteps(DP8()))
nothing #hide

# Now that we have solved all five models, we can plot the solutions for comparison:

p = plot(1e3t, z_Bloch, label="Bloch model", xlabel="t [ms]", ylabel="zs(t)")
p = plot!(1e3t, zero(similar(t)) .+ z_steady_state_Lorentzian, label="Henkelman's steady-state")
p = plot!(1e3t, z_Graham_Lorentzian, label="Graham's model")
p = plot!(1e3t, (hcat(z_Sled_Lorentzian(t).u...)'), label="Sled's model")
p = plot!(1e3t, (hcat(z_gBloch_Lorentzian(t).u...)'), label="generalized Bloch model")
Main.HTMLPlot(p) #hide #md

# The zoom functionality of the plot reveals virtually perfect (besides numerical differences) agreement between Bloch and generalized Bloch model and suble, but existing differences when comapred to the other models. Choosing a longer T2s amplifies these differences. 

# ## Gaussian lineshape
# We can repeat the same simulation (with the exception of the Bloch model) for the Gaussian lineshape:

g_Gaussian(ω0) = T2s / sqrt(2π) * exp(-(T2s * ω0)^2 / 2)
z_steady_state_Gaussian = R1 / (R1 + π * ω1^2 * g_Gaussian(ω0))

Rrf = π * ω1^2 * g_Gaussian(ω0)
z_Graham_Gaussian = @. (Rrf * exp(-t * (R1 + Rrf)) + R1) / (R1 + Rrf)

z_gBloch_Gaussian = solve(DDEProblem(apply_hamiltonian_gbloch!, z0, z_fun, tspan, (ω1, 1, ω0, R1, T2s, greens_gaussian)), MethodOfSteps(DP8()))

z_Sled_Gaussian = solve(ODEProblem(apply_hamiltonian_sled!, z0, tspan, (ω1, 1, ω0, R1, T2s, greens_gaussian)), Tsit5())

p = plot(1e3t, zero(similar(t)) .+ z_steady_state_Gaussian, label="Henkelman's steady-state")
p = plot!(1e3t, z_Graham_Gaussian, label="Graham' model")
p = plot!(1e3t, (hcat(z_Sled_Gaussian(t).u...)'), label="Sled's model")
p = plot!(1e3t, (hcat(z_gBloch_Gaussian(t).u...)'), label="generalized Bloch model")
Main.HTMLPlot(p) #hide #md

# ## super-Lorentzian lineshape
# And we can repeat the same simulation (with the exception of the Bloch model) for the super-Lorentzian lineshape, which reveals the most pronounced deviations between the models due to the substantially slower decay of the Green's function:

g_superLorentzian(ω0) = sqrt(2 / π) * T2s * quadgk(ct -> exp(-2 * (T2s * ω0 / abs(3 * ct^2 - 1))^2) / abs(3 * ct^2 - 1), 0.0, sqrt(1 / 3), 1)[1]
z_steady_state_superLorentzian = R1 / (R1 + π * ω1^2 * g_superLorentzian(ω0))
plot(1e3t, zero(similar(t)) .+ z_steady_state_superLorentzian, label="Henkelman's steady-state (super-Lorentzian)")

Rrf = π * ω1^2 * g_superLorentzian(ω0)
z_Graham_superLorentzian = @. (Rrf * exp(-t * (R1 + Rrf)) + R1) / (R1 + Rrf)
plot!(1e3t, z_Graham_superLorentzian, label="Graham super-Lorentzian")

G_superLorentzian = interpolate_greens_function(greens_superlorentzian, 0, TRF/T2s)
z_gBloch_superLorentzian = solve(DDEProblem(apply_hamiltonian_gbloch!, z0, z_fun, tspan, (ω1, 1, ω0, R1, T2s, G_superLorentzian)), MethodOfSteps(DP8()))
plot!(1e3t, (hcat(z_gBloch_superLorentzian(t).u...)'), label="gBloch super-Lorentzian")

z_Sled_superLorentzian = solve(ODEProblem(apply_hamiltonian_sled!, z0, tspan, (ω1, 1, ω0, R1, T2s, G_superLorentzian)), Tsit5())
p = plot!(1e3t, (hcat(z_Sled_superLorentzian(t).u...)'), label="Sled super-Lorentzian")
Main.HTMLPlot(p) #hide #md





#src ##################################################################
#src export data for plotting
#src ##################################################################
using Printf #src
io = open(expanduser(string("~/Documents/Paper/2021_MT_IDE/Figures/CW_Henkelman_steady_state_", version, ".txt")), "w") #src
write(io, "t_s Lorentzian Gaussian superLorentzian \n") #src
write(io, @sprintf("%1.3e %1.3e %1.3e %1.3e \n", 0, z_steady_state_Lorentzian, z_steady_state_Gaussian, z_steady_state_superLorentzian)) #src
write(io, @sprintf("%1.3e %1.3e %1.3e %1.3e \n", t[end], z_steady_state_Lorentzian, z_steady_state_Gaussian, z_steady_state_superLorentzian)) #src
close(io) #src
    
io = open(expanduser(string("~/Documents/Paper/2021_MT_IDE/Figures/CW_SpinDynamics_", version, ".txt")), "w") #src
write(io, "t_s t_ms z_Bloch z_gBloch_Lorentzian z_gBloch_Gaussian z_gBloch_superLorentzian z_Graham_Lorentzian z_Graham_Gaussian z_Graham_superLorentzian z_Sled_Lorentzian z_Sled_Gaussian z_Sled_superLorentzian \n") #src
for i = 1:length(t) #src
    write(io, @sprintf("%1.3e %1.3e %1.3e %1.3e %1.3e %1.3e %1.3e %1.3e %1.3e %1.3e %1.3e %1.3e \n", t[i], t[i]*1e3, z_Bloch[i], z_gBloch_Lorentzian(t[i])[1], z_gBloch_Gaussian(t[i])[1], z_gBloch_superLorentzian(t[i])[1], z_Graham_Lorentzian[i], z_Graham_Gaussian[i], z_Graham_superLorentzian[i], z_Sled_Lorentzian(t[i])[1], z_Sled_Gaussian(t[i])[1], z_Sled_superLorentzian(t[i])[1])) #src
end #src
close(io) #src
