import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.dates as mdates
import os
import datetime
import argparse
import json
from secret_parameters import main_registry

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

WINDOW = 10
CUTOFF_BUFFER = 40
TICK_INTERVAL = 4

DEFAULT_DIR = "temp_data"
WORKER2_REPLACEMENTS = {
    '{mode="idle"}': 'Idle',
    '{mode="iowait"}': 'IOWait',
    '{mode="irq"}': 'IRQ',
    '{mode="nice"}': 'Nice',
    '{mode="softirq"}': 'SoftIRQ',
    '{mode="steal"}': 'Steal',
    '{mode="system"}': 'System',
    '{mode="user"}': 'User',
}

WORKERXY_REPLACEMENTS = {
    'Worker2_x': 'Disk',
    'Worker2_y': 'Network',
    'Worker1_x': 'Disk',
    'Worker1_y': 'Network'
}

DISKNETWORK_REPLACEMENTS = {
    '{instance="192.168.221.10:9100"}': 'Master',
    '{instance="192.168.221.11:9100"}': 'Worker1',
    '{instance="192.168.221.12:9100"}': 'Worker2',
    '{instance="192.168.200.10:9100"}': 'Master',
    '{instance="192.168.200.11:9100"}': 'Worker1',
    '{instance="192.168.200.12:9100"}': 'Registry',
    '{instance="' + main_registry + ':9100"}': 'Registry',
    '{instance="192.168.221.10:9100",job="prometheus"}': 'Master',
    '{instance="192.168.221.11:9100",job="prometheus"}': 'Worker1',
    '{instance="192.168.221.12:9100",job="prometheus"}': 'Worker2',
    '{instance="' + main_registry + ':9100",job="prometheus"}': 'Registry',
}


def plot_normal(df: pd.DataFrame, plot: str, plot_dir: str):
    df.rename(
        columns=DISKNETWORK_REPLACEMENTS,
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
    ax = df.plot(x='Time', y='Worker')
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
    ax.set_xticklabels(labels, rotation=45)
    ax.set_xlim([-0.01, mmax - 60 + 0.01])

    # ax.xaxis.set_major_locator(mdates.SecondLocator(interval=60))
    # ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))

    # print(df.head())

    # plt.gcf().autofmt_xdate()

    # Set the labels
    ax.set_xlabel('Time')
    ax.set_ylabel(MAPPINGS[plot]['ylabel'])
    ax.set_title(MAPPINGS[plot]['title'])

    # Save the figure
    plt.tight_layout()
    plt.savefig(plot_dir + '/' + plot + '.png', bbox_inches="tight", pad_inches=0.01)
    plt.close()


def plot_disk_network(df_disk: pd.DataFrame,
                      df_network: pd.DataFrame,
                      plot_name: str,
                      seconds: int,
                      cutoff_seconds: int,
                      plot_dir: str):
    for df in (df_disk, df_network):
        df["Time"].apply(pd.to_timedelta, unit='s')
        df["Time"] = df["Time"] - df["Time"].iloc[0]
        df.rename(
            columns=DISKNETWORK_REPLACEMENTS,
            inplace=True
        )
    # Merge the two df by creating a new df (time, disk, network) of only worker2
    df = pd.merge(df_disk, df_network, on='Time')

    if 'Worker2' in df or 'Worker2_x' in df:
        df = df[['Time', 'Worker2_x', 'Worker2_y']]

    print(df.head())
    df.rename(
        columns=WORKERXY_REPLACEMENTS,
        inplace=True
    )

    for column in df.columns[1:]:
        df[column] = df[column].rolling(WINDOW, min_periods=1).mean()

    # Trim the table at the cutoff if passed
    if cutoff_seconds is not None and cutoff_seconds > 0:
        df = df[df['Time'] <= cutoff_seconds]

    df['Disk'] = df['Disk'] / 1024 / 1024
    df['Network'] = df['Network'] / 1024 / 1024

    print(df.head())

    ax = df.plot(x='Time', y='Disk', linewidth=1)
    df.plot(x='Time', y='Network', ax=ax, linewidth=1.2)

    # On the left put the ticks for the disk, on the right the ticks for the network
    ax.set_xlim([-0.01, df['Time'].max() - (df['Time'].max() % 60) + 60 + 0.01])

    ticks = []
    labels = []

    if seconds is None or seconds <= 0:
        mmax = df['Time'].max() - (df['Time'].max() % 60) + 60
    else:
        mmax = seconds

    for i in range(0, mmax, 60):
        if i % (60*TICK_INTERVAL) == 0:
            ticks.append(i)
            labels.append(datetime.datetime.utcfromtimestamp(i).strftime('%M:%S'))

    ax.set_xticks(ticks)
    ax.set_xticklabels(labels, rotation=30)
    ax.set_xlim([-0.01, mmax - 60 + 0.01])
    ax.set_ylim([-0.01, 175])
    plt.setp(ax.get_xticklabels(), color="black")
    plt.setp(ax.get_yticklabels(), color="black")

    ax.set_xlabel('Time')
    ax.set_ylabel(MAPPINGS[plot_name]['ylabel'])
    ax.set_title(MAPPINGS[plot_name]['title'])

    # print(df.head())
    #plt.legend().set_visible(False)

    plt.grid(axis='y')
    plt.tight_layout()
    plt.savefig(plot_dir + '/' + plot_name + '.png', bbox_inches="tight", pad_inches=0.01)
    plt.close()


def plot_worker2cpu(df: pd.DataFrame,
                    plot: str,
                    seconds: int,
                    cutoff_seconds: int,
                    plot_dir: str):
    df["Time"].apply(pd.to_timedelta, unit='s')
    df["Time"] = df["Time"] - df["Time"].iloc[0]
    df.rename(
        columns=WORKER2_REPLACEMENTS,
        inplace=True
    )

    for column in df.columns[1:]:
        df[column] = df[column].rolling(WINDOW, min_periods=1).mean()

    # compress the dataframe, taking the average of each 60s interval
    # df = df.groupby(np.arange(len(df))//60).mean()
    # set the time column to 0, 1, 2, ...
    df['Time'] = df.index

    # Trim the table at the cutoff if passed
    #if cutoff_seconds is not None and cutoff_seconds > 0:
    #    df = df[df['Time'] <= cutoff_seconds]

    # reorder the columns
    df = df[['Time', 'System', 'User', 'IOWait', 'Idle', 'Nice', 'SoftIRQ', 'Steal', 'IRQ']]

    # normalize each data row s.t. the sum of all values is 1
    for i, row in df.iterrows():
        s = row[1:].sum()
        for col in df.columns[1:]:
            df.at[i, col] = df.at[i, col] / s * 100

    # Estimate average CPU usage
    acc = 0
    for i, row in df.iterrows():
        if i >= cutoff_seconds - CUTOFF_BUFFER:
            break
        acc += row[1:].sum() - row["Idle"]

    # Take the average by counting the number of lines in the file
    print(f"Average CPU utilization: {acc/(len(df)-CUTOFF_BUFFER)}")

    # use a palette that colors the bars in the same color as the lines
    # plot a barplot. in each row, stack all the values that are at time t, t+60
    ax = df.plot.area(x='Time', y=df.columns[1:4], stacked=True)

    ticks = []
    labels = []
    if seconds is None or seconds <= 0:
        mmax = df['Time'].max() - (df['Time'].max() % 60) + 60
    else:
        mmax = seconds

    for i in range(0, mmax, 60):
        if i % (60*TICK_INTERVAL) == 0:
            ticks.append(i)
            labels.append(datetime.datetime.utcfromtimestamp(i).strftime('%M:%S'))

    ax.set_xticks(ticks)
    ax.set_xticklabels(labels, rotation=30)
    ax.set_xlim([-0.01, mmax - 60 + 0.01])
    ax.set_ylim(0, 100)
    plt.setp(ax.get_xticklabels(), color="black")
    plt.setp(ax.get_yticklabels(), color="black")

    # Set the labels
    ax.set_xlabel('Time')
    ax.set_ylabel(MAPPINGS[plot]['ylabel'])
    ax.set_title(MAPPINGS[plot]['title'])

    # pls hide the legend
    # plt.legend().set_visible(False)

    # print(df.head())

    # Save the figure
    plt.tight_layout()
    plt.savefig(plot_dir + '/' + plot + '.png', bbox_inches="tight", pad_inches=0.01)


def main():
    # Read in the data
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', '--time',
                        help='Experiment time in minutes',
                        dest='time',
                        required=True,
                        type=int)
    parser.add_argument('-c', '--cutoff',
                        help='Cutoff time after which data is ignored in seconds, 0 is no cutoff',
                        dest='cutoff',
                        required=False,
                        type=int)
    parser.add_argument('-d', '--dir',
                        help='Directory with the csv files',
                        dest='dir')
    parser.add_argument("-a", "--all", action="store_true",
                        help=f"Plot everything in {DEFAULT_DIR}/",
                        dest="all")
    args = parser.parse_args()

    if (args.dir and os.path.isdir(args.dir)) and not args.all:
        if os.path.isdir(f'{args.dir}/data'):
            directory = args.dir
        else:
            print('Provide a directory which contains a "data" subdirectory.')
            exit()
    else:
        subs = os.listdir(DEFAULT_DIR)
        avail = []
        for x in subs:
            if x == '.DS_Store' or x == "exports":
                continue
            subs2 = os.listdir(f'{DEFAULT_DIR}/{x}')
            for y in subs2:
                if os.path.isdir(f'{DEFAULT_DIR}/{x}/{y}') and y != '.DS_Store':
                    avail.append(f'{DEFAULT_DIR}/{x}/{y}')

        avail = sorted(avail)

        if not args.all:
            for i in range(1, len(avail) + 1):
                print(f"{i}: {avail[i - 1]}")
            directory = input(f"Which directory do you want to plot? ")
            if not directory.isdigit():
                print("Invalid directory, exiting...")
                exit()
            directory = avail[int(directory) - 1]
        else:
            for d in avail:
                print(f"Plotting {d}...")
                init(d, args.cutoff, args.time)
            exit(1)

    print(f"Plotting {directory}...")
    init(directory, args.cutoff, args.time)


def init(directory: str,
         cutoff: int,
         time: int):
    data_dir = f'{directory}/data'
    plot_dir = f'{directory}/plots'
    # metadata = json.load(open(f'{directory}/metadata.json'))

    plots = os.listdir(data_dir)
    os.makedirs(plot_dir, exist_ok=True)

    plots.append('disk_w+network_r')

    if not cutoff:
        co = calculate_cutoff(data_dir)
    else:
        co = cutoff

    time += 1
    time *= 60

    for plot in plots:
        sns.set_context('paper')
        sns.set(rc={'figure.figsize': (6, 3.5), 'figure.dpi': 300, 'savefig.dpi': 300}, font_scale=1.3)
        style = sns.axes_style("whitegrid")
        style['xtick.bottom'] = True
        style["xtick.color"] = ".8"
        style['ytick.left'] = True
        style["ytick.color"] = ".8"

        sns.set_style(style)
        sns.despine()

        if plot == "worker2cpu":
            sns.set_palette(["#17374d", '#4884cf', "lightgrey"])
            df = pd.read_csv(data_dir + '/' + plot, sep=';')

            plot_worker2cpu(df,
                            plot,
                            seconds=time,
                            cutoff_seconds=co,
                            plot_dir=plot_dir)
        elif plot == "disk_w+network_r":
            sns.set_palette(['lightgrey', '#17374d'])
            df_disk = pd.read_csv(data_dir + '/' + 'disk_w', sep=';')
            df_network = pd.read_csv(data_dir + '/' + 'network_r', sep=';')

            plot_disk_network(df_disk=df_disk,
                              df_network=df_network,
                              plot_name=plot,
                              seconds=time,
                              cutoff_seconds=co,
                              plot_dir=plot_dir)


def calculate_cutoff(data_dir):
    # Open the worker2cpu data
    if 'worker2cpu' not in os.listdir(data_dir):
        raise Exception(f"No worker2cpu data found in {data_dir}.")
    df = pd.read_csv(data_dir + '/' + 'worker2cpu', sep=';')
    # Detect the first time the sum of all the fields is lower than 0.2
    df["Time"].apply(pd.to_timedelta, unit='s')
    df["Time"] = df["Time"] - df["Time"].iloc[0]
    df.rename(
        columns=WORKER2_REPLACEMENTS,
        inplace=True
    )

    min_detected = 1000

    for i, row in df.iterrows():
        # Skip the first 50% of the data for precaution.
        if i <= len(df) * 0.5:
            continue

        t = row.sum() - row['Time'] - row['Idle']
        if t <= min_detected:
            min_detected = t
        if t <= 0.15:
            print(f"Suggested cutoff: {row['Time']} @ {t}")
            return min(row['Time'] + CUTOFF_BUFFER, len(df))

    print(f"Couldn't detect any cutoff. Minimum: {min_detected}")
    return 0


if __name__ == "__main__":
    main()
