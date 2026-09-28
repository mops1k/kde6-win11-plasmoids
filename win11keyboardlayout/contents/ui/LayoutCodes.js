/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

.pragma library

// X11 layout code -> three letter code used by Windows.
// Cyrillic languages keep a Cyrillic code, like the Russian Windows locale does (РУС, УКР).
const CODES = {
    "us": "ENG", "gb": "ENG", "en": "ENG",
    "ru": "РУС", "ua": "УКР", "by": "БЕЛ", "be": "БЕЛ",
    "de": "DEU", "fr": "FRA", "es": "SPA", "latam": "SPA",
    "it": "ITA", "pt": "POR", "br": "POR", "nl": "NLD",
    "sv": "SWE", "no": "NOR", "nb": "NOR", "nn": "NOR", "da": "DNK",
    "fi": "FIN", "is": "ISL", "pl": "POL", "cs": "CZE", "cz": "CZE",
    "sk": "SLK", "hu": "HUN", "ro": "RON", "bg": "BUL", "sr": "SRP",
    "hr": "HRV", "sl": "SLV", "bs": "BOS", "mk": "MKD", "sq": "SQI",
    "el": "ELL", "gr": "ELL", "tr": "TUR", "az": "AZE", "kk": "KAZ",
    "ky": "KIR", "uz": "UZB", "tg": "TGK", "tk": "TUK", "hy": "HYE",
    "ka": "KAT", "he": "HEB", "il": "HEB", "ar": "ARA", "fa": "FAS",
    "ur": "URD", "hi": "HIN", "bn": "BEN", "ta": "TAM", "te": "TEL",
    "ml": "MAL", "kn": "KAN", "mr": "MAR", "gu": "GUJ", "pa": "PAN",
    "ne": "NEP", "si": "SIN", "th": "THA", "lo": "LAO", "km": "KHM",
    "my": "MYA", "vi": "VIE", "id": "IND", "ms": "MSA", "tl": "TGL",
    "zh": "ZHO", "ja": "JPN", "ko": "KOR", "mn": "MON", "bo": "TIB",
    "et": "EST", "lv": "LAV", "lt": "LIT", "mt": "MLT", "ga": "GLE",
    "cy": "CYM", "gd": "GLA", "eu": "EUS", "ca": "CAT", "gl": "GLG",
    "af": "AFR", "sw": "SWA", "am": "AMH", "yo": "YOR", "ig": "IBO",
    "ha": "HAU", "zu": "ZUL", "so": "SOM", "mg": "MLG", "tt": "TAT",
    "ba": "BAK", "cv": "CHV", "sah": "SAH", "os": "OSS", "ce": "CHE",
    "udm": "UDM", "kv": "KOM", "eo": "EPO", "la": "LAT"
};

function codeFor(shortName, uppercase) {
    if (!shortName) {
        return "";
    }
    const key = String(shortName).toLowerCase().split(/[-_(]/)[0];
    const code = CODES[key] || key.slice(0, 3).toUpperCase();
    return uppercase ? code.toUpperCase() : code.toLowerCase();
}
