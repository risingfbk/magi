import pandas as pd
import matplotlib.pyplot as plt

# Load the data
df = pd.read_csv('master-magi.csv')
df_w2 = pd.read_csv('worker2-magi.csv')

# Convert the 'time' column to datetime
df['time'] = pd.to_datetime(df['time'])
df_w2['time'] = pd.to_datetime(df_w2['time'])

# Set 'time' as the index
df.set_index('time', inplace=True)
df_w2.set_index('time', inplace=True)

# Plot the data
plt.figure(figsize=(10, 6))

plt.subplot(3, 1, 1)
plt.plot(df['cpu'], label='CPU Master', color='blue')
plt.plot(df_w2['cpu'], label='CPU Worker2', color='cyan')
plt.legend()

plt.subplot(3, 1, 2)
plt.plot(df['mem'], label='Memory Master', color='orange')
plt.plot(df_w2['mem'], label='Memory Worker2', color='red')
plt.legend()

plt.subplot(3, 1, 3)
plt.plot(df['pids'], label='PIDs Master', color='green')
plt.plot(df_w2['pids'], label='PIDs Worker2', color='lime')
plt.legend()

plt.tight_layout()
plt.savefig('plot.png')