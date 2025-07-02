import numpy as np
import matplotlib.pyplot as plt



for name in [3, 30, 100, 600]:
    data = np.loadtxt("channel_out_%s.csv"%name,delimiter = ",", skiprows = 1)
    data = data.T
    t =  data[0]
    results = data[-1]

    plt.plot(t,results, label = r"$\beta = %s$"%name,  alpha = 0.5)

plt.ylim(0,5)
plt.grid()
plt.xlabel("time")
plt.ylabel("Power")
plt.legend()
plt.savefig("PK_time.pdf")
plt.show()
