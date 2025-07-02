const categories = [
  {
    "name": "At the Coffee Shop",
    "words": ["coffee", "tea", "milk", "sugar", "cup", "order", "menu", "table", "barista", "receipt", "change", "to-go", "iced", "hot", "spoon", "napkin", "cream", "espresso", "latte", "tip"]
  },
  {
    "name": "Weather Talk",
    "words": ["sunny", "rainy", "cloudy", "windy", "stormy", "snow", "hot", "cold", "warm", "cool", "forecast", "umbrella", "coat", "temperature", "degrees", "season", "humid", "dry"]
  },
  {
    "name": "In the Supermarket",
    "words": ["cart", "basket", "aisle", "checkout", "cashier", "receipt", "bag", "fruit", "vegetables", "bread", "dairy", "meat", "frozen", "canned", "shelf", "price", "sale", "barcode", "cash", "card"]
  },
  {
    "name": "Asking for Directions",
    "words": ["map", "street", "road", "avenue", "left", "right", "straight", "corner", "block", "traffic light", "intersection", "turn", "near", "far", "behind", "in front of", "next to", "between", "opposite", "sign"]
  },
  {
    "name": "Essential Conversations",
    "words": ["hello", "hi", "how", "fine", "thank", "you", "weather", "good", "bad", "busy", "tired", "weekend", "plans", "enjoy", "today", "tomorrow", "yesterday", "nice", "meet", "again"]
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
      "carry-on",
      "stroller",
      "visa",
      "duty-free"
    ]
  },
  {
    "name": "At the Restaurant",
    "words": ["menu", "waiter", "reservation", "order", "appetizer", "main course", "dessert", "bill", "tip", "drink", "water", "wine", "beer", "fork", "knife", "spoon", "plate", "glass", "napkin", "special"]
  },
  {
    "name": "At the Hotel",
    "words": [
      "reception",
      "check-in",
      "check-out",
      "room",
      "key",
      "reservation",
      "luggage",
      "elevator",
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
    "words": ["bus", "train", "subway", "ticket", "station", "stop", "schedule", "map", "route", "platform", "fare", "transfer", "passenger", "driver", "conductor", "delay", "exit", "entrance", "seat", "standing"]
  },
  {
    "name": "Shopping for Clothes",
    "words": ["shirt", "pants", "dress", "shoes", "size", "color", "price", "sale", "fitting room", "cashier", "receipt", "bag", "jacket", "sweater", "skirt", "hat", "socks", "jeans", "belt", "discount"]
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
      "exercise",
      "cardio",
      "strength",
      "reps",
      "sets",
      "warm-up",
      "cool-down",
      "dumbbell",
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
      "ATM",
      "teller",
      "balance",
      "currency",
      "exchange",
      "check",
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
      "package",
      "letter",
      "stamp",
      "envelope",
      "address",
      "postcard",
      "parcel",
      "delivery",
      "tracking",
      "mailbox",
      "sender",
      "receiver",
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
      "sanitizer"
    ]
  },
  {
    "name": "At the Park",
    "words": ["bench", "tree", "grass", "path", "playground", "fountain", "dog", "picnic", "bicycle", "jogging", "flowers", "pond", "duck", "shade", "sun", "children", "swing", "slide", "trash can", "statue"]
  },
  {
    "name": "At the Beach",
    "words": ["sand", "waves", "sun", "umbrella", "towel", "swimsuit", "sunscreen", "sunglasses", "hat", "shells", "seagull", "ocean", "tide", "surf", "board", "snorkel", "mask", "fins", "beach ball", "ice cream"]
  },
  {
    "name": "At the Library",
    "words": [
      "book",
      "shelf",
      "catalog",
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
    "words": ["ticket", "movie", "popcorn", "drink", "seat", "screen", "trailer", "genre", "horror", "comedy", "action", "drama", "romance", "director", "actor", "actress", "subtitles", "3D", "showtime", "concession"]
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
      "color",
      "highlights",
      "trim",
      "bangs",
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
