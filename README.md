# 🐿️ Squirrel Tutorial

This repository provides a simple tutorial demonstrating the use of **Squirrel**, a framework for modeling delayed neutron precursor (DNP) transport and feedback effects in flowing-fuel reactor systems.

📘 For downloading Squirrel, theoretical background, and kernel explanations, see the official repository:
🔗 [Squirrel GitHub – by Philip Pfahl](https://github.com/philipJFpfahl/Squirrel)

These input files were originally part of a DTU university course.
**Author:** Philip Pfahl
**Contact:** [Philip.j.f.pfahl@gmail.com](mailto:Philip.j.f.pfahl@gmail.com)

---

## Overview

This tutorial demonstrates the basic application of Squirrel using a **simplified 1D channel model**. Two setups are included:

1. **1D channel** – neglecting temperature feedback
2. **1D channel (temp)** – including temperature feedback

Each setup illustrates how to compute a **steady-state** solution for a molten salt reactor with flowing fuel and how to **run transient simulations** from that steady-state condition.

### 📂 Input File Overview

| Input File                   | Description                                            |
| ---------------------------- | ------------------------------------------------------ |
| **`1D_channel/channel_SS.i`**           | Steady-state DNP and flux calculation                  |
| **`1D_channel/Squirrel_SS.i`**          | Reactivity loss postprocessing for steady state        |
| **`1D_channel/channel.i`**              | Transient simulation restart (no temperature feedback) |
| **`1D_channel/Squirrel.i`**             | Power evolution and flux scaling during transient      |
| **`1D_channel_temp/channel_SS.i`**      | Steady-state with temperature variable                 |
| **`1D_channel_temp/Squirrel_SS.i`**     | Steady-state with thermal feedback enabled             |
| **`1D_channel_temp/channel.i`**         | Transient with temperature feedback                    |
| **`1D_channel_temp/Squirrel.i`**        | Transient calculation with thermal reactivity effects  |

### Run Instructions

To run the steady-state and transient calculations:

```bash
./squirrel-opt -i channel_SS.i
./squirrel-opt -i channel.i
```

These commands will produce a steady-state solution from **`channel_SS.i`**, which is then used to restart the transient simulation in **`channel.i`**.
The transient represents a **10 pcm positive reactivity insertion**, without temperature feedback.

---
## 🧩 Model Description

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

A constant flow of fuel salt from left to right is assumed.

---
## 1D Channel: Steady-State Calculations

### Steady-State Setup (`channel_SS.i`)

In the **`channel_SS.i`** file, we define two variables: the DNP concentration, `C`, and the flux, `flux`. These are both assumed to be constant throughout the steady-state solution.

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

### Kernels for Steady-State Solution

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

### Reactivity Loss Calculation in `Squirrel_SS.i`

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

Post-processing to calculate static reactivity loss and weighted DNP source:

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

### Transient Setup

For the transient simulation (`channel.i`), we restart from **`channel_SS_out.e`** and pull the updated flux from **`Squirrel.i`**:

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

Updated flux is pulled from **`Squirrel.i`**:

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

The power equation is solved using an external reactivity insertion to compensate for the DNP advection:

```ini
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

```ini
Squirrel0: Scalar Variable Values:
Squirrel0: +----------------+----------------+
Squirrel0: | time           | power_scalar   |
Squirrel0: +----------------+----------------+
Squirrel0: |   1.000000e+01 |   1.318840e+00 |
Squirrel0: +----------------+----------------+
```

---


## 1D Channel Temperature Feedback

### The Steady-State Calculations

For this section, we introduce temperature feedback into the system. The setup is similar to the previous one, but now we also need to track the **temperature** as a variable and incorporate it into the system’s feedback.

#### Temperature Variables

We begin by defining the **temperature** variable in the **[Variables]** block:

```ini
[Variables]
  [T]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]
```

This defines a scalar temperature variable, **T**, which will be used throughout the system.

#### Advection, Heating, and Cooling

We introduce a set of **kernels** to handle temperature transport and feedback.

* **Advection** of the temperature field:

```ini
[FVKernels]
  [T_advection]
    type = FVAdvection
    variable = T
    velocity = '${vel} 0 0'
  []
```

* **Heating** in the active core region, based on the flux variable:

```ini
  [T_heating]
    type = FVCoupledForce
    variable = T
    coef = 1e2  
    v = 'flux'
    block = '1'
  []
```

* **Cooling** in the heat exchanger region:

```ini
  [T_cooling]
    type = FVCoupledForce
    variable = T
    coef = -0.1
    v = T
    block = "0"
  []
[]
```

These kernels define the physical behavior of temperature within the system: the **advection** of heat, **heating** in the reactor core, and **cooling** in the heat exchanger.

#### Boundary Conditions for Temperature

Next, we set up the boundary conditions for the temperature variable.

```ini
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

Here, the **inlet temperature** is defined using a **Dirichlet boundary condition** (with a user-defined **BC_T** functor), and the **outlet temperature** uses a **constant scalar outflow BC**.

#### Pushing the Temperature Field to Squirrel

We also need to transfer the temperature field to **Squirrel** at each timestep:

```ini
    [push_T]
        type = MultiAppGeneralFieldShapeEvaluationTransfer
        to_multi_app = Squirrel 
        source_variable = T 
        variable = T
        execute_on= "timestep_end initial"
    [] 
```

This ensures that **Squirrel** receives the updated temperature field from the channel simulation.

---

### The Transient Calculations

Now we move to the transient setup, where we track how the system behaves over time, with the inclusion of **temperature feedback**. In this section, **Squirrel** is responsible for receiving the temperature data and applying it to adjust the reactor's reactivity.

#### Restart and Temperature Initialization

We begin by restarting the transient calculation using the **steady-state solution** from the **`channel_SS_out.e`** file, which now includes the updated temperature field.

In the **Squirrel.i** file, we initialize the temperature field:

```ini
[AuxVariables]
  [T_ref]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file_var = 'T'
  []
[]
```

Here, **T_ref** will serve as the reference temperature used to calculate the reactivity feedback.

#### Temperature Feedback and Reactivity

We introduce the **temperature feedback** effect through a postprocessor that computes the change in reactivity due to the temperature field. The reactivity feedback is computed based on the temperature difference between the reference temperature and the current temperature:

```ini
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

This postprocessor calculates the temperature feedback, where:

* **`rho_T`** is the reactivity change due to temperature,
* **`flux_int`** is the integral of the flux over the volume,
* **`T_ref`** is the reference temperature, and
* **`total_rho`** is the total reactivity change, scaled by a constant.

#### Reactivity in the Power Equation

The feedback in reactivity is used to adjust the power equation. The temperature-dependent reactivity change is incorporated into the differential equation for power:

```ini
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

This ensures that the reactivity change, based on the temperature feedback, will influence the power evolution over time.

---
The resulting power is lower compared to the transient without feedback.

Squirrel0: Scalar Variable Values:
Squirrel0: +----------------+----------------+
Squirrel0: | time           | power_scalar   |
Squirrel0: +----------------+----------------+
Squirrel0: |   1.000000e+01 |   1.003838e+00 |

