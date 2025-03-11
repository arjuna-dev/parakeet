from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore
import firebase_functions.options as options
import json
import time

options.set_global_options(region="europe-west1")
app = initialize_app()

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def plottwist_story(req: https_fn.Request) -> https_fn.Response:
    try:
        request_data = req.get_json()
        post_id = request_data.get("post_id")
        data = request_data.get("data")
        
        if not post_id or not data:
            return https_fn.Response(
                json.dumps({"error": "Missing required fields: post_id or data"}),
                status=400,
            )

        db = firestore.client()
        doc_ref = db.collection('plotTwistStories').document(f'story_{post_id}')
        doc_ref.set(data, merge=True)

        return https_fn.Response(
            json.dumps({
                "message": "Document written successfully",
                "document_id": f'story_{post_id}'
            }),
            status=200,
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET"]
    )
)
def get_openai_key(req: https_fn.Request) -> https_fn.Response:
    try:

        # Validate the API key
        api_key = req.headers.get("Authorization")
        expected_api_key = "amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-"
        if api_key != f"Bearer {expected_api_key}":
            return https_fn.Response(
                json.dumps({"error": "Unauthorized"}),
                status=401
            )

        db = firestore.client()
        doc_ref = db.collection('plotTwistStories').document('other_data')
        doc = doc_ref.get()

        if not doc.exists:
            return https_fn.Response(
                json.dumps({"error": "OpenAI key document not found"}),
                status=404
            )

        key = doc.get('openai_key')
        if not key:
            return https_fn.Response(
                json.dumps({"error": "OpenAI key not found in document"}),
                status=404
            )

        return https_fn.Response(
            json.dumps({"key": key}),
            status=200
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def check_rate_limit(req: https_fn.Request) -> https_fn.Response:

    rate_limits = {
        "minutely": 1,
        "hourly": 30,
        "daily": 60,
        "monthly": 250
    }
    try:
        request_data = req.get_json()
        username = request_data.get('username')
        
        if not username:
            return https_fn.Response(
                json.dumps({"error": "Username is required"}),
                status=400
            )

        db = firestore.client()
        user_ref = db.collection('plotTwistUsers').document(username)
        user_doc = user_ref.get()

        now = time.time()
        one_minute_ago = now - 60
        one_hour_ago = now - 3600
        one_day_ago = now - 86400
        one_month_ago = now - 2592000

        if user_doc.exists:
            data = user_doc.to_dict()
            
            # Check if user is a paid user with valid subscription
            payment_date = data.get('paymentDate')
            print(f"Payment date: {payment_date}")
            print(f"One month ago: {one_month_ago}")
            print(f"Payment date > one month ago: {payment_date > one_month_ago}")
            if payment_date and payment_date > one_month_ago:
                generations = data.get('payedGenerations', 0)
                if generations < 1000:
                    # Increment generations count
                    user_ref.update({'payedGenerations': generations + 1})
                    return https_fn.Response(
                        json.dumps({"allowed": True}),
                        status=200
                    )
            
            # Regular rate limit logic
            timestamps = data.get('timestamps', [])
            timestamps = [ts for ts in timestamps if ts > one_month_ago]
            
            # Count API calls in different time windows
            last_minute = sum(1 for ts in timestamps if ts > one_minute_ago)
            last_hour = sum(1 for ts in timestamps if ts > one_hour_ago)
            last_day = sum(1 for ts in timestamps if ts > one_day_ago)
            last_month = len(timestamps)

            # Check rate limits
            if last_minute >= rate_limits["minutely"]:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "That was fast! Please wait at least one minute before your next story part!",
                        "timespan": "minutely",
                        "limit": rate_limits["minutely"]
                    }),
                    status=200
                )
            if last_hour >= rate_limits["hourly"]:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Rate limit exceeded",
                        "timespan": "hourly",
                        "limit": rate_limits["hourly"]
                    }),
                    status=200
                )
            if last_day >= rate_limits["daily"]:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Rate limit exceeded",
                        "timespan": "daily",
                        "limit": rate_limits["daily"]
                    }),
                    status=200
                )
            if last_month >= rate_limits["monthly"]:
                return https_fn.Response(
                    json.dumps({
                        "allowed": False,
                        "error": "Rate limit exceeded",
                        "timespan": "monthly",
                        "limit": rate_limits["monthly"]
                    }),
                    status=200
                )

            # Update timestamps array (remove old ones)
            user_ref.update({'timestamps': timestamps})

        return https_fn.Response(
            json.dumps({"allowed": True}),
            status=200
        )

    except Exception as e:
        print(f"Error in check_rate_limit: {str(e)}")
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def record_api_call(req: https_fn.Request) -> https_fn.Response:
    try:
        # Get username from request body
        request_data = req.get_json()
        username = request_data.get('username')
        
        if not username:
            return https_fn.Response(
                json.dumps({"error": "Username is required"}),
                status=400
            )

        db = firestore.client()
        user_ref = db.collection('plotTwistUsers').document(username)
        user_doc = user_ref.get()

        now = time.time()
        one_month_ago = now - 2592000  # 30 days in seconds

        if user_doc.exists:
            data = user_doc.to_dict()
            timestamps = data.get('timestamps', [])
            # Remove timestamps older than 31 days
            timestamps = [ts for ts in timestamps if ts > one_month_ago]
            # Add new timestamp
            timestamps.append(now)
            user_ref.update({'timestamps': timestamps})
        else:
            # Create new user document
            user_ref.set({'timestamps': [now]})

        return https_fn.Response(
            json.dumps({"success": True}),
            status=200
        )

    except Exception as e:
        print(f"Error in record_api_call: {str(e)}")
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def handle_kofi_donation(req: https_fn.Request) -> https_fn.Response:
    try:
        # Handle different content types
        content_type = req.headers.get('content-type', '')
        
        if 'application/json' in content_type:
            data = req.get_json()
        elif 'application/x-www-form-urlencoded' in content_type:
            # Parse form data
            form_data = req.form.to_dict()
            # Ko-fi sends the data in a 'data' field as a JSON string
            data = json.loads(form_data.get('data', '{}'))
        else:
            return https_fn.Response(
                json.dumps({
                    "error": f"Unsupported Content-Type: {content_type}. Expected application/json or application/x-www-form-urlencoded"
                }),
                status=415
            )

        # Rest of the function remains the same
        verification_token = data.get('verification_token')
        import os
        KOFI_TOKEN = os.environ.get("KOFI_TOKEN")
        expected_token = KOFI_TOKEN
        
        if verification_token != expected_token:
            return https_fn.Response(
                json.dumps({"error": "Invalid verification token"}),
                status=401
            )

        # Extract relevant information
        amount = float(data.get('amount', '0'))
        username = data.get('message', '').strip()  # Reddit username in message field
        print(f"Received donation of ${amount} from {username}")
        
        if not username:
            return https_fn.Response(
                json.dumps({"error": "No username provided in message field"}),
                status=400
            )

        if amount >= 3.00:
            db = firestore.client()
            user_ref = db.collection('plotTwistUsers').document(username)
            
            # Set payment date and reset generations counter
            now = time.time()
            user_ref.set({
                'paymentDate': now,
                'payedGenerations': 0,
                'timestamps': []
            }, merge=True)
            
            return https_fn.Response(
                json.dumps({
                    "success": True,
                    "message": f"Premium access granted to user {username}"
                }),
                status=200
            )
        
        return https_fn.Response(
            json.dumps({
                "success": True,
                "message": "Donation received but amount is less than $5.00"
            }),
            status=200
        )

    except Exception as e:
        print(f"Error processing Ko-fi donation: {str(e)}")
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET"]
    )
)
def dynamic_message(req: https_fn.Request) -> https_fn.Response:
    try:
        api_key = req.headers.get("Authorization")
        expected_api_key = "amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-amvhihffd&*(90-)asdjjla+_)8hflaksjn|_-_-_-"
        
        if api_key != f"Bearer {expected_api_key}":
            return https_fn.Response(
                json.dumps({"error": "Unauthorized"}),
                status=401
            )

        db = firestore.client()
        doc_ref = db.collection('plotTwistStories').document('other_data')
        doc = doc_ref.get()

        if not doc.exists:
            return https_fn.Response(
                json.dumps({"error": "Message document not found"}),
                status=404
            )

        message = doc.get('dynamic_message')
        if not message:
            message = ""

        return https_fn.Response(
            json.dumps({"message": message}),
            status=200
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500
        )

