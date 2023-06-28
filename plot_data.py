import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.dates as mdates
import os
import datetime

avail = os.listdir('results/')
directory = input(f"Which directory do you want to plot? {avail} ")
if directory not in avail:
    print("Invalid directory, exiting...")
    exit()

DATA_DIR = f'results/{directory}/data'
PLOT_DIR = f'results/{directory}/plots'

MAPPINGS = {
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
    'worker2cpu': {
        "title": "Worker CPU usage by mode",
        "ylabel": "CPU Usage (%)",
    },
    'disk_w+network_r': {
        "title": "Disk writes and network receives",
        "ylabel": "Throughput (MB/s)",
    }
}


def plot_normal(df: pd.DataFrame, plot: str):
    df.rename(
        columns={
            '{instance="192.168.221.10:9100"}': 'Master',
            '{instance="192.168.221.11:9100"}': 'Worker1',
            '{instance="192.168.221.12:9100"}': 'Worker2',
            '{instance="10.231.0.208:9100"}': 'Registry',
            '{instance="192.168.221.10:9100",job="prometheus"}': 'Master',
            '{instance="192.168.221.11:9100",job="prometheus"}': 'Worker1',
            '{instance="192.168.221.12:9100",job="prometheus"}': 'Worker2',
            '{instance="10.231.0.208:9100",job="prometheus"}': 'Registry',
        },
        inplace=True
    )

    # delete all columns != worker2
    # df.drop(columns=df.columns[~df.columns.str.contains("Worker2|Time", regex=True)], inplace=True)

    if plot in ("disk_r", "disk_w", "network_r", "network_w"):
        df['Master'] = df['Master'] / 1024 / 1024
        df['Worker1'] = df['Worker1'] / 1024 / 1024
        df['Worker2'] = df['Worker2'] / 1024 / 1024
        df['Registry'] = df['Registry'] / 1024 / 1024

    # df = df[(df['Time'] >= '2023-05-14 19:23:00') & (df['Time'] <= '2023-05-14 19:45:00')]

    df.rename(
        columns={
            'Worker2': 'Worker'
        },
        inplace=True
    )
    ax = df.plot(x='Time', y='Worker', figsize=(6, 4))
    # df.plot(x='Time', y='Worker1', ax=ax)
    # df.plot(x='Time', y='Worker2', ax=ax)
    # df.plot(x='Time', y='Registry', ax=ax)

    ticks = []
    labels = []
    mmax = df['Time'].max() - (df['Time'].max() % 60) + 60
    for i in range(0, mmax, 60):
        ticks.append(i)
        labels.append(datetime.datetime.utcfromtimestamp(i).strftime('%M:%S'))
    ax.set_xticks(ticks)
    ax.set_xticklabels(labels)
    ax.set_xlim([-0.01, mmax - 60 + 0.01])

    # ax.xaxis.set_major_locator(mdates.SecondLocator(interval=60))
    # ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))

    print(df.head())

    # plt.gcf().autofmt_xdate()

    # Set the labels
    ax.set_xlabel('Time')
    ax.set_ylabel(MAPPINGS[plot]['ylabel'])
    ax.set_title(MAPPINGS[plot]['title'])

    # Save the figure
    plt.tight_layout()
    plt.savefig(PLOT_DIR + '/' + plot + '.png')


def plot_disk_network(df_disk: pd.DataFrame, df_network: pd.DataFrame, plot: str):
    for df in (df_disk, df_network):
        df["Time"].apply(pd.to_timedelta, unit='s')
        df["Time"] = df["Time"] - df["Time"].iloc[0]
        df.rename(
            columns={
                '{instance="192.168.221.10:9100"}': 'Master',
                '{instance="192.168.221.11:9100"}': 'Worker1',
                '{instance="192.168.221.12:9100"}': 'Worker2',
                '{instance="10.231.0.208:9100"}': 'Registry',
                '{instance="192.168.221.10:9100",job="prometheus"}': 'Master',
                '{instance="192.168.221.11:9100",job="prometheus"}': 'Worker1',
                '{instance="192.168.221.12:9100",job="prometheus"}': 'Worker2',
                '{instance="10.231.0.208:9100",job="prometheus"}': 'Registry',
            },
            inplace=True
        )
    # Merge the two df by creating a new df (time, disk, network) of only worker2
    df = pd.merge(df_disk, df_network, on='Time')
    df = df[['Time', 'Worker2_x', 'Worker2_y']]
    df.rename(
        columns={
            'Worker2_x': 'Disk',
            'Worker2_y': 'Network',
        },
        inplace=True
    )

    df['Disk'] = df['Disk'] / 1024 / 1024
    df['Network'] = df['Network'] / 1024 / 1024

    ax = df.plot(x='Time', y='Disk', figsize=(6, 4))
    df.plot(x='Time', y='Network', ax=ax)

    # On the left put the ticks for the disk, on the right the ticks for the network
    ax.set_xlim([-0.01, df['Time'].max() - (df['Time'].max() % 60) + 60 + 0.01])

    ticks = []
    labels = []
    mmax = df['Time'].max() - (df['Time'].max() % 60) + 60
    for i in range(0, mmax, 60):
        ticks.append(i)
        labels.append(datetime.datetime.utcfromtimestamp(i).strftime('%M:%S'))
    ax.set_xticks(ticks)
    ax.set_xticklabels(labels)
    ax.set_xlim([-0.01, mmax - 60 + 0.01])

    ax.set_xlabel('Time')
    ax.set_ylabel(MAPPINGS[plot]['ylabel'])
    ax.set_title(MAPPINGS[plot]['title'])

    print(df.head())

    plt.grid(axis='y')
    plt.tight_layout()
    plt.savefig(PLOT_DIR + '/' + plot + '.png')


def plot_worker2cpu(df: pd.DataFrame, plot: str):
    df["Time"].apply(pd.to_timedelta, unit='s')
    df["Time"] = df["Time"] - df["Time"].iloc[0]
    df.rename(
        columns={
            '{mode="idle"}': 'Idle',
            '{mode="iowait"}': 'IOWait',
            '{mode="irq"}': 'IRQ',
            '{mode="nice"}': 'Nice',
            '{mode="softirq"}': 'SoftIRQ',
            '{mode="steal"}': 'Steal',
            '{mode="system"}': 'System',
            '{mode="user"}': 'User',
        },
        inplace=True
    )

    # compress the dataframe, taking the average of each 60s interval
    # df = df.groupby(np.arange(len(df))//60).mean()
    # set the time column to 0, 1, 2, ...
    df['Time'] = df.index

    # reorder the columns
    df = df[['Time', 'User', 'System', 'IOWait', 'Idle', 'Nice', 'SoftIRQ', 'Steal', 'IRQ']]

    # normalize each data row s.t. the sum of all values is 1
    for i, row in df.iterrows():
        s = row[1:].sum()
        for col in df.columns[1:]:
            df.at[i, col] = df.at[i, col] / s * 100

    # stop sns's white border on the bars

    # use a palette that colors the bars in the same color as the lines
    # plot a barplot. in each row, stack all the values that are at time t, t+60
    ax = df.plot.area(x='Time', y=df.columns[1:4], stacked=True, figsize=(6, 4))

    ticks = []
    labels = []
    mmax = df['Time'].max() - (df['Time'].max() % 60) + 60
    for i in range(0, mmax, 60):
        ticks.append(i)
        labels.append(datetime.datetime.utcfromtimestamp(i).strftime('%M:%S'))
    ax.set_xticks(ticks)
    ax.set_xticklabels(labels)
    ax.set_xlim([-0.01, mmax - 60 + 0.01])
    ax.set_ylim(0, 100)

    # Set the labels
    ax.set_xlabel('Time')
    ax.set_ylabel(MAPPINGS[plot]['ylabel'])
    ax.set_title(MAPPINGS[plot]['title'])

    print(df.head())

    # Save the figure
    plt.tight_layout()
    plt.savefig(PLOT_DIR + '/' + plot + '.png')



def main():
    # Read in the data
    plots = os.listdir(DATA_DIR)
    os.makedirs(PLOT_DIR, exist_ok=True)

    plots.append('disk_w+network_r')

    for plot in plots:
        sns.set(rc={'figure.figsize': (6, 4), 'figure.dpi': 300, 'savefig.dpi': 300}, font_scale=.9)

        sns.set_style('whitegrid')
        sns.set_context('paper')
        sns.set_palette('colorblind')

        if plot == "worker2cpu":
            df = pd.read_csv(DATA_DIR + '/' + plot, sep=';')

            plot_worker2cpu(df, plot)
        elif plot == "disk_w+network_r":
            df_disk = pd.read_csv(DATA_DIR + '/' + 'disk_w', sep=';')
            df_network = pd.read_csv(DATA_DIR + '/' + 'network_r', sep=';')

            plot_disk_network(df_disk=df_disk, df_network=df_network, plot=plot)


if __name__ == "__main__":
    main()
