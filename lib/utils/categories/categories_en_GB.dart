const categories = [
  {
    "name": "At the Coffee Shop",
    "words": ["coffee", "tea", "milk", "sugar", "cup", "order", "menu", "table", "barista", "receipt", "change", "takeaway", "iced", "hot", "spoon", "napkin", "cream", "espresso", "latte", "tip"]
  },
  {
    "name": "Weather Talk",
    "words": ["sunny", "rainy", "cloudy", "windy", "stormy", "snowy", "hot", "cold", "warm", "cool", "forecast", "umbrella", "coat", "temperature", "degrees", "season", "humid", "dry"]
  },
  {
    "name": "In the Supermarket",
    "words": ["trolley", "basket", "aisle", "checkout", "cashier", "receipt", "bag", "fruit", "vegetables", "bread", "dairy", "meat", "frozen", "tinned", "shelf", "price", "sale", "barcode", "cash", "card"]
  },
  {
    "name": "Asking for Directions",
    "words": ["map", "street", "road", "avenue", "left", "right", "straight", "corner", "block", "traffic lights", "junction", "turn", "near", "far", "behind", "in front", "beside", "between", "opposite", "sign"]
  },
  {
    "name": "Making Small Talk",
    "words": ["hello", "hi", "how are you", "fine", "thank you", "you", "weather", "good", "bad", "busy", "tired", "weekend", "plans", "enjoy", "today", "tomorrow", "yesterday", "nice", "meet", "again"]
  },
  {
    "name": "At the Airport",
    "words": [
      "boarding pass",
      "passport",
      "luggage",
      "check-in",
      "security",
      "gate",
      "flight",
      "delay",
      "departure",
      "arrival",
      "terminal",
      "baggage claim",
      "customs",
      "ticket",
      "seat",
      "boarding",
      "hand luggage",
      "pushchair",
      "visa",
      "duty-free"
    ]
  },
  {
    "name": "At the Restaurant",
    "words": ["menu", "waiter", "reservation", "order", "starter", "main course", "dessert", "bill", "tip", "drink", "water", "wine", "beer", "fork", "knife", "spoon", "plate", "glass", "napkin", "special"]
  },
  {
    "name": "At the Hotel",
    "words": [
      "reception",
      "check-in",
      "check-out",
      "room",
      "key",
      "booking",
      "luggage",
      "lift",
      "breakfast",
      "wi-fi",
      "shower",
      "towel",
      "bed",
      "pillow",
      "blanket",
      "air conditioning",
      "laundry",
      "service",
      "safe",
      "view"
    ]
  },
  {
    "name": "At the Doctor's Office",
    "words": [
      "appointment",
      "doctor",
      "nurse",
      "symptoms",
      "pain",
      "fever",
      "cough",
      "headache",
      "prescription",
      "medicine",
      "pharmacy",
      "allergy",
      "blood pressure",
      "temperature",
      "stethoscope",
      "bandage",
      "injection",
      "x-ray",
      "diagnosis",
      "treatment"
    ]
  },
  {
    "name": "Public Transportation",
    "words": ["bus", "train", "tube", "ticket", "station", "stop", "timetable", "map", "route", "platform", "fare", "change", "passenger", "driver", "conductor", "delay", "exit", "entrance", "seat", "standing"]
  },
  {
    "name": "Shopping for Clothes",
    "words": ["shirt", "trousers", "dress", "shoes", "size", "colour", "price", "sale", "fitting room", "cashier", "receipt", "bag", "jacket", "jumper", "skirt", "hat", "socks", "jeans", "belt", "discount"]
  },
  {
    "name": "At the Gym",
    "words": [
      "treadmill",
      "weights",
      "yoga",
      "stretching",
      "trainer",
      "membership",
      "locker",
      "shower",
      "towel",
      "water bottle",
      "workout",
      "cardio",
      "strength",
      "reps",
      "sets",
      "warm-up",
      "cool-down",
      "dumbbells",
      "barbell",
      "machine"
    ]
  },
  {
    "name": "At the Bank",
    "words": [
      "account",
      "withdrawal",
      "deposit",
      "loan",
      "interest",
      "credit card",
      "debit card",
      "atm",
      "bank teller",
      "balance",
      "currency",
      "exchange",
      "cheque",
      "savings",
      "investment",
      "password",
      "pin",
      "statement",
      "fee",
      "transfer"
    ]
  },
  {
    "name": "At the Post Office",
    "words": [
      "parcel",
      "letter",
      "stamp",
      "envelope",
      "address",
      "postcard",
      "package",
      "delivery",
      "tracking",
      "postbox",
      "sender",
      "recipient",
      "weight",
      "size",
      "priority",
      "express",
      "airmail",
      "customs",
      "fee",
      "receipt"
    ]
  },
  {
    "name": "At the Pharmacy",
    "words": [
      "medicine",
      "prescription",
      "painkiller",
      "bandage",
      "vitamins",
      "cough syrup",
      "allergy",
      "cream",
      "ointment",
      "pill",
      "tablet",
      "capsule",
      "pharmacist",
      "dosage",
      "side effects",
      "refill",
      "antibiotic",
      "thermometer",
      "mask",
      "sanitiser"
    ]
  },
  {
    "name": "At the Park",
    "words": ["bench", "tree", "grass", "path", "playground", "fountain", "dog", "picnic", "bike", "jogging", "flowers", "pond", "duck", "shade", "sun", "children", "swing", "slide", "bin", "statue"]
  },
  {
    "name": "At the Beach",
    "words": ["sand", "waves", "sun", "parasol", "towel", "swimsuit", "sunscreen", "sunglasses", "hat", "shells", "seagull", "sea", "tide", "surfing", "board", "snorkelling", "mask", "fins", "beach ball", "ice cream"]
  },
  {
    "name": "At the Library",
    "words": [
      "book",
      "shelf",
      "catalogue",
      "borrow",
      "return",
      "due date",
      "librarian",
      "study",
      "quiet",
      "desk",
      "chair",
      "computer",
      "internet",
      "magazine",
      "newspaper",
      "fiction",
      "non-fiction",
      "reference",
      "loan",
      "card"
    ]
  },
  {
    "name": "At the Cinema",
    "words": ["ticket", "film", "popcorn", "drink", "seat", "screen", "trailer", "genre", "horror", "comedy", "action", "drama", "romance", "director", "actor", "actress", "subtitles", "3d", "showtime", "concessions"]
  },
  {
    "name": "At the Hair Salon",
    "words": [
      "haircut",
      "shampoo",
      "conditioner",
      "stylist",
      "scissors",
      "comb",
      "blow-dry",
      "colour",
      "highlights",
      "trim",
      "fringe",
      "curls",
      "straighten",
      "appointment",
      "mirror",
      "chair",
      "cape",
      "razor",
      "gel",
      "spray"
    ]
  }
];
