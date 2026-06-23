import Foundation

// MARK: - Regex Rule Struct
struct RegexRule {
    let regex: NSRegularExpression
    let template: String
    
    init(pattern: String, options: NSRegularExpression.Options = [], template: String) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
        self.template = template
    }
}

// MARK: - Vietnamese Word Checker
final class VietnameseWordChecker {
    private static let vnAccentRegex = try! NSRegularExpression(
        pattern: "[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]",
        options: .caseInsensitive
    )
    
    private static let vnUnsignedWords: Set<String> = [
        "a", "ai", "am", "an", "ang", "anh", "ao", "au", "ba", "bai",
        "ban", "bang", "banh", "bao", "bay", "be", "bem", "ben", "beng", "beo",
        "bi", "bia", "bin", "binh", "bo", "boa", "bom", "bon", "bong", "boong",
        "bu", "bua", "bung", "ca", "cai", "cam", "can", "cang", "canh", "cao",
        "cau", "cay", "cha", "chai", "chan", "chang", "chanh", "chao", "chau", "chay",
        "che", "chen", "cheng", "cheo", "chi", "chia", "chim", "chinh", "chiu", "cho",
        "choa", "choai", "choang", "choe", "choen", "choi", "chon", "chong", "chu", "chua",
        "chui", "chum", "chun", "chung", "co", "coi", "com", "con", "cong", "cu",
        "cua", "cun", "cung", "da", "dai", "dam", "dan", "dang", "danh", "dao",
        "day", "de", "den", "deo", "di", "dim", "din", "dinh", "do", "doa",
        "doanh", "doi", "dom", "don", "dong", "du", "dua", "dun", "dung", "duy",
        "e", "em", "en", "eng", "eo", "ga", "gai", "gam", "gan", "gang",
        "ganh", "gao", "gau", "gay", "ghe", "ghen", "ghi", "ghim", "gi", "gia",
        "giai", "giam", "gian", "giang", "gianh", "giao", "gie", "gien", "gieo", "gin",
        "gio", "gioi", "gion", "giong", "giun", "go", "gom", "gon", "gu", "ha",
        "hai", "ham", "han", "hang", "hanh", "hao", "hau", "hay", "he", "hem",
        "hen", "heo", "hi", "hia", "him", "hin", "hiu", "ho", "hoa", "hoai",
        "hoan", "hoang", "hoay", "hoe", "hoen", "hoi", "hom", "hon", "hong", "hu",
        "hua", "hui", "hum", "hun", "hung", "huy", "huynh", "hy", "i", "im",
        "in", "inh", "iu", "ke", "kem", "ken", "keng", "keo", "kha", "khai",
        "kham", "khan", "khang", "khanh", "khao", "khau", "khay", "khe", "khem", "khen",
        "kheo", "khi", "khin", "khinh", "khiu", "kho", "khoa", "khoai", "khoan", "khoang",
        "khoanh", "khoe", "khoen", "khoeo", "khoi", "khom", "khu", "khua", "khui", "khum",
        "khung", "khuy", "khuya", "khuynh", "ki", "kia", "kim", "kinh", "la", "lai",
        "lam", "lan", "lang", "lanh", "lao", "lau", "lay", "le", "lem", "len",
        "leng", "leo", "li", "lia", "lim", "lin", "linh", "liu", "lo", "loa",
        "loan", "loang", "loanh", "loay", "loe", "loen", "loi", "lom", "lon", "long",
        "loong", "lu", "lua", "lui", "lum", "lung", "luya", "luyn", "ly", "ma",
        "mai", "man", "mang", "manh", "mao", "mau", "may", "me", "men", "meng",
        "meo", "mi", "mia", "min", "minh", "mo", "moay", "moi", "mom", "mon",
        "mong", "moong", "mu", "mua", "mui", "mun", "mung", "na", "nai", "nam",
        "nan", "nang", "nanh", "nao", "nay", "ne", "nem", "nen", "neo", "nga",
        "ngai", "ngan", "ngang", "ngao", "ngau", "ngay", "nghe", "nghen", "nghi", "nghinh",
        "nghiu", "ngo", "ngoa", "ngoai", "ngoan", "ngoao", "ngoay", "ngoe", "ngoen", "ngoi",
        "ngon", "ngu", "nguy", "nha", "nhai", "nham", "nhan", "nhang", "nhanh", "nhao",
        "nhau", "nhay", "nhe", "nhem", "nhen", "nheo", "nhi", "nhinh", "nho", "nhoai",
        "nhoay", "nhoe", "nhoen", "nhoi", "nhom", "nhon", "nhong", "nhu", "nhum", "nhung",
        "ni", "nia", "nin", "ninh", "niu", "no", "noi", "nom", "non", "nong",
        "nu", "nua", "nung", "o", "oa", "oai", "oan", "oang", "oanh", "oe",
        "oi", "om", "ong", "pa", "pan", "panh", "pha", "phai", "phang", "phanh",
        "phao", "phau", "phay", "phe", "phen", "pheo", "phi", "phim", "phin", "phinh",
        "phiu", "pho", "phoi", "phong", "phu", "phua", "phui", "phun", "phung", "phuy",
        "pi", "pin", "pom", "pu", "qua", "quai", "quan", "quang", "quanh", "quay",
        "que", "quen", "queo", "quy", "ra", "rai", "ram", "ran", "rang", "ranh",
        "rao", "rau", "ray", "re", "ren", "reo", "ri", "ria", "rim", "rin",
        "rinh", "riu", "ro", "roa", "roi", "rong", "ru", "rua", "rui", "rum",
        "run", "rung", "sa", "sai", "sam", "san", "sang", "sanh", "sao", "sau",
        "say", "se", "sen", "seo", "si", "sim", "sin", "sinh", "so", "soa",
        "soi", "son", "song", "soong", "su", "sui", "sum", "sun", "sung", "suy",
        "ta", "tai", "tam", "tan", "tang", "tanh", "tao", "tau", "tay", "te",
        "tem", "ten", "teng", "teo", "tha", "thai", "tham", "than", "thang", "thanh",
        "thao", "thau", "thay", "the", "then", "theo", "thi", "thia", "thin", "thinh",
        "thiu", "tho", "thoa", "thoai", "thoang", "thoi", "thom", "thon", "thong", "thu",
        "thua", "thui", "thum", "thun", "thung", "ti", "tia", "tim", "tin", "tinh",
        "tiu", "to", "toa", "toan", "toang", "toanh", "toe", "toen", "toi", "tom",
        "ton", "tong", "toong", "tra", "trai", "trang", "tranh", "trao", "trau", "tre",
        "treo", "tri", "trinh", "tro", "trom", "trong", "tru", "trui", "trung", "truy",
        "tu", "tua", "tui", "tum", "tun", "tung", "tuy", "tuya", "tuyn", "u",
        "ui", "um", "un", "ung", "uy", "va", "vai", "van", "vang", "vanh",
        "vao", "vay", "ve", "ven", "veo", "vi", "vin", "vinh", "vo", "voan",
        "voi", "von", "vong", "vu", "vua", "vui", "vun", "vung", "xa", "xam",
        "xan", "xang", "xanh", "xao", "xay", "xe", "xem", "xen", "xeo", "xi",
        "xin", "xinh", "xo", "xoa", "xoai", "xoan", "xoang", "xoay", "xoe", "xoen",
        "xoi", "xom", "xon", "xong", "xoong", "xu", "xua", "xui", "xum", "xun",
        "xung", "xuya", "y"
    ]

    static func isVietnameseWord(_ word: String) -> Bool {
        let s = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        
        let range = NSRange(location: 0, length: s.utf16.count)
        if vnAccentRegex.firstMatch(in: s, options: [], range: range) != nil {
            return true
        }
        
        return vnUnsignedWords.contains(s)
    }
}



// MARK: - English Transliterator
final class EnglishTransliterator {
    static let vowels = "aeiouyăâêôơưáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ"
    
    static let sRules: [RegexRule] = [
        RegexRule(pattern: "tion$", options: .caseInsensitive, template: "ân"),
        RegexRule(pattern: "sion$", options: .caseInsensitive, template: "ân"),
        RegexRule(pattern: "age$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ing$", options: .caseInsensitive, template: "ing"),
        RegexRule(pattern: "ture$", options: .caseInsensitive, template: "chờ"),
        RegexRule(pattern: "cial$", options: .caseInsensitive, template: "xô"),
        RegexRule(pattern: "tial$", options: .caseInsensitive, template: "xô"),
        RegexRule(pattern: "aught", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "ought", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "ound", options: .caseInsensitive, template: "ao"),
        RegexRule(pattern: "ight", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "eigh", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ough", options: .caseInsensitive, template: "ao"),
        RegexRule(pattern: "\\bst(?!r)", options: .caseInsensitive, template: "t"),
        RegexRule(pattern: "\\bstr", options: .caseInsensitive, template: "tr"),
        RegexRule(pattern: "\\bsch", options: .caseInsensitive, template: "c"),
        RegexRule(pattern: "\\bsc(?=h)", options: .caseInsensitive, template: "c"),
        RegexRule(pattern: "\\bsc|sk", options: .caseInsensitive, template: "c"),
        RegexRule(pattern: "\\bsp", options: .caseInsensitive, template: "p"),
        RegexRule(pattern: "\\btr", options: .caseInsensitive, template: "tr"),
        RegexRule(pattern: "\\bbr", options: .caseInsensitive, template: "r"),
        RegexRule(pattern: "\\bcr|pr|gr|dr|fr", options: .caseInsensitive, template: "r"),
        RegexRule(pattern: "\\bbl|cl|sl|pl", options: .caseInsensitive, template: "l"),
        RegexRule(pattern: "\\bfl", options: .caseInsensitive, template: "ph"),
        RegexRule(pattern: "ck", options: .caseInsensitive, template: "c"),
        RegexRule(pattern: "sh", options: .caseInsensitive, template: "s"),
        RegexRule(pattern: "ch", options: .caseInsensitive, template: "ch"),
        RegexRule(pattern: "th", options: .caseInsensitive, template: "th"),
        RegexRule(pattern: "ph", options: .caseInsensitive, template: "ph"),
        RegexRule(pattern: "wh", options: .caseInsensitive, template: "q"),
        RegexRule(pattern: "qu", options: .caseInsensitive, template: "q"),
        RegexRule(pattern: "kn", options: .caseInsensitive, template: "n"),
        RegexRule(pattern: "wr", options: .caseInsensitive, template: "r")
    ]
    
    static let rRules: [RegexRule] = [
        RegexRule(pattern: "le$", options: .caseInsensitive, template: "ồ"),
        RegexRule(pattern: "ook$", options: .caseInsensitive, template: "úc"),
        RegexRule(pattern: "ood$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ool$", options: .caseInsensitive, template: "un"),
        RegexRule(pattern: "oom$", options: .caseInsensitive, template: "um"),
        RegexRule(pattern: "oon$", options: .caseInsensitive, template: "un"),
        RegexRule(pattern: "oot$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "iend$", options: .caseInsensitive, template: "en"),
        RegexRule(pattern: "end$", options: .caseInsensitive, template: "en"),
        RegexRule(pattern: "eau$", options: .caseInsensitive, template: "iu"),
        RegexRule(pattern: "ail$", options: .caseInsensitive, template: "ain"),
        RegexRule(pattern: "ain$", options: .caseInsensitive, template: "ain"),
        RegexRule(pattern: "ait$", options: .caseInsensitive, template: "ât"),
        RegexRule(pattern: "oat$", options: .caseInsensitive, template: "ốt"),
        RegexRule(pattern: "oad$", options: .caseInsensitive, template: "ốt"),
        RegexRule(pattern: "oal$", options: .caseInsensitive, template: "ôn"),
        RegexRule(pattern: "eep$", options: .caseInsensitive, template: "íp"),
        RegexRule(pattern: "eet$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "eel$", options: .caseInsensitive, template: "in"),
        RegexRule(pattern: "atch$", options: .caseInsensitive, template: "át"),
        RegexRule(pattern: "etch$", options: .caseInsensitive, template: "éch"),
        RegexRule(pattern: "itch$", options: .caseInsensitive, template: "ích"),
        RegexRule(pattern: "otch$", options: .caseInsensitive, template: "ốt"),
        RegexRule(pattern: "utch$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "edge$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "idge$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "odge$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "udge$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ack$", options: .caseInsensitive, template: "ác"),
        RegexRule(pattern: "eck$", options: .caseInsensitive, template: "éc"),
        RegexRule(pattern: "ick$", options: .caseInsensitive, template: "ích"),
        RegexRule(pattern: "ock$", options: .caseInsensitive, template: "óc"),
        RegexRule(pattern: "uck$", options: .caseInsensitive, template: "úc"),
        RegexRule(pattern: "ash$", options: .caseInsensitive, template: "át"),
        RegexRule(pattern: "esh$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "ish$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "osh$", options: .caseInsensitive, template: "ốt"),
        RegexRule(pattern: "ush$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ath$", options: .caseInsensitive, template: "át"),
        RegexRule(pattern: "eth$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "ith$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "oth$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "uth$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ate$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ete$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "ite$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "ote$", options: .caseInsensitive, template: "ốt"),
        RegexRule(pattern: "ute$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ade$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ede$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "ide$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "ode$", options: .caseInsensitive, template: "ốt"),
        RegexRule(pattern: "ude$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ake$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ame$", options: .caseInsensitive, template: "am"),
        RegexRule(pattern: "ane$", options: .caseInsensitive, template: "an"),
        RegexRule(pattern: "ape$", options: .caseInsensitive, template: "ếp"),
        RegexRule(pattern: "eke$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "eme$", options: .caseInsensitive, template: "êm"),
        RegexRule(pattern: "ene$", options: .caseInsensitive, template: "en"),
        RegexRule(pattern: "ike$", options: .caseInsensitive, template: "íc"),
        RegexRule(pattern: "ime$", options: .caseInsensitive, template: "am"),
        RegexRule(pattern: "ine$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "oke$", options: .caseInsensitive, template: "ốc"),
        RegexRule(pattern: "ome$", options: .caseInsensitive, template: "om"),
        RegexRule(pattern: "\\bone$", options: .caseInsensitive, template: "oăn"),
        RegexRule(pattern: "one$", options: .caseInsensitive, template: "ôn"),
        RegexRule(pattern: "uke$", options: .caseInsensitive, template: "ấc"),
        RegexRule(pattern: "ume$", options: .caseInsensitive, template: "uym"),
        RegexRule(pattern: "une$", options: .caseInsensitive, template: "uyn"),
        RegexRule(pattern: "ase$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ise$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "ose$", options: .caseInsensitive, template: "âu"),
        RegexRule(pattern: "ace$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ice$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "ope$", options: .caseInsensitive, template: "ốp"),
        RegexRule(pattern: "ave$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ife$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "all$", options: .caseInsensitive, template: "âu"),
        RegexRule(pattern: "ell$", options: .caseInsensitive, template: "eo"),
        RegexRule(pattern: "ill$", options: .caseInsensitive, template: "iu"),
        RegexRule(pattern: "oll$", options: .caseInsensitive, template: "ôn"),
        RegexRule(pattern: "ull$", options: .caseInsensitive, template: "un"),
        RegexRule(pattern: "ang$", options: .caseInsensitive, template: "ang"),
        RegexRule(pattern: "eng$", options: .caseInsensitive, template: "ing"),
        RegexRule(pattern: "ong$", options: .caseInsensitive, template: "ong"),
        RegexRule(pattern: "ung$", options: .caseInsensitive, template: "âng"),
        RegexRule(pattern: "air$", options: .caseInsensitive, template: "e"),
        RegexRule(pattern: "ear$", options: .caseInsensitive, template: "ia"),
        RegexRule(pattern: "ire$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "ure$", options: .caseInsensitive, template: "iu"),
        RegexRule(pattern: "our$", options: .caseInsensitive, template: "ao"),
        RegexRule(pattern: "ore$", options: .caseInsensitive, template: "o"),
        RegexRule(pattern: "ound$", options: .caseInsensitive, template: "ao"),
        RegexRule(pattern: "ight$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "aught$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "ought$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "eigh$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ork$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "ee$", options: .caseInsensitive, template: "i"),
        RegexRule(pattern: "ea$", options: .caseInsensitive, template: "i"),
        RegexRule(pattern: "oo$", options: .caseInsensitive, template: "u"),
        RegexRule(pattern: "oa$", options: .caseInsensitive, template: "oa"),
        RegexRule(pattern: "oe$", options: .caseInsensitive, template: "oe"),
        RegexRule(pattern: "ai$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "ay$", options: .caseInsensitive, template: "ay"),
        RegexRule(pattern: "au$", options: .caseInsensitive, template: "au"),
        RegexRule(pattern: "aw$", options: .caseInsensitive, template: "â"),
        RegexRule(pattern: "ei$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "ey$", options: .caseInsensitive, template: "ây"),
        RegexRule(pattern: "oi$", options: .caseInsensitive, template: "oi"),
        RegexRule(pattern: "oy$", options: .caseInsensitive, template: "oi"),
        RegexRule(pattern: "ou$", options: .caseInsensitive, template: "u"),
        RegexRule(pattern: "ow$", options: .caseInsensitive, template: "ô"),
        RegexRule(pattern: "ue$", options: .caseInsensitive, template: "ue"),
        RegexRule(pattern: "ui$", options: .caseInsensitive, template: "ui"),
        RegexRule(pattern: "ie$", options: .caseInsensitive, template: "ai"),
        RegexRule(pattern: "eu$", options: .caseInsensitive, template: "iu"),
        RegexRule(pattern: "ar$", options: .caseInsensitive, template: "a"),
        RegexRule(pattern: "er$", options: .caseInsensitive, template: "ơ"),
        RegexRule(pattern: "ir$", options: .caseInsensitive, template: "ơ"),
        RegexRule(pattern: "or$", options: .caseInsensitive, template: "o"),
        RegexRule(pattern: "ur$", options: .caseInsensitive, template: "ơ"),
        RegexRule(pattern: "al$", options: .caseInsensitive, template: "an"),
        RegexRule(pattern: "el$", options: .caseInsensitive, template: "eo"),
        RegexRule(pattern: "il$", options: .caseInsensitive, template: "iu"),
        RegexRule(pattern: "ol$", options: .caseInsensitive, template: "ôn"),
        RegexRule(pattern: "ul$", options: .caseInsensitive, template: "un"),
        RegexRule(pattern: "ab$", options: .caseInsensitive, template: "áp"),
        RegexRule(pattern: "ad$", options: .caseInsensitive, template: "át"),
        RegexRule(pattern: "ag$", options: .caseInsensitive, template: "ác"),
        RegexRule(pattern: "ak$", options: .caseInsensitive, template: "át"),
        RegexRule(pattern: "ap$", options: .caseInsensitive, template: "áp"),
        RegexRule(pattern: "at$", options: .caseInsensitive, template: "át"),
        RegexRule(pattern: "eb$", options: .caseInsensitive, template: "ép"),
        RegexRule(pattern: "ed$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "eg$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "ek$", options: .caseInsensitive, template: "éc"),
        RegexRule(pattern: "ep$", options: .caseInsensitive, template: "ép"),
        RegexRule(pattern: "et$", options: .caseInsensitive, template: "ét"),
        RegexRule(pattern: "ib$", options: .caseInsensitive, template: "íp"),
        RegexRule(pattern: "id$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "ig$", options: .caseInsensitive, template: "íc"),
        RegexRule(pattern: "ik$", options: .caseInsensitive, template: "íc"),
        RegexRule(pattern: "ip$", options: .caseInsensitive, template: "íp"),
        RegexRule(pattern: "it$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "ob$", options: .caseInsensitive, template: "óp"),
        RegexRule(pattern: "od$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "og$", options: .caseInsensitive, template: "óc"),
        RegexRule(pattern: "ok$", options: .caseInsensitive, template: "óc"),
        RegexRule(pattern: "op$", options: .caseInsensitive, template: "óp"),
        RegexRule(pattern: "ot$", options: .caseInsensitive, template: "ót"),
        RegexRule(pattern: "ub$", options: .caseInsensitive, template: "úp"),
        RegexRule(pattern: "ud$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "ug$", options: .caseInsensitive, template: "úc"),
        RegexRule(pattern: "uk$", options: .caseInsensitive, template: "úc"),
        RegexRule(pattern: "up$", options: .caseInsensitive, template: "úp"),
        RegexRule(pattern: "ut$", options: .caseInsensitive, template: "út"),
        RegexRule(pattern: "am$", options: .caseInsensitive, template: "am"),
        RegexRule(pattern: "an$", options: .caseInsensitive, template: "an"),
        RegexRule(pattern: "em$", options: .caseInsensitive, template: "em"),
        RegexRule(pattern: "en$", options: .caseInsensitive, template: "en"),
        RegexRule(pattern: "im$", options: .caseInsensitive, template: "im"),
        RegexRule(pattern: "in$", options: .caseInsensitive, template: "in"),
        RegexRule(pattern: "om$", options: .caseInsensitive, template: "om"),
        RegexRule(pattern: "on$", options: .caseInsensitive, template: "on"),
        RegexRule(pattern: "um$", options: .caseInsensitive, template: "âm"),
        RegexRule(pattern: "un$", options: .caseInsensitive, template: "ân"),
        RegexRule(pattern: "as$", options: .caseInsensitive, template: "ẹt"),
        RegexRule(pattern: "es$", options: .caseInsensitive, template: "ẹt"),
        RegexRule(pattern: "is$", options: .caseInsensitive, template: "ít"),
        RegexRule(pattern: "os$", options: .caseInsensitive, template: "ọt"),
        RegexRule(pattern: "us$", options: .caseInsensitive, template: "ợt"),
        RegexRule(pattern: "aa$", options: .caseInsensitive, template: "a"),
        RegexRule(pattern: "ii$", options: .caseInsensitive, template: "i"),
        RegexRule(pattern: "uu$", options: .caseInsensitive, template: "u")
    ]
    
    static let tRules: [RegexRule] = {
        let v = vowels
        return [
            RegexRule(pattern: "x(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "c"),
            RegexRule(pattern: "j", options: .caseInsensitive, template: "d"),
            RegexRule(pattern: "w", options: .caseInsensitive, template: "u"),
            RegexRule(pattern: "f(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "ph"),
            RegexRule(pattern: "f(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "p"),
            RegexRule(pattern: "s(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "x"),
            RegexRule(pattern: "s(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "t"),
            RegexRule(pattern: "d(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "đ"),
            RegexRule(pattern: "d(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "t"),
            RegexRule(pattern: "z(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "d"),
            RegexRule(pattern: "z(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "t"),
            RegexRule(pattern: "g(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "g"),
            RegexRule(pattern: "g(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "c"),
            RegexRule(pattern: "b(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "b"),
            RegexRule(pattern: "b(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "p"),
            RegexRule(pattern: "c(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "k"),
            RegexRule(pattern: "c(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "c"),
            RegexRule(pattern: "r(?=[v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "r"),
            RegexRule(pattern: "r(?![v])".replacingOccurrences(of: "v", with: v), options: .caseInsensitive, template: "ơ"),
            RegexRule(pattern: "a", options: .caseInsensitive, template: "a"),
            RegexRule(pattern: "e", options: .caseInsensitive, template: "e"),
            RegexRule(pattern: "i", options: .caseInsensitive, template: "i"),
            RegexRule(pattern: "o", options: .caseInsensitive, template: "o"),
            RegexRule(pattern: "u", options: .caseInsensitive, template: "u")
        ]
    }()
    
    static func transliterateWord(_ word: String) -> String {
        guard !word.isEmpty else { return "" }
        let vowels = Self.vowels
        var n = word.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if n.hasPrefix("y") {
            n = "d" + n.dropFirst()
        }
        if n.hasPrefix("d") {
            n = "đ" + n.dropFirst()
        }
        
        for rule in sRules {
            n = rule.regex.stringByReplacingMatches(in: n, options: [], range: NSRange(location: 0, length: n.utf16.count), withTemplate: rule.template)
        }
        for rule in rRules {
            n = rule.regex.stringByReplacingMatches(in: n, options: [], range: NSRange(location: 0, length: n.utf16.count), withTemplate: rule.template)
        }
        for rule in tRules {
            n = rule.regex.stringByReplacingMatches(in: n, options: [], range: NSRange(location: 0, length: n.utf16.count), withTemplate: rule.template)
        }
        
        n = n.replacingOccurrences(of: "([bcdfghjklmnpqrstvwxz])y", with: "$1i", options: .regularExpression)
        n = n.replacingOccurrences(of: "y$", with: "i", options: .regularExpression)
        
        let splitPattern = try! NSRegularExpression(pattern: "([^\\(vowels\\)]*[\\(vowels\\)]+[^\\(vowels\\)]*(?![\\(vowels\\)]))".replacingOccurrences(of: "\\(vowels\\)", with: vowels))
        
        let matches = splitPattern.matches(in: n, options: [], range: NSRange(location: 0, length: n.utf16.count))
        let nsString = n as NSString
        let a = matches.map { nsString.substring(with: $0.range) }
        
        if a.isEmpty {
            return n
        }
        
        var g = a.map { part -> String in
            var l = part.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if l.isEmpty { return "" }
            if l.hasPrefix("y") {
                l = "d" + l.dropFirst()
            }
            for rule in sRules {
                l = rule.regex.stringByReplacingMatches(in: l, options: [], range: NSRange(location: 0, length: l.utf16.count), withTemplate: rule.template)
            }
            for rule in rRules {
                l = rule.regex.stringByReplacingMatches(in: l, options: [], range: NSRange(location: 0, length: l.utf16.count), withTemplate: rule.template)
            }
            for rule in tRules {
                l = rule.regex.stringByReplacingMatches(in: l, options: [], range: NSRange(location: 0, length: l.utf16.count), withTemplate: rule.template)
            }
            l = l.replacingOccurrences(of: "([bcdfghjklmnpqrstvwxz])y", with: "$1i", options: .regularExpression)
            l = l.replacingOccurrences(of: "y$", with: "i", options: .regularExpression)
            return l
        }
        
        g = g.map { part -> String in
            var i = part.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if i.isEmpty { return "" }
            
            let lConsonants = "bcdfghjklmnpqrstvwxz"
            i = i.replacingOccurrences(of: "([brlptdgmnckxsvfzjwqh])\\1+", with: "$1", options: .regularExpression)
            
            let mCombos = ["ch", "th", "ph", "sh", "ng", "tr", "nh", "gh", "kh"]
            var p = ""
            let chars = Array(i)
            var d = 0
            while d < chars.count {
                if d < chars.count - 1, lConsonants.contains(chars[d]), lConsonants.contains(chars[d+1]) {
                    let w = String(chars[d...d+1])
                    if mCombos.contains(w) {
                        p += w
                        d += 2
                    } else {
                        p += String(chars[d+1])
                        d += 2
                    }
                } else {
                    p += String(chars[d])
                    d += 1
                }
            }
            i = p
            
            if !i.hasPrefix("ch") && !i.hasPrefix("th") && !i.hasPrefix("ph") && !i.hasPrefix("sh") {
                if i.hasPrefix("k") || i.hasPrefix("c") {
                    let second = i.dropFirst().first.map(String.init) ?? ""
                    let nextIsKey = ["i", "e", "y"].contains(second)
                    i = (nextIsKey ? "k" : "c") + i.dropFirst()
                }
            }
            
            if i.count > 1, let lastChar = i.last {
                if !vowels.contains(lastChar) {
                    let w = String(lastChar)
                    if !["p", "t", "c", "m", "n", "g", "s"].contains(w) {
                        if w == "l" {
                            i = String(i.dropLast()) + "n"
                        } else if w == "k" {
                            i = String(i.dropLast()) + "c"
                        } else if w == "d" {
                            i = String(i.dropLast()) + "t"
                        } else if w == "g" {
                            i = String(i.dropLast()) + "c"
                        } else {
                            i = String(i.dropLast())
                        }
                    }
                }
            }
            return i
        }.filter { !$0.isEmpty }
        
        return g.joined(separator: "-")
    }
}

// MARK: - Japanese Transliterator (Hiragana/Katakana to Romaji)
final class JapaneseTransliterator {
    private static let kanaToRomaji: [String: String] = [
        // Hiragana cơ bản
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "わ": "wa", "を": "o", "ん": "n",
        
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        
        // Katakana cơ bản
        "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
        "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
        "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
        "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
        "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
        "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
        "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
        "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
        "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
        "ワ": "wa", "ヲ": "o", "ン": "n",
        
        "ガ": "ga", "ギ": "gi", "グ": "gu", "ゲ": "ge", "ゴ": "go",
        "ザ": "za", "ジ": "ji", "ズ": "zu", "ゼ": "ze", "ゾ": "zo",
        "ダ": "da", "ヂ": "ji", "ヅ": "zu", "デ": "de", "ド": "do",
        "バ": "ba", "ビ": "bi", "ブ": "bu", "ベ": "be", "ボ": "bo",
        "パ": "pa", "ピ": "pi", "プ": "pu", "ペ": "pe", "ポ": "po",
        
        // Âm ghép Hiragana (Yo-on)
        "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
        "しゃ": "sha", "しゅ": "shu", "しょ": "sho",
        "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho",
        "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
        "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
        "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
        "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
        "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
        "じゃ": "ja", "じゅ": "ju", "じょ": "jo",
        "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
        "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
        
        // Âm ghép Katakana (Yo-on)
        "キャ": "kya", "キュ": "kyu", "キョ": "kyo",
        "シャ": "sha", "シュ": "shu", "ショ": "sho",
        "チャ": "cha", "チュ": "chu", "チョ": "cho",
        "ニャ": "nya", "ニュ": "nyu", "ニョ": "nyo",
        "ヒャ": "hya", "ヒュ": "hyu", "ヒョ": "hyo",
        "ミャ": "mya", "ミュ": "myu", "ミョ": "myo",
        "リャ": "rya", "リュ": "ryu", "リョ": "ryo",
        "ギャ": "gya", "ギュ": "gyu", "ギョ": "gyo",
        "ジャ": "ja", "ジュ": "ju", "ジョ": "jo",
        "ビャ": "bya", "ビュ": "byu", "ビョ": "byo",
        "ピャ": "pya", "ピュ": "pyu", "ピョ": "pyo",
        
        // Ký tự trường âm
        "ー": ""
    ]
    
    static func convertToRomaji(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        var i = 0
        
        while i < chars.count {
            // Kiểm tra âm ghép Yo-on (2 ký tự)
            if i < chars.count - 1 {
                let digraph = String(chars[i...i+1])
                if let romaji = kanaToRomaji[digraph] {
                    result += romaji
                    i += 2
                    continue
                }
            }
            
            let charStr = String(chars[i])
            
            // Kiểm tra âm ngắt Sokuon (っ/ッ)
            if charStr == "っ" || charStr == "ッ" {
                if i < chars.count - 1 {
                    let nextCharStr = String(chars[i+1])
                    if let nextRomaji = kanaToRomaji[nextCharStr], let firstLetter = nextRomaji.first {
                        // Nhân đôi phụ âm đứng trước (trừ nguyên âm)
                        if !"aeiou".contains(firstLetter) {
                            result += String(firstLetter)
                        }
                    }
                }
                i += 1
                continue
            }
            
            if let romaji = kanaToRomaji[charStr] {
                result += romaji
            } else {
                result += charStr
            }
            i += 1
        }
        return result
    }

    // Bảng ánh xạ Romaji sang Phiên âm Việt
    private static let romajiToViSyllable: [String: String] = [
        "sha": "sa", "shi": "si", "shu": "su", "she": "sê", "sho": "sô",
        "cha": "cha", "chi": "chi", "chu": "chu", "che": "chê", "cho": "chô",
        "tsu": "chư",
        "kya": "kia", "kyu": "kiu", "kyo": "kiô",
        "nya": "nia", "nyu": "niu", "nyo": "niô",
        "hya": "hia", "hyu": "hiu", "hyo": "hiô",
        "mya": "mia", "myu": "miu", "myo": "miô",
        "rya": "ria", "ryu": "riu", "ryo": "riô",
        "gya": "ghia", "gyu": "ghiu", "gyo": "ghiô",
        "bya": "bia", "byu": "biu", "byo": "biô",
        "pya": "pia", "pyu": "piu", "pyo": "piô",
        "ka": "ka", "ki": "ki", "ku": "kư", "ke": "kê", "ko": "kô",
        "sa": "xa", "si": "xi", "su": "xư", "se": "xê", "so": "xô",
        "ta": "ta", "ti": "chi", "tu": "chư", "te": "tê", "to": "tô",
        "na": "na", "ni": "ni", "nu": "nư", "ne": "nê", "no": "nô",
        "ha": "ha", "hi": "hi", "hu": "hư", "he": "hê", "ho": "hô",
        "fu": "phư",
        "ma": "ma", "mi": "mi", "mu": "mư", "me": "mê", "mo": "mô",
        "ya": "da", "yi": "di", "yu": "du", "ye": "dê", "yo": "dô",
        "ra": "ra", "ri": "ri", "ru": "rư", "re": "rê", "ro": "rô",
        "wa": "oa", "wi": "uy", "we": "uê", "wo": "ô",
        "ga": "ga", "gi": "ghi", "gu": "gư", "ge": "ghê", "go": "gô",
        "za": "da", "zi": "di", "zu": "dư", "ze": "dê", "zo": "dô",
        "da": "đa", "di": "đi", "du": "đư", "de": "đê", "do": "đô",
        "ba": "ba", "bi": "bi", "bu": "bư", "be": "bê", "bo": "bô",
        "pa": "pa", "pi": "pi", "pu": "pư", "pe": "pê", "po": "pô",
        "ja": "gia", "ji": "gi", "ju": "giu", "je": "giê", "jo": "giô",
        "a": "a", "i": "i", "u": "ư", "e": "ê", "o": "ô",
        "n": "n"
    ]

    private static let validRomajiSyllables: Set<String> = Set(romajiToViSyllable.keys)

    private static let englishBlacklist: Set<String> = [
        "no", "so", "to", "do", "go", "on", "an", "in", "he", "she", "we", "me",
        "be", "re", "or", "by", "my", "if", "up", "at", "it", "is", "as", "am",
        "one", "two", "ten", "run", "ran", "son", "sun", "won", "ton", "gun", "fun",
        "pan", "pin", "sin", "win", "bin", "ban", "can", "man", "fan", "van", "dan",
        "age", "ago", "are", "ate", "ape", "use", "ore", "owe", "awe",
        "sea", "see", "tea", "tee", "bee", "fee", "pea",
        "too", "woo", "boo", "goo", "moo", "zoo",
        "pie", "tie", "die", "lie", "vie",
        "sue", "due", "hue", "rue", "cue",
        "you", "our", "her", "him", "his", "who",
        "take", "make", "sake", "wake", "bake", "cake", "fake", "lake", "rake",
        "name", "same", "came", "game", "fame", "dame", "tame", "lame",
        "some", "come", "home", "done", "gone", "bone", "tone", "zone", "none",
        "more", "bore", "core", "fore", "gore", "pore", "sore", "wore", "tore",
        "page", "sage", "cage", "rage", "wage",
        "nose", "rose", "pose", "dose", "hose",
        "side", "wide", "hide", "ride", "tide",
        "time", "dime", "mime", "lime",
        "mine", "wine", "dine", "fine", "line", "nine", "pine", "vine",
        "sure", "pure", "cure",
        "pipe", "ripe", "wipe",
        "pike", "hike", "bike", "mike",
        "note", "vote", "dote",
        "open", "oven",
        "upon",
        "reason", "season", "poison", "prison", "bison",
        "position", "opinion", "pension", "tension", "session", "mission",
        "passion", "fashion", "nation", "station", "motion", "notion",
        "opposite", "sunshine", "someone", "anyone",
        "imagine", "machine", "routine", "marine", "genuine",
        "revenue", "continue", "pursue", "issue",
        "orange", "manage", "passage", "message", "damage", "garage",
        "surprise", "paradise", "enterprise",
        "noise", "poise", "raise",
        "piano", "casino", "volcano",
        "refuse", "rescue", "statue",
        "tongue", "unique", "technique",
        "resume", "costume", "fortune",
        "ature", "nature", "future", "mature", "posture",
        "measure", "treasure", "pleasure",
        "russia", "russian", "siberia",
        "toronto", "ohio", "waikiki", "oahu",
        "sudden", "happen", "kitten", "mitten", "bitten", "rotten", "gotten",
        "women", "woman",
        "minute", "ribute", "absolute",
        "were", "here", "mere", "there", "where",
        "undue", "undo", "unto",
        "semi", "anti",
        "originate", "dominate", "nominate", "terminate", "estimate",
        "situation", "reputation", "population", "operation", "generation",
        "sensation", "combination", "imagination", "destination",
        "possession", "opposition", "composition", "proposition",
        "refugee", "guarantee",
        "wanton", "pardon",
        "taboo", "bamboo", "shampoo", "tattoo",
        "zero", "hero", "nero",
        "yankee",
        "yoke", "woke", "joke", "poke", "smoke", "broke", "spoke", "choke",
        "shake", "shaken",
        "shore", "share",
        "since", "once", "hence", "fence", "prince",
        "bone", "stone", "phone", "throne", "ozone",
        "remain", "obtain", "contain", "maintain", "sustain", "retain",
        "pain", "rain", "gain", "main", "vain", "brain", "train", "grain", "drain",
        "ruin",
        "basin",
        "again", "arose", "arrange", "ashore", "aside", "attitude", "aurora",
        "automaton", "awaken",
        "beau", "been", "began", "begin", "begun", "beside", "bizarre",
        "bohemian", "bonanza",
        "chain", "change", "cherokee", "china", "chinese", "chosen",
        "dante", "date", "debutante", "desire", "disease", "doggone", "don", "dozen",
        "eaten", "ego", "emma", "emotion", "endure", "engage",
        "eurasian", "europe", "eye",
        "gaze", "geese", "goose",
        "harrison", "hate", "hawaii", "hawaiian", "hope", "house", "human",
        "idea", "indian", "insinuate", "intention", "into", "iota", "irate", "iron", "irritation",
        "japanese", "jeanne", "jesse", "joan", "joe", "jose", "joshua", "junta",
        "made", "magazine", "massage", "mate", "maui", "mean", "men", "mention",
        "mirage", "moon", "moore", "moose",
        "nope", "onto",
        "patino", "pierre",
        "rancho", "rate", "refuge", "repose",
        "seen", "soon", "suppose",
        "tirade",
        "wise", "yea", "yukon",
        "oona", "ooze", "wada", "weren", "unwin",
        "naomi", "niihau", "dennin", "doane", "hanrahan", "howison", "nakata",
        "ee", "san"
    ]

    private static func normalizeRomaji(_ word: String) -> String {
        var w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let macronMap = ["ā": "a", "ī": "i", "ū": "u", "ē": "e", "ō": "o"]
        for (k, v) in macronMap {
            w = w.replacingOccurrences(of: k, with: v)
        }
        w = w.folding(options: .diacriticInsensitive, locale: nil)
        return w
    }

    private static func simplifySokuon(_ word: String) -> (String, [Int: Character]) {
        let chars = Array(word)
        var result: [Character] = []
        var sokuonBefore: [Int: Character] = [:]
        var i = 0
        while i < chars.count {
            if i < chars.count - 1 && chars[i] == chars[i+1] && !"aeiou".contains(chars[i]) {
                sokuonBefore[result.count] = chars[i]
                result.append(chars[i])
                i += 2
            } else {
                result.append(chars[i])
                i += 1
            }
        }
        return (String(result), sokuonBefore)
    }

    private static func greedySegment(_ word: String) -> [String]? {
        var syllables: [String] = []
        let chars = Array(word)
        var i = 0
        while i < chars.count {
            var matched = false
            for len in [3, 2, 1] {
                if i + len <= chars.count {
                    let candidate = String(chars[i..<i+len])
                    if validRomajiSyllables.contains(candidate) {
                        if candidate == "n" && len == 1 {
                            if i + 1 < chars.count {
                                let nextChar = chars[i+1]
                                if "aiueony".contains(nextChar) {
                                    continue
                                }
                            }
                        }
                        syllables.append(candidate)
                        i += len
                        matched = true
                        break
                    }
                }
            }
            if !matched {
                return nil
            }
        }
        return syllables
    }

    static func isJapaneseRomaji(_ word: String) -> Bool {
        if word.count < 2 { return false }
        
        let normalized = normalizeRomaji(word)
        
        if englishBlacklist.contains(normalized) { return false }
        
        for ch in normalized {
            if "lqvx".contains(ch) { return false }
        }
        
        let regex = try! NSRegularExpression(pattern: "^[a-z]+$")
        let range = NSRange(location: 0, length: normalized.utf16.count)
        if regex.firstMatch(in: normalized, options: [], range: range) == nil {
            return false
        }
        
        let (simplified, _) = simplifySokuon(normalized)
        guard let syllables = greedySegment(simplified) else { return false }
        
        return syllables.count >= 2
    }

    static func transliterateRomaji(_ word: String) -> String {
        let normalized = normalizeRomaji(word)
        
        var sokuonChars: [(Int, Character)] = []
        var simplifiedChars: [Character] = []
        let chars = Array(normalized)
        var i = 0
        while i < chars.count {
            if i < chars.count - 1 && chars[i] == chars[i+1] && !"aeiou".contains(chars[i]) {
                sokuonChars.append((simplifiedChars.count, chars[i]))
                simplifiedChars.append(chars[i])
                i += 2
            } else {
                simplifiedChars.append(chars[i])
                i += 1
            }
        }
        let simplified = String(simplifiedChars)
        
        guard let syllables = greedySegment(simplified) else {
            return word
        }
        
        var viSyllables = syllables.map { romajiToViSyllable[$0] ?? $0 }
        
        var merged: [String] = []
        i = 0
        while i < viSyllables.count {
            if viSyllables[i] == "n" && i > 0 && !merged.isEmpty {
                merged[merged.count - 1] = merged[merged.count - 1] + "n"
                i += 1
            } else {
                merged.append(viSyllables[i])
                i += 1
            }
        }
        
        if !sokuonChars.isEmpty {
            var pos = 0
            var sylBoundaries: [(Int, Int)] = []
            for syl in syllables {
                sylBoundaries.append((pos, pos + syl.count))
                pos += syl.count
            }
            
            for (sokuPos, sokuChar) in sokuonChars {
                for (si, (start, end)) in sylBoundaries.enumerated() {
                    if sokuPos >= start && sokuPos < end {
                        let mergedIdx = findMergedIndex(syllables: syllables, mergedCount: merged.count, sylIndex: si)
                        if mergedIdx > 0 && mergedIdx < merged.count {
                            let sokuVi = sokuonCoda(sokuChar)
                            merged[mergedIdx - 1] = merged[mergedIdx - 1] + sokuVi
                        }
                        break
                    }
                }
            }
        }
        
        return merged.joined(separator: "-")
    }

    private static func findMergedIndex(syllables: [String], mergedCount: Int, sylIndex: Int) -> Int {
        var mi = 0
        for si in 0..<syllables.count {
            if si == sylIndex {
                return mi
            }
            if syllables[si] != "n" || si == 0 {
                mi += 1
            }
        }
        return mi
    }

    private static func sokuonCoda(_ char: Character) -> String {
        let mapping: [Character: String] = [
            "k": "c", "s": "t", "t": "t", "p": "p",
            "g": "c", "b": "p", "d": "t", "z": "t",
            "n": "n", "m": "m"
        ]
        if let mapped = mapping[char] {
            return mapped
        }
        return String(char)
    }
}

// MARK: - Vietnamese Number Speller
final class VietnameseNumberSpeller {
    private static let S = ["không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín"]
    private static let V = [
        10: "mười", 11: "mười một", 12: "mười hai", 13: "mười ba", 14: "mười bốn",
        15: "mười lăm", 16: "mười sáu", 17: "mười bảy", 18: "mười tám", 19: "mười chín"
    ]
    private static let C = [
        2: "hai mươi", 3: "ba mươi", 4: "bốn mươi", 5: "năm mươi",
        6: "sáu mươi", 7: "bảy mươi", 8: "tám mươi", 9: "chín mươi"
    ]

    static func spell(_ numberStr: String) -> String {
        var e = numberStr.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        if e.isEmpty { e = "0" }
        if e.hasPrefix("-") {
            return "âm " + spell(String(e.dropFirst()))
        }
        
        guard let n = Int(e) else {
            // If too large to parse as Int, map it digit by digit
            return e.map { String($0) }.map { S[Int($0) ?? 0] }.joined(separator: " ")
        }
        
        if n == 0 { return "không" }
        if n < 10 { return S[n] }
        if n < 20 { return V[n] ?? e }
        if n < 100 {
            let s = n / 10
            let r = n % 10
            let prefix = C[s] ?? ""
            if r == 0 { return prefix }
            if r == 1 { return prefix + " mốt" }
            if r == 5 { return prefix + " lăm" }
            return prefix + " " + S[r]
        }
        if n < 1000 {
            let s = n / 100
            let r = n % 100
            let prefix = S[s] + " trăm"
            if r == 0 { return prefix }
            if r < 10 { return prefix + " lẻ " + S[r] }
            return prefix + " " + spell(String(r))
        }
        if n < 1000000 {
            let s = n / 1000
            let r = n % 1000
            let prefix = spell(String(s)) + " nghìn"
            if r == 0 { return prefix }
            if r < 100 {
                if r < 10 { return prefix + " không trăm lẻ " + S[r] }
                return prefix + " không trăm " + spell(String(r))
            }
            return prefix + " " + spell(String(r))
        }
        if n < 1000000000 {
            let s = n / 1000000
            let r = n % 1000000
            let prefix = spell(String(s)) + " triệu"
            if r == 0 { return prefix }
            if r < 100 {
                if r < 10 { return prefix + " không trăm lẻ " + S[r] }
                return prefix + " không trăm " + spell(String(r))
            }
            return prefix + " " + spell(String(r))
        }
        if n < 1000000000000 {
            let s = n / 1000000000
            let r = n % 1000000000
            let prefix = spell(String(s)) + " tỷ"
            if r == 0 { return prefix }
            if r < 100 {
                if r < 10 { return prefix + " không trăm lẻ " + S[r] }
                return prefix + " không trăm " + spell(String(r))
            }
            return prefix + " " + spell(String(r))
        }
        
        return e.map { String($0) }.map { S[Int($0) ?? 0] }.joined(separator: " ")
    }
}

// MARK: - Text Preprocessor Service
final actor TextPreprocessor {
    static let shared = TextPreprocessor()
    
    private var wordMap: [String: String] = [:]
    private var acronymMap: [String: String] = [:]
    private var transliterationCache: [String: String] = [:]
    
    func lookupAcronym(_ key: String) -> String? {
        return acronymMap[key]
    }
    
    func lookupWord(_ key: String) -> String? {
        return wordMap[key]
    }
    
    private init() {
        let loaded = Self.loadResourcesFromDisk()
        self.wordMap = loaded.wordMap
        self.acronymMap = loaded.acronymMap
    }
    
    func loadResources() {
        let loaded = Self.loadResourcesFromDisk()
        self.wordMap = loaded.wordMap
        self.acronymMap = loaded.acronymMap
    }
    
    private static func loadResourcesFromDisk() -> (wordMap: [String: String], acronymMap: [String: String]) {
        let fileManager = FileManager.default
        var wordMap: [String: String] = [:]
        var acronymMap: [String: String] = [:]
        var wordsLoaded = false
        var acronymsLoaded = false
        
        // 1. Try loading from Application Support directory
        if let appSupport = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let rootURL = appSupport.appendingPathComponent("LocalTTS", isDirectory: true)
            let wordsURL = rootURL.appendingPathComponent("non-vietnamese-words.plist")
            let acronymsURL = rootURL.appendingPathComponent("acronyms.plist")
            
            if fileManager.fileExists(atPath: wordsURL.path) {
                wordMap = Self.loadPlist(from: wordsURL)
                wordsLoaded = true
            }
            if fileManager.fileExists(atPath: acronymsURL.path) {
                acronymMap = Self.loadPlist(from: acronymsURL)
                acronymsLoaded = true
            }
        }
        
        // 2. Fallback to Bundle resources if not loaded
        if !wordsLoaded {
            if let bundleURL = Bundle.main.url(forResource: "non-vietnamese-words", withExtension: "plist") {
                wordMap = Self.loadPlist(from: bundleURL)
            }
        }
        if !acronymsLoaded {
            if let bundleURL = Bundle.main.url(forResource: "acronyms", withExtension: "plist") {
                acronymMap = Self.loadPlist(from: bundleURL)
            }
        }
        
        appLog("Loaded \(wordMap.count) non-Vietnamese words and \(acronymMap.count) acronyms.")
        return (wordMap, acronymMap)
    }
    
    // MARK: - Plist Loading Helper
    private static func loadPlist(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] else {
            appLog("Warning: Could not read Plist file at \(url.path)")
            return [:]
        }
        return dict
    }
    
    // MARK: - Regex Replacement Helper
    typealias MatchReplacer = (NSTextCheckingResult, NSString) -> String?
    
    private static func replaceMatches(in text: String, pattern: String, options: NSRegularExpression.Options = [], replacer: MatchReplacer) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        var result = text
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches.reversed() {
            if let replacement = replacer(match, nsString) {
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }
    
    // MARK: - Cleaners & Formatters
    private static func cleanText(_ text: String) -> String {
        var e = text
        e = e.replacingOccurrences(of: "&", with: " và ")
        e = e.replacingOccurrences(of: "@", with: " a còng ")
        e = e.replacingOccurrences(of: "#", with: " thăng ")
        e = e.replacingOccurrences(of: "*", with: "")
        e = e.replacingOccurrences(of: "_", with: " ")
        e = e.replacingOccurrences(of: "~", with: "")
        e = e.replacingOccurrences(of: "`", with: "")
        e = e.replacingOccurrences(of: "^", with: "")
        e = e.replacingOccurrences(of: "https?:\\/\\/\\S+", with: "", options: .regularExpression)
        e = e.replacingOccurrences(of: "www\\.\\S+", with: "", options: .regularExpression)
        e = e.replacingOccurrences(of: "\\S+@\\S+\\.\\S+", with: "", options: .regularExpression)
        return e
    }
    
    private static func normalizeQuotesAndDashes(_ text: String) -> String {
        var e = text
        e = e.replacingOccurrences(of: "[\"\"„‟]", with: "\"", options: .regularExpression)
        e = e.replacingOccurrences(of: "[''‚‛]", with: "'", options: .regularExpression)
        e = e.replacingOccurrences(of: "[–—−]", with: "-", options: .regularExpression)
        e = e.replacingOccurrences(of: "\\.{3,}", with: "...", options: .regularExpression)
        e = e.replacingOccurrences(of: "…", with: "...")
        e = e.replacingOccurrences(of: "([!?.])\\1+", with: "$1", options: .regularExpression)
        return e
    }
    
    private static func cleanEmojisAndSymbols(_ text: String) -> String {
        var e = text
        let emojiPattern = "[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F900}-\u{1F9FF}]|[\u{1F018}-\u{1F270}]|[\u{238C}-\u{2454}]|[\u{20D0}-\u{20FF}]|\u{FE0F}|\u{200D}"
        e = e.replacingOccurrences(of: emojiPattern, with: " ", options: .regularExpression)
        
        e = e.replacingOccurrences(of: "[\\\\()¯']", with: " ", options: .regularExpression)
        e = e.replacingOccurrences(of: "[\"\"\"]", with: " ", options: .regularExpression)
        e = e.replacingOccurrences(of: "\\s—", with: ".", options: .regularExpression)
        e = e.replacingOccurrences(of: "\\b_\\b", with: " ", options: .regularExpression)
        e = e.replacingOccurrences(of: "(?<!\\d)-(?!\\d)", with: " ", options: .regularExpression)
        
        let keepPattern = "[^\\u0000-\u{024F}\u{1E00}-\u{1EFF}\u{3040}-\u{30FF}]"
        e = e.replacingOccurrences(of: keepPattern, with: " ", options: .regularExpression)
        
        e = e.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return e.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatNumbers(_ text: String) -> String {
        let pattern = "(\\d{1,3}(?:\\.\\d{3})+)(?=\\s|$|[^\\d.,])"
        return replaceMatches(in: text, pattern: pattern) { match, ns in
            let val = ns.substring(with: match.range(at: 1))
            return val.replacingOccurrences(of: ".", with: "")
        }
    }
    
    // MARK: - Unit, Ranges, Dates, Times, Currency
    private static let units: [String] = [
        "m","cm","mm","km","dm","hm","dam","inch","kg","g","mg","t","tấn","yến","lạng","ml","l","lít",
        "m²","m2","km²","km2","ha","cm²","cm2","m³","m3","cm³","cm3","km³","km3","s","sec","min","h",
        "hr","hrs","km/h","kmh","m/s","ms","mm/h","cm/s","°C","°F","°K","°R","°Re","°Ro","°N","°D"
    ]
    private static let currencies: [String] = ["đồng","VND","vnđ","đ","USD","$"]
    
    private static let unitsPattern: String = {
        let all = Array(Set(units + currencies))
        let escaped = all.map { NSRegularExpression.escapedPattern(for: $0) }
        let sorted = escaped.sorted { $0.count > $1.count }
        return sorted.joined(separator: "|")
    }()

    private static func processUnitsRangeAndRatio(_ text: String) -> String {
        var e = text
        let patternRange = "(\\d+)\\s*[-–—]\\s*(\\d+)\\s*(\(unitsPattern))\\b"
        e = replaceMatches(in: e, pattern: patternRange, options: [.caseInsensitive]) { match, ns in
            let i = ns.substring(with: match.range(at: 1))
            let l = ns.substring(with: match.range(at: 2))
            let h = ns.substring(with: match.range(at: 3))
            let p = h.lowercased() == "đ" ? "" : " "
            return "\(i) đến \(l)\(p)\(h)"
        }
        
        let patternRatio = "(\\d+)\\s*[\\/:]\\s*(\\d+)\\s*(\(unitsPattern))\\b"
        e = replaceMatches(in: e, pattern: patternRatio, options: [.caseInsensitive]) { match, ns in
            let i = ns.substring(with: match.range(at: 1))
            let l = ns.substring(with: match.range(at: 2))
            let h = ns.substring(with: match.range(at: 3))
            let p = h.lowercased() == "đ" ? "" : " "
            return "\(i) phần \(l)\(p)\(h)"
        }
        
        return e
    }

    private static func processYearRanges(_ text: String) -> String {
        return replaceMatches(in: text, pattern: "(\\d{4})\\s*[-–—]\\s*(\\d{4})") { match, ns in
            let s = ns.substring(with: match.range(at: 1))
            let r = ns.substring(with: match.range(at: 2))
            return "\(VietnameseNumberSpeller.spell(s)) đến \(VietnameseNumberSpeller.spell(r))"
        }
    }
    
    private static func isValidDate(day: String, month: String, year: String? = nil) -> Bool {
        guard let d = Int(day), let m = Int(month) else { return false }
        if let yStr = year, let y = Int(yStr) {
            return d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 1000 && y <= 9999
        }
        return d >= 1 && d <= 31 && m >= 1 && m <= 12
    }

    private static func isValidMonth(month: String) -> Bool {
        guard let m = Int(month) else { return false }
        return m >= 1 && m <= 12
    }

    private static func processDates(_ text: String) -> String {
        var e = text
        
        e = replaceMatches(in: e, pattern: "ngày\\s+(\\d{1,2})\\s*[-–—]\\s*(\\d{1,2})\\s*[/-]\\s*(\\d{1,2})(?:\\s*[/-]\\s*(\\d{4}))?") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            let a = ns.substring(with: match.range(at: 3))
            let g = match.range(at: 4).location != NSNotFound ? ns.substring(with: match.range(at: 4)) : nil
            if isValidDate(day: o, month: a, year: g) && isValidDate(day: c, month: a, year: g) {
                var res = "ngày \(VietnameseNumberSpeller.spell(o)) đến \(VietnameseNumberSpeller.spell(c)) tháng \(VietnameseNumberSpeller.spell(a))"
                if let yearVal = g {
                    res += " năm \(VietnameseNumberSpeller.spell(yearVal))"
                }
                return res
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2})\\s*[-–—]\\s*(\\d{1,2})\\s*[/-]\\s*(\\d{1,2})(?:\\s*[/-]\\s*(\\d{4}))?") { match, ns in
            let start = match.range.location
            let prefixLength = min(10, start)
            let prefixRange = NSRange(location: start - prefixLength, length: prefixLength)
            if prefixRange.location >= 0 {
                let prefix = ns.substring(with: prefixRange)
                if prefix.contains("ngày") || prefix.contains("đến") {
                    return nil
                }
            }
            
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            let a = ns.substring(with: match.range(at: 3))
            let g = match.range(at: 4).location != NSNotFound ? ns.substring(with: match.range(at: 4)) : nil
            if isValidDate(day: o, month: a, year: g) && isValidDate(day: c, month: a, year: g) {
                var res = "\(VietnameseNumberSpeller.spell(o)) đến \(VietnameseNumberSpeller.spell(c)) tháng \(VietnameseNumberSpeller.spell(a))"
                if let yearVal = g {
                    res += " năm \(VietnameseNumberSpeller.spell(yearVal))"
                }
                return res
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2})\\s*[-–—]\\s*(\\d{1,2})\\s*[/-]\\s*(\\d{4})") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            let a = ns.substring(with: match.range(at: 3))
            if isValidMonth(month: o) && isValidMonth(month: c), let y = Int(a), y >= 1000 && y <= 9999 {
                return "tháng \(VietnameseNumberSpeller.spell(o)) đến tháng \(VietnameseNumberSpeller.spell(c)) năm \(VietnameseNumberSpeller.spell(a))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(Sinh|sinh)\\s+ngày\\s+(\\d{1,2})[/-](\\d{1,2})[/-](\\d{4})") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            let a = ns.substring(with: match.range(at: 3))
            let g = ns.substring(with: match.range(at: 4))
            if isValidDate(day: c, month: a, year: g) {
                return "\(o) ngày \(VietnameseNumberSpeller.spell(c)) tháng \(VietnameseNumberSpeller.spell(a)) năm \(VietnameseNumberSpeller.spell(g))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2})[/-](\\d{1,2})[/-](\\d{4})") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            let a = ns.substring(with: match.range(at: 3))
            if isValidDate(day: o, month: c, year: a) {
                return "ngày \(VietnameseNumberSpeller.spell(o)) tháng \(VietnameseNumberSpeller.spell(c)) năm \(VietnameseNumberSpeller.spell(a))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(?:tháng\\s+)?(\\d{1,2})\\s*[/-]\\s*(\\d{4})(?![\\/-]\\d)") { match, ns in
            let end = match.range.location + match.range.length
            if end < ns.length {
                let rest = ns.substring(from: end)
                if let firstChar = rest.first, firstChar.isLetter || firstChar.isNumber {
                    return nil
                }
            }
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            if isValidMonth(month: o), let y = Int(c), y >= 1000 && y <= 9999 {
                return "tháng \(VietnameseNumberSpeller.spell(o)) năm \(VietnameseNumberSpeller.spell(c))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2})\\s*[/-]\\s*(\\d{1,2})(?![\\/-]\\d)(?!\\d+\\s*%)") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            if isValidDate(day: o, month: c) {
                return "\(VietnameseNumberSpeller.spell(o)) tháng \(VietnameseNumberSpeller.spell(c))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d+)\\s*tháng\\s*(\\d+)") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            let c = ns.substring(with: match.range(at: 2))
            if isValidDate(day: o, month: c) {
                return "ngày \(VietnameseNumberSpeller.spell(o)) tháng \(VietnameseNumberSpeller.spell(c))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "tháng\\s*(\\d+)") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            if isValidMonth(month: o) {
                return "tháng \(VietnameseNumberSpeller.spell(o))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "ngày\\s*(\\d+)") { match, ns in
            let o = ns.substring(with: match.range(at: 1))
            if let d = Int(o), d >= 1 && d <= 31 {
                return "ngày \(VietnameseNumberSpeller.spell(o))"
            }
            return nil
        }
        
        return e
    }

    static func processTime(_ text: String) -> String {
        var e = text
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2}):(\\d{2})(?::(\\d{2}))?") { match, ns in
            let hr = ns.substring(with: match.range(at: 1))
            let min = ns.substring(with: match.range(at: 2))
            var replacement = "\(VietnameseNumberSpeller.spell(hr)) giờ"
            if match.range(at: 3).location != NSNotFound {
                let sec = ns.substring(with: match.range(at: 3))
                replacement += " \(VietnameseNumberSpeller.spell(min)) phút \(VietnameseNumberSpeller.spell(sec)) giây"
            } else {
                replacement += " \(VietnameseNumberSpeller.spell(min)) phút"
            }
            return replacement
        }
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2})h(\\d{2})(?![a-zà-ỹ])", options: [.caseInsensitive]) { match, ns in
            let hrStr = ns.substring(with: match.range(at: 1))
            let minStr = ns.substring(with: match.range(at: 2))
            if let hr = Int(hrStr), let min = Int(minStr), hr >= 0 && hr <= 23 && min >= 0 && min <= 59 {
                return "\(VietnameseNumberSpeller.spell(hrStr)) giờ \(VietnameseNumberSpeller.spell(minStr))"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d{1,2})h(?![a-zà-ỹ\\d])", options: [.caseInsensitive]) { match, ns in
            let hrStr = ns.substring(with: match.range(at: 1))
            if let hr = Int(hrStr), hr >= 0 && hr <= 23 {
                return "\(VietnameseNumberSpeller.spell(hrStr)) giờ"
            }
            return nil
        }
        
        e = replaceMatches(in: e, pattern: "(\\d+)\\s*giờ\\s*(\\d+)\\s*phút") { match, ns in
            let s = ns.substring(with: match.range(at: 1))
            let r = ns.substring(with: match.range(at: 2))
            return "\(VietnameseNumberSpeller.spell(s)) giờ \(VietnameseNumberSpeller.spell(r)) phút"
        }
        
        e = replaceMatches(in: e, pattern: "(\\d+)\\s*giờ(?!\\s*\\d)") { match, ns in
            let s = ns.substring(with: match.range(at: 1))
            return "\(VietnameseNumberSpeller.spell(s)) giờ"
        }
        
        return e
    }

    private static func romanToInt(_ roman: String) -> Int? {
        let a = roman.uppercased()
        let g: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000]
        for char in a {
            if g[char] == nil { return nil }
        }
        var i = 0
        var l = 0
        let chars = Array(a)
        while l < chars.count {
            guard let h = g[chars[l]] else { return nil }
            let m = l + 1 < chars.count ? (g[chars[l+1]] ?? 0) : 0
            if h < m {
                let allowed: [Character: [Character]] = ["I": ["V", "X"], "X": ["L", "C"], "C": ["D", "M"]]
                guard let list = allowed[chars[l]], list.contains(chars[l+1]) else { return nil }
                i += m - h
                l += 2
            } else {
                i += h
                l += 1
            }
        }
        return i
    }

    private static func isValidRoman(_ roman: String) -> Bool {
        let a = roman.uppercased()
        if a.isEmpty { return false }
        
        let romanCharsRegex = try! NSRegularExpression(pattern: "^[IVXLCDM]+$", options: [])
        if romanCharsRegex.firstMatch(in: a, options: [], range: NSRange(location: 0, length: a.utf16.count)) == nil {
            return false
        }
        
        let invalidRepeatRegex = try! NSRegularExpression(pattern: "([IVXLCD])\\\\1{3,}|VV|LL|DD", options: [])
        if invalidRepeatRegex.firstMatch(in: a, options: [], range: NSRange(location: 0, length: a.utf16.count)) != nil {
            return false
        }
        
        let g: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000]
        let chars = Array(a)
        for i in 0..<chars.count-1 {
            guard let m = g[chars[i]], let p = g[chars[i+1]] else { return false }
            if m < p {
                let allowed: [Character: [Character]] = ["I": ["V", "X"], "X": ["L", "C"], "C": ["D", "M"]]
                guard let list = allowed[chars[i]], list.contains(chars[i+1]) else { return false }
            }
        }
        
        guard let val = romanToInt(roman) else { return false }
        return val > 0
    }

    private static func processRomanNumerals(_ text: String, unlimited: Bool = false) -> String {
        return replaceMatches(in: text, pattern: "(^|[\\s\\W])([IVXLCDMivxlcdm]+)(?=[\\s\\W]|$)") { match, ns in
            let prefix = ns.substring(with: match.range(at: 1))
            let roman = ns.substring(with: match.range(at: 2))
            
            let wordCharRegex = try! NSRegularExpression(pattern: "[\\wà-ỹ]", options: [.caseInsensitive])
            if !prefix.isEmpty && wordCharRegex.firstMatch(in: prefix, options: [], range: NSRange(location: 0, length: prefix.utf16.count)) != nil {
                return nil
            }
            
            if roman != roman.uppercased() || !isValidRoman(roman) {
                return nil
            }
            
            guard let val = romanToInt(roman) else { return nil }
            if !unlimited && (val < 1 || val > 30) {
                return nil
            }
            
            return prefix + String(val)
        }
    }



    private static func processCurrency(_ text: String) -> String {
        var e = text
        
        let vndRegex = try! NSRegularExpression(pattern: "(\\d+(?:,\\d+)?)\\s*(?:đồng|VND|vnđ)\\b", options: [.caseInsensitive])
        while let match = vndRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let val = nsString.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let replacement = "\(VietnameseNumberSpeller.spell(val)) đồng"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        let dRegex = try! NSRegularExpression(pattern: "(\\d+(?:,\\d+)?)[đđ](?![a-zà-ỹ])", options: [.caseInsensitive])
        while let match = dRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let val = nsString.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let replacement = "\(VietnameseNumberSpeller.spell(val)) đồng"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        let dollarPrefixRegex = try! NSRegularExpression(pattern: "\\$\\s*(\\d+(?:,\\d+)?)", options: [])
        while let match = dollarPrefixRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let val = nsString.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let replacement = "\(VietnameseNumberSpeller.spell(val)) đô la"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        let dollarSuffixRegex = try! NSRegularExpression(pattern: "(\\d+(?:,\\d+)?)\\s*(?:USD|\\$)", options: [.caseInsensitive])
        while let match = dollarSuffixRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let val = nsString.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let replacement = "\(VietnameseNumberSpeller.spell(val)) đô la"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        return e
    }

    private static func processPercentages(_ text: String) -> String {
        var e = text
        
        let rangeRegex = try! NSRegularExpression(pattern: "(\\d+)\\s*[-–—]\\s*(\\d+)\\s*%", options: [])
        while let match = rangeRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let s = nsString.substring(with: match.range(at: 1))
            let r = nsString.substring(with: match.range(at: 2))
            let replacement = "\(VietnameseNumberSpeller.spell(s)) đến \(VietnameseNumberSpeller.spell(r)) phần trăm"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        let decimalRegex = try! NSRegularExpression(pattern: "(\\d+),(\\d+)\\s*%", options: [])
        while let match = decimalRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let s = nsString.substring(with: match.range(at: 1))
            let r = nsString.substring(with: match.range(at: 2))
            let cleanedR = r.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
            let replacement = "\(VietnameseNumberSpeller.spell(s)) phẩy \(VietnameseNumberSpeller.spell(cleanedR.isEmpty ? "0" : cleanedR)) phần trăm"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        let singleRegex = try! NSRegularExpression(pattern: "(\\d+)\\s*%", options: [])
        while let match = singleRegex.firstMatch(in: e, options: [], range: NSRange(location: 0, length: e.utf16.count)) {
            let nsString = e as NSString
            let s = nsString.substring(with: match.range(at: 1))
            let replacement = "\(VietnameseNumberSpeller.spell(s)) phần trăm"
            e = nsString.replacingCharacters(in: match.range, with: replacement)
        }
        
        return e
    }

    private static func processPhoneNumbers(_ text: String) -> String {
        let phoneReplacer: MatchReplacer = { match, ns in
            let s = ns.substring(with: match.range)
            let digits = s.compactMap { char -> String? in
                guard let digit = Int(String(char)) else { return nil }
                return VietnameseNumberSpeller.spell(String(digit))
            }
            return digits.joined(separator: " ")
        }
        var e = replaceMatches(in: text, pattern: "0\\d{9,10}", replacer: phoneReplacer)
        e = replaceMatches(in: e, pattern: "\\+84\\d{9,10}", replacer: phoneReplacer)
        return e
    }

    private static func processDecimals(_ text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "(\\d+),(\\d+)(?=\\s|$|[^\\d,])", options: [])
        var result = text
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches.reversed() {
            let s = nsString.substring(with: match.range(at: 1))
            let r = nsString.substring(with: match.range(at: 2))
            let leftSpelled = VietnameseNumberSpeller.spell(s)
            let cleanedR = r.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
            let rightSpelled = VietnameseNumberSpeller.spell(cleanedR.isEmpty ? "0" : cleanedR)
            let replacement = "\(leftSpelled) phẩy \(rightSpelled)"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    private static let unitExpansions: [String: String] = [
        "m": "mét", "cm": "xăng-ti-mét", "mm": "mi-li-mét", "km": "ki-lô-mét", "dm": "đề-xi-mét",
        "hm": "héc-tô-mét", "dam": "đề-ca-mét", "inch": "in", "kg": "ki-lô-gam", "g": "gam",
        "mg": "mi-li-gam", "t": "tấn", "tấn": "tấn", "yến": "yến", "lạng": "lạng", "ml": "mi-li-lít",
        "l": "lít", "lít": "lít", "m²": "mét vuông", "m2": "mét vuông", "km²": "ki-lô-mét vuông",
        "km2": "ki-lô-mét vuông", "ha": "héc-ta", "cm²": "xăng-ti-mét vuông", "cm2": "xăng-ti-mét vuông",
        "m³": "mét khối", "m3": "mét khối", "cm³": "xăng-ti-mét khối", "cm3": "xăng-ti-mét khối",
        "km³": "ki-lô-mét khối", "km3": "ki-lô-mét khối", "s": "giây", "sec": "giây", "min": "phút",
        "h": "giờ", "hr": "giờ", "hrs": "giờ", "km/h": "ki-lô-mét trên giờ", "kmh": "ki-lô-mét trên giờ",
        "m/s": "mét trên giây", "ms": "mét trên giây", "mm/h": "mi-li-mét trên giờ", "cm/s": "xăng-ti-mét trên giây",
        "°C": "độ C", "°F": "độ F", "°K": "độ K", "°R": "độ R", "°Re": "độ Re", "°Ro": "độ Ro",
        "°N": "độ N", "°D": "độ D"
    ]

    private static func processUnits(_ text: String) -> String {
        var e = text
        let sortedUnits = unitExpansions.keys.sorted { $0.count > $1.count }
        
        for unit in sortedUnits {
            guard let expansion = unitExpansions[unit] else { continue }
            let escapedUnit = NSRegularExpression.escapedPattern(for: unit)
            
            let pattern1: String
            let pattern2: String
            
            let numberSpelledPattern = "(?:\\b(?:một|hai|ba|bốn|năm|sáu|bảy|tám|chín|mười|không|trăm|nghìn|triệu|tỷ|lẻ|mốt|tư|lăm|phẩy)\\b\\s*)+"
            
            if unit.count == 1 {
                pattern1 = "(\\d+)\\s*\(escapedUnit)(?!\\s*[a-zA-Zà-ỹ])(?=\\s*[^a-zA-Zà-ỹ]|$)"
                pattern2 = "(\(numberSpelledPattern))\\s*\\b\(escapedUnit)\\b(?!\\s*[a-zA-Zà-ỹ])(?=\\s*[^a-zA-Zà-ỹ]|$)"
            } else {
                pattern1 = "(\\d+)\\s*\(escapedUnit)(?=\\s|[^\\w]|$)"
                pattern2 = "(\(numberSpelledPattern))\\s*\\b\(escapedUnit)\\b(?=\\s|[^\\w]|$)"
            }
            
            e = replaceMatches(in: e, pattern: pattern1, options: [.caseInsensitive]) { match, ns in
                let val = ns.substring(with: match.range(at: 1))
                return val + " " + expansion
            }
            
            e = replaceMatches(in: e, pattern: pattern2, options: [.caseInsensitive]) { match, ns in
                let start = match.range.location
                let length = match.range.length
                
                let prevIndex = start - 1
                let nextIndex = start + length
                
                let wordCharRegex = try! NSRegularExpression(pattern: "[a-zA-Zà-ỹ]", options: [])
                
                if prevIndex >= 0 {
                    let prevChar = ns.substring(with: NSRange(location: prevIndex, length: 1))
                    if wordCharRegex.firstMatch(in: prevChar, options: [], range: NSRange(location: 0, length: 1)) != nil {
                        return nil
                    }
                }
                if nextIndex < ns.length {
                    let nextChar = ns.substring(with: NSRange(location: nextIndex, length: 1))
                    if wordCharRegex.firstMatch(in: nextChar, options: [], range: NSRange(location: 0, length: 1)) != nil {
                        return nil
                    }
                }
                
                let spelled = ns.substring(with: match.range(at: 1))
                return spelled.trimmingCharacters(in: .whitespacesAndNewlines) + " " + expansion
            }
        }
        return e
    }

    private static func processDigits(_ text: String) -> String {
        return replaceMatches(in: text, pattern: "\\b\\d+\\b") { match, ns in
            let n = ns.substring(with: match.range)
            return VietnameseNumberSpeller.spell(n)
        }
    }
    
    private static func processVietnameseText(_ text: String, unlimitedRoman: Bool = false) -> String {
        appLog("📝 [Vietnamese Normalizer] Starting preprocess for text: '\(text)'")
        var e = text
        
        appLog("   - Running precomposedStringWithCanonicalMapping")
        e = text.precomposedStringWithCanonicalMapping
        
        appLog("   - Running cleanText")
        e = cleanText(e)
        
        appLog("   - Running normalizeQuotesAndDashes")
        e = normalizeQuotesAndDashes(e)
        
        appLog("   - Running formatNumbers")
        e = formatNumbers(e)
        
        appLog("   - Running processUnitsRangeAndRatio")
        e = processUnitsRangeAndRatio(e)
        
        appLog("   - Running processYearRanges")
        e = processYearRanges(e)
        
        appLog("   - Running processDates")
        e = processDates(e)
        
        appLog("   - Running processTime")
        e = processTime(e)
        
        appLog("   - Running processRomanNumerals")
        e = processRomanNumerals(e, unlimited: unlimitedRoman)
        

        
        appLog("   - Running processCurrency")
        e = processCurrency(e)
        
        appLog("   - Running processPercentages")
        e = processPercentages(e)
        
        appLog("   - Running processPhoneNumbers")
        e = processPhoneNumbers(e)
        
        appLog("   - Running processDecimals")
        e = processDecimals(e)
        
        appLog("   - Running processUnits")
        e = processUnits(e)
        
        appLog("   - Running processDigits")
        e = processDigits(e)
        
        appLog("   - Trimming and cleaning white spaces")
        e = e.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        e = e.trimmingCharacters(in: .whitespacesAndNewlines)
        
        appLog("📝 [Vietnamese Normalizer] Finished. Output: '\(e)'")
        return e
    }

    enum DictionaryType {
        case acronym
        case word
    }

    private func replaceDictionaryWords(in text: String, type: DictionaryType) -> String {
        let typeStr = type == .acronym ? "acronym" : "word"
        appLog("📖 [ReplaceDictionary] Type: \(typeStr), Input: '\(text)'")
        // Tìm toàn bộ các token là từ (word tokens) trong văn bản
        let wordPattern = "[a-zA-Z0-9_\u{00C0}-\u{1EFF}]+"
        guard let regex = try? NSRegularExpression(pattern: wordPattern, options: []) else { return text }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else {
            appLog("📖 [ReplaceDictionary] Type: \(typeStr), No word matches found.")
            return text
        }
        
        struct WordToken {
            let text: String
            let range: NSRange
        }
        
        let words = matches.map { WordToken(text: nsString.substring(with: $0.range).lowercased(), range: $0.range) }
        
        var result = ""
        var lastCopiedIndex = 0
        var i = 0
        
        while i < words.count {
            var matchedLength = 0
            var replacement: String? = nil
            var matchStartLoc = 0
            var matchEndLoc = 0
            
            // Tìm kiếm tham lam (greedy matching): thử khớp cụm từ tối đa 4 từ giảm dần về 1 từ
            for lookAhead in (1...4).reversed() {
                guard i + lookAhead <= words.count else { continue }
                
                let startLoc = words[i].range.location
                let lastWord = words[i + lookAhead - 1]
                let endLoc = lastWord.range.location + lastWord.range.length
                
                // Lấy cụm từ gốc từ văn bản ban đầu và chuẩn hóa khoảng trắng để đối chiếu
                let rawPhrase = nsString.substring(with: NSRange(location: startLoc, length: endLoc - startLoc)).lowercased()
                let phrase = rawPhrase.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                      .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Tra cứu trực tiếp từ bộ nhớ của actor
                let matchedValue = (type == .acronym) ? acronymMap[phrase] : wordMap[phrase]
                    
                if let match = matchedValue {
                    matchedLength = lookAhead
                    replacement = match
                    matchStartLoc = startLoc
                    matchEndLoc = endLoc
                    break
                }
            }
            
            if let match = replacement, matchedLength > 0 {
                // Sao chép đoạn văn bản không thay đổi từ lastCopiedIndex đến matchStartLoc
                if matchStartLoc > lastCopiedIndex {
                    result += nsString.substring(with: NSRange(location: lastCopiedIndex, length: matchStartLoc - lastCopiedIndex))
                }
                
                let replacementText = (type == .word) ? "\u{FEFF}\(match)\u{FEFF}" : match
                result += replacementText
                
                appLog("   - Replaced phrase '\(nsString.substring(with: NSRange(location: matchStartLoc, length: matchEndLoc - matchStartLoc)))' with '\(replacementText)'")
                
                lastCopiedIndex = matchEndLoc
                i += matchedLength
            } else {
                i += 1
            }
        }
        
        // Sao chép đoạn văn bản còn lại từ lastCopiedIndex đến cuối
        if lastCopiedIndex < nsString.length {
            result += nsString.substring(with: NSRange(location: lastCopiedIndex, length: nsString.length - lastCopiedIndex))
        }
        
        appLog("📖 [ReplaceDictionary] Type: \(typeStr), Output: '\(result)'")
        return result
    }

    private static let tokenRegex = try! NSRegularExpression(
        pattern: "[a-zA-Z0-9_\u{00C0}-\u{1EFF}]+(?:[-.][a-zA-Z0-9_\u{00C0}-\u{1EFF}]+)*",
        options: []
    )

    // MARK: - Main Preprocess Pipeline
    func preprocess(_ text: String) -> String {
        appLog("🚀 [Preprocess] Start preprocessing for: '\(text)'")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appLog("🚀 [Preprocess] Text is empty, returning empty string.")
            return ""
        }
        
        // 0. Chuyển đổi Hiragana/Katakana tiếng Nhật sang Romaji
        appLog("🚀 [Preprocess] Step 0a: Converting Japanese characters (Romaji)...")
        let romajiText = JapaneseTransliterator.convertToRomaji(text)
        
        appLog("🚀 [Preprocess] Step 0b: Running Vietnamese text processor...")
        let processedVi = Self.processVietnameseText(romajiText)
        
        appLog("🚀 [Preprocess] Step 0c: Cleaning emojis and symbols...")
        let cleaned = Self.cleanEmojisAndSymbols(processedVi)
        
        let lowercased = cleaned.lowercased()
        
        // 1. Thay thế từ viết tắt (Acronyms) luôn luôn chạy
        appLog("🚀 [Preprocess] Step 1: Replacing acronyms...")
        var replacedText = replaceDictionaryWords(in: lowercased, type: .acronym)
        
        // 2. Tiến hành khớp từ điển tiếng Anh và chạy bộ quy tắc
        appLog("🚀 [Preprocess] Step 2: Translating English words...")
        replacedText = replaceDictionaryWords(in: replacedText, type: .word)
        
        let nsString = replacedText as NSString
        let matches = Self.tokenRegex.matches(in: replacedText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var result = ""
        var lastOffset = 0
        
        appLog("🚀 [Preprocess] Step 2b: Processing individual non-Vietnamese tokens...")
        for match in matches {
            if match.range.location > lastOffset {
                let gapRange = NSRange(location: lastOffset, length: match.range.location - lastOffset)
                result += nsString.substring(with: gapRange)
            }
            
            let token = nsString.substring(with: match.range)
            
            // Kiểm tra xem token này có phải đã được xử lý bởi từ điển (Sentinel check) hay không
            var isTranslatedByDict = false
            if match.range.location > 0 {
                let prevCharRange = NSRange(location: match.range.location - 1, length: 1)
                if nsString.substring(with: prevCharRange) == "\u{FEFF}" {
                    isTranslatedByDict = true
                }
            }
            
            let processedToken: String
            if isTranslatedByDict {
                processedToken = token
            } else if token.count > 1 && token != "mc" && !VietnameseWordChecker.isVietnameseWord(token) {
                // Check cache first
                if let cached = transliterationCache[token] {
                    processedToken = cached
                } else {
                    // Tự động chuẩn hóa dấu phụ (ví dụ: ryū -> ryu, arigatō -> arigato)
                    let folded = token.folding(options: .diacriticInsensitive, locale: nil)
                    
                    let transliterated: String
                    if let dictMatch = lookupWord(folded) {
                        transliterated = dictMatch
                    } else if JapaneseTransliterator.isJapaneseRomaji(folded) {
                        transliterated = JapaneseTransliterator.transliterateRomaji(folded)
                    } else {
                        if folded.contains("-") || folded.contains(".") {
                            var partsResult = ""
                            var currentPart = ""
                            for char in folded {
                                if char == "-" || char == "." {
                                    if !currentPart.isEmpty {
                                        if !VietnameseWordChecker.isVietnameseWord(currentPart) {
                                            if JapaneseTransliterator.isJapaneseRomaji(currentPart) {
                                                partsResult += JapaneseTransliterator.transliterateRomaji(currentPart)
                                            } else {
                                                partsResult += EnglishTransliterator.transliterateWord(currentPart)
                                            }
                                        } else {
                                            partsResult += currentPart
                                        }
                                        currentPart = ""
                                    }
                                    partsResult.append(char)
                                } else {
                                    currentPart.append(char)
                                }
                            }
                            if !currentPart.isEmpty {
                                if !VietnameseWordChecker.isVietnameseWord(currentPart) {
                                    if JapaneseTransliterator.isJapaneseRomaji(currentPart) {
                                        partsResult += JapaneseTransliterator.transliterateRomaji(currentPart)
                                    } else {
                                        partsResult += EnglishTransliterator.transliterateWord(currentPart)
                                    }
                                } else {
                                    partsResult += currentPart
                                }
                            }
                            transliterated = partsResult
                        } else {
                            transliterated = EnglishTransliterator.transliterateWord(folded)
                        }
                    }
                    // Cache the result
                    transliterationCache[token] = transliterated
                    processedToken = transliterated
                }
            } else {
                processedToken = token
            }
            
            result += processedToken
            lastOffset = match.range.location + match.range.length
        }
        
        if lastOffset < nsString.length {
            let gapRange = NSRange(location: lastOffset, length: nsString.length - lastOffset)
            result += nsString.substring(with: gapRange)
        }
        
        // Loại bỏ sentinel trước khi trả về kết quả
        let cleanedResult = result.replacingOccurrences(of: "\u{FEFF}", with: "")
        appLog("🚀 [Preprocess] Finish preprocessing. Output: '\(cleanedResult)'")
        return cleanedResult
    }
}
