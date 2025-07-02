import numpy as np
import matplotlib.pyplot as plt

beta = 600e-5
lam = 1
Lambda = 1e-4
rho = 1e-4

def P(t, rho, beta, Lambda, lam):
    return rho/(rho-beta)*np.exp((rho-beta)*t/Lambda) - beta/(rho - beta) * np.exp(-lam*rho*t/(rho-beta))

def C(t, rho, beta, Lambda, lam):
    return rho*beta/(rho-beta)**2 * np.exp((rho - beta)*t/Lambda) + beta/(lam*Lambda)*np.exp(-lam*rho*t/(rho-beta))

data = np.loadtxt("channel_out_Squirrel0.csv",delimiter = ",", skiprows = 1)
data = data.T
t =  data[0]
results = data[-1]

plt.plot(t,results, label = "Power ",  alpha = 0.5)
plt.plot(t+1, P(t, rho, beta, Lambda, lam)*results[0],"--", label = "Power analytical", color = "b")
plt.grid()
plt.xlabel("time")
plt.ylabel("Power")
plt.legend()
plt.savefig("PK_time.pdf")
plt.show()
