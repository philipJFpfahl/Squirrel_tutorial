################################################################################
# Properties 
################################################################################
L = 10
beta = 600e-5
lambda = 1
nx = 50 
vel = 0

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
    # area = 1
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

