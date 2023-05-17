import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.dates as mdates
import os

DATA_DIR = 'results/5gb-nolimit/data'
PLOT_DIR = 'results/5gb-nolimit/plots'

# Read in the data
plots = os.listdir(DATA_DIR)
os.makedirs(PLOT_DIR, exist_ok=True)

mapping = {
    'cpu': {
        "title": "CPU Usage",
        "ylabel": "CPU Usage (%)",
    },
    'memory': {
        "title": "Memory Usage",
        "ylabel": "Used Resident Memory (%)",
    },
    'disk_r': {
        "title": "Disk Read",
        "ylabel": "Disk Read (MB/s)",
    },
    'disk_w': {
        "title": "Disk Write",
        "ylabel": "Disk Write (MB/s)",
    },
    'network_r': {
        "title": "Network Receive",
        "ylabel": "Network Receive (MB/s)",
    },
    'network_w': {
        "title": "Network Transmit",
        "ylabel": "Network Transmit (MB/s)",
    },
}

for plot in plots:
    df = pd.read_csv(DATA_DIR + '/' + plot, sep=';')
    # header
    # Time;{instance="192.168.221.100:9100"};{instance="192.168.221.10:9100"};{instance="192.168.221.11:9100"};{instance="192.168.221.12:9100"}
    # Plot the data
    sns.set_style('whitegrid')
    sns.set_context('paper')
    sns.set_palette('colorblind')

    df.rename(
        columns={
            '{instance="192.168.221.10:9100"}': 'Master',
            '{instance="192.168.221.11:9100"}': 'Worker1',
            '{instance="192.168.221.12:9100"}': 'Worker2',
            '{instance="192.168.221.100:9100"}': 'Registry',
            '{device="vda",instance="192.168.221.10:9100",job="prometheus"}': 'Master',
            '{device="vda",instance="192.168.221.11:9100",job="prometheus"}': 'Worker1',
            '{device="vda",instance="192.168.221.12:9100",job="prometheus"}': 'Worker2',
            '{device="vda",instance="192.168.221.100:9100",job="prometheus"}': 'Registry',
            '{instance="192.168.221.10:9100",job="prometheus"}': 'Master',
            '{instance="192.168.221.11:9100",job="prometheus"}': 'Worker1',
            '{instance="192.168.221.12:9100",job="prometheus"}': 'Worker2',
            '{instance="192.168.221.100:9100",job="prometheus"}': 'Registry',
        },
        inplace=True
    )

    # convert the time to datetime; time is like 1684088862
    df["Time"].apply(pd.to_timedelta, unit='s')
    df["Time"] = df["Time"] - df["Time"].iloc[0]
    #df['Time'] = pd.to_datetime(df['Time'], unit='s')

    # df["round_time"].apply(pd.to_timedelta, unit='s',
                           
    # df = df.groupby(by=[pd.Grouper(freq='1S', key='Time')]).mean().reset_index()

    if plot in ("disk_r", "disk_w", "network_r", "network_w"):
        df['Master'] = df['Master'] / 1024 / 1024
        df['Worker1'] = df['Worker1'] / 1024 / 1024
        df['Worker2'] = df['Worker2'] / 1024 / 1024
        df['Registry'] = df['Registry'] / 1024 / 1024

    # select the subset of rows of the 
    # df = df[(df['Time'] >= '2023-05-14 19:23:00') & (df['Time'] <= '2023-05-14 19:45:00')]

    ax = df.plot(x='Time', y='Master', figsize=(6, 4))
    df.plot(x='Time', y='Worker1', ax=ax)
    df.plot(x='Time', y='Worker2', ax=ax)
    df.plot(x='Time', y='Registry', ax=ax)

    ticks = []
    labels = []
    mmax = df['Time'].max() - (df['Time'].max() % 60) + 60
    for i in range(0, mmax, 60):
        ticks.append(i)
        labels.append(str(i // 60))
    ax.set_xticks(ticks)
    ax.set_xticklabels(labels)
    

    # ax.xaxis.set_major_locator(mdates.SecondLocator(interval=60))
    # ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))

    print(df.head())

    plt.gcf().autofmt_xdate()

    # Set the labels
    ax.set_xlabel('Time (min)')
    ax.set_ylabel(mapping[plot]['ylabel'])
    ax.set_title(mapping[plot]['title'])
    
    # Save the figure
    plt.savefig(PLOT_DIR + '/' + plot + '.png', dpi=300)