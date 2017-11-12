include("../../../../src/fourierflows.jl")

using FourierFlows, PyPlot, PyCall, JLD2

import FourierFlows.TwoModeBoussinesq

import FourierFlows.TwoModeBoussinesq: mode0apv, mode1apv, mode1speed, mode1w, 
  wave_induced_speed, wave_induced_psi, wave_induced_uv, lagrangian_mean_uv,
  calc_chi, calc_chi_uv, totalenergy, mode0energy, mode1energy, CFL,
  lagrangian_mean_psi

@pyimport mpl_toolkits.axes_grid1 as pltgrid

simname = "nk32_nu1e+32_122f_n512_ep20_Ro05_nkw32"
plotname = "./plots/wif"
filename = "../data/$simname.jld2"

# Plot parameters
eddylim = 10
Ro0 = 0.04
w0  = 0.08
sp0 = 1.0

# Recreate problem
jldopen(filename, "r") do file

  ν0, nν0 = file["params"]["ν0"], file["params"]["nν0"]
  ν1, nν1 = file["params"]["ν1"], file["params"]["nν1"]

   n = file["grid"]["nx"]
   L = file["grid"]["Lx"]
   f = file["params"]["f"]
   N = file["params"]["N"]
   m = file["params"]["m"]
  dt = file["timestepper"]["dt"]

  steps = parse.(Int, keys(file["timeseries/t"]))

  prob = TwoModeBoussinesq.InitialValueProblem(
    nx=n, Lx=L, ν0=ν0, nν0=nν0, ν1=ν1, nν1=nν1, f=f, N=N, m=m, dt=dt)

  # Non-retrievable parameters
  nkw = 32
   kw = 2π*nkw/L
    α = (N*kw)^2/(f*m)^2
    σ = f*sqrt(1+α)
   tσ = 2π/σ
   Re = L/40

  x, y = prob.grid.X/Re, prob.grid.Y/Re

  iscolorbar = false
  for (istep, step) in enumerate(steps)
    t = file["timeseries/t/$step"]
    Zh = file["timeseries/solr/$step"]
    solc = file["timeseries/solc/$step"]

    Z = irfft(Zh, prob.grid.nx) 
    u = ifft(solc[:, :, 1])
    v = ifft(solc[:, :, 2])
    p = ifft(solc[:, :, 3])

    TwoModeBoussinesq.set_Z!(prob, Z)
    TwoModeBoussinesq.set_uvp!(prob, u, v, p)

    Umax = maximum(sqrt.(prob.vars.U.^2+prob.vars.V.^2))
    
    w = mode1w(prob)
    Q = mode0apv(prob)
    sp = wave_induced_speed(σ, prob)/Umax
    psiw = wave_induced_psi(σ, prob)
    psiL = lagrangian_mean_psi(σ, prob)
    uL, vL = lagrangian_mean_uv(σ, prob)

    println(step)

    close("all")
    fig, axs = subplots(ncols=3, nrows=1, sharex=true, sharey=true, 
      figsize=(12, 5))

    axes(axs[1]); axis("equal")
    Zplot = pcolormesh(x, y, Q/f, 
      cmap="RdBu_r", vmin=-Ro0, vmax=Ro0)

    contour(x, y, psiL, 20, colors="k", linewidths=0.2, alpha=0.5)

    nquiv = 32
    iquiv = floor(Int, prob.grid.nx/nquiv)
    quiverplot = quiver(
      x[1:iquiv:end, 1:iquiv:end], y[1:iquiv:end, 1:iquiv:end],
      uL[1:iquiv:end, 1:iquiv:end], vL[1:iquiv:end, 1:iquiv:end], 
      units="x", alpha=0.2, scale=2.0, scale_units="x")


    axes(axs[2]); axis("equal")
    Qplot = pcolormesh(x, y, sp, 
      cmap="YlGnBu_r", vmin=0.0, vmax=sp0)

    contour(x, y, psiw, 20, colors="w", linewidths=0.2, alpha=0.5)

    axes(axs[3]); axis("equal")
    wplot = pcolormesh(x, y, w, 
      cmap="RdBu_r", vmin=-w0, vmax=w0)


    plots = [Zplot, wplot, Qplot]
    cbs = []
    for (i, ax) in enumerate(axs)
      ax[:set_adjustable]("box-forced")
      ax[:set_xlim](-eddylim, eddylim)
      ax[:set_ylim](-eddylim, eddylim)
      ax[:tick_params](axis="both", which="both", length=0)

      divider = pltgrid.make_axes_locatable(ax)
      cax = divider[:append_axes]("top", size="5%", pad="5%")
      cb = colorbar(plots[i], cax=cax, orientation="horizontal")

      cb[:ax][:xaxis][:set_ticks_position]("top")
      cb[:ax][:xaxis][:set_label_position]("top")
      cb[:ax][:tick_params](axis="x", which="both", length=0)

      push!(cbs, cb)
      iscolorbar = true
    end

    axs[1][:set_xlabel](L"x/R")
    axs[2][:set_xlabel](L"x/R")
    axs[3][:set_xlabel](L"x/R")
    axs[1][:set_ylabel](L"y/R")

    cbs[1][:set_ticks]([-Ro0, 0.0, Ro0])
    cbs[2][:set_ticks]([-Ro0, 0.0, Ro0])
    cbs[3][:set_ticks]([-w0, 0.0, w0])

    cbs[1][:set_label](L"Q/f", labelpad=12.0)
    cbs[2][:set_label](L"| \nabla \Psi^w |^2", labelpad=12.0)
    cbs[3][:set_label](L"\hat w(z=0) = w + w^*", labelpad=12.0)

    msg = @sprintf("\$t = %02d\$ wave periods", t/tσ)
    figtext(0.51, 0.95, msg, horizontalalignment="center", fontsize=14)

    tight_layout(rect=(0.00, 0.00, 0.95, 0.90), h_pad=0.05)

    pause(0.1)
    
    #savename = @sprintf("%s_%06d.png", plotname, istep)
    #savefig(savename, dpi=240)
  end

end
