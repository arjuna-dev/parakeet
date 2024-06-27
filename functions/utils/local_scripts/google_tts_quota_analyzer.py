import os
import json
import csv
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime

# Step 1: Collect data from files
def collect_file_data(base_path):
    file_data = []
    for i in range(1, 8):  # Directories u1 to u7
        dir_path = os.path.join(base_path, f'd{i}')
        for filename in os.listdir(dir_path):
            if filename.endswith('.mp3'):
                filepath = os.path.join(dir_path, filename)
                creation_time = os.path.getctime(filepath)
                # Get the total seconds since epoch and fractional part
                total_seconds = datetime.fromtimestamp(creation_time).timestamp()
                # Subtract the integer part to get only the fractional seconds
                seconds_since_midnight = total_seconds % 86400  # seconds in a day
                file_data.append({
                    'filename': filename,
                    'time_of_creation': seconds_since_midnight,
                    'parent_directory': f'd{i}'
                })
    return file_data

# Step 2: Save data to JSON and CSV
def save_data(file_data):
    # Write to JSON
    with open('file_data.json', 'w') as f:
        json.dump(file_data, f, default=str)
    
    # Write to CSV
    with open('file_data.csv', 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['filename', 'time_of_creation', 'parent_directory'])
        writer.writeheader()
        for row in file_data:
            writer.writerow(row)

# Step 3: Plot data
def plot_data(file_data):
    # Convert to DataFrame for easier manipulation
    df = pd.DataFrame(file_data)
    
    # Calculate the minimum time_of_creation value
    min_time_of_creation = df['time_of_creation'].min()
    
    # Subtract the minimum value from each time_of_creation value
    df['adjusted_time_of_creation'] = df['time_of_creation'] - min_time_of_creation
    
    # Plot 1: Adjusted time-of-creation distribution of all files
    plt.figure(figsize=(10, 5))
    # Plot all points in blue first
    plt.scatter(df['adjusted_time_of_creation'], [1]*len(df), alpha=0.5, c='blue')
    # Then plot every 500th point in red on top
    plt.scatter(df['adjusted_time_of_creation'][::500], [1]*len(df[::500]), alpha=0.5, c='red')
    plt.title('Adjusted time-of-creation distribution of all files')
    plt.xlabel('Adjusted seconds since midnight')
    plt.yticks([])
    plt.show()

    # Adjusted time-of-creation distribution as a histogram (every 5 seconds)
    plt.figure(figsize=(10, 5))
    plt.hist(df['adjusted_time_of_creation'], bins=range(0, int(df['adjusted_time_of_creation'].max()) + 5, 5), alpha=0.7)
    plt.title('Number of files created every 5 seconds (adjusted)')
    plt.xlabel('Adjusted seconds since midnight')
    plt.ylabel('Number of files')
    plt.show()

    # Time needed to create each file
    # Ensure the DataFrame is sorted by time_of_creation
    df = df.sort_values(by='time_of_creation')

    # Calculate the time difference between each file and its predecessor
    df['creation_time_diff'] = df['time_of_creation'].diff()

    # Plotting the time needed to create each file
    plt.figure(figsize=(10, 5))
    # Plot all points in blue first
    plt.scatter(range(len(df)), df['creation_time_diff'])
    # Then plot every 500th point in red on top
    plt.scatter(range(len(df))[::500], df['creation_time_diff'][::500], c='red')
    plt.title('Time needed to create each file')
    plt.xlabel('File Index')
    plt.ylabel('Time to create file (seconds)')
    plt.grid(True)
    plt.show()

    # Plotting the time needed to create each file
    plt.figure(figsize=(10, 5))
    plt.scatter(df['time_of_creation'], df['creation_time_diff'])
    # Then plot every 500th point in red on top
    plt.scatter(df['time_of_creation'][::500], df['creation_time_diff'][::500], c='red')
    plt.title('Time needed to create each file')
    plt.xlabel('File Index')
    plt.ylabel('Time to create file (seconds)')
    plt.grid(True)
    plt.show()

    # Plot 3: Individual plots for each directory with adjusted times
    # for i in range(1, 8):
    #     dir_df = df[df['parent_directory'] == f'd{i}']
    #     plt.figure(figsize=(10, 5))
    #     plt.scatter(dir_df['adjusted_time_of_creation'], [1]*len(dir_df), alpha=0.5)
    #     plt.title(f'Adjusted time-of-creation distribution for directory d{i}')
    #     plt.xlabel('Adjusted seconds since midnight')
    #     plt.yticks([])
    #     plt.show()

# Main function to run the tasks
def main():
    base_path = 'concurrent_API_calls_responses'  # Set the correct path to your directories
    file_data = collect_file_data(base_path)
    save_data(file_data)
    plot_data(file_data)

if __name__ == '__main__':
    main()
