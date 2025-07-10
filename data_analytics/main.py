import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import os
import re
from datetime import datetime, timedelta
import json
from collections import Counter
from utils.update_data import get_updated_data as update_csvs

# update_csvs()

# Create directories for output
os.makedirs('img', exist_ok=True)
os.makedirs('csv', exist_ok=True)

def load_data():
    """
    Load the CSV files and perform basic data cleaning
    """
    # Load data
    lessons_df = pd.read_csv('big_jsons.csv')
    users_df = pd.read_csv('users.csv')
    analytics_df = pd.read_csv('analytics.csv')
    
    # Convert timestamp to datetime
    lessons_df['timestamp'] = pd.to_datetime(lessons_df['timestamp'])
    
    # Remove developers' data
    dev_ids = [
        'JRqn79vzmsYDYv7x6iLv2Zr9BKB3', # Arjuna
        'rCsgOp1brSOqmTgzFjRoyl2h7F12', # Aman
        'Reiwcc9qlEdxkIaL2qEUJrHijDc2', # Mukesh
        'epq5Ea6Ds7WZEcFbF4Q0WolwC7L2', # Mukesh
        'W2xup6UV1qeouNa8SjXxC8OX8IA3', # Aman
        'giWzKROPdBOIsplPk7j4f5jsesf2', # Aman
        'kqwaN5Iy5scWkAJ5INP5b9agX9y1', # Aman
        'Guqjyd9NbOMpeb7cX1cAfvAnjw02', # Aman
        'MWAACokJ57emcpJI99wxjxuc3Xk2', # Aman
        'O2lrNu55kVa1AsbOXtUGRThq2MI3'  # Aman
    ]
    lessons_df = lessons_df[~lessons_df['user_ID'].isin(dev_ids)]
    users_df = users_df[~users_df['id'].isin(dev_ids)]
    analytics_df = analytics_df[~analytics_df['user_id'].isin(dev_ids)]

    return lessons_df, users_df, analytics_df

def lessons_created_over_time(lessons_df, period_days=None, save=True):
    """
    Visualize lessons created over time
    
    Args:
        lessons_df: DataFrame with lesson data
        period_days: Number of days to include in the analysis (None for all data)
        save: Whether to save the plot to a file
    """
    # Filter by period if needed
    if period_days is not None:
        today = datetime.now()
        cutoff = today - timedelta(days=period_days)
        filtered_df = lessons_df[lessons_df['timestamp'] >= cutoff]
    else:
        filtered_df = lessons_df
    
    # Group by date and count lessons
    daily_counts = filtered_df.groupby(filtered_df['timestamp'].dt.date).size()
    daily_counts = daily_counts.reset_index()
    daily_counts.columns = ['Date', 'Count']
    
    # Plot
    plt.figure(figsize=(12, 6))
    plt.plot(daily_counts['Date'], daily_counts['Count'], marker='o', linestyle='-')
    plt.xlabel('Date')
    plt.ylabel('Number of Lessons Created')
    period_text = f'Past {period_days} days' if period_days else 'All time'
    plt.title(f'Lessons Created Over Time ({period_text})')
    plt.xticks(rotation=45)
    plt.tight_layout()
    
    if save:
        plt.savefig('img/lessons_over_time.png')
        daily_counts.to_csv('csv/lessons_over_time.csv', index=False)
    
    return daily_counts

def top_users_lessons_count(lessons_df, users_df, top_n=10, period_days=None, save=True):
    """
    Visualize number of lessons created by each user (sorted by top users)
    
    Args:
        lessons_df: DataFrame with lesson data
        users_df: DataFrame with user data
        top_n: Number of top users to display
        period_days: Number of days to include in the analysis (None for all data)
        save: Whether to save the plot to a file
    """
    # Filter by period if needed
    if period_days is not None:
        today = datetime.now()
        cutoff = today - timedelta(days=period_days)
        filtered_df = lessons_df[lessons_df['timestamp'] >= cutoff]
    else:
        filtered_df = lessons_df
    
    # Count lessons per user
    user_counts = filtered_df['user_ID'].value_counts().reset_index()
    user_counts.columns = ['user_ID', 'lesson_count']
    
    # Merge with users to get names
    user_counts_with_names = pd.merge(
        user_counts, 
        users_df[['id', 'name']], 
        how='left',
        left_on='user_ID', 
        right_on='id'
    )
    
    # Handle missing names
    user_counts_with_names['name'] = user_counts_with_names['name'].fillna('Unknown User')
    
    # Sort by lesson count and take top N
    top_users = user_counts_with_names.sort_values('lesson_count', ascending=False).head(top_n)
    
    # Plot
    plt.figure(figsize=(12, 6))
    sns.barplot(x='lesson_count', y='name', data=top_users)
    period_text = f'Past {period_days} days' if period_days else 'All time'
    plt.title(f'Top {top_n} Users by Number of Lessons Created ({period_text})')
    plt.xlabel('Number of Lessons')
    plt.ylabel('User')
    plt.tight_layout()
    
    if save:
        plt.savefig(f'img/top_{top_n}_users_lessons.png')
        top_users.to_csv(f'csv/top_{top_n}_users_lessons.csv', index=False)
    
    return top_users

# TODO: Add calendar for top N users function

def pie_chart_replay_status(analytics_df, period_days=None, save=True):
    """
    Create a pie chart showing "Files played only on creation date" vs "Files played on 2+ dates"
    
    Args:
        analytics_df: DataFrame with lesson data
        period_days: Number of days to include in the analysis (None for all data)
        save: Whether to save the plot to a file
    """
    # Filter by period if needed - note that analytics_df doesn't have a direct timestamp column
    # We'll extract timestamp information from the 'play' column during processing
    filtered_analytics = analytics_df
    
    # We'll track the cutoff date for filtering during processing
    cutoff_date = None
    if period_days is not None:
        today = datetime.now()
        cutoff_date = (today - timedelta(days=period_days)).date()
    
    # Initialize counters for the pie chart
    single_day_plays = 0
    multi_day_plays = 0
    
    # Process each row to analyze the play timestamps
    for _, row in filtered_analytics.iterrows():
        # Skip if play column is empty
        if pd.isna(row['play']):
            continue
        
        try:
            # More robust parsing for the play data
            play_str = row['play']
            
            # Use regex to directly extract timestamps without full JSON parsing
            # This is more robust against JSON parsing errors
            timestamp_match = re.search(r"'timestamps':\s*\[(.*?)\]", play_str)
            
            if not timestamp_match:
                continue
                
            # Extract the timestamps array content
            timestamps_str = timestamp_match.group(1)
            
            # Get all timestamps by splitting the string
            timestamps = re.findall(r"'([^']*?)'", timestamps_str)
            
            if not timestamps:
                continue
                
            # Process the timestamps directly
            unique_days = set()
            earliest_date = None
            
            for timestamp_str in timestamps:
                try:
                    # Extract just the date part (YYYY-MM-DD)
                    date_str = timestamp_str.split('T')[0]
                    date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
                    
                    # Track earliest date for period filtering
                    if earliest_date is None or date_obj < earliest_date:
                        earliest_date = date_obj
                        
                    unique_days.add(date_str)
                except (ValueError, IndexError):
                    # Skip problematic timestamp
                    continue
                    
            # Skip if no valid timestamps found
            if not unique_days:
                continue
                
            # Skip if before cutoff date (period filtering)
            if cutoff_date and earliest_date < cutoff_date:
                continue
                
            # We've already extracted the unique_days and earliest_date above
            # Categorize based on number of unique days
            if len(unique_days) == 1:
                single_day_plays += 1
            else:
                multi_day_plays += 1
                
        except (json.JSONDecodeError, KeyError, IndexError, AttributeError) as e:
            # Skip problematic entries
            print(f"Error processing play data for document {row['id']}: {e}")
            continue
    
    # Create pie chart
    labels = ['Played on a single day', 'Played on multiple days']
    sizes = [single_day_plays, multi_day_plays]
    
    # Skip empty data
    if sum(sizes) == 0:
        print("No valid play data found for analysis")
        return {'single_day_plays': 0, 'multi_day_plays': 0}
    
    # Create the pie chart
    plt.figure(figsize=(10, 8))
    plt.pie(sizes, labels=labels, autopct='%1.1f%%', startangle=90, 
            shadow=False, explode=[0, 0.1], colors=['lightblue', 'lightgreen'])
    period_text = f'Past {period_days} days' if period_days else 'All time'
    plt.title(f'Lesson Replay Patterns ({period_text})')
    plt.axis('equal')
    
    if save:
        plt.savefig('img/lesson_replay_patterns.png')
        replay_data = pd.DataFrame({
            'replay_pattern': labels,
            'count': sizes
        })
        replay_data.to_csv('csv/lesson_replay_patterns.csv', index=False)
    
    return {
        'single_day_plays': single_day_plays,
        'multi_day_plays': multi_day_plays,
        'total_analyzed': single_day_plays + multi_day_plays
    }

def pie_chart_lessons_distribution(lessons_df, users_df, period_days=None, user_creation_days=None, save=True):
    """
    Create a pie chart showing distribution of users by number of lessons created
    
    Args:
        lessons_df: DataFrame with lesson data
        users_df: DataFrame with user data
        period_days: Number of days to include in the analysis for lessons (None for all data)
        user_creation_days: Number of days to include only users created within this period (None for all users)
        save: Whether to save the plot to a file
    """
    # Filter lessons by period if needed
    if period_days is not None:
        today = datetime.now()
        cutoff = today - timedelta(days=period_days)
        filtered_df = lessons_df[lessons_df['timestamp'] >= cutoff]
    else:
        filtered_df = lessons_df
    
    # Filter users by creation date if specified
    if user_creation_days is not None:
        today = datetime.now()
        user_cutoff = today - timedelta(days=user_creation_days)
        
        if 'created_at' in users_df.columns:
            # Convert to datetime if not already
            if not pd.api.types.is_datetime64_any_dtype(users_df['created_at']):
                users_df['created_at'] = pd.to_datetime(users_df['created_at'])
            filtered_users_df = users_df[users_df['created_at'] >= user_cutoff]
        else:
            print("Warning: No creation date column found in users_df. Using all users.")
            filtered_users_df = users_df
    else:
        filtered_users_df = users_df
    
    # Count lessons per user
    user_lesson_counts = filtered_df['user_ID'].value_counts().reset_index()
    user_lesson_counts.columns = ['user_ID', 'lesson_count']

    # save filtered_users_df to a csv
    filtered_users_df_path = 'csv/filtered_users.csv'
    filtered_users_df.to_csv(filtered_users_df_path, index=False)
    print(f"Saved filtered users data to {filtered_users_df_path}")

    
    # Get filtered users and merge with lesson counts
    all_users = filtered_users_df[['id']].copy()
    all_users = pd.merge(all_users, user_lesson_counts, 
                        how='left', left_on='id', right_on='user_ID')
    all_users['lesson_count'] = all_users['lesson_count'].fillna(0)
    
    # Create bins for lesson counts
    bins = {
        '0 lessons': 0,
        '1 lesson': 0,
        '2 lessons': 0,
        '3 lessons': 0,
        '4 lessons': 0,
        '5 lessons': 0,
        '6 lessons': 0,
        '7 lessons': 0,
        '8 lessons': 0,
        '8+ lessons': 0
    }
    
    # Count users in each bin
    for count in all_users['lesson_count']:
        count = int(count)
        if count == 0:
            bins['0 lessons'] += 1
        elif count == 1:
            bins['1 lesson'] += 1
        elif count == 2:
            bins['2 lessons'] += 1
        elif count == 3:
            bins['3 lessons'] += 1
        elif count == 4:
            bins['4 lessons'] += 1
        elif count == 5:
            bins['5 lessons'] += 1
        elif count == 6:
            bins['6 lessons'] += 1
        elif count == 7:
            bins['7 lessons'] += 1
        elif count == 8:
            bins['8 lessons'] += 1
        else:
            bins['8+ lessons'] += 1
    
    # Create pie chart data
    labels = list(bins.keys())
    sizes = list(bins.values())
    
    # Remove empty categories for better visualization
    non_zero_labels = []
    non_zero_sizes = []
    for i, size in enumerate(sizes):
        if size > 0:
            non_zero_labels.append(labels[i])
            non_zero_sizes.append(size)
    
    plt.figure(figsize=(12, 8))
    plt.pie(non_zero_sizes, labels=non_zero_labels, autopct='%1.1f%%', startangle=90,
            shadow=False, explode=[0.05] * len(non_zero_sizes))
    period_text = f'Past {period_days} days' if period_days else 'All time'
    user_period_text = f', users created in past {user_creation_days} days' if user_creation_days else ''
    plt.title(f'Distribution of Users by Number of Lessons Created ({period_text}{user_period_text})')
    plt.axis('equal')
    
    if save:
        plt.savefig('img/user_lesson_distribution.png')
        dist_data = pd.DataFrame({
            'lesson_count': labels,
            'number_of_users': sizes
        })
        dist_data.to_csv('csv/user_lesson_distribution.csv', index=False)
    
    return bins

def analyze_user_engagement_patterns(lessons_df, users_df, period_days=None, save=True):
    """
    Analyze user engagement patterns based on lesson creation frequency
    
    Args:
        lessons_df: DataFrame with lesson data
        users_df: DataFrame with user data
        period_days: Number of days to include in the analysis (None for all data)
        save: Whether to save the plot to a file
    """
    # Filter by period if needed
    if period_days is not None:
        today = datetime.now()
        cutoff = today - timedelta(days=period_days)
        filtered_df = lessons_df[lessons_df['timestamp'] >= cutoff]
    else:
        filtered_df = lessons_df
    
    # Group by user and date to find active days per user
    filtered_df['date'] = filtered_df['timestamp'].dt.date
    
    # Get unique date values per user to account for multiple lessons per day
    user_activity = filtered_df[['user_ID', 'date']].drop_duplicates()
    
    # Count lessons created per day per user
    lessons_per_day = filtered_df.groupby(['user_ID', 'date']).size().reset_index()
    lessons_per_day.columns = ['user_ID', 'date', 'lessons_created']
    
    # Count active days per user
    active_days_per_user = user_activity.groupby('user_ID').size().reset_index()
    active_days_per_user.columns = ['user_ID', 'active_days']
    
    # Calculate average lessons per active day
    lessons_per_user = filtered_df.groupby('user_ID').size().reset_index()
    lessons_per_user.columns = ['user_ID', 'total_lessons']
    
    # Merge data
    engagement_data = pd.merge(active_days_per_user, lessons_per_user, on='user_ID')
    engagement_data['avg_lessons_per_active_day'] = engagement_data['total_lessons'] / engagement_data['active_days']
    
    # Add user information
    engagement_data = pd.merge(engagement_data, users_df[['id', 'name', 'premium', 'language_level', 'target_language']], 
                              left_on='user_ID', right_on='id', how='left')
    
    # Create user engagement segments
    def categorize_user(row):
        if row['active_days'] == 1 and row['total_lessons'] <= 2:
            return 'One-time User'
        elif row['active_days'] <= 3 and row['total_lessons'] <= 5:
            return 'Casual User'
        elif row['active_days'] > 3 and row['active_days'] <= 10:
            return 'Regular User'
        else:
            return 'Power User'
    
    engagement_data['user_segment'] = engagement_data.apply(categorize_user, axis=1)
    
    # Create visualization of user segments with explanatory labels
    segment_counts = engagement_data['user_segment'].value_counts()
    
    # Create a figure with a subplot grid for the chart and labels
    fig = plt.figure(figsize=(14, 8))
    
    # Create grid spec for two columns (chart and labels)
    gs = fig.add_gridspec(1, 2, width_ratios=[3, 1])
    
    # Create subplot for the main chart
    ax1 = fig.add_subplot(gs[0])
    
    # Create the count plot with the segment order
    sns.countplot(x='user_segment', data=engagement_data, 
                  order=['One-time User', 'Casual User', 'Regular User', 'Power User'], 
                  ax=ax1)
    
    ax1.set_title('User Engagement Segments')
    ax1.set_xlabel('User Segment')
    ax1.set_ylabel('Number of Users')
    ax1.tick_params(axis='x', rotation=0)
    
    # Create subplot for the explanatory text
    ax2 = fig.add_subplot(gs[1])
    ax2.axis('off')  # Turn off axis for text panel
    
    # Define segment explanations
    segment_descriptions = {
        'One-time User': 'Users who used the app on a single day\nand created 1-2 lessons only',
        'Casual User': 'Users who used the app on 1-3 days\nand created up to 5 lessons',
        'Regular User': 'Users who used the app on 4-10 days',
        'Power User': 'Users who used the app on more than 10 days'
    }
    
    # Add explanatory text with segment counts
    y_pos = 0.9
    for segment in ['One-time User', 'Casual User', 'Regular User', 'Power User']:
        count = segment_counts.get(segment, 0)
        percentage = 100 * count / segment_counts.sum() if segment_counts.sum() > 0 else 0
        description = segment_descriptions[segment]
        
        # Format text with count and percentage
        text = f"{segment}:\n{description}\n({count} users, {percentage:.1f}%)"
        
        # Add text with appropriate color box
        ax2.text(0.05, y_pos, text, va='top', ha='left', fontsize=10,
                 bbox=dict(facecolor='lightgray', alpha=0.3, pad=10))
        
        y_pos -= 0.22  # Move down for next segment
    
    plt.tight_layout()
    
    if save:
        plt.savefig('img/user_engagement_segments.png')
        engagement_data.to_csv('csv/user_engagement_data.csv', index=False)
    
    # Create scatter plot of active days vs total lessons
    plt.figure(figsize=(12, 8))
    scatter = sns.scatterplot(data=engagement_data, x='active_days', y='total_lessons', 
                             hue='user_segment', size='avg_lessons_per_active_day',
                             sizes=(20, 200), alpha=0.7)
    
    plt.title('User Engagement: Active Days vs Total Lessons')
    plt.xlabel('Number of Active Days')
    plt.ylabel('Total Lessons Created')
    plt.tight_layout()
    
    if save:
        plt.savefig('img/user_engagement_scatter.png')
    
    return engagement_data

def analyze_language_preferences(lessons_df, users_df, period_days=None, save=True):
    """
    Analyze target and native language preferences
    
    Args:
        lessons_df: DataFrame with lesson data
        users_df: DataFrame with user data
        period_days: Number of days to include in the analysis (None for all data)
        save: Whether to save the plot to a file
    """
    # Filter by period if needed
    if period_days is not None:
        today = datetime.now()
        cutoff = today - timedelta(days=period_days)
        filtered_df = lessons_df[lessons_df['timestamp'] >= cutoff]
    else:
        filtered_df = lessons_df
    
    # Analyze target languages in lessons
    target_lang_counts = filtered_df['target_language'].value_counts()
    
    # Analyze native languages in lessons
    native_lang_counts = filtered_df['native_language'].value_counts()
    
    # Create figures
    fig, axes = plt.subplots(1, 2, figsize=(16, 8))
    
    # Target languages plot
    target_lang_counts.plot(kind='bar', ax=axes[0], color='skyblue')
    axes[0].set_title('Lessons by Target Language')
    axes[0].set_xlabel('Target Language')
    axes[0].set_ylabel('Number of Lessons')
    axes[0].tick_params(axis='x', rotation=45)
    
    # Native languages plot
    native_lang_counts.plot(kind='bar', ax=axes[1], color='lightgreen')
    axes[1].set_title('Lessons by Native Language')
    axes[1].set_xlabel('Native Language')
    axes[1].set_ylabel('Number of Lessons')
    axes[1].tick_params(axis='x', rotation=45)
    
    plt.tight_layout()
    
    if save:
        plt.savefig('img/language_preferences.png')
        target_lang_counts.to_frame('count').to_csv('csv/target_languages.csv')
        native_lang_counts.to_frame('count').to_csv('csv/native_languages.csv')
    
    # Analyze language level distribution
    plt.figure(figsize=(12, 6))
    level_counts = filtered_df['language_level'].value_counts()
    level_counts.plot(kind='pie', autopct='%1.1f%%')
    plt.title('Distribution of Language Levels')
    plt.axis('equal')
    
    if save:
        plt.savefig('img/language_levels.png')
        level_counts.to_frame('count').to_csv('csv/language_levels.csv')
    
    # Create a heatmap showing relationship between native and target languages
    lang_cross_tab = pd.crosstab(filtered_df['native_language'], filtered_df['target_language'])
    
    plt.figure(figsize=(14, 10))
    sns.heatmap(lang_cross_tab, annot=True, cmap='YlGnBu', fmt='d')
    plt.title('Relationship Between Native and Target Languages')
    plt.xlabel('Target Language')
    plt.ylabel('Native Language')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    
    if save:
        plt.savefig('img/native_target_heatmap.png')
        lang_cross_tab.to_csv('csv/language_relationships.csv')
    
    return {
        'target_languages': target_lang_counts,
        'native_languages': native_lang_counts,
        'language_levels': level_counts,
        'language_relationships': lang_cross_tab
    }

def analyze_user_retention(lessons_df, users_df, period_days=None, save=True):
    """
    Analyze user retention by cohort
    
    Args:
        lessons_df: DataFrame with lesson data
        users_df: DataFrame with user data
        period_days: Number of days to include in the analysis (None for all data)
        save: Whether to save the plot to a file
    """
    # Filter by period if needed
    if period_days is not None:
        today = datetime.now()
        cutoff = today - timedelta(days=period_days)
        filtered_df = lessons_df[lessons_df['timestamp'] >= cutoff]
    else:
        filtered_df = lessons_df
    
    # Extract first activity date for each user - using weeks instead of months for more granular analysis
    filtered_df['date'] = filtered_df['timestamp'].dt.to_period('W')  # 'W' represents weekly periods
    first_activity = filtered_df.groupby('user_ID')['date'].min().reset_index()
    first_activity.columns = ['user_ID', 'cohort']
    
    # Combine with activity data
    user_activity = filtered_df[['user_ID', 'date']].copy()
    user_cohorts = pd.merge(user_activity, first_activity, on='user_ID')
    
    # Calculate periods (weeks) since first activity
    user_cohorts['period_number'] = (user_cohorts['date'] - user_cohorts['cohort']).apply(lambda x: x.n)
    
    # Count UNIQUE users by cohort and period
    # First get unique user-cohort combinations to count cohort sizes correctly
    unique_user_cohorts = user_cohorts[['user_ID', 'cohort']].drop_duplicates()
    cohort_sizes = unique_user_cohorts.groupby('cohort').size()
    
    # For each cohort and period, count unique users
    # This prevents the same user from being counted multiple times in the same period
    retention_table = user_cohorts.drop_duplicates(['user_ID', 'cohort', 'period_number'])\
                               .groupby(['cohort', 'period_number'])['user_ID'].count().unstack(fill_value=0)
    
    # Calculate retention rates
    retention_rates = retention_table.divide(cohort_sizes, axis=0) * 100

    # This keeps track of each user's active periods
    user_retention_details = user_cohorts.drop_duplicates(['user_ID', 'period_number'])
    user_retention_details = user_retention_details[['user_ID', 'cohort', 'period_number']]
    
    # Add user information
    user_details = pd.merge(user_retention_details, 
                           users_df[['id', 'name', 'premium', 'language_level', 'target_language']], 
                           left_on='user_ID', right_on='id', how='left')
    
    # Plot the retention heatmap
    plt.figure(figsize=(15, 8))
    sns.heatmap(retention_rates, annot=True, fmt='.0f', cmap='YlGnBu')
    plt.title('User Retention by Cohort (%)')
    plt.xlabel('Weeks Since First Activity')
    plt.ylabel('Cohort (Week of First Activity)')
    plt.tight_layout()
    
    if save:
        plt.savefig('img/retention_heatmap.png')
        retention_rates.to_csv('csv/retention_rates.csv')
        
        # Save the detailed user retention data - all user-period combinations
        user_details.to_csv('csv/user_retention_details.csv', index=False)
        
        # Create a detailed CSV with cohort activity counts and IDs for verification
        # This will help identify the specific users in each cohort+period combination
        cohort_detail_rows = []
        
        # Process each cohort individually
        for cohort in retention_table.index:
            cohort_str = str(cohort)
            
            # For each period in the cohort
            for period in retention_table.columns:
                # Find users from this cohort active in this period
                users_in_period = user_cohorts[
                    (user_cohorts['cohort'] == cohort) & 
                    (user_cohorts['period_number'] == period)
                ]['user_ID'].unique()
                
                # Get the actual count of unique users
                user_count = len(users_in_period)
                
                # If there are users in this period, add them to our detail rows
                if user_count > 0:                    
                    # Add to our detail rows
                    cohort_detail_rows.append({
                        'cohort': cohort_str,
                        'period': period,
                        'user_count': user_count,
                        'user_ids': ','.join(users_in_period)
                    })
        
        # Create and save the verification dataframe
        cohort_verification_df = pd.DataFrame(cohort_detail_rows)
        cohort_verification_df.to_csv('csv/cohort_verification.csv', index=False)
        print(f"Saved cohort verification data to csv/cohort_verification.csv")
    
    # Plot the absolute numbers
    plt.figure(figsize=(15, 8))
    sns.heatmap(retention_table, annot=True, fmt='g', cmap='YlGnBu')
    plt.title('User Activity by Cohort (Absolute Numbers)')
    plt.xlabel('Weeks Since First Activity')
    plt.ylabel('Cohort (Week of First Activity)')
    plt.tight_layout()
    
    if save:
        plt.savefig('img/cohort_activity.png')
        retention_table.to_csv('csv/cohort_activity.csv')
    
    return {
        'retention_rates': retention_rates, 
        'retention_table': retention_table,
        'user_retention_details': user_details
    }


def generate_all_charts(period_days=None):
    """
    Generate all charts with the specified time period
    
    Args:
        period_days: Number of days to include in the analysis (None for all data)
    """
    lessons_df, users_df, analytics_df = load_data()
    
    print("Generating lessons created over time chart...")
    lessons_created_over_time(lessons_df, period_days)
    
    print("Generating top users by lesson count chart...")
    top_users_lessons_count(lessons_df, users_df, period_days=period_days)
    
    print("Generating lesson replay pattern pie chart...")
    pie_chart_replay_status(analytics_df, period_days)
    
    print("Generating user lesson distribution pie chart...")
    pie_chart_lessons_distribution(lessons_df, users_df, period_days, user_creation_days=period_days)
    
    print("Analyzing user engagement patterns...")
    analyze_user_engagement_patterns(lessons_df, users_df, period_days)
    
    print("Analyzing language preferences...")
    analyze_language_preferences(lessons_df, users_df, period_days)
    
    print("Analyzing user retention...")
    analyze_user_retention(lessons_df, users_df, period_days)
    
    print("All charts generated successfully!")

if __name__ == "__main__":
    # Generate charts for all time
    print("Generating charts for all time...")
    generate_all_charts()
    
    # Generate charts for last 30 days
    print("\nGenerating charts for last 30 days...")
    generate_all_charts(period_days=30)