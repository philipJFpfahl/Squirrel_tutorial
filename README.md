# Squirrel Tutorial

To download Squirrel, for the theory and an explanation of the kernels see the Squirrel github: https://github.com/philipJFpfahl/Squirrel
These inputs where part of a DTU university course.
Author: Philip Pfahl
Contact: Philip.j.f.pfahl@gmail.com

In this tutorial the basic application of Squirrel is shown with an simplified 1D channel setup.
The 1D channel folder contains all the nessesary inputs to use Squirrel, neglecting temperature effects. The 1D channel temp folder contains the same inputs with themperature feedback.
This tutorial shows how to calculate a steady state solution of a Molten Salt Reactor with flowing fuel and how to run a transients from the steady state output. 

## Model
The mesh consits of two 1 dimensional areas with length L/2. One critical area (the core) and a non critical area (outside of the core).

```
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
```


## 1D channel
This folder contains four input files. The two input files with the subscript \_SS are for steady state calculations and need to be run first. The outputs are used as inputs for the transient simulation.

### Run the input
If you just want to run the steady state and transient calculation:

```
./squirrel-opt -i channel_SS.i

./squirrel-opt -i channel.i

```
That will give you a steady state soultion. From this solution the transient will restart. The transient is a 10 pcm insertion, without any temperature feedback.

### The steady state caclulations.

Beginning with the channel_SS.i file:
Two variables are defined. The DNP concentration "C" with one group and the flux "flux" in the channel. 

```
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

```


Now we define the Kernels to solve:


$$\frac{\partial  c(x,t)}{\partial t}   =  \beta flux(x) - \lambda  c(x,t)  - \frac{\partial}{\partial x}\mathbf{U}(x,t) c(x, t) $$


```
################################################################################
# Define Kernels 
################################################################################
[FVKernels]
  #Time kernel
  [C_time]
    type = FVTimeKernel
    variable = C
  []
  #DNP production kernel
  [C_external]
    type = FVCoupledForce
    variable = C
    coef = ${fparse beta}  
    v = 'flux'
    block = '1'
  []
  #DNP decay kernel
  [C_interal]
    type = FVCoupledForce
    variable = C
    coef =   ${fparse -lambda}
    v = C
  []
  #Advection kernel
  [C_advection]
    type = FVAdvection
    variable = C
    velocity = '${vel} 0 0'
  []
[]
```
There is a time kernel, a production kernel (restricted to block 1, where the reactor is critical), a decay kernel, and an advection kernel. 
We will assume that the flux, and the fission rate are the same. That is not correct, but could be corrected with a simple factor that canceled in the equation. It is still possible to simply add that factor.

Likewise we will define a outflow and inflow boundary condition for the advected DNP concentration.

```
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

```
And we define the shape of the flux on the whole domain.

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

With the time steper we let the solution converge 


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


The DNP concnetration will be send to the Squirrel_SS.i file.


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
Now in the Squirrel_SS.i file:

The transfered information is used to calculate the static reactivity loss. 

We define the same variable on the same mesh, but both are known values.

```
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

using the post processors of Squirrel we can calculate the static reactivity loss due to the flowing fuel.

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
in this example the loss should be 121.7 pcm

```
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: | time           | B              | Rho_Flow       | S              |
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: |   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
Squirrel0: +----------------+----------------+----------------+----------------+
```

we can see that it is reached after ~1000s. 

### The transient caclulations.

For the channel.i file:

Not much is changing since the thermal hydraulics stays the same.
We will now do a normal resart using the channel_SS_out.e file.

```
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
```

Additionally we will now pull the updated flux from Squirrel.i 

```
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
```

For the Squirrel.i file 

We now want to have a transient, so that the scalar power can go up or down. 

To have a steady state we need to compensate the reactivity loss due to the DNP advection. To do that a external reactivity is inserted called 
"rho_external".


```
################################################################################
# Properties 
################################################################################
beta = 600e-5
lambda = 1
LAMBDA = 1e-4

rho_external = 1.217096e-03
```

Now we restart from the file


```
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
[]

```
Additionally we introduce a scaled flux, in contrast to the initial flux. This scaled flux is transfered to the channel.i file.

The scaling is done with an Aux Kerel:

```
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

```
[Variables]
  [power_scalar]
    family = SCALAR
    order = FIRST
    initial_condition = 1
  []
[]

```
We then solve the power equation: 
$$  \frac{\text{d} p(t)}{\text{d} t} &= \frac{\left(  \rho_{insertion} + \rho_{external} - \beta \right)}{\Lambda} p(t) + \frac{S}{\Lambda}
With the MOOSE Scalar Kernel solver:

```
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
```

This system should be at steady state for rho_insertion = 0. We test this with an insertion of 10pcm after 1 s. For that we define a insertion function:

```
[Functions]
  [insertion_func]
    type = PiecewiseConstant
    xy_data = '0  0
               1  1e-4'
  []
[]
```

In the output we can see that the power raised due to the insertion 

Squirrel0: Scalar Variable Values:
Squirrel0: +----------------+----------------+
Squirrel0: | time           | power_scalar   |
Squirrel0: +----------------+----------------+
Squirrel0: :                :                :
Squirrel0: |   1.000000e+01 |   1.318840e+00 |
Squirrel0: +----------------+----------------+

Since there is no temperature feedback we expected the power to rise continuesly.

## 1D channel temp
