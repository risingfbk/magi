import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
import matplotlib.dates as dates
import numpy as np
import copy
import math 

images = list(range(1, 8))
t = [sum(range(1, i)) for i in images]
duration = copy.deepcopy(images)
images = [str(i) for i in images]

y = [67.409, 68.313, 69.189, 70.421, 71.547, 73.286, 74.853, 76.262, 77.578,
     78.645, 79.446, 80.130, 80.765, 81.414, 82.009,
     82.519, 82.921, 83.324, 83.677, 83.924, 84.149,
     84.359, 84.559, 84.759, 84.948, 85.137, 70.637,
     71.288, 72.513, 73.430, 73.430, 73.430, 73.430,
     73.430, 73.430]

sns.set_context('paper')
sns.set(rc={'figure.figsize': (12, 5), 'figure.dpi': 300, 'savefig.dpi': 300}, font_scale=1.8)
sns.set_style('whitegrid')
sns.set_palette(['#4884cf'])  # , "#17374d", "lightgrey"])

# plot on top ( 7/12 of the figure height a bar plot
# plot on bottom ( 5/12 of figure height ) a time series plot, with ticks and tick labels on hover and format properly

fig, ax = plt.subplots()
axes = [ax, ax.twinx()]
ax1, ax2 = axes

ax1.grid(False)
ax2.grid(False)

fig.subplots_adjust(right=0.75)

for i in range(len(images)):
    ax1.barh(i, duration[i], alpha=1, height=0.3, align='center', edgecolor='white', left=t[i])
    if i != len(images) - 1:
        ax1.barh(i, sum(duration[i:]) - duration[-1] - i + 3, alpha=0.3, height=0.3, align='center', color='black', left=t[i] + duration[i], linestyle=":", linewidth=1, edgecolor="black", hatch='//')

ax2.plot(range(0, 35, 1), y, alpha=0, linewidth=0)
ax2.fill_between(range(0, 35, 1), y, ['0'] * len(y), alpha=0.2, color=sns.color_palette()[0])
ax2.set_ylim([65, 86])
ax2.set_yticks(range(65, 90, 5))
ax2.set_yticklabels(range(65, 90, 5))

ax.set_yticks(np.arange(len(images)))
ax.set_yticklabels(images)
ax.set_xlim(0, 30)
ax.set_ylim(-0.5, 6.5)

ax.vlines([25], -1, 7, colors="black", linestyles=":", linewidth=1.5)

# ax.set_xticks(range(0, 35, 2))
ax.set_xlabel('Time (m)')
ax1.set_ylabel("Image tag")
ax2.set_ylabel('Disk used (%)')
# pls change the font size of yticks
plt.savefig('temp.png', bbox_inches='tight')
exit(1)

fig, axs = plt.subplots(2,1, gridspec_kw={'height_ratios': [2.5, 1]})

ax = axs[0]

for i in range(len(images)):
    ax.barh(i, duration[i], alpha=0.8, height=0.3, align='center', edgecolor='white', left=t[i])
    if i != len(images) - 1:
        ax.barh(i, sum(duration[i:]) - duration[-1] - i + 3, alpha=0.2, height=0.3, align='center', color='black', left=t[i] + duration[i], linestyle=":", linewidth=1, edgecolor="black", hatch='//')

plt.ylabel('Images')
plt.xlabel('Time (s)')
ax.set_yticks(np.arange(len(images)))
ax.set_yticklabels(images)
ax.set_xticks(range(0, 35, 2))
ax.set_xticklabels([])  # range(0, 35, 2))
ax.set_xlim(0, 29)
ax.set_ylabel("Variable GB Image")
ax.invert_yaxis()

# remove space between subplots
plt.subplots_adjust(hspace=0.1)

ax2 = axs[1]
# fill data below 0.7 with 0.7 and above 0.85 with 0.85
# print(y)
# plot
ax2.plot(range(0, 35, 1), y)
ax2.set_ylabel('Disk used (%)')
ax2.set_xlabel('Time (s)')
ax2.set_xticks(range(0, 35, 2))
ax2.set_xticklabels(range(0, 35, 2))
ax2.set_yticks(range(65, 90, 5))
ax2.set_yticklabels(range(65, 90, 5))
ax2.set_xlim(0, 29)

plt.savefig('temp.png', bbox_inches='tight')