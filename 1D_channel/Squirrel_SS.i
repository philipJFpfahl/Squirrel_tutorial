################################################################################
# Properties 
################################################################################
L = 10
beta = 600e-5
lambda = 1
nx =50 

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

################################################################################
# Define variables here its just a placeholder 
################################################################################
[Variables]
  [power_scalar]
    family = SCALAR
    order = FIRST
    initial_condition = 1
  []
[]

################################################################################
# Variable does not change over time 
################################################################################
[ScalarKernels]
  [Dt]
    type = ODETimeDerivative
    variable = power_scalar
  []
[]

[AuxVariables]
  [flux]
    type = MooseVariableFVReal
  []
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
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


[Executioner]
  type = Transient
  dt = 1e9
  end_time = 1e18
  solve_type = 'PJFNK'
  petsc_options_iname = '-pc_type -pc_factor_shift_type'
  petsc_options_value = 'lu NONZERO'
  line_search = 'none'
  nl_abs_tol = 1e-16
  nl_rel_tol = 1e-16
  l_max_its = 200
[]

[Outputs]
  exodus = true
[]


[Postprocessors]
 [Rho_Flow]
  type = ParsedPostprocessor
  function = 'beta-S'
  pp_names = 'S'
  constant_names =  'beta'
  constant_expressions ='${beta}'
 []
 [B]
  type = TwoValuesL2Norm
  variable = flux
  other_variable = flux
  execute_on = 'initial'
  execution_order_group = -1
  block = 1
 []
 [S] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = C
  Norm = B
  lambda = ${lambda}
  execute_on = 'initial timestep_end'
  block = 1
 [] 
[]
