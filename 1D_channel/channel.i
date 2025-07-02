################################################################################
# Properties 
################################################################################
L = 10
beta = 100e-5
lambda = 1
vel = 1

################################################################################
# Meshing 
################################################################################
[Mesh]
  file = 'channel_SS_out.e'
[]

[Problem]
    kernel_coverage_check=false
    allow_initial_conditions_with_restart = true
[]

################################################################################
# Define variables that are solved for 
################################################################################
[Variables]
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file_var = 'C'
  []
[]

################################################################################
# Define variables that are known 
################################################################################
[AuxVariables]
    [flux]
        family = MONOMIAL
        order = CONSTANT
        fv = true
        initial_from_file_var = 'flux'
    []
[]


################################################################################
# Define Kernels 
################################################################################
[FVKernels]
  #Time kernel
  [C_time]
    type = FVTimeKernel
    variable = C
  []
  #Advection kernel
  [C_advection]
    type = FVAdvection
    variable = C
    velocity = '${vel} 0 0'
  []
  #DNP decay kernel
  [C_interal]
    type = FVCoupledForce
    variable = C
    coef =   ${fparse -lambda}
    v = 1
  []
  #DNP production kernel
  [C_external]
    type = FVCoupledForce
    variable = C
    coef = ${fparse beta}  
    v = 'flux'
    block = '1'
  []
[]

################################################################################
# Boundary and Initial conditions 
################################################################################

[FVBCs]
  [inlet_C]
    type = FVFunctorDirichletBC
    boundary = 'left'
    variable = C
    functor = BC_C 
  []
  [Outlet_C]
    type = FVConstantScalarOutflowBC
    velocity = '${vel} 0 0'
    variable = C
    boundary = 'right'
  []
[]

################################################################################
# EXECUTION / SOLVE
################################################################################

[Executioner]
  type = Transient

  end_time = 10

  dt = 0.1

  # Time integration scheme
  scheme = 'implicit-euler'

  # Solver parameters
  solve_type = 'NEWTON'
  line_search = 'none'

  # nonlinear solver parameters
  nl_rel_tol = 2e-13
  nl_abs_tol = 2e-13
  nl_abs_div_tol = 1e11
  nl_max_its = 15

  # linear solver parameters
  l_max_its = 50

  automatic_scaling = true
[]

################################################################################
# SIMULATION OUTPUTS
################################################################################
[Outputs]
  exodus = true
  # Reduce base output
  print_linear_converged_reason = false
  print_linear_residuals = false
  print_nonlinear_converged_reason = false
[]

################################################################################
# Post Processing 
################################################################################

[Postprocessors]
  # Find the DNP concentration at the end of the channel
  [BC_C]
    type = PointValue
    point = '${L} 0 0'
    variable = 'C'
    execute_on = " initial timestep_end"
  []
[]

################################################################################
# Use Transient Squirrel 
################################################################################
[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel.i"
      execute_on= "timestep_end "
      sub_cycling = true #false
    []
[]

[Transfers]
    [push_C]
        type = MultiAppGeneralFieldShapeEvaluationTransfer
        to_multi_app = Squirrel 
        source_variable = C 
        variable = C
        execute_on= "timestep_end initial"
    [] 
    [pull_flux]
        type = MultiAppGeneralFieldShapeEvaluationTransfer
        from_multi_app = Squirrel 
        source_variable = flux_scaled 
        variable = flux
        execute_on= "timestep_end initial"
    [] 
[]

