const categories = [
  {
    "name": "At the Coffee Shop",
    "words": ["kahve", "çay", "süt", "şeker", "fincan", "sipariş", "menü", "masa", "barista", "fatura", "para üstü", "paket servis", "buzlu", "sıcak", "kaşık", "peçete", "krema", "espresso", "latte", "bahşiş"]
  },
  {
    "name": "Weather Talk",
    "words": ["güneşli", "yağmurlu", "bulutlu", "rüzgarlı", "fırtınalı", "karlı", "sıcak", "soğuk", "ılık", "serin", "hava durumu", "şemsiye", "mont", "sıcaklık", "derece", "mevsim", "nemli", "kuru"]
  },
  {
    "name": "In the Supermarket",
    "words": ["araba", "sepet", "koridor", "kasa", "kasiyer", "fatura", "poşet", "meyve", "sebze", "ekmek", "süt ürünleri", "et", "dondurulmuş", "konserve", "raf", "fiyat", "indirim", "barkod", "nakit", "kart"]
  },
  {
    "name": "Asking for Directions",
    "words": ["harita", "cadde", "yol", "bulvar", "sol", "sağ", "düz", "köşe", "blok", "trafik ışığı", "kavşak", "dönmek", "yakın", "uzak", "arka", "ön", "yanında", "arasında", "karşısında", "işaret"]
  },
  {
    "name": "Essential Conversations",
    "words": [
      "merhaba",
      "selam",
      "nasılsın",
      "iyiyim",
      "teşekkür ederim",
      "sen",
      "hava",
      "iyi",
      "kötü",
      "meşgul",
      "yorgun",
      "hafta sonu",
      "planlar",
      "keyfini çıkar",
      "bugün",
      "yarın",
      "dün",
      "güzel",
      "tanışmak",
      "tekrar"
    ]
  },
  {
    "name": "At the Airport",
    "words": [
      "biniş kartı",
      "pasaport",
      "bagaj",
      "check-in",
      "güvenlik",
      "kapı",
      "uçuş",
      "gecikme",
      "kalkış",
      "varış",
      "terminal",
      "bagaj alım",
      "gümrük",
      "bilet",
      "koltuk",
      "biniş",
      "el bagajı",
      "bebek arabası",
      "vize",
      "gümrüksüz"
    ]
  },
  {
    "name": "At the Restaurant",
    "words": ["menü", "garson", "rezervasyon", "sipariş", "başlangıç", "ana yemek", "tatlı", "hesap", "bahşiş", "içecek", "su", "şarap", "bira", "çatal", "bıçak", "kaşık", "tabak", "bardak", "peçete", "özel"]
  },
  {
    "name": "At the Hotel",
    "words": ["resepsiyon", "giriş", "çıkış", "oda", "anahtar", "rezervasyon", "bagaj", "asansör", "kahvaltı", "wi-fi", "duş", "havlu", "yatak", "yastık", "battaniye", "klima", "çamaşırhane", "servis", "kasa", "manzara"]
  },
  {
    "name": "At the Doctor's Office",
    "words": [
      "randevu",
      "doktor",
      "hemşire",
      "belirtiler",
      "ağrı",
      "ateş",
      "öksürük",
      "baş ağrısı",
      "reçete",
      "ilaç",
      "eczane",
      "alerji",
      "tansiyon",
      "sıcaklık",
      "steteskop",
      "bandaj",
      "iğne",
      "röntgen",
      "teşhis",
      "tedavi"
    ]
  },
  {
    "name": "Public Transportation",
    "words": ["otobüs", "tren", "metro", "bilet", "istasyon", "durak", "tarife", "harita", "hat", "peron", "ücret", "aktarma", "yolcu", "şoför", "kondüktör", "gecikme", "çıkış", "giriş", "koltuk", "ayakta"]
  },
  {
    "name": "Shopping for Clothes",
    "words": ["gömlek", "pantolon", "elbise", "ayakkabı", "beden", "renk", "fiyat", "indirim", "deneme kabini", "kasiyer", "fatura", "poşet", "ceket", "kazak", "etek", "şapka", "çorap", "kot", "kemer", "indirim"]
  },
  {
    "name": "At the Gym",
    "words": ["koşu bandı", "ağırlıklar", "yoga", "esneme", "eğitmen", "üyelik", "dolap", "duş", "havlu", "su şişesi", "egzersiz", "kardiyo", "güç", "tekrar", "set", "ısınma", "soğuma", "dambıl", "barbel", "makine"]
  },
  {
    "name": "At the Bank",
    "words": [
      "hesap",
      "para çekme",
      "para yatırma",
      "kredi",
      "faiz",
      "kredi kartı",
      "banka kartı",
      "atm",
      "banka memuru",
      "bakiye",
      "döviz",
      "döviz bozdurma",
      "çek",
      "tasarruf",
      "yatırım",
      "şifre",
      "pin",
      "ekstre",
      "ücret",
      "transfer"
    ]
  },
  {
    "name": "At the Post Office",
    "words": [
      "paket",
      "mektup",
      "pul",
      "zarf",
      "adres",
      "kartpostal",
      "koli",
      "teslimat",
      "takip",
      "posta kutusu",
      "gönderen",
      "alıcı",
      "ağırlık",
      "boyut",
      "öncelik",
      "ekspres",
      "uçak postası",
      "gümrük",
      "ücret",
      "fatura"
    ]
  },
  {
    "name": "At the Pharmacy",
    "words": [
      "ilaç",
      "reçete",
      "ağrı kesici",
      "bandaj",
      "vitaminler",
      "öksürük şurubu",
      "alerji",
      "krem",
      "merhem",
      "hap",
      "tablet",
      "kapsül",
      "eczacı",
      "doz",
      "yan etkiler",
      "yenileme",
      "antibiyotik",
      "termometre",
      "maske",
      "dezenfektan"
    ]
  },
  {
    "name": "At the Park",
    "words": ["bank", "ağaç", "çim", "yol", "oyun alanı", "fıskiye", "köpek", "piknik", "bisiklet", "koşu", "çiçekler", "gölet", "ördek", "gölge", "güneş", "çocuklar", "salıncak", "kaydırak", "çöp kutusu", "heykel"]
  },
  {
    "name": "At the Beach",
    "words": [
      "kum",
      "dalgalar",
      "güneş",
      "şemsiye",
      "havlu",
      "mayo",
      "güneş kremi",
      "güneş gözlüğü",
      "şapka",
      "deniz kabukları",
      "martı",
      "deniz",
      "gelgit",
      "sörf",
      "tahta",
      "şnorkel",
      "maske",
      "palet",
      "plaj topu",
      "dondurma"
    ]
  },
  {
    "name": "At the Library",
    "words": [
      "kitap",
      "raf",
      "katalog",
      "ödünç almak",
      "geri vermek",
      "son teslim tarihi",
      "kütüphaneci",
      "ders çalışmak",
      "sessiz",
      "masa",
      "sandalye",
      "bilgisayar",
      "internet",
      "dergi",
      "gazete",
      "kurgu",
      "kurgu dışı",
      "referans",
      "ödünç",
      "kart"
    ]
  },
  {
    "name": "At the Cinema",
    "words": [
      "bilet",
      "film",
      "patlamış mısır",
      "içecek",
      "koltuk",
      "perde",
      "fragman",
      "tür",
      "korku",
      "komedi",
      "aksiyon",
      "drama",
      "romantik",
      "yönetmen",
      "oyuncu",
      "aktris",
      "altyazı",
      "3d",
      "gösterim zamanı",
      "büfe"
    ]
  },
  {
    "name": "At the Hair Salon",
    "words": ["saç kesimi", "şampuan", "saç kremi", "kuaför", "makas", "tarak", "fön", "boya", "röfle", "kırpma", "kahkül", "bukleler", "düzleştirme", "randevu", "ayna", "koltuk", "pelerin", "ustura", "jel", "sprey"]
  }
];
