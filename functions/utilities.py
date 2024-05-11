import os

def is_running_locally():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(current_dir, '_local_tester_chatGPT.py')
    return os.path.isfile(file_path)