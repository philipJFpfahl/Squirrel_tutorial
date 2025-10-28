# 🐿️ Squirrel Tutorial

This repository provides a simple tutorial demonstrating the use of **Squirrel**, a framework for modeling delayed neutron precursor (DNP) transport and feedback effects in flowing-fuel reactor systems.

📘 For downloading Squirrel, theoretical background, and kernel explanations, see the official repository:
🔗 [Squirrel GitHub – by Philip Pfahl](https://github.com/philipJFpfahl/Squirrel)

These input files were originally part of a DTU university course.
**Author:** Philip Pfahl
**Contact:** [Philip.j.f.pfahl@gmail.com](mailto:Philip.j.f.pfahl@gmail.com)

🐿️ If you use the Squirrel app considder citing: 
🔗 [https://doi.org/10.1080/00295639.2025.2494182](https://doi.org/10.1080/00295639.2025.2494182)

---

## Overview

This tutorial demonstrates the basic application of Squirrel using a **simplified 1D channel model**. Two setups are included:

1. **1D channel kinetics** – neglecting temperature feedback
2. **1D channel dynamics** – including temperature feedback

Each setup illustrates how to compute a **steady-state** solution for a molten salt reactor with flowing fuel and how to **run transient simulations** from that steady-state condition.

### 📂 Input File Overview

| Input File                   | Description                                            |
| ---------------------------- | ------------------------------------------------------ |
| **`1D_channel/channel_SS.i`**           | **`Thermal-Hydaulics`** Steady-state DNP and flux calculation                  |
| **`1D_channel/Squirrel_SS.i`**          | **`Neutronics`** Reactivity loss postprocessing for steady state        |
| **`1D_channel/channel.i`**              | **`Thermal-Hydaulics`** Transient simulation restart (no temperature feedback) |
| **`1D_channel/Squirrel.i`**             | **`Neutronics`** Power evolution and flux scaling during transient      |
| **`1D_channel_temp/channel_SS.i`**      | **`Thermal-Hydaulics`** Steady-state with temperature variable                 |
| **`1D_channel_temp/Squirrel_SS.i`**     | **`Neutronics`** Steady-state with thermal feedback enabled             |
| **`1D_channel_temp/channel.i`**         | **`Thermal-Hydaulics`** Transient with temperature feedback                    |
| **`1D_channel_temp/Squirrel.i`**        | **`Neutronics`** Transient calculation with thermal reactivity effects  |

### Run Instructions

To run the steady-state and transient calculations:

```bash
./squirrel-opt -i channel_SS.i
./squirrel-opt -i channel.i
```

These commands will produce a steady-state solution from **`channel_SS.i`**, which is then used to restart the transient simulation in **`channel.i`**.
The transient represents a **10 pcm positive reactivity insertion**, without temperature feedback.

---
# 🧩 Model Description

The model consists of two 1D regions of equal length (**L/2**):

* A **critical core region** (where fission occurs)
* A **non-critical out-of-core region**

```ini
[Mesh]
    [cmbn]
        type = CartesianMeshGenerator
        dim = 1
        dx = '${fparse L/2} ${fparse L/2}'
        ix = '${nx} ${nx}'
        subdomain_id = '1 0'
    []
[]
```

A constant flow of fuel salt from left to right and continuous boundary conditions are assumed.

---
# 1D Channel: Steady-State Calculations

### Steady-State Thermal-Hydaulics (`channel_SS.i`)

In the **`channel_SS.i`** file, we define two variables: the DNP concentration, `C`, and the flux, `flux`. The flux is assumed to be constant throughout the steady-state solution.

```ini
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


The equation governing the DNP concentration is:

$$\frac{\partial c(x,t)}{\partial t} =  \beta , flux(x) - \lambda , c(x,t) - \frac{\partial}{\partial x}\mathbf{U}(x,t) c(x,t)$$

The following kernels are used to solve for this:

```ini
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

```ini
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

```ini
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

```ini
[TimeStepper]
  type = IterationAdaptiveDT
  dt = 0.001
  optimal_iterations = 20
  iteration_window = 2
  growth_factor = 2
  cutback_factor = 0.5
[]
```

The DNP concentration is transferred to **`Squirrel_SS.i`** for reactivity loss calculations:

```ini
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

### Steady-State Neutronics (`Squirrel_SS.i`)
In the **`Squirrel_SS.i`** the Post-processing is used to calculate static reactivity loss and weighted DNP source:

```ini
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

```ini
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: | time           | B              | Rho_Flow       | S              |
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: |   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
Squirrel0: +----------------+----------------+----------------+----------------+
```
## 1D Channel: Transient Calculations

### Transient Thermal-Hydraulics setup (`channel.i`)
For the transient Thermal-Hydraulics simulation (`channel.i`), we restart from **`channel_SS_out.e`**:

```ini
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

During the transient the scaled flux is pulled from **`Squirrel.i`**:

```ini
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

### Transient Neutronics (`Squirrel.i`)

Now we restart from the file 


For the transient neutronics simulation (`Squirrel.i`), we restart from **`channel_SS_out_Squirrel0.e`**:

```ini
[Mesh]
  file = 'channel_SS_out_Squirrel0.e'
[]
[Problem]
    kernel_coverage_check=false
    allow_initial_conditions_with_restart = true
[]
[AuxVariables]
  [flux]
    type = MooseVariableFVReal
    initial_from_file_var = 'flux'
  []
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file_var = 'C'
  []
  [flux_scaled]
    type = MooseVariableFVReal
    initial_from_file_var = 'flux'
  []
[]
```

Additionally we introduce a scaled flux Aux variable, that is updated at each time step. 
This scaled flux is transfered to the channel.i file.

The scaling is done with an Aux Kerel:

```ini
[AuxKernels]
    [power_scaling]
        type = ScalarMultiplication
        variable = flux_scaled
        source_variable = flux 
        factor = power_scalar
    []
[]
```

An external reactivity insertion scalar is defined to compensate for the DNP advection:


```ini
################################################################################
# Properties 
################################################################################
beta = 600e-5
lambda = 1
LAMBDA = 1e-4
rho_external = 1.217096e-03
```
Additionally we introduce a scaled flux, in contrast to the initial flux. This scaled flux is transfered to the channel.i file.

The scaling is done with an Aux Kerel:

```ini
[AuxKernels]
    [power_scaling]
        type = ScalarMultiplication
        variable = flux_scaled
        source_variable = flux 
        factor = power_scalar
    []
[]
```

Now we calucalte the factor or the scalar power. Initially we normalize it to 1.
```ini
[Variables]
  [power_scalar]
    family = SCALAR
    order = FIRST
    initial_condition = 1
  []
[]

```
We then solve the power equation

$$\frac{\text{d} p(t)}{\text{d} t} = \frac{\left(  \rho_{insertion} + \rho_{external} - \beta \right)}{\Lambda} p(t) + \frac{S}{\Lambda}$$

with the MOOSE Scalar Kernel solver:
```ini
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

This system should be at steady state for if there is no insertion. We test this with an insertion of 10pcm after 1 s. For that we define a insertion function:

```
[Functions]
  [insertion_func]
    type = PiecewiseConstant
    xy_data = '0  0
               1  1e-4'
  []
[]
```

Power at 10s:

```ini
Squirrel0: Scalar Variable Values:
Squirrel0: +----------------+----------------+
Squirrel0: | time           | power_scalar   |
Squirrel0: +----------------+----------------+
Squirrel0: |   1.000000e+01 |   1.318840e+00 |
Squirrel0: +----------------+----------------+
```

---
---

# 1D Channel Temperature Feedback

## The steady state caclulations

### Steady-State Thermal-Hydaulics (`channel_SS.i`)

We use the same input as we had before, but now with a temperature variable. 

We start by defining the variable:

```
[Variables]
  [T]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]
```

And we define a corresponding kernel for the advection of the temperature, the heating in the active core region and the cooling in the heatexchanger. 


```
[FVKernels]
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
    type = FVCoupledForce
    variable = T
    coef = 1e2  
    v = 'flux'
    block = '1'
  []
  #HX kernel
  [T_cooling]
    type = FVCoupledForce
    variable = T
    coef =   -0.1
    v = T
    block = "0"
  []
[]
```


Additionally we define the boundary conditions: 

```
[FVBCs]
  [inlet_T]
    type = FVFunctorDirichletBC
    boundary = 'left'
    variable = T
    functor = BC_T 
  []
  [Outlet_T]
    type = FVConstantScalarOutflowBC
    velocity = '${vel} 0 0'
    variable = T
    boundary = 'right'
  []
[]
```

finaly we push the temperature field to Squirrel.

```
    [push_T]
        type = MultiAppGeneralFieldShapeEvaluationTransfer
        to_multi_app = Squirrel 
        source_variable = T 
        variable = T
        execute_on= "timestep_end initial"
    [] 
```
---

### Steady-State Neutronics (`Squirrel_SS.i`)
In the **`Squirrel_SS.i`**  we have to initialize the coresponding AuxVariable:

```
[AuxVariables]
  [T]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]
```


## The transient caclulations

### Transient Thermal-Hydraulics setup (`channel.i`)
For the transient Thermal-Hydraulics simulation (`channel.i`), we restart from **`channel_SS_out.e`**:
In the transient calculation the channel.i file pulls the changed flux from Squirrel.i

```
[Transfers]
    [pull_flux]
        type = MultiAppGeneralFieldShapeEvaluationTransfer
        from_multi_app = Squirrel 
        source_variable = flux_scaled 
        variable = flux
        execute_on= "timestep_end initial"
    [] 
[]
```


### Transient Neutronics (`Squirrel.i`)
In the **`Squirrel.i`** file we initalize a reference temperature. 


```
[AuxVariables]
  [T_ref]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file_var = 'T'
  []
[]
```

The weighted temperature difference is calculated as a postprocessor. 

```
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
[]
```

The calculated change in reactivity is used in the power equation:


```
  [expression]
    type = ParsedODEKernel
    expression = '-(rho_external + rho_T + rho_insertion-beta)/LAMBDA*power_scalar-S/LAMBDA'
    constant_expressions = '${fparse rho_external} ${fparse beta} ${fparse LAMBDA}'
    constant_names = 'rho_external beta LAMBDA'
    variable = power_scalar
    postprocessors = 'S rho_insertion rho_T'
  []

```

The resulting power is lower compared to the transient without feedback.


```
Squirrel0: Scalar Variable Values:
Squirrel0: +----------------+----------------+
Squirrel0: | time           | power_scalar   |
Squirrel0: +----------------+----------------+
Squirrel0: |   1.000000e+01 |   1.003838e+00 |
```
