Here's the formatted README based on the example you provided:

---

# 🐿️ Squirrel Tutorial: 1D Channel & Temperature Feedback

This repository provides input files for **Squirrel**, a framework used to model delayed neutron precursor (DNP) transport and feedback effects in molten salt reactors (MSRs) with flowing fuel.

---

## Overview

This tutorial includes two main configurations:

1. **1D channel** – Basic model without temperature feedback
2. **1D channel (temp)** – Model including temperature feedback

The **1D channel** demonstrates a steady-state calculation followed by a transient simulation. The **1D channel (temp)** extends this by including temperature-dependent feedback in the calculations.

Each configuration contains both steady-state and transient input files, with the transient simulations being based on the outputs from the steady-state simulations.

### 📂 Input File Overview

| Input File                          | Description                                     |
| ----------------------------------- | ----------------------------------------------- |
| **`1D_channel/channel_SS.i`**       | Steady-state DNP and flux calculation           |
| **`1D_channel/Squirrel_SS.i`**      | Reactivity loss postprocessing for steady state |
| **`1D_channel/channel.i`**          | Transient simulation (no temperature feedback)  |
| **`1D_channel/Squirrel.i`**         | Power evolution during transient                |
| **`1D_channel_temp/channel_SS.i`**  | Steady-state with temperature feedback          |
| **`1D_channel_temp/Squirrel_SS.i`** | Steady-state with thermal feedback              |
| **`1D_channel_temp/channel.i`**     | Transient with temperature feedback             |
| **`1D_channel_temp/Squirrel.i`**    | Transient with thermal reactivity effects       |

---

## 1D Channel: Steady-State Calculations

### Steady-State Setup (`channel_SS.i`)

In the **`channel_SS.i`** file, we define two variables: the DNP concentration, `C`, and the flux, `flux`. These are both assumed to be constant throughout the steady-state solution.

```
[Variables]
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]

[AuxVariables]
  [flux]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]
```

### Kernels for Steady-State Solution

The equation governing the DNP concentration is:

$$\frac{\partial c(x,t)}{\partial t} =  \beta , flux(x) - \lambda , c(x,t) - \frac{\partial}{\partial x}\mathbf{U}(x,t) c(x,t)$$

The following kernels are used to solve for this:

```
[FVKernels]
  [C_time]
    type = FVTimeKernel
    variable = C
  []
  [C_external]
    type = FVCoupledForce
    variable = C
    coef = ${fparse beta}  
    v = 'flux'
    block = '1'
  []
  [C_interal]
    type = FVCoupledForce
    variable = C
    coef = ${fparse -lambda}
    v = C
  []
  [C_advection]
    type = FVAdvection
    variable = C
    velocity = '${vel} 0 0'
  []
[]
```

Boundary conditions for the advected DNP concentration are defined as follows:

```
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
```

Flux initialization:

```
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
```

Time stepper setup for convergence:

```
[TimeStepper]
  type = IterationAdaptiveDT
  dt = 0.001
  optimal_iterations = 20
  iteration_window = 2
  growth_factor = 2
  cutback_factor = 0.5
[]
```

### Reactivity Loss Calculation in `Squirrel_SS.i`

The DNP concentration is transferred to **`Squirrel_SS.i`** for reactivity loss calculations:

```
[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel_SS.i"
      execute_on= "timestep_end "
      sub_cycling = false
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
[]
```

Post-processing to calculate static reactivity loss and weighted DNP source:

```
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
```

Reactivity loss after ~1000s:

```
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: | time           | B              | Rho_Flow       | S              |
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: |   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
Squirrel0: +----------------+----------------+----------------+----------------+
```

### Transient Setup

For the transient simulation (`channel.i`), we restart from **`channel_SS_out.e`** and pull the updated flux from **`Squirrel.i`**:

```
[Mesh]
  file = 'channel_SS_out.e'
[]

[Problem]
    kernel_coverage_check=false
    allow_initial_conditions_with_restart = true
[]

[Variables]
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file_var = 'C'
  []
[]

[AuxVariables]
    [flux]
        family = MONOMIAL
        order = CONSTANT
        fv = true
        initial_from_file_var = 'flux'
    []
[]
```

Updated flux is pulled from **`Squirrel.i`**:

```
[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel.i"
      execute_on= "timestep_end "
      sub_cycling = true
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
```

The power equation is solved using an external reactivity insertion to compensate for the DNP advection:

```
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
    expression = '-(rho_external+rho_insertion-beta)/LAMBDA*power_scalar-S/LAMBDA'
    constant_expressions = '${fparse rho_external} ${fparse beta} ${fparse LAMBDA}'
    constant_names = 'rho_external beta LAMBDA'
    variable = power_scalar
    postprocessors = 'S rho_insertion '
  []
[]
```

Power evolution:

```
Squirrel0: Scalar Variable Values:
Squirrel0: +----------------+----------------+
Squirrel0: | time           | power_scalar   |
Squirrel0: +----------------+----------------+
Squirrel0: |   1.000000e+01 |   1.318840e+00 |
Squirrel0: +----------------+----------------+
```

---

## 1D Channel with Temperature Feedback

This configuration builds on the **1D channel** setup by adding a temperature variable and corresponding feedback effects.

### Steady-State Setup (`channel_SS.i`)

Variables and kernels are similar to the previous setup, but with the addition of a temperature variable:

```
[Variables]
  [T]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]
```

### Temperature Feedback Kernels

```
[FVKernels]
  [T_time]
    type = FV
```
