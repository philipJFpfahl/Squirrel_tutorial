################################################################################
# Properties 
################################################################################
beta = 600e-5
lambda = 1
LAMBDA = 1e-4
rho_external = 1.217096e-03

################################################################################
# Meshing 
################################################################################
[Mesh]
  file = 'channel_SS_out_Squirrel0.e'
[]
[Problem]
    kernel_coverage_check=false
    allow_initial_conditions_with_restart = true
[]


################################################################################
# Variable now changes over time 
################################################################################
[Variables]
  [power_scalar]
    family = SCALAR
    order = FIRST
    initial_condition = 1
  []
[]

[ScalarKernels]
  [Dt]
    type = ODETimeDerivative
    variable = power_scalar
  []
################################################################################
# add the right hand side of the ODE 
################################################################################
  [expression]
    type = ParsedODEKernel
    expression = '-(rho_external+rho_insertion-beta)/LAMBDA*power_scalar-S/LAMBDA'
    constant_expressions = '${fparse rho_external} ${fparse beta} ${fparse LAMBDA}'
    constant_names = 'rho_external beta LAMBDA'
    variable = power_scalar
    postprocessors = 'S rho_insertion '
  []
[]


[AuxVariables]
  [flux]
    type = MooseVariableFVReal
    initial_from_file_var = 'flux'
  []
################################################################################
# Scaled flux shape  
################################################################################
  [flux_scaled]
    type = MooseVariableFVReal
    initial_from_file_var = 'flux'
  []
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file_var = 'C'
  []
[]

[AuxKernels]
    [power_scaling]
        type = ScalarMultiplication
        variable = flux_scaled
        source_variable = flux 
        factor = power_scalar
    []
[]

[Functions]
  [insertion_func]
    type = PiecewiseConstant
    xy_data = '0  0
               1  1e-4'
  []
[]

[Executioner]
  type = Transient
  dt = 1e9
  end_time = 1e9
  solve_type = 'PJFNK'
  petsc_options_iname = '-pc_type -pc_factor_shift_type'
  petsc_options_value = 'lu NONZERO'
  line_search = 'none'
  nl_abs_tol = 1e-11
  nl_rel_tol = 1e-11
  l_max_its = 200
[]

[Outputs]
  exodus = true
  csv = true
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
 [rho_insertion]
   type = FunctionValuePostprocessor
   function = insertion_func
 []
[]
