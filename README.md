# Squirrel Tutorial

To download Squirrel, for the theory and an explanation of the kernels see the Squirrel GitHub: [https://github.com/philipJFpfahl/Squirrel](https://github.com/philipJFpfahl/Squirrel)
These inputs were part of a DTU university course.
**Author:** Philip Pfahl
**Contact:** [Philip.j.f.pfahl@gmail.com](mailto:Philip.j.f.pfahl@gmail.com)

In this tutorial, the basic application of Squirrel is shown with a simplified 1D channel setup.
The `1D channel` folder contains all the necessary inputs to use Squirrel, neglecting temperature effects. The `1D channel temp` folder contains the same inputs with temperature feedback.
This tutorial shows how to calculate a steady-state solution of a Molten Salt Reactor with flowing fuel and how to run transients from the steady-state output.

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
## Model

The mesh consists of two 1-dimensional areas with length ( L/2 ). One critical area (the core) and a non-critical area (outside of the core).

```ini
[Mesh]
    # generate active core region and out of core region
    [cmbn]
        type = CartesianMeshGenerator
        dim = 1
        dx = '${fparse L/2} ${fparse L/2}'
        ix = '${nx} ${nx}'
        subdomain_id = '1 0'
    []
[]
```

A constant flow of the fuel salt from left to right is assumed.

## 1D Channel

This folder contains four input files. The two input files with the subscript `_SS` are for steady-state calculations and need to be run first. The outputs are used as inputs for the transient simulation.

### The Steady-State Calculations

Starting with the `channel_SS.i` file:
Two variables are defined: the DNP concentration "C" with one group and the flux "flux" in the channel.

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

Now we define the kernels to solve:

[
\frac{\partial  c(x,t)}{\partial t}   =  \beta \cdot \text{flux}(x) - \lambda  \cdot c(x,t)  - \frac{\partial}{\partial x} \mathbf{U}(x,t) \cdot c(x, t)
]

```ini
[FVKernels]
  # Time kernel
  [C_time]
    type = FVTimeKernel
    variable = C
  []
  # DNP production kernel
  [C_external]
    type = FVCoupledForce
    variable = C
    coef = ${fparse beta}
    v = 'flux'
    block = '1'
  []
  # DNP decay kernel
  [C_interal]
    type = FVCoupledForce
    variable = C
    coef =   ${fparse -lambda}
    v = C
  []
  # Advection kernel
  [C_advection]
    type = FVAdvection
    variable = C
    velocity = '${vel} 0 0'
  []
[]
```

There is a time kernel, a production kernel (restricted to block 1, where the reactor is critical), a decay kernel, and an advection kernel.
We will assume that the flux, and the fission rate are the same. That is not correct, but could be corrected with a simple factor that cancels in the equation. It is still possible to simply add that factor.

Likewise, we will define an outflow and inflow boundary condition for the advected DNP concentration.

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

And we define the shape of the flux on the whole domain.

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

With the time stepper, we let the solution converge.

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

The DNP concentration will be sent to the `Squirrel_SS.i` file.

```ini
[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel_SS.i"
      execute_on= "timestep_end"
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

In the `Squirrel_SS.i` file:

The transferred information is used to calculate the static reactivity loss.

We define the same variable on the same mesh, but both are known values.

```ini
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
```

Using the postprocessors of Squirrel, we can calculate the static reactivity loss due to the flowing fuel ( \rho_{\text{flow}} ) and the spatially weighted (or effective) DNP source ( S ).

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

In this example, the loss should be 121.7 pcm.

```
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: | time           | B              | Rho_Flow       | S              |
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: |   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
Squirrel0: +----------------+----------------+----------------+----------------+
```

We can see that it is reached after ~1000s.

## The Transient Calculation

For the `channel.i` file:

Not much is changing since the thermal hydraulics stay the same.
We will now do a normal restart using the `channel_SS_out.e` file.

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

Additionally, we will now pull the updated flux from `Squirrel.i`.

```ini
[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel.i"
      execute_on= "timestep_end"
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

### For the `Squirrel.i` file

We now want to have a


normalized flux value based on the steady-state output.

```ini
[Variables]
    [flux_scaled]
        family = MONOMIAL
        order = CONSTANT
        fv = true
    []
[]

[Functions]
  [normalized_flux]
    type = ParsedFunction
    expression = 'flux / max(flux)'
    symbol_names = 'flux'
    symbol_values = '${flux}'
  []
[]
```

---

