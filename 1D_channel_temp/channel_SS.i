################################################################################
# Properties 
################################################################################
L = 10
beta = 600e-5
lambda = 1
nx = 50 
vel = 1

################################################################################
# Meshing 
################################################################################
[Mesh]
    #generate active core region and out of core region
    [cmbn]
        type = CartesianMeshGenerator
        dim = 1
        dx = '${fparse L/2} ${fparse L/2}'
        ix = '${nx} ${nx}'
        subdomain_id = '1 0'
      []
[]

[Problem]
    kernel_coverage_check=false
[]

################################################################################
# Define variables that are solved for 
################################################################################
[Variables]
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
  [T]
      family = MONOMIAL
      order = CONSTANT
      fv = true
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
    []
[]


################################################################################
# Define Kernels 
################################################################################
[FVKernels]
################################################################################
# Define scalar variable kernel 
################################################################################
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
    v = "C"
  []
  #DNP production kernel
  [C_external]
    type = FVCoupledForce
    variable = C
    coef = ${fparse beta}  
    v = 'flux'
    block = '1'
  []
################################################################################
# Define temperature variable kernel 
################################################################################
  [T_time]
    type = FVTimeKernel
    variable = T
  []
  #Advection kernel
  [T_advection]
    type = FVAdvection
    variable = T
    velocity = '${vel} 0 0'
  []
  #Heat source Kernel
  [T_heating]
  []
  #HX kernel
  [T_cooling]
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
  [inlet_T]
    type = FVFunctorDirichletBC
    boundary = 'left'
    variable = T
    functor = BC_T 
  []
  [Outlet_T]
  []
[]


[FVICs]
  [flux_ic]
    type = FVFunctionIC
    variable = 'flux'
    function = parsed_function
  []
[]

[Functions]
  [parsed_function]
    type = ParsedFunction
    expression = '0.5*sin(2*x*pi/L)'
    symbol_names = 'L'
    symbol_values = '${L}'
  []
[]

################################################################################
# EXECUTION / SOLVE
################################################################################

[Executioner]
  type = Transient

  end_time = 1e10
  # this timestepper increases the step size, so that a steady state can be found
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.01
    optimal_iterations = 20
    iteration_window = 2
    growth_factor = 2
    cutback_factor = 0.5
  []
  steady_state_detection = true
  steady_state_tolerance = 1e-12

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
  csv = true
  exodus = true
  # Reduce base output
  print_linear_converged_reason =       false
  print_linear_residuals =              false
  print_nonlinear_converged_reason =    false
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
  # Find the temperature at the end of the channel
  [BC_T]
    type = PointValue
    point = '${L} 0 0'
    variable = 'T'
    execute_on = " initial timestep_end"
  []
[]

[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel_SS.i"
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
    [push_T]
    [] 
[]

