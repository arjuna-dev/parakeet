import pandas as pd
import json
import matplotlib.pyplot as plt
from utils.update_data import get_updated_data as update_csvs
import datetime
import matplotlib.dates as mdates
import seaborn as sns
from matplotlib.colors import ListedColormap


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

# Remove developers' data
dev_ids = [
    'JRqn79vzmsYDYv7x6iLv2Zr9BKB3',
    'iGSXBmdrYcSknvDvCsKVPh0BXOC3',
    'zP881wvbGYVsh79aWH7ydUBbk2E2',
    'lHvsiMBs5Met5vTfWJWyNs59t4f1'
]
df_big_jsons = df_big_jsons[~df_big_jsons['user_ID'].isin(dev_ids)]
df_analytics = df_analytics[~df_analytics['user_id'].isin(dev_ids)]

# Get rid of unused columns in users table
df_users = df_users[['id', 'name', 'email', 'favoriteAudioFiles']]

# Convert favoriteAudioFiles to count
def count_favorites(fav):
    if isinstance(fav, str) and fav != 'nan':
        fav_list = json.loads(fav.replace("'", '"'))
        return len(fav_list)
    else:
        return 0

df_users['Favorite Files Count'] = df_users['favoriteAudioFiles'].apply(count_favorites)

# Drop the original favoriteAudioFiles column
df_users.drop('favoriteAudioFiles', axis=1, inplace=True)

# Calculate number of lessons created per user
user_id_counts = df_big_jsons['user_ID'].value_counts()
df_counts = user_id_counts.rename_axis('id').reset_index(name='# of Lessons')  # Convert to DataFrame
df_users = pd.merge(df_users, df_counts, how='left', on='id')
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
# plt.show()

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
top_5_users = df_daily_usage.groupby('user_ID')['# of Lessons'].max().nlargest(number_of_top_users).index

# Find top 10 users by # of Lessons
top_10_users = df_daily_usage.groupby('user_ID')['# of Lessons'].max().nlargest(10).index

# Filter the original DataFrame to keep only the top 10 users
df_daily_usage_top = df_daily_usage[df_daily_usage['user_ID'].isin(top_5_users)]

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
# plt.show()

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

print(df_analytics['timestamps'])
df_analytics['timestamps'].to_csv('timestamps.csv', index=False)


def timestamps_count(row):
    timestamps = row['timestamps']
    timestamps_count = len(timestamps)
    return timestamps_count

# Apply the function and create a new column to flag rows where timestamps differ
df_analytics['played_on_different_date'] = df_analytics.apply(timestamps_count, axis=1)

df_played_on_different_date = df_analytics[df_analytics['played_on_different_date'] > 1]



# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_Usage per user (counts)-_-_-_-_-_-_-_-_-_
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

# Explode the 'timestamps' column to get one row per timestamp
df_analytics_exploded = df_analytics.explode('timestamps')

# Drop 'id' from df_analytics_exploded to avoid conflict
df_analytics_exploded.drop(columns=['id'], inplace=True)

# Continue with your processing
# Convert 'timestamps' to datetime
df_analytics_exploded['timestamps'] = pd.to_datetime(df_analytics_exploded['timestamps'])

# Extract dates
df_analytics_exploded['date'] = df_analytics_exploded['timestamps'].dt.date

# Merge with df_users to add user details
df_analytics_with_users = df_analytics_exploded.merge(
    df_users, left_on='user_id', right_on='id', how='left'
)

# Now, you can group by 'id' without issues
user_unique_date_counts = df_analytics_with_users.groupby('id')['date'].nunique().reset_index()
user_unique_date_counts.rename(columns={'date': 'Number of Unique Active Days'}, inplace=True)

# Sort the counts in descending order
user_unique_date_counts = user_unique_date_counts.sort_values(by='Number of Unique Active Days', ascending=False)

# Merge 'Number of Unique Active Days' into df_users
df_users = pd.merge(df_users, user_unique_date_counts[['id', 'Number of Unique Active Days']], how='left', on='id')
df_users['Number of Unique Active Days'].fillna(0, inplace=True)

# Convert counts to integer type
df_users['# of Lessons'] = df_users['# of Lessons'].astype(int)
df_users['Number of Unique Active Days'] = df_users['Number of Unique Active Days'].astype(int)
df_users['Favorite Files Count'] = df_users['Favorite Files Count'].astype(int)

# Now create df_data
df_data = df_users[['id', 'name', 'email', 'Favorite Files Count', '# of Lessons', 'Number of Unique Active Days']]

# Save to CSV
df_data.to_csv('csv/data.csv', index=False)

# Visualize the data
user_unique_date_counts.plot(kind='bar', figsize=(10, 6))
plt.xlabel('User')
plt.ylabel('Number of Active Days')
plt.title('Number of Unique Active Days per User')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('img/user_unique_active_days.png')
# plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
# _-_-_-_-_-_-_Usage per user (over time)-_-_-_-_-_-_-_-_-_
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

# Identify top 5 users
user_timestamp_counts = df_analytics_with_users.groupby('name')['timestamps'].count()
user_timestamp_counts = user_timestamp_counts.sort_values(ascending=False)
top_5_users = user_timestamp_counts.head(5).index.tolist()

# Filter data for top 5 users
df_top_users = df_analytics_with_users[df_analytics_with_users['name'].isin(top_5_users)]

df_top_users = df_top_users.copy()

df_top_users['timestamps'] = pd.to_datetime(df_top_users['timestamps'])

# Extract dates
df_top_users['date'] = df_top_users['timestamps'].dt.date

# Create date range
all_dates = pd.date_range(start=df_top_users['date'].min(), end=df_top_users['date'].max())

# Initialize activity DataFrame
activity_df = pd.DataFrame({'date': all_dates})

# # Create binary activity columns
# for user in top_5_users:
#     user_dates = df_top_users[df_top_users['name'] == user]['date'].unique()
#     activity_df[user] = activity_df['date'].isin(user_dates).astype(int)

# Convert 'date' columns to datetime64[ns]
activity_df['date'] = pd.to_datetime(activity_df['date'])

# Adjust the loop for creating binary activity columns
for user in top_5_users:
    user_dates = df_top_users[df_top_users['name'] == user]['date']
    user_dates = pd.to_datetime(user_dates)
    activity_df[user] = activity_df['date'].isin(user_dates).astype(int)

activity_df.set_index('date', inplace=True)

# Plot binary activity
plt.figure(figsize=(12, 6))

for idx, user in enumerate(top_5_users):
    plt.step(activity_df.index, activity_df[user] + idx * 1.5, where='post', label=user)

plt.yticks([])
plt.xlabel('Date')
plt.title('User Activity Over Time (Top 5 Users)')
plt.legend(title='User')

# Adjust x-axis labels
plt.gca().xaxis.set_major_locator(mdates.AutoDateLocator())
plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
plt.xticks(rotation=45)

plt.tight_layout()
plt.savefig('img/user_activity_binary.png')
# plt.show()

# Ensure 'date' is a datetime index
activity_df.index = pd.to_datetime(activity_df.index)

# Transpose the DataFrame so that users are on the y-axis and dates on the x-axis
heatmap_data = activity_df.T

# Sort the dates in chronological order
heatmap_data = heatmap_data.sort_index(axis=1)

# Define a custom discrete color map
cmap = ListedColormap(['#232844', '#EB60B8'])  # Light gray for inactive, red for active

# Plot the heatmap
plt.figure(figsize=(15, 6))
sns.heatmap(
    heatmap_data,
    cmap=cmap,
    cbar=True,              # Show the color bar
    linewidths=0.5,
    linecolor='white',
    square=False,
    # annot=True,             # Annotate cells with data values (0 or 1)
    # fmt='d',                # Format annotations as integers
    cbar_kws={'ticks': [0, 1]}  # Set color bar ticks to 0 and 1
)

plt.xlabel('Date')
plt.ylabel('User')
plt.title('User Activity Heatmap Over Time (Top 5 Users)')
plt.xticks(rotation=45)

plt.tight_layout()
plt.savefig('img/user_activity_heatmap_custom.png')
# plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
# _-_-_-_-_-Re-listen Pie Chart-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

files_played_on_different_date = df_played_on_different_date[df_played_on_different_date['user_id'].isin(top_10_users)].shape[0]
all_files = df_analytics[df_analytics['user_id'].isin(top_10_users)].shape[0]

percentage_of_files_played_on_different_date = files_played_on_different_date / all_files * 100

list_for_pie = [files_played_on_different_date, all_files - files_played_on_different_date]
# print('list_for_pie: ', list_for_pie)

# Create pie chart of files played on different date
plt.figure(figsize=(10, 6))
plt.pie(list_for_pie, labels=['Files played on different date', 'Files played on creation day only'], autopct='%1.1f%%', startangle=90)
plt.title('Percentage of files played on different date for top 10 users')
plt.savefig('img/relisten_pie.png')
# plt.show()

# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
# _-_-_-_-_-Pie Chart-_-_-_-_-_-_-_-_-
# _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

files_played_on_different_date = df_played_on_different_date.shape[0]
all_files = df_analytics.shape[0]

percentage_of_files_played_on_different_date = files_played_on_different_date / all_files * 100

list_for_pie = [files_played_on_different_date, all_files - files_played_on_different_date]
# print('list_for_pie: ', list_for_pie)

# Pie chart of users by lessons created
lesson_counts = df_users['# of Lessons'].apply(lambda x: '0 lessons' if x == 0 else ('1 lesson' if x == 1 else ('2 lessons' if x == 2 else 'More than 2 lessons'))).value_counts()

plt.figure(figsize=(10, 6))
plt.pie(lesson_counts.values, labels=lesson_counts.index, autopct='%1.1f%%', startangle=90)
plt.title('Distribution of Users by Number of Lessons Created')
plt.savefig('img/lesson_distribution_pie.png')
# plt.show()

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
# plt.show()

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
# plt.show()


df_data = df_users[['id', 'name', 'email', 'Favorite Files Count', '# of Lessons', 'Number of Unique Active Days']]
