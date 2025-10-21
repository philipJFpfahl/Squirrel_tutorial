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

### The channel_SS.i file
Two variables are defined. The DNP concentration with one group and the flux in the channel. 

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
$$\frac{\partial  c(x,t)}{\partial t}   =  \beta flux(x) - \lambda  c(x,t)  - \frax{\partial}{\partial x}\mathbf{U}(x,t) c(x, t) + D \frax{\partial}{\partial x^2} c(x,t)$$

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
    v = C
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
```
We will assume that the flux, and the fission rate are the same. That is not correct, but could be corrected with a simple factor that canceled in the equation. It is still possible to simply add that factor.



## 1D channel temp
