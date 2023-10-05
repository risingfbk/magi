import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

images_a = {
    0: [
        "cocalc", "jupyter", "nginx", "ob-frontend", "ob-adservice", None
    ],
    1: [
        "cocalc", "attack", "jupyter", "nginx", "ob-frontend", "ob-adservice", None
    ],
    2: [
        "cocalc", "attack", "jupyter", "nginx", "ob-frontend", "ob-adservice", None
    ]
}

t_a = {
    0: [0,     40, 60, 82, 83, 0],
    1: [0, 20, 40, 61, 82, 84, 0],
    2: [0, 20, 40, 60, 88, 94, 0]
}

duration_a = {
    0: [460,       512,  495,  500,  555,  0],
    1: [474, 2050, 2128, 2131, 2203, 2240, 0],
    2: [420, 550,  668,  672,  698,  735,  0]
}

sns.set_context('paper')
sns.set(rc={'figure.figsize': (15, 5.8), 'figure.dpi': 300, 'savefig.dpi': 300}, font_scale=1.35)
sns.set_style('whitegrid')
sns.set_palette(['#4884cf'])  # , "#17374d", "lightgrey"])

# plot on top ( 7/12 of the figure height a bar plot
# plot on bottom ( 5/12 of figure height ) a time series plot, with ticks and tick labels on hover and format properly

fig, axs = plt.subplots(3, 1, gridspec_kw={'height_ratios': [1, 1, 1]})
# ax.grid(False)

for qq in range(len(axs)):
    ax = axs[qq]
    t = t_a[qq]
    images = images_a[qq]
    duration = duration_a[qq]
    for i in range(len(images) - 1):
        previous_completion_time = t[i - 1] + duration[i - 1]
        download_time = max(duration[i] + t[i] - previous_completion_time, 15)

        ax.barh(i, duration[i] - download_time, alpha=0.7, height=0.25,
                align='center', edgecolor='white', left=t[i], hatch="|-|", color="grey")
        if images[i] != "attack":
            ax.barh(i, download_time, alpha=1, height=0.55,
                    align='center', edgecolor='white', left=t[i] + duration[i] - download_time)
        else:
            ax.barh(i, download_time, alpha=0.8, height=0.55,
                    align='center', edgecolor='white', left=t[i] + duration[i] - download_time,
                    color="black", hatch="X")

        if i == len(images) - 2:
            ax.vlines([duration[i] + t[i]], 0 - 0.5, len(images) - 2 + 0.5,
                      colors="black", linestyle="-", linewidth=1.5, alpha=0.4)

    ax.set_yticks(np.arange(len(images)))
    ax.set_yticklabels(images)
    ax.set_xticks(range(0, 2600, 120))
    if qq == len(axs) - 1:
        ax.set_xticklabels([i//60 for i in range(0, 2600, 120)])
    else:
        ax.set_xticklabels([])
    if qq == 0:
        ax.set_ylabel("No attack")
    elif qq == 1:
        ax.set_ylabel("With attack")
    else:
        ax.set_ylabel("With mitigation")
    ax.set_ylim(-0.5, len(images) - 1 - 0.5)
    ax.invert_yaxis()
    ax.set_xlim(0, 40*60)

plt.subplots_adjust(hspace=0.05)
plt.xlabel('Time (min)')

plt.savefig('temp.png', bbox_inches='tight')
exit(1)
