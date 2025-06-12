#rho_external = ${fparse 2.022985e-03}
rho_external = ${fparse 1.932381e-03+1.461588e-05 }
LAMBDA = 8.57e-7
beta =0.0030207957
lambda1 = 0.0133104
lambda2 = 0.0305427
lambda3 = 0.115179
lambda4 = 0.301152
lambda5 = 0.879376
lambda6 = 2.91303
[Problem]
  allow_initial_conditions_with_restart = true
[]

[Mesh]
    file = '../Initial_state/run_ns_out.e'
[]

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
  [expression]
    type = ParsedODEKernel
    expression = '-(rho_external + rho_T + rho_insertion-beta)/LAMBDA*power_scalar-S/LAMBDA'
    constant_expressions = '${fparse rho_external} ${fparse beta} ${fparse LAMBDA}'
    constant_names = 'rho_external beta LAMBDA'
    variable = power_scalar
    postprocessors = 'S rho_insertion rho_T'
  []
[]


[AuxVariables]
  [power_density]
    type = MooseVariableFVReal
    initial_from_file_var = 'power_density'
  []
  [power_density_scaled]
    type = MooseVariableFVReal
    initial_from_file_var = 'power_density'
  []
  [fission_source]
    type = MooseVariableFVReal
    initial_from_file_var = 'fission_source'
  []
  [fission_source_scaled]
    type = MooseVariableFVReal
    initial_from_file_var = 'fission_source'
  []
  [flux]
    type = MooseVariableFVReal
    initial_from_file_var = 'flux'
  []
  [T]
    type = MooseVariableFVReal
    initial_from_file_var = 'T_fluid'
  []
  [T_ref]
    type = MooseVariableFVReal
    initial_from_file_var = 'T_fluid'
  []
  [c1]
    type = INSFVScalarFieldVariable
    initial_from_file_var = c1
  []
  [c2]
    type = INSFVScalarFieldVariable
    initial_from_file_var = c2
  []
  [c3]
    type = INSFVScalarFieldVariable
    initial_from_file_var = c3
  []
  [c4]
    type = INSFVScalarFieldVariable
    initial_from_file_var = c4
  []
  [c5]
    type = INSFVScalarFieldVariable
    initial_from_file_var = c5 
  []
  [c6]
    type = INSFVScalarFieldVariable
    initial_from_file_var = c6 
  []
[]

[AuxKernels]
    [power_scaling]
        type = ScalarMultiplication
        variable = power_density_scaled
        source_variable = power_density 
        factor = power_scalar
    []
    [fs_scaling]
        type = ScalarMultiplication
        variable = fission_source_scaled
        source_variable = fission_source 
        factor = power_scalar
    []
[]

[Functions]
  [insertion_func]
    type = PiecewiseLinear
    xy_data = '0.00 0
               10   0'
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
  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-4
  l_max_its = 200
[]

[Outputs]
  exodus = true
[]


[Postprocessors]
 [rho_T]
   type = TemperatureFeedbackInt
   variable = T
   flux = flux
   T_ref = T_ref
   total_rho = ${fparse -10e-5}
   Norm = flux_int
   block = 1
 []
 [flux_int]
   type = ElementIntegralVariablePostprocessor
   execute_on = 'INITIAL TIMESTEP_END'
   variable = flux
   block = 1
 []
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
    other_variable = fission_source
    execute_on = 'initial'
    execution_order_group = -1
 []
 [S] 
  type = ParsedPostprocessor
  function = '  S_c_1  +  S_c_2  +  S_c_3  +  S_c_4  +  S_c_5  +  S_c_6  ' 
  pp_names = '  S_c_1  S_c_2  S_c_3  S_c_4  S_c_5  S_c_6  ' 
 execute_on = 'initial timestep_end' 
 [] 
 [S_c_1] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = c1
  Norm = B
  lambda = ${lambda1}
  execute_on = 'initial timestep_end'
 [] 
 [S_c_2] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = c2
  Norm = B
  lambda = ${lambda2}
  execute_on = 'initial timestep_end'
 [] 
 [S_c_3] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = c3
  Norm = B
  lambda = ${lambda3}
  execute_on = 'initial timestep_end'
 [] 
 [S_c_4] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = c4
  Norm = B
  lambda = ${lambda4}
  execute_on = 'initial timestep_end'
 [] 
 [S_c_5] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = c5
  Norm = B
  lambda = ${lambda5}
  execute_on = 'initial timestep_end'
 [] 
 [S_c_6] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = c6
  Norm = B
  lambda = ${lambda6}
  execute_on = 'initial timestep_end'
 [] 
[]
