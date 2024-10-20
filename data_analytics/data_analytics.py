import pandas as pd
import json
import matplotlib.pyplot as plt
from utils.update_data import get_updated_data as update_csvs
import datetime

# ['Solarize_Light2', '_classic_test_patch', '_mpl-gallery', '_mpl-gallery-nogrid', 'bmh', 'classic', 'dark_background', 'fast', 'fivethirtyeight', 'ggplot', 'grayscale', 'seaborn-v0_8', 'seaborn-v0_8-bright', 'seaborn-v0_8-colorblind', 'seaborn-v0_8-dark', 'seaborn-v0_8-dark-palette', 'seaborn-v0_8-darkgrid', 'seaborn-v0_8-deep', 'seaborn-v0_8-muted', 'seaborn-v0_8-notebook', 'seaborn-v0_8-paper', 'seaborn-v0_8-pastel', 'seaborn-v0_8-poster', 'seaborn-v0_8-talk', 'seaborn-v0_8-ticks', 'seaborn-v0_8-white', 'seaborn-v0_8-whitegrid', 'tableau-colorblind10']

# plt.style.use('seaborn-v0_8') # Marginally better
# plt.style.use('Solarize_Light2') # Stylish/pale yellow
# plt.style.use('fivethirtyeight') # bold
# plt.style.use('seaborn-v0_8-muted') # Nice pallette
# plt.style.use('bmh') #
# plt.style.use('ggplot') #
import mplcyberpunk
plt.style.use("cyberpunk")

# update_csvs()

# CSV to data frames
df_users = pd.read_csv('users.csv')
df_big_jsons = pd.read_csv('big_jsons.csv')
df_analytics = pd.read_csv('analytics.csv')

# Delete devs. Arjuna: JRqn79vzmsYDYv7x6iLv2Zr9BKB3. Aman: iGSXBmdrYcSknvDvCsKVPh0BXOC3, zP881wvbGYVsh79aWH7ydUBbk2E2, lHvsiMBs5Met5vTfWJWyNs59t4f1
df_big_jsons = df_big_jsons[(df_big_jsons['user_ID'] != 'JRqn79vzmsYDYv7x6iLv2Zr9BKB3') & (df_big_jsons['user_ID'] != 'iGSXBmdrYcSknvDvCsKVPh0BXOC3') & (df_big_jsons['user_ID'] != 'zP881wvbGYVsh79aWH7ydUBbk2E2') & (df_big_jsons['user_ID'] != 'lHvsiMBs5Met5vTfWJWyNs59t4f1')]
df_analytics = df_analytics[(df_analytics['user_id'] != 'JRqn79vzmsYDYv7x6iLv2Zr9BKB3') & (df_analytics['user_id'] != 'iGSXBmdrYcSknvDvCsKVPh0BXOC3') & (df_analytics['user_id'] != 'zP881wvbGYVsh79aWH7ydUBbk2E2') & (df_analytics['user_id'] != 'lHvsiMBs5Met5vTfWJWyNs59t4f1')]

# Get rid of unused columns in users table
df_users = df_users[['id', 'name', 'email', 'favoriteAudioFiles']]

# Convert favorites to count of favorites
df_users['favoriteAudioFiles'] = df_users['favoriteAudioFiles'].apply(
    lambda x: len(json.loads(x.replace("'", '"'))) if isinstance(x, str) else 0
)

# Add number of lessons created to users table
user_id_counts = df_big_jsons['user_ID'].value_counts()
df_counts = user_id_counts.rename_axis('id').reset_index(name='# of Lessons') #Turn into df
df_users = pd.merge(df_users, df_counts, how='left', left_on='id', right_on='id')
df_users['# of Lessons'].fillna(0, inplace=True)
df_users.sort_values(by='# of Lessons', ascending=False, inplace=True)

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_Visualize users by number of lessons-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-


users_N_lessons = df_users.groupby('name')['# of Lessons'].sum().sort_values(ascending=False)
users_N_lessons.to_csv('csv/users_N_lessons.csv')

# Visualize as bar chart
fig = plt.figure(figsize=(10, 6))

plt.bar(users_N_lessons.index, users_N_lessons.values)
plt.title('Number of lessons created by user')
plt.xlabel('User')
plt.ylabel('Number of lessons')
plt.xticks(rotation=90)
plt.savefig('img/users_N_lessons.png')
plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_Users and lessons by date of creation for top users-_-_-_-_-_-_-_-_
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

# Select the necessary columns
df_daily_usage = df_big_jsons[["language_level", "document_id", "user_ID", "target_language", "timestamp"]]

# Add name column
df_daily_usage = pd.merge(df_daily_usage, df_users[['id', 'name']], how='left', left_on='user_ID', right_on='id')

# Add # of Lessons column
df_daily_usage['# of Lessons'] = df_daily_usage['user_ID'].map(df_users.set_index('id')['# of Lessons'])

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_Users and lessons by date of creation for top users-_-_-_-_-_-_-_-_
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

# Find top unique users by # of Lessons
number_of_top_users = 5
top_users = df_daily_usage.groupby('user_ID')['# of Lessons'].max().nlargest(number_of_top_users).index

# Filter the original DataFrame to keep only the top 10 users
df_daily_usage_top = df_daily_usage[df_daily_usage['user_ID'].isin(top_users)]

# Convert timestamp to datetime and extract only the date part
df_daily_usage_top['timestamp'] = pd.to_datetime(df_daily_usage_top['timestamp']).dt.date

# Group by 'name' and 'timestamp', then count the number of lessons created per day
lessons_per_day = df_daily_usage_top.groupby([df_daily_usage_top['name'], df_daily_usage_top['timestamp']]).size().reset_index(name='lesson_count')

# Pivot the table so each name becomes a column
pivot_table = lessons_per_day.pivot(index='timestamp', columns='name', values='lesson_count').fillna(0)

# Plot each user's lessons per day
pivot_table.plot(kind='line', marker='o', figsize=(10, 6))

# Add labels and title
plt.xlabel('Date')
plt.ylabel('Number of Lessons')
plt.title('Lessons Created Per Day by Top 5 Users')
plt.xticks(rotation=45)
plt.legend(title='User')

plt.tight_layout()
plt.savefig('img/lessons_per_day.png')
plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_Users that re-listen to lessons on different dates-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

def return_creation_date(play):
    # Remove 'DatetimeWithNanoseconds' and replace it with just a placeholder or proper datetime
    data_str = play.replace('DatetimeWithNanoseconds', 'datetime.datetime')
    # Safely evaluate the string into a dictionary
    data = eval(data_str)

    # Extract the datetime object
    timestamp = data['timestamp'].date()

    return timestamp

def return_timestamps_dates(play):
    # Remove 'DatetimeWithNanoseconds' and replace it with just a placeholder or proper datetime
    data_str = play.replace('DatetimeWithNanoseconds', 'datetime.datetime')
    # Safely evaluate the string into a dictionary
    data = eval(data_str)

    timestamps = set([datetime.datetime.fromisoformat(ts).date() for ts in data.get('timestamps', [])])

    return timestamps

df_analytics['creation_date'] = df_analytics['play'].apply(return_creation_date)

df_analytics['timestamps'] = df_analytics['play'].apply(return_timestamps_dates)

def timestamps_count(row):
    timestamps = row['timestamps']
    timestamps_count = len(timestamps)
    return timestamps_count

# Apply the function and create a new column to flag rows where timestamps differ
df_analytics['played_on_different_date'] = df_analytics.apply(timestamps_count, axis=1)

df_played_on_different_date = df_analytics[df_analytics['played_on_different_date'] > 1]


# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-Pie Chart-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

files_played_on_different_date = df_played_on_different_date.shape[0]
all_files = df_analytics.shape[0]

percentage_of_files_played_on_different_date = files_played_on_different_date / all_files * 100

list_for_pie = [files_played_on_different_date, all_files - files_played_on_different_date]
print('list_for_pie: ', list_for_pie)

# Create pie chart of files played on different date
plt.figure(figsize=(10, 6))
plt.pie(list_for_pie, labels=['Files played on different date', 'Files played on creation day only'], autopct='%1.1f%%', startangle=90)
plt.title('Percentage of files played on different date')
plt.savefig('img/relisten_pie.png')
plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-Bar Chart-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

df_played_on_different_date = df_played_on_different_date[['creation_date', 'played_on_different_date', 'id', 'user_id']]

# Create bar chart of files played on different date
plt.figure(figsize=(10, 6))
plt.bar(df_played_on_different_date['id'], df_played_on_different_date['played_on_different_date'])
plt.title('Files played on different date')
plt.xlabel('File')
plt.ylabel('Number of days')
plt.savefig('img/relisten_bar.png')
plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
# _-_-_-_-_-Top re-listened With User, Target Language and File Name-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

# Get the top 10 re-listened files
top_10_relistened = df_played_on_different_date.nlargest(10, 'played_on_different_date')

# Merge to get the title. Use analytics id and big_jsons document_id
top_10_relistened = pd.merge(top_10_relistened, df_big_jsons[['document_id', 'title']], left_on='id', right_on='document_id', how='left')

# Merge to get user name. Use analytics user_id and users id
top_10_relistened = pd.merge(top_10_relistened, df_users[['id', 'name']], left_on='user_id', right_on='id', how='left')
top_10_relistened = top_10_relistened.drop('id_y', axis=1).rename(columns={'id_x': 'id'})

# Merge to get language. Use analytics id and big_jsons target_language
top_10_relistened = pd.merge(top_10_relistened, df_big_jsons[['document_id', 'target_language']], left_on='id', right_on='document_id', how='left')

# Keep meaningful columns
top_10_relistened = top_10_relistened[['played_on_different_date', 'name', 'title', 'target_language']]

# Display top_10_relistened as a table with matplotlib
plt.style.use('seaborn-v0_8') # bold
fig, ax = plt.subplots(figsize=(13, 6))
# ax.table(cellText=top_10_relistened.values, colLabels=top_10_relistened.columns, loc='center')
# Create the table
table = ax.table(cellText=top_10_relistened.values, colLabels=top_10_relistened.columns, cellLoc='center', loc='center')

# Customize font sizes and styles
table.auto_set_font_size(False)
table.set_fontsize(12)  # Set the font size for all cells

# Make the header bold and larger
# Make the header bold and larger
for key, cell in table.get_celld().items():
    row, col = key
    if row == 0:  # Header row
        cell.set_text_props(weight='bold', fontsize=14)
    cell.set_fontsize(12)

# Adjust cell sizes for better readability
table.scale(1.5, 1.5)  # Scale table size

# Make lines thicker
table.auto_set_column_width(col=list(range(len(top_10_relistened.columns))))  # Set column width automatically


ax.axis('off')
plt.savefig('img/top_10_relistened.png')
plt.show()

print(top_10_relistened)
