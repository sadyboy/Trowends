import SwiftUI
import CoreGraphics
import Combine
import SpriteKit
import Charts
import CoreData
import PhotosUI
import AudioToolbox
import UserNotifications

@main
struct AntiGroundsApp: App {

    @StateObject private var state = GameState.shared
    @State private var showSplash = true
    @State private var selectedTab = 0

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                } else if !state.onboardingDone {
                    OnboardingView(state: state)
                        .transition(.opacity)
                } else {
                    mainContent
                }

                if state.showLevelUp {
                    LevelUpOverlay(state: state)
                }

                if state.showDailyReward {
                    DailyRewardOverlay(state: state)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .animation(.easeInOut(duration: 0.5), value: state.onboardingDone)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showSplash = false
                }
                state.updateStreak()
                state.checkDailyReward()
                state.checkBossWeek()
                checkStreakAchievements()
                requestNotificationPermission()
            }
        }
    }

    var mainContent: some View {
        ZStack(alignment: .bottom) {
            AnimatedCosmicBackground()

            Group {
                switch selectedTab {
                case 0: DashboardView(state: state, selectedTab: $selectedTab)
                case 1: LessonsAtlasView(state: state)
                case 2: QuizGameView(state: state)
                case 3: StatsView(state: state)
                case 4: ProfileView(state: state)
                default: DashboardView(state: state, selectedTab: $selectedTab)
                }
            }

            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 16)
        }
    }

    func checkStreakAchievements() {
        if state.streakDays >= 7 { state.unlockAchievement("streak_7") }
        if state.streakDays >= 30 { state.unlockAchievement("streak_30") }
        if state.streakDays >= 100 { state.unlockAchievement("streak_100") }
        if state.streakWeeks >= 1 { state.unlockAchievement("week_1") }
        if state.streakWeeks >= 2 { state.unlockAchievement("week_2") }
        if state.streakWeeks >= 3 { state.unlockAchievement("week_3") }
        if state.streakWeeks >= 4 { state.unlockAchievement("week_4") }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
// Competitors: 1) Star Walk 2 — blue/purple sky realism, list-based. 2) SkyView — dark + AR overlay, minimal gamification.
// 3) NASA App — white/red official branding, news feed layout. Differentiator: vinyl/cassette analog warmth aesthetic,
// brutalist neon-glass UI, full gamification engine with mascot, SpriteKit mini-game, no competitor has this combo.


// MARK: - Core Data Stack

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init() {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "LearningSession"
        entity.managedObjectClassName = NSStringFromClass(LearningSessionEntity.self)

        let tsAttr = NSAttributeDescription()
        tsAttr.name = "timestamp"
        tsAttr.attributeType = .dateAttributeType
        tsAttr.isOptional = false

        let modeAttr = NSAttributeDescription()
        modeAttr.name = "mode"
        modeAttr.attributeType = .stringAttributeType
        modeAttr.isOptional = false

        let correctAttr = NSAttributeDescription()
        correctAttr.name = "correctAnswers"
        correctAttr.attributeType = .integer16AttributeType
        correctAttr.isOptional = false

        let totalAttr = NSAttributeDescription()
        totalAttr.name = "totalAnswers"
        totalAttr.attributeType = .integer16AttributeType
        totalAttr.isOptional = false

        let xpAttr = NSAttributeDescription()
        xpAttr.name = "xpGained"
        xpAttr.attributeType = .integer32AttributeType
        xpAttr.isOptional = false

        let timeAttr = NSAttributeDescription()
        timeAttr.name = "timeSpent"
        timeAttr.attributeType = .floatAttributeType
        timeAttr.isOptional = false

        entity.properties = [tsAttr, modeAttr, correctAttr, totalAttr, xpAttr, timeAttr]
        model.entities = [entity]

        container = NSPersistentContainer(name: "StarterGhoste", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData error: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        let ctx = container.viewContext
        if ctx.hasChanges { try? ctx.save() }
    }

    func addSession(mode: String, correct: Int, total: Int, xp: Int, time: Float) {
        let ctx = container.viewContext
        let s = LearningSessionEntity(context: ctx)
        s.timestamp = Date()
        s.mode = mode
        s.correctAnswers = Int16(correct)
        s.totalAnswers = Int16(total)
        s.xpGained = Int32(xp)
        s.timeSpent = time
        save()
    }

    func fetchSessions() -> [LearningSessionEntity] {
        let req = NSFetchRequest<LearningSessionEntity>(entityName: "LearningSession")
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return (try? container.viewContext.fetch(req)) ?? []
    }

    func deleteSession(_ s: LearningSessionEntity) {
        container.viewContext.delete(s)
        save()
    }
}

@objc(LearningSessionEntity)
class LearningSessionEntity: NSManagedObject {
    @NSManaged var timestamp: Date
    @NSManaged var mode: String
    @NSManaged var correctAnswers: Int16
    @NSManaged var totalAnswers: Int16
    @NSManaged var xpGained: Int32
    @NSManaged var timeSpent: Float
}

// MARK: - Theme

struct AppTheme {
    static let deepBg = Color(red: 0.04, green: 0.02, blue: 0.12)
    static let neonCyan = Color(red: 0.0, green: 0.9, blue: 0.9)
    static let electricPurple = Color(red: 0.55, green: 0.2, blue: 1.0)
    static let hotPink = Color(red: 1.0, green: 0.18, blue: 0.55)
    static let mintGreen = Color(red: 0.2, green: 1.0, blue: 0.6)
    static let starYellow = Color(red: 1.0, green: 0.85, blue: 0.2)
    static let warmOrange = Color(red: 1.0, green: 0.55, blue: 0.15)
    static let vinylBrown = Color(red: 0.35, green: 0.22, blue: 0.12)
    static let tapeBeige = Color(red: 0.85, green: 0.78, blue: 0.65)
    static let analogWarm = Color(red: 0.95, green: 0.6, blue: 0.3)

    static let accentGradient = LinearGradient(
        colors: [neonCyan, electricPurple],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let warmGradient = LinearGradient(
        colors: [warmOrange, hotPink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let pinkGradient = LinearGradient(
        colors: [hotPink, electricPurple],
        startPoint: .leading, endPoint: .trailing
    )
    static let vinylGradient = LinearGradient(
        colors: [vinylBrown, Color(red: 0.18, green: 0.1, blue: 0.06)],
        startPoint: .top, endPoint: .bottom
    )
    static let cassetteGradient = LinearGradient(
        colors: [tapeBeige.opacity(0.3), analogWarm.opacity(0.15)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Haptics

struct Haptics {
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func levelUp() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { g.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { g.impactOccurred() }
    }
}

// MARK: - Content Banks

struct LessonContent: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let difficulty: String
    let xpReward: Int
    let body: String
}

struct QuizQuestion: Identifiable {
    let id: Int
    let text: String
    let type: String
    let options: [String]
    let correctIndex: Int
    let difficulty: String
    let xpReward: Int
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let desc: String
    let icon: String
    let category: String
    let isRare: Bool
}

let contentBank: [LessonContent] = [
    LessonContent(id: 0, title: "Our Solar System", icon: "sun.max.fill", difficulty: "Beginner", xpReward: 40,
        body: "Our Solar System formed about 4.6 billion years ago from a giant cloud of gas and dust called a solar nebula. At its center sits the Sun, a G-type main-sequence star containing 99.86% of the system's mass. Eight planets orbit the Sun: four rocky inner planets (Mercury, Venus, Earth, Mars) and four gas/ice giants (Jupiter, Saturn, Uranus, Neptune). Between Mars and Jupiter lies the asteroid belt, home to millions of rocky remnants. Beyond Neptune, the Kuiper Belt stretches out with icy bodies including dwarf planet Pluto. The Oort Cloud, a theoretical shell of icy objects, marks the outermost boundary, extending nearly a light-year from the Sun. Each planet has unique characteristics — from Mercury's extreme temperature swings of over 600°C to Jupiter's Great Red Spot, a storm raging for centuries."),
    LessonContent(id: 1, title: "The Life of Stars", icon: "star.fill", difficulty: "Beginner", xpReward: 40,
        body: "Stars are born in vast molecular clouds called stellar nurseries, where gravity causes pockets of gas to collapse and heat up. When the core reaches about 10 million Kelvin, hydrogen fusion ignites and a protostar becomes a true star. Main-sequence stars like our Sun fuse hydrogen into helium for billions of years. A star's mass determines its fate: low-mass stars (under 8 solar masses) expand into red giants, shed their outer layers as planetary nebulae, and leave behind white dwarfs. Massive stars burn through fuel rapidly, swelling into supergiants before exploding as supernovae. These cataclysmic events forge elements heavier than iron and scatter them across space. The remnants become neutron stars — incredibly dense objects where a teaspoon weighs billions of tons — or black holes if the core exceeds about 3 solar masses."),
    LessonContent(id: 2, title: "Galaxy Types", icon: "sparkles", difficulty: "Beginner", xpReward: 40,
        body: "Galaxies are gravitationally bound systems of stars, gas, dust, and dark matter. Edwin Hubble classified them into three main types. Spiral galaxies like our Milky Way feature rotating disks with curved arms rich in young blue stars and active star-forming regions, surrounding a central bulge of older yellow stars. Elliptical galaxies range from nearly spherical to elongated shapes, contain mostly older red stars, and have little gas for new star formation. Irregular galaxies lack distinct shape — often the result of gravitational interactions. The Milky Way spans about 100,000 light-years and contains 200-400 billion stars. Our nearest large neighbor, the Andromeda Galaxy (M31), is approaching at 110 km/s and will merge with the Milky Way in about 4.5 billion years, forming an elliptical galaxy astronomers have nicknamed \"Milkomeda.\""),
    LessonContent(id: 3, title: "Black Holes Explained", icon: "circle.fill", difficulty: "Beginner", xpReward: 40,
        body: "Black holes are regions of spacetime where gravity is so extreme that nothing — not even light — can escape once past the event horizon. They form when massive stars (25+ solar masses) exhaust their nuclear fuel and their cores collapse. Stellar black holes typically have 5-50 solar masses. Supermassive black holes, found at galaxy centers, contain millions to billions of solar masses — Sagittarius A* at the Milky Way's center has about 4 million solar masses. The event horizon isn't a physical surface but an invisible boundary. At the singularity, density is theoretically infinite. Near a black hole, time dilates dramatically due to general relativity — clocks tick slower in stronger gravitational fields. Hawking radiation, proposed by Stephen Hawking in 1974, suggests black holes slowly evaporate by emitting quantum particles, though this process takes longer than the current age of the universe for stellar-mass black holes."),
    LessonContent(id: 4, title: "Exoplanet Discovery", icon: "globe.americas.fill", difficulty: "Intermediate", xpReward: 50,
        body: "Exoplanets are worlds orbiting stars beyond our Sun. The first confirmed exoplanet around a Sun-like star, 51 Pegasi b, was discovered in 1995. NASA's Kepler Space Telescope revolutionized the field by finding over 2,600 confirmed exoplanets using the transit method — detecting tiny dips in starlight as planets cross their host stars. The radial velocity method detects stellar wobbles caused by orbiting planets' gravitational pull. Hot Jupiters are gas giants orbiting extremely close to their stars with surface temperatures exceeding 1000°C. Super-Earths are rocky planets 1-10 times Earth's mass. The habitable zone — the \"Goldilocks region\" — is the orbital distance where liquid water could exist. TRAPPIST-1, a red dwarf 40 light-years away, hosts seven Earth-sized planets, three in the habitable zone. The James Webb Space Telescope now analyzes exoplanet atmospheres for biosignatures like oxygen, methane, and water vapor."),
    LessonContent(id: 5, title: "The Big Bang Theory", icon: "bolt.fill", difficulty: "Intermediate", xpReward: 50,
        body: "The Big Bang theory describes the universe's origin approximately 13.8 billion years ago from an incredibly hot, dense state. In the first fraction of a second, the universe underwent inflation — expanding faster than light. Within three minutes, protons and neutrons formed hydrogen and helium nuclei (Big Bang nucleosynthesis). For 380,000 years, the universe was an opaque plasma until it cooled enough for electrons to combine with nuclei, releasing the Cosmic Microwave Background (CMB) — the oldest light we can observe. First discovered accidentally by Penzias and Wilson in 1965, the CMB has a temperature of 2.725 Kelvin with tiny fluctuations that seeded galaxy formation. Dark matter (27% of the universe) provides gravitational scaffolding for galaxies, while dark energy (68%) drives accelerating expansion discovered in 1998 through Type Ia supernovae observations. Only 5% of the universe is ordinary matter."),
    LessonContent(id: 6, title: "Space Telescopes", icon: "camera.fill", difficulty: "Intermediate", xpReward: 50,
        body: "Space telescopes observe the cosmos without atmospheric interference that blurs and absorbs light. The Hubble Space Telescope, launched in 1990, orbits at 547 km altitude and has captured iconic images like the Pillars of Creation in the Eagle Nebula. After a corrective optics mission in 1993, Hubble revealed the universe's expansion rate, deep field images showing thousands of galaxies, and evidence for supermassive black holes. The James Webb Space Telescope (JWST), launched December 2021, is the most powerful space telescope ever built. Its 6.5-meter gold-coated beryllium mirror (vs Hubble's 2.4m) observes in infrared, seeing through dust clouds and detecting light from the first galaxies formed 200 million years after the Big Bang. JWST orbits the L2 Lagrange point, 1.5 million km from Earth, protected by a tennis-court-sized sunshield. The Chandra X-ray Observatory studies high-energy phenomena like black holes and supernova remnants."),
    LessonContent(id: 7, title: "Rocket Science 101", icon: "flame.fill", difficulty: "Intermediate", xpReward: 50,
        body: "Rockets work on Newton's Third Law: exhaust gases expelled downward push the rocket upward. Chemical rockets burn fuel (like liquid hydrogen) with an oxidizer (liquid oxygen) in combustion chambers reaching 3,300°C. Specific impulse (Isp) measures engine efficiency in seconds. The Tsiolkovsky rocket equation relates velocity change to exhaust velocity and mass ratio. Multi-stage rockets shed empty tanks to reduce weight — Saturn V had three stages to reach the Moon. SpaceX revolutionized spaceflight with reusable Falcon 9 first stages that land vertically, reducing launch costs from ~$54,500/kg to ~$2,720/kg. Starship, the largest rocket ever built at 121 meters, aims for Mars missions with full reusability. Ion engines produce tiny thrust but extraordinary efficiency (Isp 3000+ seconds) for deep space missions. Nuclear thermal propulsion could halve Mars transit time. The escape velocity from Earth is 11.2 km/s — about 40,000 km/h."),
    LessonContent(id: 8, title: "Mars Exploration", icon: "mountain.2.fill", difficulty: "Expert", xpReward: 60,
        body: "Mars, the fourth planet, has fascinated humanity for centuries. Its rusty red color comes from iron oxide (rust) in its soil. With a thin CO₂ atmosphere (1% of Earth's pressure), surface temperatures average -60°C. Olympus Mons, the solar system's tallest volcano at 21.9 km, dwarfs Mount Everest. Valles Marineris, a canyon system 4,000 km long, could stretch across the continental United States. NASA's Perseverance rover, landing in Jezero Crater in 2021, searches for ancient microbial life in a dried-up river delta. Its companion, the Ingenuity helicopter, achieved the first powered flight on another planet. The Mars Sample Return mission plans to bring Perseverance's cached samples to Earth by the 2030s. SpaceX envisions human settlements using Starship, with plans for in-situ resource utilization — manufacturing oxygen and fuel from Martian CO₂ and water ice. A one-way trip takes 6-9 months depending on orbital alignment."),
    LessonContent(id: 9, title: "Dark Matter & Energy", icon: "eye.slash.fill", difficulty: "Expert", xpReward: 60,
        body: "Dark matter and dark energy are the universe's greatest mysteries, comprising 95% of all existence yet remaining invisible. Dark matter was first proposed by Fritz Zwicky in 1933 when galaxy cluster velocities exceeded predictions. Vera Rubin's galaxy rotation curves in the 1970s provided compelling evidence — outer stars orbit too fast without unseen mass. Dark matter candidates include WIMPs (Weakly Interacting Massive Particles), axions, and sterile neutrinos. Experiments like XENON1T and LUX-ZEPLIN search for direct detection. Gravitational lensing — light bending around massive objects — maps dark matter distribution. Dark energy, discovered in 1998 through distant supernovae, drives the universe's accelerating expansion. The cosmological constant (Λ) in Einstein's equations represents this energy density. The DESI (Dark Energy Spectroscopic Instrument) maps millions of galaxies to measure expansion history. If dark energy strengthens, a \"Big Rip\" could tear apart all matter in ~22 billion years."),
    LessonContent(id: 10, title: "Neutron Stars & Pulsars", icon: "waveform.path.ecg", difficulty: "Expert", xpReward: 60,
        body: "When massive stars (8-25 solar masses) explode as supernovae, their cores collapse into neutron stars — objects so dense that a sugar-cube-sized piece weighs about a billion tons. With diameters of only 20 km but 1.4-2.1 solar masses, neutron star matter is compressed beyond atomic structure — protons and electrons merge into neutrons. The surface gravity is 2 × 10¹¹ times Earth's. Pulsars are rapidly rotating neutron stars emitting beams of radiation from their magnetic poles. As they spin, these beams sweep like lighthouse beacons, appearing as regular pulses. The fastest known pulsar (PSR J1748-2446ad) spins 716 times per second. Magnetars are neutron stars with magnetic fields 10¹⁵ times Earth's — the strongest magnets in the universe. Their field rearrangements trigger starquakes and gamma-ray bursts detectable across galaxies. In 2017, LIGO detected gravitational waves from merging neutron stars (GW170817), confirming they produce heavy elements like gold and platinum through r-process nucleosynthesis."),
    LessonContent(id: 11, title: "The Multiverse Theory", icon: "infinity", difficulty: "Expert", xpReward: 60,
        body: "The multiverse hypothesis suggests our universe may be one of countless parallel universes. Several frameworks propose this: Eternal inflation theory posits that quantum fluctuations during cosmic inflation spawn separate \"bubble universes\" with potentially different physical constants. String theory's landscape offers 10⁵⁰⁰ possible vacuum states, each corresponding to a universe with unique properties. Hugh Everett's Many-Worlds Interpretation of quantum mechanics suggests every quantum measurement splits reality into branches where all possible outcomes occur. The fine-tuning problem motivates multiverse thinking — why are physical constants perfectly tuned for life? In a multiverse, our universe's constants aren't special, just anthropically selected. Critics argue the multiverse is unfalsifiable and thus unscientific. However, some predictions are testable: eternal inflation predicts specific CMB patterns, and string theory landscapes might leave signatures in cosmic structure. The concept challenges our understanding of probability, identity, and the nature of existence itself.")
]

let quizBank: [QuizQuestion] = [
    QuizQuestion(id: 0, text: "How old is our Solar System approximately?", type: "mc", options: ["2.5 billion years", "4.6 billion years", "6.8 billion years", "10 billion years"], correctIndex: 1, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 1, text: "What percentage of the Solar System's mass does the Sun contain?", type: "mc", options: ["85%", "92%", "99.86%", "75%"], correctIndex: 2, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 2, text: "The Milky Way is a spiral galaxy.", type: "tf", options: ["True", "False"], correctIndex: 0, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 3, text: "What happens to a low-mass star at the end of its life?", type: "mc", options: ["Becomes a black hole", "Becomes a white dwarf", "Becomes a neutron star", "Explodes as a hypernova"], correctIndex: 1, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 4, text: "Light can escape from a black hole.", type: "tf", options: ["True", "False"], correctIndex: 1, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 5, text: "Which planet has the tallest volcano in the Solar System?", type: "mc", options: ["Earth", "Venus", "Mars", "Jupiter"], correctIndex: 2, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 6, text: "What is the name of the boundary around a black hole beyond which nothing can escape?", type: "mc", options: ["Singularity", "Event Horizon", "Photon Sphere", "Accretion Disk"], correctIndex: 1, difficulty: "Beginner", xpReward: 8),
    QuizQuestion(id: 7, text: "What method did the Kepler telescope primarily use to find exoplanets?", type: "mc", options: ["Direct imaging", "Transit method", "Gravitational lensing", "Astrometry"], correctIndex: 1, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 8, text: "The CMB radiation has a temperature of approximately 2.725 Kelvin.", type: "tf", options: ["True", "False"], correctIndex: 0, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 9, text: "How far from Earth does JWST orbit at the L2 point?", type: "mc", options: ["547 km", "384,400 km", "1.5 million km", "150 million km"], correctIndex: 2, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 10, text: "What is the escape velocity from Earth's surface?", type: "mc", options: ["7.9 km/s", "11.2 km/s", "16.7 km/s", "3.2 km/s"], correctIndex: 1, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 11, text: "Who first proposed the existence of dark matter in 1933?", type: "mc", options: ["Albert Einstein", "Fritz Zwicky", "Edwin Hubble", "Vera Rubin"], correctIndex: 1, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 12, text: "SpaceX's Falcon 9 first stages are reusable.", type: "tf", options: ["True", "False"], correctIndex: 0, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 13, text: "What percentage of the universe is ordinary (baryonic) matter?", type: "mc", options: ["5%", "27%", "68%", "15%"], correctIndex: 0, difficulty: "Intermediate", xpReward: 10),
    QuizQuestion(id: 14, text: "How fast does the fastest known pulsar spin per second?", type: "mc", options: ["30 times", "142 times", "716 times", "1200 times"], correctIndex: 2, difficulty: "Expert", xpReward: 12),
    QuizQuestion(id: 15, text: "What is the approximate diameter of a typical neutron star?", type: "mc", options: ["200 km", "20 km", "2,000 km", "2 km"], correctIndex: 1, difficulty: "Expert", xpReward: 12),
    QuizQuestion(id: 16, text: "Gravitational waves from merging neutron stars were first detected in the year ____.", type: "fill", options: ["2017"], correctIndex: 0, difficulty: "Expert", xpReward: 12),
    QuizQuestion(id: 17, text: "The string theory landscape offers approximately 10 to the power of ____ possible vacuum states.", type: "fill", options: ["500"], correctIndex: 0, difficulty: "Expert", xpReward: 12),
    QuizQuestion(id: 18, text: "What event designation was given to the first neutron star merger gravitational wave detection?", type: "mc", options: ["GW150914", "GW170817", "GW190521", "GW151226"], correctIndex: 1, difficulty: "Expert", xpReward: 12),
    QuizQuestion(id: 19, text: "The TRAPPIST-1 system is approximately ____ light-years away.", type: "fill", options: ["40"], correctIndex: 0, difficulty: "Expert", xpReward: 12)
]

let achievementCatalog: [Achievement] = [
    Achievement(id: "first_lesson", title: "First Step", desc: "Complete your first lesson", icon: "book.fill", category: "Learning", isRare: false),
    Achievement(id: "five_lessons", title: "Bookworm", desc: "Complete 5 lessons", icon: "books.vertical.fill", category: "Learning", isRare: false),
    Achievement(id: "all_lessons", title: "Scholar", desc: "Complete all 12 lessons", icon: "graduationcap.fill", category: "Learning", isRare: false),
    Achievement(id: "first_quiz", title: "Quiz Novice", desc: "Complete your first quiz", icon: "questionmark.circle.fill", category: "Quiz", isRare: false),
    Achievement(id: "perfect_quiz", title: "Perfection", desc: "Score 100% on a quiz", icon: "star.circle.fill", category: "Quiz", isRare: false),
    Achievement(id: "fifty_questions", title: "Inquisitive", desc: "Answer 50 questions", icon: "brain.fill", category: "Quiz", isRare: false),
    Achievement(id: "streak_7", title: "Week Warrior", desc: "7-day streak", icon: "flame.fill", category: "Streak", isRare: false),
    Achievement(id: "streak_30", title: "Monthly Master", desc: "30-day streak", icon: "flame.circle.fill", category: "Streak", isRare: false),
    Achievement(id: "streak_100", title: "Eternal Flame", desc: "100-day streak", icon: "flame.circle", category: "Streak", isRare: false),
    Achievement(id: "week_1", title: "Week 1 Hero", desc: "Complete week 1", icon: "1.circle.fill", category: "Weekly", isRare: true),
    Achievement(id: "week_2", title: "Week 2 Hero", desc: "Complete week 2", icon: "2.circle.fill", category: "Weekly", isRare: true),
    Achievement(id: "week_3", title: "Week 3 Hero", desc: "Complete week 3", icon: "3.circle.fill", category: "Weekly", isRare: true),
    Achievement(id: "week_4", title: "Week 4 Hero", desc: "Complete week 4", icon: "4.circle.fill", category: "Weekly", isRare: true),
    Achievement(id: "boss_win", title: "Boss Slayer", desc: "Win a Weekly Boss Challenge", icon: "crown.fill", category: "Challenge", isRare: false),
    Achievement(id: "game_perfect", title: "Sharpshooter", desc: "Perfect round in mini-game", icon: "target", category: "Game", isRare: false),
    Achievement(id: "xp_1000", title: "Rising Star", desc: "Earn 1000 XP", icon: "star.fill", category: "XP", isRare: false),
    Achievement(id: "xp_5000", title: "Supernova", desc: "Earn 5000 XP", icon: "sparkle", category: "XP", isRare: false),
    Achievement(id: "secret_tap", title: "Ghost in the Machine", desc: "Find the secret Easter egg", icon: "eye.trianglebadge.exclamationmark.fill", category: "Secret", isRare: true),
    Achievement(id: "level_max", title: "Kingdom Ruler", desc: "Reach the final level", icon: "crown.fill", category: "XP", isRare: true),
    Achievement(id: "share_card", title: "Ambassador", desc: "Share your progress", icon: "square.and.arrow.up.fill", category: "Social", isRare: false)
]

let dailyFacts: [String] = {
    var facts = [
        "A neutron star is so dense that a teaspoon of its material would weigh about 6 billion tons on Earth.",
        "The Voyager 1 spacecraft, launched in 1977, is the farthest human-made object from Earth at over 24 billion km.",
        "There are more stars in the observable universe than grains of sand on all Earth's beaches.",
        "A day on Venus is longer than a year on Venus — it takes 243 Earth days to rotate but only 225 to orbit the Sun.",
        "The largest known star, UY Scuti, has a radius about 1,700 times that of our Sun.",
        "Saturn's density is so low that it would float if placed in a large enough body of water.",
        "The Andromeda Galaxy is approaching the Milky Way at about 110 kilometers per second.",
        "A photon of light takes about 8 minutes and 20 seconds to travel from the Sun to Earth.",
        "Jupiter's Great Red Spot is a storm that has been raging for at least 350 years.",
        "The footprints left by Apollo astronauts on the Moon will remain for millions of years due to no atmosphere.",
        "The International Space Station orbits Earth at approximately 28,000 km/h, circling the planet every 90 minutes.",
        "Black holes can spin at nearly the speed of light.",
        "The temperature at the Sun's core is approximately 15 million degrees Celsius.",
        "Olympus Mons on Mars is nearly three times the height of Mount Everest.",
        "There are rogue planets wandering through space without orbiting any star.",
        "The observable universe has a diameter of about 93 billion light-years.",
        "Neutron stars can spin up to 716 times per second.",
        "The Hubble Space Telescope can see objects 13.4 billion light-years away.",
        "Space is completely silent because there is no medium for sound waves to travel.",
        "A year on Mercury is just 88 Earth days, but a day lasts 59 Earth days.",
        "The Kuiper Belt is a region beyond Neptune filled with icy bodies and dwarf planets.",
        "Gamma-ray bursts are the most energetic events in the universe since the Big Bang.",
        "The Milky Way is on a collision course with the Andromeda Galaxy, merging in ~4.5 billion years.",
        "There are more than 5,000 confirmed exoplanets discovered as of 2024.",
        "The JWST sunshield is about the size of a tennis court.",
        "One million Earths could fit inside the Sun.",
        "The cosmic microwave background radiation was discovered accidentally in 1965.",
        "Light from the most distant galaxies observed by JWST traveled for over 13 billion years.",
        "Pluto's heart-shaped region is called Tombaugh Regio.",
        "The tallest cliff in the solar system is on Uranus's moon Miranda — about 20 km high."
    ]
    while facts.count < 365 {
        facts.append(facts[facts.count % 30])
    }
    return facts
}()

// MARK: - Game State

class GameState: ObservableObject {
    static let shared = GameState()

    @AppStorage("userName") var userName = "Explorer"
    @AppStorage("onboardingDone") var onboardingDone = false
    @AppStorage("skillLevel") var skillLevel = "Beginner"
    @AppStorage("learningGoal") var learningGoal = "Myself"
    @AppStorage("selectedTopics") var selectedTopics = ""
    @AppStorage("totalXP") var totalXP = 0
    @AppStorage("currentLevel") var currentLevel = 0
    @AppStorage("streakDays") var streakDays = 0
    @AppStorage("streakWeeks") var streakWeeks = 0
    @AppStorage("lastActiveDate") var lastActiveDate = ""
    @AppStorage("lessonProgressStr") var lessonProgressStr = "000000000000"
    @AppStorage("unlockedAchievements") var unlockedAchievements = ""
    @AppStorage("lastRewardDate") var lastRewardDate = ""
    @AppStorage("secretThemeActive") var secretThemeActive = false
    @AppStorage("streakFreezeActive") var streakFreezeActive = false
    @AppStorage("totalQuestionsAnswered") var totalQuestionsAnswered = 0
    @AppStorage("totalSessionsCount") var totalSessionsCount = 0
    @AppStorage("bestQuizScore") var bestQuizScore = 0
    @AppStorage("bossDefeatedThisWeek") var bossDefeatedThisWeek = false
    @AppStorage("lastBossWeek") var lastBossWeek = 0
    @AppStorage("weeklyXPData") var weeklyXPData = "0,0,0,0,0,0,0"
    @AppStorage("monthlyXPData") var monthlyXPData = "0,0,0,0"

    @Published var showLevelUp = false
    @Published var showDailyReward = false
    @Published var dailyRewardXP = 0
    @Published var newLevelName = ""

    let levelNames = ["Atom", "Molecule", "Cell", "Organism", "Species", "Genus", "Order", "Class", "Phylum", "Kingdom"]
    let levelThresholds = [0, 160, 380, 700, 1150, 1850, 2850, 4300, 6300, 10200]

    var lessonProgress: [Bool] {
        get { Array(lessonProgressStr).map { $0 == "1" } }
        set {
            lessonProgressStr = String(newValue.map { $0 ? Character("1") : Character("0") })
        }
    }

    var completedLessonCount: Int { lessonProgress.filter { $0 }.count }

    var unlockedSet: Set<String> {
        Set(unlockedAchievements.split(separator: ",").map(String.init))
    }

    func isUnlocked(_ id: String) -> Bool { unlockedSet.contains(id) }

    func unlockAchievement(_ id: String) {
        guard !isUnlocked(id) else { return }
        if unlockedAchievements.isEmpty {
            unlockedAchievements = id
        } else {
            unlockedAchievements += ",\(id)"
        }
        objectWillChange.send()
    }

    func addXP(_ amount: Int) {
        totalXP += amount
        updateWeeklyXP(amount)
        updateMonthlyXP(amount)
        checkLevelUp()
        if totalXP >= 1000 { unlockAchievement("xp_1000") }
        if totalXP >= 5000 { unlockAchievement("xp_5000") }
    }

    func checkLevelUp() {
        var newLevel = 0
        for i in 0..<levelThresholds.count {
            if totalXP >= levelThresholds[i] { newLevel = i }
        }
        if newLevel > currentLevel {
            currentLevel = newLevel
            newLevelName = levelNames[min(newLevel, levelNames.count - 1)]
            showLevelUp = true
            Haptics.levelUp()
            AudioServicesPlaySystemSound(1016)
            if newLevel >= levelNames.count - 1 { unlockAchievement("level_max") }
            if newLevel >= 5 { streakFreezeActive = true }
        }
    }

    func completeLesson(_ index: Int) {
        guard index < 12 else { return }
        var prog = lessonProgress
        if !prog[index] {
            prog[index] = true
            lessonProgress = prog
            addXP(contentBank[index].xpReward)
            if completedLessonCount == 1 { unlockAchievement("first_lesson") }
            if completedLessonCount >= 5 { unlockAchievement("five_lessons") }
            if completedLessonCount >= 12 { unlockAchievement("all_lessons") }
        }
    }

    func isLessonUnlocked(_ index: Int) -> Bool {
        if index == 0 { return true }
        return lessonProgress[index - 1]
    }

    func updateStreak() {
        let today = dateString(Date())
        if lastActiveDate == today { return }
        let yesterday = dateString(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        if lastActiveDate == yesterday {
            streakDays += 1
        } else if lastActiveDate != today {
            if streakFreezeActive {
                streakFreezeActive = false
            } else {
                streakDays = 1
            }
        }
        streakWeeks = streakDays / 7
        lastActiveDate = today
        addXP(25 + streakDays * 10)
    }

    func checkDailyReward() {
        let today = dateString(Date())
        if lastRewardDate != today {
            dailyRewardXP = Int.random(in: 15...60)
            showDailyReward = true
            lastRewardDate = today
        }
    }

    func checkBossWeek() {
        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        if weekOfYear != lastBossWeek {
            bossDefeatedThisWeek = false
            lastBossWeek = weekOfYear
        }
    }

    var isBossDay: Bool {
        Calendar.current.component(.weekday, from: Date()) == 2
    }

    func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func updateWeeklyXP(_ amount: Int) {
        var arr = weeklyXPData.split(separator: ",").compactMap { Int($0) }
        while arr.count < 7 { arr.append(0) }
        let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        arr[weekday] += amount
        weeklyXPData = arr.map(String.init).joined(separator: ",")
    }

    func updateMonthlyXP(_ amount: Int) {
        var arr = monthlyXPData.split(separator: ",").compactMap { Int($0) }
        while arr.count < 4 { arr.append(0) }
        let weekOfMonth = min(Calendar.current.component(.weekOfMonth, from: Date()) - 1, 3)
        arr[weekOfMonth] += amount
        monthlyXPData = arr.map(String.init).joined(separator: ",")
    }

    var weeklyXPArray: [Int] {
        weeklyXPData.split(separator: ",").compactMap { Int($0) }
    }

    var monthlyXPArray: [Int] {
        monthlyXPData.split(separator: ",").compactMap { Int($0) }
    }

    func streakTemperature() -> (String, Color, String) {
        if streakDays >= 100 { return ("Molten", Color(red: 1, green: 0.95, blue: 0.7), "bolt.fill") }
        if streakDays >= 30 { return ("Hot", Color.red, "flame.fill") }
        if streakDays >= 7 { return ("Warm", AppTheme.warmOrange, "flame") }
        return ("Cold", Color(red: 0.5, green: 0.8, blue: 1.0), "snowflake") }

    var xpForCurrentLevel: Int { totalXP - levelThresholds[min(currentLevel, levelThresholds.count - 1)] }
    var xpForNextLevel: Int {
        let next = min(currentLevel + 1, levelThresholds.count - 1)
        return levelThresholds[next] - levelThresholds[min(currentLevel, levelThresholds.count - 1)]
    }
    var levelProgress: Double {
        guard xpForNextLevel > 0 else { return 1.0 }
        return Double(xpForCurrentLevel) / Double(xpForNextLevel)
    }
    var currentLevelName: String { levelNames[min(currentLevel, levelNames.count - 1)] }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var todayFact: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return dailyFacts[(dayOfYear - 1) % dailyFacts.count]
    }
}

// MARK: - Animated Cosmic Background

 struct AnimatedCosmicBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var ctx = context
                drawBackground(ctx: &ctx, size: size)
                drawStars(ctx: &ctx, size: size, t: t)
                drawGrooves(ctx: &ctx, size: size, t: t)
                drawWaves(ctx: &ctx, size: size, t: t)
            }
        }
        .ignoresSafeArea()
    }
    
    private func drawBackground(ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppTheme.deepBg))
    }
    
    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<50 {
            let seed = Double(i) * 137.508
            let x = (seed.truncatingRemainder(dividingBy: 1.0) + seed / 1000.0)
                .truncatingRemainder(dividingBy: 1.0) * size.width
            let y = ((seed * 0.618).truncatingRemainder(dividingBy: 1.0)) * size.height
            let brightness = (sin(t * (0.5 + Double(i) * 0.1) + seed) + 1) / 2
            let r = 1.0 + brightness * 1.5
            
            let starPath = Path(ellipseIn: CGRect(
                x: x - r,
                y: y - r,
                width: r * 2,
                height: r * 2
            ))
            
            ctx.fill(starPath, with: .color(.white.opacity(0.3 + brightness * 0.5)))
        }
    }
    
    private func drawGrooves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let grooveCount = 8
        let cx = size.width / 2
        let cy = size.height * 0.35
        
        for g in 0..<grooveCount {
            let radius = 30.0 + Double(g) * 28.0
            let opacity = 0.03 + sin(t * 0.4 + Double(g)) * 0.015
            
            var path = Path()
            path.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            
            ctx.stroke(
                path,
                with: .color(AppTheme.neonCyan.opacity(opacity)),
                lineWidth: 0.8
            )
        }
    }
    
    private func drawWaves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for j in 0..<3 {
            let ny = size.height * (0.6 + Double(j) * 0.12)
            var path = Path()
            var firstPoint = true
            
            for xi in stride(from: 0, through: size.width, by: 4) {
                let wave = sin(xi * 0.01 + t * 0.25 + Double(j) * 1.8) * 25
                let point = CGPoint(x: xi, y: ny + wave)
                
                if firstPoint {
                    path.move(to: point)
                    firstPoint = false
                } else {
                    path.addLine(to: point)
                }
            }
            
            ctx.stroke(
                path,
                with: .color(AppTheme.electricPurple.opacity(0.04 + Double(j) * 0.015)),
                lineWidth: 1.2
            )
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var scanlineY: CGFloat = 0
    @State private var particlePhase: Double = 0

    var body: some View {
        ZStack {
            AppTheme.deepBg.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    for i in 0..<40 {
                        let seed = Double(i) * 97.3
                        let progress = min(1, max(0, (t.truncatingRemainder(dividingBy: 3.0)) / 2.0))
                        let targetX = size.width / 2
                        let targetY = size.height / 2 - 30
                        let startX = (sin(seed) * 0.5 + 0.5) * size.width
                        let startY = (cos(seed * 1.3) * 0.5 + 0.5) * size.height
                        let x = startX + (targetX - startX) * progress
                        let y = startY + (targetY - startY) * progress
                        let r = 2.0 + sin(seed) * 1.5
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(AppTheme.neonCyan.opacity(0.6 + progress * 0.4))
                        )
                    }
                }
            }

            VStack(spacing: 20) {
                ZStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(AppTheme.accentGradient)
                        .scaleEffect(scale)
                        .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 20)

                    Circle()
                        .stroke(AppTheme.electricPurple.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale * 1.1)
                }

                Text("StarterGhoste")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.accentGradient)
                    .opacity(opacity)

                Text("analog cosmos")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.tapeBeige.opacity(0.6))
                    .opacity(opacity)
            }

            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.clear, AppTheme.neonCyan.opacity(0.08), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(height: 3)
                    .offset(y: scanlineY)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            scanlineY = geo.size.height
                        }
                    }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) { scale = 1.0 }
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) { opacity = 1.0 }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @ObservedObject var state: GameState
    @State private var page = 0
    @State private var nameInput = ""
    @State private var selectedGoal = "Myself"
    @State private var selectedTopicIndices: Set<Int> = []

    let goals = ["Myself", "Career", "Fun", "Challenge"]
    let goalIcons = ["person.fill", "briefcase.fill", "gamecontroller.fill", "flag.checkered"]
    let topics = ["Solar System", "Stars", "Galaxies", "Black Holes", "Exoplanets", "Cosmology", "Space Tech", "Astrophysics"]

    var body: some View {
        ZStack {
            AnimatedCosmicBackground()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i <= page ? AppTheme.neonCyan : Color.white.opacity(0.15))
                            .frame(height: 4)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 60)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    topicPage.tag(1)
                    goalPage.tag(2)
                    namePage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
            }
        }
    }

    var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            CosmoMascot(mood: .excited, size: 120)
            Text("Welcome to\nStarterGhoste")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Your analog cosmos learning journey")
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.tapeBeige.opacity(0.7))

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    GhostTapIndicator(icon: "hand.tap.fill", label: "Tap to learn")
                    GhostTapIndicator(icon: "hand.draw.fill", label: "Swipe to explore")
                }
                HStack(spacing: 12) {
                    GhostTapIndicator(icon: "star.fill", label: "Earn XP")
                    GhostTapIndicator(icon: "flame.fill", label: "Build streaks")
                }
            }
            .padding(.horizontal, 30)

            Spacer()
            BrutalistButton(title: "BEGIN", icon: "arrow.right") { page = 1 }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
        }
    }

    var topicPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Pick topics you love")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<topics.count, id: \.self) { i in
                    Button {
                        Haptics.medium()
                        if selectedTopicIndices.contains(i) { selectedTopicIndices.remove(i) }
                        else { selectedTopicIndices.insert(i) }
                    } label: {
                        Text(topics[i])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                NeonGlassCard(isActive: selectedTopicIndices.contains(i))
                            )
                    }
                    .accessibilityLabel("Topic: \(topics[i])")
                }
            }
            .padding(.horizontal, 30)

            Spacer()
            BrutalistButton(title: "NEXT", icon: "arrow.right") { page = 2 }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
        }
    }

    var goalPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Why are you learning?")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(0..<goals.count, id: \.self) { i in
                    Button {
                        Haptics.medium()
                        selectedGoal = goals[i]
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: goalIcons[i])
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.accentGradient)
                                .frame(width: 44, height: 44)
                            Text(goals[i])
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            if selectedGoal == goals[i] {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accentGradient)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(16)
                        .background(NeonGlassCard(isActive: selectedGoal == goals[i]))
                    }
                    .accessibilityLabel("Goal: \(goals[i])")
                }
            }
            .padding(.horizontal, 30)

            Spacer()
            BrutalistButton(title: "NEXT", icon: "arrow.right") {
                state.learningGoal = selectedGoal
                page = 3
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    var namePage: some View {
        VStack(spacing: 24) {
            Spacer()
            CosmoMascot(mood: .happy, size: 80)
            Text("What should we call you?")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)

            TextField("Your name", text: $nameInput)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)

            if !nameInput.isEmpty {
                VStack(spacing: 6) {
                    Text("Welcome, \(nameInput)!")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                    Text("Goal: \(selectedGoal) • \(selectedTopicIndices.count) topics")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            BrutalistButton(title: "START EXPLORING", icon: "sparkles") {
                state.userName = nameInput.isEmpty ? "Explorer" : nameInput
                state.selectedTopics = selectedTopicIndices.map { topics[$0] }.joined(separator: ",")
                state.onboardingDone = true
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

struct GhostTapIndicator: View {
    let icon: String
    let label: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accentGradient)
                .scaleEffect(pulse ? 1.15 : 1.0)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(AppTheme.neonCyan.opacity(0.15), lineWidth: 1))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) { pulse = true }
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Mascot

enum MascotMood { case happy, excited, thinking, sad }

struct CosmoMascot: View {
    let mood: MascotMood
    var size: CGFloat = 80
    @State private var bounce = false
    @State private var eyeBlink = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [AppTheme.electricPurple.opacity(0.3), .clear],
                                   center: .center, startRadius: 0, endRadius: size * 0.8)
                )
                .frame(width: size * 1.6, height: size * 1.6)

            ZStack {
                Circle()
                    .fill(AppTheme.deepBg)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [AppTheme.neonCyan, AppTheme.electricPurple],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 12)

                HStack(spacing: size * 0.15) {
                    MascotEye(size: size * 0.15, blink: eyeBlink, mood: mood)
                    MascotEye(size: size * 0.15, blink: eyeBlink, mood: mood)
                }
                .offset(y: -size * 0.05)

                mouthShape
                    .offset(y: size * 0.18)

                if mood == .excited {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: size * 0.12))
                            .foregroundStyle(AppTheme.starYellow)
                            .offset(x: CGFloat([-1, 1, 0][i]) * size * 0.4,
                                    y: CGFloat([-0.3, -0.25, -0.45][i]) * size)
                            .scaleEffect(bounce ? 1.2 : 0.8)
                    }
                }
            }
            .offset(y: bounce ? -4 : 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever()) { bounce.toggle() }
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                eyeBlink = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { eyeBlink = false }
            }
        }
    }

    @ViewBuilder
    var mouthShape: some View {
        switch mood {
        case .happy, .excited:
            Capsule().fill(AppTheme.hotPink)
                .frame(width: size * 0.25, height: size * 0.08)
        case .thinking:
            Circle().fill(AppTheme.hotPink.opacity(0.7))
                .frame(width: size * 0.1, height: size * 0.1)
        case .sad:
            Capsule().fill(AppTheme.hotPink.opacity(0.5))
                .frame(width: size * 0.2, height: size * 0.04)
        }
    }
}

struct MascotEye: View {
    let size: CGFloat
    let blink: Bool
    let mood: MascotMood

    var body: some View {
        Capsule()
            .fill(mood == .excited ? AppTheme.starYellow : AppTheme.neonCyan)
            .frame(width: size, height: blink ? 2 : size)
            .shadow(color: (mood == .excited ? AppTheme.starYellow : AppTheme.neonCyan).opacity(0.6), radius: 4)
            .animation(.easeInOut(duration: 0.1), value: blink)
    }
}

// MARK: - Reusable Components

struct NeonGlassCard: View {
    var isActive: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isActive ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
            .shadow(color: isActive ? AppTheme.neonCyan.opacity(0.2) : .clear, radius: 12)
    }
}

struct BrutalistButton: View {
    let title: String
    var icon: String = ""
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                Capsule()
                    .fill(AppTheme.accentGradient)
                    .shadow(color: AppTheme.neonCyan.opacity(0.3), radius: 8, y: 4)
            )
            .clipShape(Capsule())
            .scaleEffect(pressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { pressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { pressed = false } }
        )
        .accessibilityLabel(title)
    }
}

 struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabNS
    let items: [(String, String)] = [
        ("house.fill", "Home"),
        ("book.fill", "Atlas"),
        ("bolt.fill", "Quiz"),
        ("chart.bar.fill", "Stats"),
        ("person.fill", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                TabButton(
                    index: i,
                    selectedTab: $selectedTab,
                    namespace: tabNS,
                    item: items[i]
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(backgroundCapsule)
        .padding(.horizontal, 20)
    }
    
    private var backgroundCapsule: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.neonCyan.opacity(0.2), AppTheme.electricPurple.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }
}

struct TabButton: View {
    let index: Int
    @Binding var selectedTab: Int
    let namespace: Namespace.ID
    let item: (String, String)
    
    var isSelected: Bool { index == selectedTab }
    
    var body: some View {
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.0)
                    .font(.system(size: isSelected ? 22 : 18, weight: .bold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.4)))
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                
                if isSelected {
                    Text(item.1)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accentGradient)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 44, minHeight: 44)
            .background(selectionBackground)
        }
        .accessibilityLabel(item.1)
    }
    
    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            Capsule()
                .fill(AppTheme.neonCyan.opacity(0.08))
                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
        }
    }
}

// MARK: - Hero Card Shape

struct HeroCardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - 40))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - 40),
                          control: CGPoint(x: rect.width / 2, y: rect.height + 20))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var state: GameState
    @Binding var selectedTab: Int
    @State private var showSettings = false
    @State private var showMiniGame = false
    @State private var animateStats = false
    @State private var selectedLesson: LessonContent? = nil
    @ScaledMetric private var heroHeight: CGFloat = 320

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    HeroCardShape()
                        .fill(
                            LinearGradient(colors: [AppTheme.electricPurple.opacity(0.4), AppTheme.deepBg],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(height: heroHeight)
                        .overlay(
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(state.greeting)
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            .foregroundColor(AppTheme.tapeBeige.opacity(0.7))
                                        Text(state.userName)
                                            .font(.system(size: 28, weight: .black))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.electricPurple.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(AppTheme.accentGradient)
                                    }
                                }

                                HStack(spacing: 4) {
                                    Text("Level \(state.currentLevel)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.accentGradient)
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.3))
                                    Text(state.currentLevelName)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.starYellow)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 10)
                                    Capsule()
                                        .fill(AppTheme.accentGradient)
                                        .frame(width: max(10, CGFloat(state.levelProgress) * (UIScreen.main.bounds.width - 80)), height: 10)
                                        .animation(.spring(response: 0.6), value: state.levelProgress)
                                }

                                Text("\(state.xpForCurrentLevel)/\(state.xpForNextLevel) XP to next level")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 16) {
                                    DashStatPill(icon: state.streakTemperature().2,
                                                 value: "\(state.streakDays)",
                                                 label: "Streak",
                                                 color: state.streakTemperature().1,
                                                 animated: animateStats)
                                    DashStatPill(icon: "star.fill",
                                                 value: "\(state.totalXP)",
                                                 label: "XP",
                                                 color: AppTheme.starYellow,
                                                 animated: animateStats)
                                    DashStatPill(icon: "book.closed.fill",
                                                 value: "\(state.totalSessionsCount)",
                                                 label: "Sessions",
                                                 color: AppTheme.mintGreen,
                                                 animated: animateStats)
                                    if state.streakFreezeActive {
                                        Image(systemName: "shield.fill")
                                            .foregroundStyle(AppTheme.neonCyan)
                                            .font(.system(size: 18))
                                            .accessibilityLabel("Streak freeze active")
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 60)
                        )

                    Button {
                        Haptics.medium()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.accentGradient)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 16)
                    .accessibilityLabel("Settings")
                }

                VStack(spacing: 20) {

                    // MARK: Quick Actions Grid
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "QUICK ACTIONS", icon: "bolt.fill")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            QuickActionTile(icon: "questionmark.diamond.fill", title: "Start Quiz", subtitle: "\(quizBank.count) questions", gradient: AppTheme.accentGradient) {
                                selectedTab = 2
                            }
                            QuickActionTile(icon: "play.circle.fill", title: "Continue", subtitle: nextLessonTitle(state: state), gradient: AppTheme.warmGradient) {
                                if let idx = state.lessonProgress.firstIndex(of: false), idx < contentBank.count {
                                    selectedLesson = contentBank[idx]
                                } else {
                                    selectedTab = 1
                                }
                            }
                            QuickActionTile(icon: "gamecontroller.fill", title: "Mini Game", subtitle: "Earn bonus XP", gradient: AppTheme.pinkGradient) {
                                showMiniGame = true
                            }
                            QuickActionTile(icon: "trophy.fill", title: "Achievements", subtitle: "\(state.unlockedSet.count)/\(achievementCatalog.count)", gradient: LinearGradient(colors: [AppTheme.starYellow, AppTheme.warmOrange], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                                selectedTab = 4
                            }
                        }
                    }

                    // MARK: Today's Challenge
                    DailyChallengeBanner(state: state)

                    // MARK: Fact of the Day
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "FACT OF THE DAY", icon: "lightbulb.fill")
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.starYellow.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "sparkle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppTheme.starYellow)
                            }
                            Text(state.todayFact)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NeonGlassCard())
                    }

                    if state.isBossDay && !state.bossDefeatedThisWeek {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(AppTheme.warmGradient)
                                Text("WEEKLY BOSS CHALLENGE")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundStyle(AppTheme.warmGradient)
                            }
                            Text("10 Expert Questions • Legendary Reward")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(AppTheme.warmOrange.opacity(0.4), lineWidth: 1.5)
                                )
                        )
                    }

                    // MARK: Weekly XP Progress
                    WeeklyXPCard(state: state)

                    // MARK: Achievements Showcase
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "ACHIEVEMENTS", icon: "medal.fill")
                        if state.unlockedSet.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.accentGradient)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("No achievements yet")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Complete lessons and quizzes to unlock")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NeonGlassCard())
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(achievementCatalog.filter { state.isUnlocked($0.id) }) { ach in
                                        AchievementBadge(achievement: ach)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }

                    // MARK: Motivational Banner
                    CosmicMotivationBanner(state: state)

                    // MARK: Continue Learning
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "CONTINUE LEARNING", icon: "play.fill")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(contentBank.prefix(6)) { lesson in
                                    FeaturedLessonCard(lesson: lesson, isUnlocked: state.isLessonUnlocked(lesson.id), isCompleted: state.lessonProgress[lesson.id])
                                        .onTapGesture {
                                            guard state.isLessonUnlocked(lesson.id) else { return }
                                            Haptics.medium()
                                            selectedLesson = lesson
                                        }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    // MARK: Learning Streak Calendar
                    StreakHeatmapCard(state: state)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear { withAnimation(.spring(response: 0.6).delay(0.3)) { animateStats = true } }
        .fullScreenCover(isPresented: $showSettings) { SettingsView(state: state) }
        .fullScreenCover(item: $selectedLesson) { lesson in
            LessonDetailView(state: state, lesson: lesson)
        }
        .fullScreenCover(isPresented: $showMiniGame) {
            MiniGameView(state: state)
        }
    }
}

struct DashStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var animated: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .offset(y: animated ? 0 : 20)
        .opacity(animated ? 1 : 0)
    }
}

struct SectionLabel: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accentGradient)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct FeaturedLessonCard: View {
    let lesson: LessonContent
    let isUnlocked: Bool
    let isCompleted: Bool

    let cardColors: [LinearGradient] = [
        LinearGradient(colors: [Color(red:0.1,green:0.3,blue:0.5), Color(red:0.05,green:0.15,blue:0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.4,green:0.1,blue:0.3), Color(red:0.2,green:0.05,blue:0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.1,green:0.35,blue:0.25), Color(red:0.05,green:0.18,blue:0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.35,green:0.2,blue:0.05), Color(red:0.18,green:0.1,blue:0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: lesson.icon)
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.accentGradient)

            Text(lesson.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 4) {
                Text(lesson.difficulty)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(difficultyColor(lesson.difficulty).opacity(0.3)))

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.mintGreen)
                        .font(.system(size: 12))
                }
            }
        }
        .frame(width: 140, height: 130, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(cardColors[lesson.id % cardColors.count])
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .overlay(
            Group {
                if !isUnlocked {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AppTheme.accentGradient)
                        )
                }
            }
        )
        .accessibilityLabel("\(lesson.title), \(isUnlocked ? "unlocked" : "locked")")
    }

    func difficultyColor(_ d: String) -> Color {
        switch d {
        case "Beginner": return AppTheme.mintGreen
        case "Intermediate": return AppTheme.warmOrange
        case "Expert": return AppTheme.hotPink
        default: return .white
        }
    }
}

// MARK: - Dashboard Helper

private func nextLessonTitle(state: GameState) -> String {
    if let idx = state.lessonProgress.firstIndex(of: false), idx < contentBank.count {
        return contentBank[idx].title
    }
    return "All done!"
}

// MARK: - Quick Action Tile

struct QuickActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    var action: () -> Void = {}
    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(gradient.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(gradient)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleTileButtonStyle())
    }
}

struct ScaleTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Daily Challenge Banner

struct DailyChallengeBanner: View {
    @ObservedObject var state: GameState

    private var challengeQuestion: QuizQuestion {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quizBank[(dayOfYear - 1) % quizBank.count]
    }

    private var hoursLeft: Int {
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        return max(0, calendar.dateComponents([.hour], from: Date(), to: endOfDay).hour ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "TODAY'S CHALLENGE", icon: "target")
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(challengeQuestion.text)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Label(challengeQuestion.difficulty, systemImage: "gauge.medium")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Text("•")
                                .foregroundColor(.white.opacity(0.3))
                            Label("+\(challengeQuestion.xpReward) XP", systemImage: "star.fill")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.starYellow)
                        }
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(hoursLeft)")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.accentGradient)
                        Text("HRS LEFT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 60)
                }
                ProgressView(value: Double(state.totalQuestionsAnswered % 5), total: 5)
                    .tint(AppTheme.neonCyan)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                HStack {
                    Text("Daily progress")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text("\(state.totalQuestionsAnswered % 5)/5 questions")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.neonCyan.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Weekly XP Card

struct WeeklyXPCard: View {
    @ObservedObject var state: GameState

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "WEEKLY XP", icon: "chart.bar.fill")
            VStack(spacing: 12) {
                HStack {
                    Text("This Week")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(state.weeklyXPArray.reduce(0, +)) XP")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.accentGradient)
                }

                let data = state.weeklyXPArray
                let maxVal = max(Double(data.max() ?? 1), 1)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<min(data.count, 7), id: \.self) { i in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    i == currentWeekdayIndex()
                                    ? AnyShapeStyle(AppTheme.accentGradient)
                                    : AnyShapeStyle(Color.white.opacity(0.15))
                                )
                                .frame(height: max(6, CGFloat(Double(data[i]) / maxVal) * 80))
                            Text(dayLabels[i])
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(
                                    i == currentWeekdayIndex()
                                    ? AppTheme.neonCyan
                                    : .white.opacity(0.35)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
            }
            .padding(16)
            .background(NeonGlassCard())
        }
    }

    private func currentWeekdayIndex() -> Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        achievement.isRare
                        ? AnyShapeStyle(AppTheme.warmGradient)
                        : AnyShapeStyle(AppTheme.accentGradient)
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: achievement.isRare ? AppTheme.warmOrange.opacity(0.4) : AppTheme.neonCyan.opacity(0.4), radius: 8)
                Image(systemName: achievement.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(achievement.title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(achievement.desc)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(width: 90)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            achievement.isRare ? AppTheme.warmOrange.opacity(0.3) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Cosmic Motivation Banner

struct CosmicMotivationBanner: View {
    @ObservedObject var state: GameState

    private var message: String {
        if state.streakDays >= 30 { return "You're on fire! \(state.streakDays) days of cosmic exploration — the universe bows to your dedication." }
        if state.streakDays >= 7 { return "A whole week of stargazing! Keep pushing beyond the event horizon." }
        if state.completedLessonCount >= 6 { return "Halfway through the curriculum! You're becoming a true space scholar." }
        if state.totalXP >= 500 { return "500+ XP earned! You're accelerating faster than Voyager 1." }
        return "Every expert was once a beginner. One lesson a day keeps ignorance light-years away."
    }

    private var icon: String {
        if state.streakDays >= 30 { return "flame.circle.fill" }
        if state.streakDays >= 7 { return "sparkles" }
        if state.completedLessonCount >= 6 { return "book.closed.circle.fill" }
        if state.totalXP >= 500 { return "bolt.circle.fill" }
        return "atom"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.pinkGradient)
                .frame(width: 48, height: 48)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.hotPink.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Streak Heatmap Card

struct StreakHeatmapCard: View {
    @ObservedObject var state: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "STREAK CALENDAR", icon: "calendar")
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(state.streakDays) Day Streak")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                        Text(streakMessage)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    let temp = state.streakTemperature()
                    HStack(spacing: 4) {
                        Image(systemName: temp.2)
                            .foregroundColor(temp.1)
                        Text(temp.0)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(temp.1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(temp.1.opacity(0.15))
                    )
                }

                let calendar = Calendar.current
                let today = Date()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<28, id: \.self) { dayOffset in
                        let date = calendar.date(byAdding: .day, value: -(27 - dayOffset), to: today)!
                        let isActive = dayOffset >= (28 - state.streakDays)
                        let isToday = calendar.isDateInToday(date)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                isActive
                                ? (isToday ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.neonCyan.opacity(0.35)))
                                : AnyShapeStyle(Color.white.opacity(0.06))
                            )
                            .frame(height: 18)
                            .overlay(
                                isToday
                                ? RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(AppTheme.neonCyan, lineWidth: 1.5)
                                : nil
                            )
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 10, height: 10)
                        Text("Missed")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppTheme.neonCyan.opacity(0.35))
                            .frame(width: 10, height: 10)
                        Text("Active")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppTheme.accentGradient)
                            .frame(width: 10, height: 10)
                        Text("Today")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(16)
            .background(NeonGlassCard())
        }
    }

    private var streakMessage: String {
        if state.streakDays == 0 { return "Start your streak today!" }
        if state.streakDays < 7 { return "Keep going to unlock Week Warrior!" }
        if state.streakDays < 30 { return "\(30 - state.streakDays) days to Monthly Master" }
        return "Unstoppable cosmic force!"
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var state: GameState
    @Environment(\.dismiss) var dismiss
    @State private var showResetAlert = false

    var body: some View {
        ZStack {
            AnimatedCosmicBackground()

            VStack(spacing: 0) {
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        Haptics.medium()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.accentGradient)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close settings")
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                ScrollView {
                    VStack(spacing: 16) {
                        SettingsRow(icon: "person.fill", label: "Name", value: state.userName)
                        SettingsRow(icon: "graduationcap.fill", label: "Level", value: state.currentLevelName)
                        SettingsRow(icon: "target", label: "Goal", value: state.learningGoal)
                        SettingsRow(icon: "star.fill", label: "Total XP", value: "\(state.totalXP)")
                        SettingsRow(icon: "flame.fill", label: "Streak", value: "\(state.streakDays) days")

                        Toggle(isOn: $state.streakFreezeActive) {
                            HStack(spacing: 10) {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(AppTheme.accentGradient)
                                Text("Streak Freeze")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(AppTheme.neonCyan)
                        .padding(16)
                        .background(NeonGlassCard())

                        Button {
                            Haptics.medium()
                            showResetAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(AppTheme.hotPink)
                                Text("Reset All Progress")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppTheme.hotPink)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(NeonGlassCard())
                        }
                        .accessibilityLabel("Reset all progress")
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Reset Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                state.totalXP = 0
                state.currentLevel = 0
                state.streakDays = 0
                state.streakWeeks = 0
                state.lessonProgressStr = "000000000000"
                state.unlockedAchievements = ""
                state.totalQuestionsAnswered = 0
                state.totalSessionsCount = 0
                state.bestQuizScore = 0
                state.weeklyXPData = "0,0,0,0,0,0,0"
                state.monthlyXPData = "0,0,0,0"
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accentGradient)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(NeonGlassCard())
    }
}

// MARK: - Lessons Atlas

struct LessonsAtlasView: View {
    @ObservedObject var state: GameState
    @State private var searchText = ""
    @State private var filterDifficulty = "All"
    @State private var selectedLesson: LessonContent? = nil
    @State private var appeared = false

    let filters = ["All", "Beginner", "Intermediate", "Expert"]

    var filteredLessons: [LessonContent] {
        contentBank.filter { lesson in
            (filterDifficulty == "All" || lesson.difficulty == filterDifficulty) &&
            (searchText.isEmpty || lesson.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var completedCount: Int { state.lessonProgress.filter { $0 }.count }
    private var totalCount: Int { contentBank.count }
    private var progressFraction: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: Header
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LESSON ATLAS")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text("\(totalCount) cosmic topics to explore")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 4)
                                .frame(width: 52, height: 52)
                            Circle()
                                .trim(from: 0, to: progressFraction)
                                .stroke(AppTheme.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 52, height: 52)
                                .rotationEffect(.degrees(-90))
                            Text("\(completedCount)")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }

                    // Progress bar
                    VStack(spacing: 6) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 8)
                            Capsule()
                                .fill(AppTheme.accentGradient)
                                .frame(width: max(8, CGFloat(progressFraction) * (UIScreen.main.bounds.width - 40)), height: 8)
                                .animation(.spring(response: 0.6), value: progressFraction)
                        }
                        HStack {
                            Text("\(completedCount)/\(totalCount) completed")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                            if completedCount == totalCount {
                                Text("ALL CLEAR")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(AppTheme.mintGreen)
                            } else {
                                Text("\(Int(progressFraction * 100))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.accentGradient)
                            }
                        }
                    }

                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.accentGradient)
                        TextField("Search lessons...", text: $searchText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(AppTheme.neonCyan.opacity(0.15), lineWidth: 1))
                    )

                    // Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { f in
                                let count = f == "All" ? contentBank.count : contentBank.filter { $0.difficulty == f }.count
                                Button {
                                    Haptics.light()
                                    withAnimation(.spring(response: 0.3)) {
                                        filterDifficulty = f
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        if f != "All" {
                                            Circle()
                                                .fill(difficultyColor(f))
                                                .frame(width: 6, height: 6)
                                        }
                                        Text(f)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        Text("(\(count))")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    .foregroundColor(filterDifficulty == f ? .white : .white.opacity(0.4))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(filterDifficulty == f ? AppTheme.electricPurple.opacity(0.4) : Color.white.opacity(0.05))
                                            .overlay(
                                                Capsule().stroke(filterDifficulty == f ? AppTheme.electricPurple : Color.clear, lineWidth: 1)
                                            )
                                    )
                                }
                                .accessibilityLabel("Filter: \(f)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                // MARK: Content
                if filteredLessons.isEmpty {
                    EmptyStateView(icon: "book.closed.fill", title: "No lessons found", subtitle: "Try a different search or filter", actionTitle: "Clear Filters") {
                        searchText = ""
                        filterDifficulty = "All"
                    }
                    .padding(.top, 60)
                } else {
                    // Next up banner
                    if filterDifficulty == "All" && searchText.isEmpty,
                       let nextIdx = state.lessonProgress.firstIndex(of: false),
                       nextIdx < contentBank.count {
                        let nextLesson = contentBank[nextIdx]
                        Button {
                            Haptics.medium()
                            selectedLesson = nextLesson
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.accentGradient.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: nextLesson.icon)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(AppTheme.accentGradient)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("UP NEXT")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(AppTheme.accentGradient)
                                    Text(nextLesson.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    HStack(spacing: 6) {
                                        Text(nextLesson.difficulty)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(difficultyColor(nextLesson.difficulty))
                                        Text("•")
                                            .foregroundColor(.white.opacity(0.2))
                                        Label("+\(nextLesson.xpReward) XP", systemImage: "star.fill")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(AppTheme.starYellow)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.accentGradient)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(AppTheme.neonCyan.opacity(0.25), lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(ScaleTileButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }

                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(Array(filteredLessons.enumerated()), id: \.element.id) { idx, lesson in
                            LessonGridCard(lesson: lesson,
                                           isUnlocked: state.isLessonUnlocked(lesson.id),
                                           isCompleted: state.lessonProgress[lesson.id],
                                           lessonNumber: lesson.id + 1)
                            .onTapGesture {
                                guard state.isLessonUnlocked(lesson.id) else { return }
                                Haptics.medium()
                                selectedLesson = lesson
                            }
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(idx) * 0.06), value: appeared)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 120)
                }
            }
        }
        .onAppear { appeared = true }
        .fullScreenCover(item: $selectedLesson) { lesson in
            LessonDetailView(state: state, lesson: lesson)
        }
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d {
        case "Beginner": return AppTheme.mintGreen
        case "Intermediate": return AppTheme.warmOrange
        case "Expert": return AppTheme.hotPink
        default: return .white
        }
    }
}

struct LessonGridCard: View {
    let lesson: LessonContent
    let isUnlocked: Bool
    let isCompleted: Bool
    var lessonNumber: Int = 0

    let gradients: [LinearGradient] = [
        LinearGradient(colors: [Color(red:0.15,green:0.25,blue:0.45), Color(red:0.08,green:0.12,blue:0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.35,green:0.12,blue:0.35), Color(red:0.18,green:0.06,blue:0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.12,green:0.32,blue:0.22), Color(red:0.06,green:0.16,blue:0.11)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.38,green:0.22,blue:0.08), Color(red:0.2,green:0.1,blue:0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red:0.3,green:0.1,blue:0.15), Color(red:0.15,green:0.05,blue:0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: number + status
            HStack {
                if lessonNumber > 0 {
                    Text("\(lessonNumber)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                }
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.mintGreen)
                } else if isUnlocked {
                    Circle()
                        .fill(AppTheme.neonCyan.opacity(0.6))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 8)

            // Icon
            ZStack {
                Circle()
                    .fill(diffColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: lesson.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        isCompleted
                        ? AnyShapeStyle(AppTheme.mintGreen)
                        : AnyShapeStyle(AppTheme.accentGradient)
                    )
            }
            .padding(.bottom, 10)

            // Title
            Text(lesson.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            // Bottom row: difficulty + XP
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(diffColor)
                        .frame(width: 5, height: 5)
                    Text(lesson.difficulty)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(diffColor)
                }

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(AppTheme.starYellow)
                    Text("\(lesson.xpReward)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.starYellow)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 185)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(gradients[lesson.id % gradients.count])
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isCompleted ? AppTheme.mintGreen.opacity(0.35) :
                            (isUnlocked ? AppTheme.neonCyan.opacity(0.12) : Color.white.opacity(0.04)),
                            lineWidth: isCompleted ? 1.5 : 1
                        )
                )
        )
        .overlay(
            Group {
                if !isUnlocked {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.deepBg.opacity(0.75))
                        .overlay(
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AppTheme.accentGradient)
                                }
                                Text("Complete #\(lesson.id)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        )
                }
            }
        )
        .accessibilityLabel("\(lesson.title), \(isUnlocked ? (isCompleted ? "completed" : "available") : "locked")")
    }

    var diffColor: Color {
        switch lesson.difficulty {
        case "Beginner": return AppTheme.mintGreen
        case "Intermediate": return AppTheme.warmOrange
        case "Expert": return AppTheme.hotPink
        default: return .white
        }
    }
}

struct LessonDetailView: View {
    @ObservedObject var state: GameState
    let lesson: LessonContent
    @Environment(\.dismiss) var dismiss
    @State private var showComplete = false

    var body: some View {
        ZStack {
            AnimatedCosmicBackground()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.difficulty.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(diffColor)
                        Text(lesson.title)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        Haptics.medium()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.accentGradient)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close lesson")
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: lesson.icon)
                                .font(.system(size: 44))
                                .foregroundStyle(AppTheme.accentGradient)
                            VStack(alignment: .leading) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.starYellow)
                                    Text("+\(lesson.xpReward) XP")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.starYellow)
                                }
                                if state.lessonProgress[lesson.id] {
                                    Text("COMPLETED")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(AppTheme.mintGreen)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NeonGlassCard())

                        Text(lesson.body)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(6)
                            .padding(16)
                            .background(NeonGlassCard())

                        if !state.lessonProgress[lesson.id] {
                            BrutalistButton(title: "MARK COMPLETE", icon: "checkmark.circle.fill") {
                                state.completeLesson(lesson.id)
                                showComplete = true
                                AudioServicesPlaySystemSound(1057)
                                Haptics.success()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }

            if showComplete {
                ConfettiOverlay()
                    .allowsHitTesting(false)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showComplete = false }
                    }
            }
        }
    }

    var diffColor: Color {
        switch lesson.difficulty {
        case "Beginner": return AppTheme.mintGreen
        case "Intermediate": return AppTheme.warmOrange
        case "Expert": return AppTheme.hotPink
        default: return .white
        }
    }
}

// MARK: - Quiz Game

struct QuizGameView: View {
    @ObservedObject var state: GameState
    @State private var selectedMode: String? = nil
    @State private var showMiniGame = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                Text("QUIZ & GAMES")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 60)

                if state.isBossDay && !state.bossDefeatedThisWeek {
                    BossChallengeBanner {
                        Haptics.medium()
                        selectedMode = "boss"
                    }
                }

                QuizModeCard(icon: "bolt.fill", title: "Quick Quiz", subtitle: "5 random questions", color: AppTheme.neonCyan) {
                    selectedMode = "quick"
                }
                QuizModeCard(icon: "target", title: "Full Challenge", subtitle: "All 20 questions", color: AppTheme.electricPurple) {
                    selectedMode = "full"
                }
                QuizModeCard(icon: "arrow.2.squarepath", title: "Practice Mode", subtitle: "Infinite practice", color: AppTheme.mintGreen) {
                    selectedMode = "practice"
                }

                SectionLabel(text: "MINI-GAME", icon: "gamecontroller.fill")
                    .padding(.top, 8)

                QuizModeCard(icon: "scope", title: "Cosmic Shooter", subtitle: "Tap targets before they vanish!", color: AppTheme.hotPink) {
                    showMiniGame = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .fullScreenCover(item: $selectedMode) { mode in
            QuizSessionView(state: state, mode: mode)
        }
        .fullScreenCover(isPresented: $showMiniGame) {
            MiniGameView(state: state)
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct BossChallengeBanner: View {
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.warmGradient)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                    Text("WEEKLY BOSS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.warmGradient)
                }
                Text("10 Expert Questions • 15s Timer • Legendary Reward")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.warmOrange.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: AppTheme.warmOrange.opacity(0.2), radius: 12)
            )
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { pulse = true } }
        .accessibilityLabel("Weekly Boss Challenge")
    }
}

struct QuizModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            }
            .padding(16)
            .background(NeonGlassCard())
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { pressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { pressed = false } }
        )
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

struct QuizSessionView: View {
    @ObservedObject var state: GameState
    let mode: String
    @Environment(\.dismiss) var dismiss

    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex = 0
    @State private var selectedAnswer = -1
    @State private var answered = false
    @State private var correctCount = 0
    @State private var totalXPEarned = 0
    @State private var showResult = false
    @State private var cardOffset: CGFloat = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var fillAnswer = ""
    @State private var timeRemaining: Float = 15
    @State private var timerActive = false
    @State private var startTime = Date()

    var isBoss: Bool { mode == "boss" }

    var body: some View {
        ZStack {
            AnimatedCosmicBackground()

            if showResult {
                quizResultView
            } else if questions.isEmpty {
                ProgressView()
                    .tint(AppTheme.neonCyan)
                    .onAppear { loadQuestions() }
            } else {
                quizActiveView
            }
        }
    }

    var quizActiveView: some View {
        let q = questions[currentIndex]
        return VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.medium()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.accentGradient)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close quiz")

                Spacer()

                if isBoss {
                    Text(String(format: "%.0f", timeRemaining))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(timeRemaining < 5 ? AppTheme.hotPink : AppTheme.neonCyan)
                }

                Spacer()

                Text("\(currentIndex + 1)/\(questions.count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            HStack(spacing: 4) {
                ForEach(0..<questions.count, id: \.self) { i in
                    Circle()
                        .fill(i < currentIndex ? AppTheme.mintGreen : (i == currentIndex ? AppTheme.neonCyan : Color.white.opacity(0.15)))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                Text(q.text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(diffGradient(q.difficulty), lineWidth: 1.5)
                            )
                    )
                    .offset(x: cardOffset + shakeOffset)

                Text(q.difficulty.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(diffColor(q.difficulty))
            }
            .padding(.horizontal, 20)

            Spacer()

            if q.type == "fill" {
                VStack(spacing: 12) {
                    TextField("Your answer", text: $fillAnswer)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        .disabled(answered)

                    if !answered {
                        BrutalistButton(title: "SUBMIT", icon: "paperplane.fill") {
                            submitFillAnswer(q)
                        }
                        .padding(.horizontal, 40)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(0..<q.options.count, id: \.self) { i in
                        Button {
                            guard !answered else { return }
                            Haptics.medium()
                            selectedAnswer = i
                            checkAnswer(q, selected: i)
                        } label: {
                            HStack {
                                Text(q.options[i])
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                if answered && i == q.correctIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.mintGreen)
                                } else if answered && i == selectedAnswer && i != q.correctIndex {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.hotPink)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(answerBorder(i, q), lineWidth: 1.5)
                                    )
                            )
                        }
                        .disabled(answered)
                        .accessibilityLabel("Option: \(q.options[i])")
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            if answered {
                BrutalistButton(title: currentIndex < questions.count - 1 ? "NEXT" : "FINISH", icon: "arrow.right") {
                    nextQuestion()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            if isBoss { startTimer() }
        }
    }

    func answerBorder(_ i: Int, _ q: QuizQuestion) -> LinearGradient {
        if !answered { return LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing) }
        if i == q.correctIndex { return LinearGradient(colors: [AppTheme.mintGreen], startPoint: .leading, endPoint: .trailing) }
        if i == selectedAnswer { return LinearGradient(colors: [AppTheme.hotPink], startPoint: .leading, endPoint: .trailing) }
        return LinearGradient(colors: [Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
    }

    func diffGradient(_ d: String) -> LinearGradient {
        switch d {
        case "Beginner": return LinearGradient(colors: [AppTheme.mintGreen.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        case "Intermediate": return LinearGradient(colors: [AppTheme.warmOrange.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        default: return LinearGradient(colors: [AppTheme.hotPink.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
    }

    func diffColor(_ d: String) -> Color {
        switch d {
        case "Beginner": return AppTheme.mintGreen
        case "Intermediate": return AppTheme.warmOrange
        default: return AppTheme.hotPink
        }
    }

    func loadQuestions() {
        startTime = Date()
        switch mode {
        case "quick":
            questions = Array(quizBank.shuffled().prefix(5))
        case "full":
            questions = quizBank.shuffled()
        case "boss":
            questions = Array(quizBank.filter { $0.difficulty == "Expert" || $0.difficulty == "Intermediate" }.shuffled().prefix(10))
            if questions.count < 10 { questions = Array(quizBank.shuffled().prefix(10)) }
        case "practice":
            questions = Array(quizBank.shuffled().prefix(5))
        default:
            questions = quizBank.shuffled()
        }
    }

    func checkAnswer(_ q: QuizQuestion, selected: Int) {
        answered = true
        timerActive = false
        if selected == q.correctIndex {
            correctCount += 1
            totalXPEarned += q.xpReward
            Haptics.success()
            AudioServicesPlaySystemSound(1057)
            withAnimation(.spring(response: 0.3)) { cardOffset = 60 }
        } else {
            Haptics.error()
            AudioServicesPlaySystemSound(1053)
            withAnimation(.default) {
                shakeOffset = 15
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shakeOffset = -15 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shakeOffset = 10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeOffset = 0 }
            }
        }
    }

    func submitFillAnswer(_ q: QuizQuestion) {
        answered = true
        timerActive = false
        let correct = fillAnswer.lowercased().trimmingCharacters(in: .whitespaces) == q.options[q.correctIndex].lowercased()
        if correct {
            correctCount += 1
            totalXPEarned += q.xpReward
            Haptics.success()
            AudioServicesPlaySystemSound(1057)
        } else {
            Haptics.error()
            AudioServicesPlaySystemSound(1053)
        }
    }

    func nextQuestion() {
        if currentIndex < questions.count - 1 {
            withAnimation(.spring(response: 0.3)) {
                cardOffset = -UIScreen.main.bounds.width
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                currentIndex += 1
                selectedAnswer = -1
                answered = false
                fillAnswer = ""
                cardOffset = UIScreen.main.bounds.width
                shakeOffset = 0
                withAnimation(.spring(response: 0.4)) { cardOffset = 0 }
                if isBoss { timeRemaining = 15; startTimer() }
            }
        } else {
            finishQuiz()
        }
    }

    func finishQuiz() {
        let elapsed = Float(Date().timeIntervalSince(startTime))
        state.addXP(totalXPEarned)
        state.totalQuestionsAnswered += questions.count
        state.totalSessionsCount += 1
        let pct = questions.count > 0 ? Int((Double(correctCount) / Double(questions.count)) * 100) : 0
        if pct > state.bestQuizScore { state.bestQuizScore = pct }
        if state.totalSessionsCount == 1 { state.unlockAchievement("first_quiz") }
        if pct == 100 { state.unlockAchievement("perfect_quiz") }
        if state.totalQuestionsAnswered >= 50 { state.unlockAchievement("fifty_questions") }
        if isBoss && pct >= 70 {
            state.bossDefeatedThisWeek = true
            state.unlockAchievement("boss_win")
            state.addXP(200)
        }
        PersistenceController.shared.addSession(mode: mode, correct: correctCount, total: questions.count, xp: totalXPEarned, time: elapsed)
        showResult = true
    }

    func startTimer() {
        timeRemaining = 15
        timerActive = true
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !timerActive { timer.invalidate(); return }
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                timer.invalidate()
                if !answered {
                    answered = true
                    Haptics.error()
                    AudioServicesPlaySystemSound(1053)
                }
            }
        }
    }

    var quizResultView: some View {
        ZStack {
            AnimatedCosmicBackground()
            let pct = questions.count > 0 ? Int((Double(correctCount) / Double(questions.count)) * 100) : 0

            VStack(spacing: 20) {
                Spacer()

                CosmoMascot(mood: pct >= 80 ? .excited : (pct >= 50 ? .happy : .sad), size: 100)

                Text(pct == 100 ? "PERFECT!" : (pct >= 80 ? "GREAT JOB!" : (pct >= 50 ? "GOOD EFFORT!" : "KEEP TRYING!")))
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.white)

                Text("\(correctCount)/\(questions.count) correct")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 24) {
                    VStack {
                        Text("\(pct)%")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.accentGradient)
                        Text("Score")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    VStack {
                        Text("+\(totalXPEarned)")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.starYellow)
                        Text("XP Earned")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(20)
                .background(NeonGlassCard())

                if isBoss && pct >= 70 {
                    Text("🏆 BOSS DEFEATED! Legendary reward earned!")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.warmGradient)
                }

                Spacer()

                BrutalistButton(title: "DONE", icon: "checkmark") { dismiss() }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
            }

            if pct == 100 { ConfettiOverlay() }
        }
    }
}

// MARK: - Mini Game

struct MiniGameView: View {
    @ObservedObject var state: GameState
    @Environment(\.dismiss) var dismiss
    @State private var score = 0
    @State private var lives = 3
    @State private var targets: [GameTarget] = []
    @State private var gameActive = false
    @State private var gameOver = false
    @State private var totalTaps = 0
    @State private var hitTaps = 0
    @State private var spawnTimer: Timer?
    @State private var round = 0

    struct GameTarget: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var type: TargetType
        var scale: CGFloat = 1.0
        var visible = true
        var created = Date()

        enum TargetType { case gold, silver, red }
    }

    var body: some View {
        ZStack {
            AppTheme.deepBg.ignoresSafeArea()

            if gameOver {
                gameOverView
            } else if !gameActive {
                startView
            } else {
                gamePlayView
            }
        }
    }

    var startView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "scope")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.accentGradient)
            Text("COSMIC SHOOTER")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            VStack(spacing: 8) {
                Text("🟡 Gold = +3 pts")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.starYellow)
                Text("⚪ Silver = +1 pt")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Text("🔴 Red = -1 life")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.hotPink)
            }
            Spacer()
            BrutalistButton(title: "START", icon: "play.fill") {
                startGame()
            }
            .padding(.horizontal, 40)

            Button {
                Haptics.medium()
                dismiss()
            } label: {
                Text("Back")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 120, height: 44)
            }
            .padding(.bottom, 60)
        }
    }

    var gamePlayView: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < lives ? "heart.fill" : "heart")
                                    .foregroundColor(i < lives ? AppTheme.hotPink : .white.opacity(0.2))
                            }
                        }
                        Spacer()
                        Text("Score: \(score)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    Spacer()
                }

                ForEach(targets) { target in
                    if target.visible {
                        Circle()
                            .fill(targetColor(target.type))
                            .frame(width: 60 * target.scale, height: 60 * target.scale)
                            .shadow(color: targetColor(target.type).opacity(0.5), radius: 8)
                            .position(x: target.x, y: target.y)
                            .onTapGesture {
                                tapTarget(target)
                            }
                            .transition(.scale)
                    }
                }
            }
        }
        .onDisappear { spawnTimer?.invalidate() }
    }

    func targetColor(_ type: GameTarget.TargetType) -> Color {
        switch type {
        case .gold: return AppTheme.starYellow
        case .silver: return .white.opacity(0.7)
        case .red: return AppTheme.hotPink
        }
    }

    func startGame() {
        score = 0
        lives = 3
        targets = []
        gameActive = true
        gameOver = false
        totalTaps = 0
        hitTaps = 0
        round = 0

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            spawnTarget()
            round += 1
            cleanTargets()
            if lives <= 0 { endGame() }
        }
    }

    func spawnTarget() {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let x = CGFloat.random(in: 50...(w - 50))
        let y = CGFloat.random(in: 120...(h - 200))
        let rand = Int.random(in: 0...9)
        let type: GameTarget.TargetType = rand < 2 ? .gold : (rand < 8 ? .silver : .red)
        let t = GameTarget(x: x, y: y, type: type)
        withAnimation(.spring(response: 0.3)) { targets.append(t) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let idx = targets.firstIndex(where: { $0.id == t.id && $0.visible }) {
                withAnimation { targets[idx].visible = false }
                if targets[idx].type != .red {
                }
            }
        }
    }

    func tapTarget(_ target: GameTarget) {
        guard let idx = targets.firstIndex(where: { $0.id == target.id && $0.visible }) else { return }
        totalTaps += 1
        Haptics.medium()
        withAnimation(.spring(response: 0.2)) { targets[idx].visible = false }

        switch target.type {
        case .gold:
            score += 3
            hitTaps += 1
            Haptics.success()
        case .silver:
            score += 1
            hitTaps += 1
        case .red:
            lives -= 1
            Haptics.error()
            if lives <= 0 { endGame() }
        }
    }

    func cleanTargets() {
        targets.removeAll { !$0.visible }
    }

    func endGame() {
        spawnTimer?.invalidate()
        gameActive = false
        gameOver = true
        let xp = max(20, min(60, score * 3))
        state.addXP(xp)
        state.totalSessionsCount += 1
        if totalTaps > 0 && hitTaps == totalTaps && totalTaps >= 5 {
            state.unlockAchievement("game_perfect")
        }
        PersistenceController.shared.addSession(mode: "minigame", correct: hitTaps, total: totalTaps, xp: xp, time: Float(round) * 1.2)
    }

    var gameOverView: some View {
        VStack(spacing: 24) {
            Spacer()
            CosmoMascot(mood: score >= 20 ? .excited : .happy, size: 100)
            Text("GAME OVER")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text("Score: \(score)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.accentGradient)
            let accuracy = totalTaps > 0 ? Int((Double(hitTaps) / Double(totalTaps)) * 100) : 0
            Text("Accuracy: \(accuracy)%")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            BrutalistButton(title: "PLAY AGAIN", icon: "arrow.counterclockwise") { startGame() }
                .padding(.horizontal, 40)
            Button {
                Haptics.medium()
                dismiss()
            } label: {
                Text("Back to Menu")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(height: 44)
            }
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Stats

struct StatsView: View {
    @ObservedObject var state: GameState
    @State private var appeared = false
    @State private var sessions: [LearningSessionEntity] = []
    @State private var expandedWidget: String? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                Text("STATISTICS")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 60)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    StatCounter(label: "Total XP", value: "\(state.totalXP)", icon: "star.fill", color: AppTheme.starYellow, appeared: appeared)
                    StatCounter(label: "Sessions", value: "\(state.totalSessionsCount)", icon: "book.fill", color: AppTheme.neonCyan, appeared: appeared)
                    StatCounter(label: "Best Score", value: "\(state.bestQuizScore)%", icon: "trophy.fill", color: AppTheme.warmOrange, appeared: appeared)
                    StatCounter(label: "Streak", value: "\(state.streakDays)d", icon: "flame.fill", color: state.streakTemperature().1, appeared: appeared)
                }

                SectionLabel(text: "WEEKLY XP", icon: "chart.bar.fill")
                WeeklyBarChart(data: state.weeklyXPArray, appeared: appeared)
                    .frame(height: 200)
                    .padding(16)
                    .background(NeonGlassCard())

                SectionLabel(text: "MONTHLY TREND", icon: "chart.line.uptrend.xyaxis")
                MonthlyLineChart(data: state.monthlyXPArray, appeared: appeared)
                    .frame(height: 200)
                    .padding(16)
                    .background(NeonGlassCard())

                SectionLabel(text: "TOPIC MASTERY", icon: "pentagon.fill")
                RadarChartView(state: state)
                    .frame(height: 260)
                    .padding(16)
                    .background(NeonGlassCard())

                SectionLabel(text: "STREAK HEATMAP", icon: "calendar")
                StreakHeatmap(streakDays: state.streakDays)
                    .padding(16)
                    .background(NeonGlassCard())

                SectionLabel(text: "SESSION LOG", icon: "list.bullet")
                if sessions.isEmpty {
                    EmptyStateView(icon: "chart.bar.doc.horizontal.fill", title: "No sessions yet", subtitle: "Complete quizzes to see your history", actionTitle: "") {}
                } else {
                    VStack(spacing: 8) {
                        ForEach(sessions, id: \.timestamp) { s in
                            SessionRow(session: s) {
                                PersistenceController.shared.deleteSession(s)
                                sessions = PersistenceController.shared.fetchSessions()
                            }
                        }
                    }
                }

                if state.bestQuizScore > 0 {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(AppTheme.warmGradient)
                        Text("Personal Best: \(state.bestQuizScore)%")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppTheme.warmOrange.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6).delay(0.2)) { appeared = true }
            sessions = PersistenceController.shared.fetchSessions()
        }
    }
}

struct StatCounter: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var appeared: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(NeonGlassCard())
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
    }
}

struct WeeklyBarChart: View {
    let data: [Int]
    var appeared: Bool
    let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(0..<min(data.count, 7), id: \.self) { i in
                    BarMark(
                        x: .value("Day", days[i]),
                        y: .value("XP", appeared ? data[i] : 0)
                    )
                    .foregroundStyle(AppTheme.accentGradient)
                    .cornerRadius(6)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .chartXAxis {
                AxisMarks {
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .animation(.spring(response: 0.8), value: appeared)
        }
    }
}

struct MonthlyLineChart: View {
    let data: [Int]
    var appeared: Bool
    let weeks = ["Wk1", "Wk2", "Wk3", "Wk4"]

    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(0..<min(data.count, 4), id: \.self) { i in
                    LineMark(
                        x: .value("Week", weeks[i]),
                        y: .value("XP", appeared ? data[i] : 0)
                    )
                    .foregroundStyle(AppTheme.electricPurple)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Week", weeks[i]),
                        y: .value("XP", appeared ? data[i] : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [AppTheme.electricPurple.opacity(0.3), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisValueLabel().foregroundStyle(.white.opacity(0.4))
                }
            }
            .chartXAxis {
                AxisMarks {
                    AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                }
            }
            .animation(.spring(response: 0.8), value: appeared)
        }
    }
}

struct RadarChartView: View {
    @ObservedObject var state: GameState
    let labels = ["Solar", "Stars", "Galaxy", "BH", "Exo", "Bang", "Scope", "Rocket", "Mars", "Dark", "Neutron", "Multi"]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2 - 30
            let count = labels.count

            for ring in 1...4 {
                let r = maxR * Double(ring) / 4.0
                var path = Path()
                for i in 0..<count {
                    let angle = (Double(i) / Double(count)) * .pi * 2 - .pi / 2
                    let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()
                ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }

            for i in 0..<count {
                let angle = (Double(i) / Double(count)) * .pi * 2 - .pi / 2
                let end = CGPoint(x: center.x + cos(angle) * maxR, y: center.y + sin(angle) * maxR)
                var line = Path()
                line.move(to: center)
                line.addLine(to: end)
                ctx.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 0.5)

                let labelP = CGPoint(x: center.x + cos(angle) * (maxR + 18), y: center.y + sin(angle) * (maxR + 18))
                ctx.draw(Text(labels[i]).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                         at: labelP)
            }

            var dataPath = Path()
            for i in 0..<count {
                let prog = state.lessonProgress
                let val: Double = i < prog.count ? (prog[i] ? 0.85 : 0.15) : 0.15
                let angle = (Double(i) / Double(count)) * .pi * 2 - .pi / 2
                let r = maxR * val
                let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                if i == 0 { dataPath.move(to: p) } else { dataPath.addLine(to: p) }
            }
            dataPath.closeSubpath()
            ctx.fill(dataPath, with: .color(AppTheme.neonCyan.opacity(0.15)))
            ctx.stroke(dataPath, with: .color(AppTheme.neonCyan.opacity(0.6)), lineWidth: 2)
        }
    }
}

struct StreakHeatmap: View {
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = row * 7 + col
                        let active = day < streakDays
                        RoundedRectangle(cornerRadius: 3)
                            .fill(active ? heatColor(day) : Color.white.opacity(0.05))
                            .frame(width: 16, height: 16)
                    }
                    Spacer()
                }
            }
        }
    }

    func heatColor(_ day: Int) -> Color {
        let intensity = min(1.0, Double(day) / 30.0)
        return Color(red: 0.0 + intensity * 0.0,
                     green: 0.3 + intensity * 0.6,
                     blue: 0.3 + intensity * 0.6)
    }
}

struct SessionRow: View {
    let session: LearningSessionEntity
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.mode.capitalized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(session.timestamp, style: .date)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.correctAnswers)/\(session.totalAnswers)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("+\(session.xpGained) XP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.starYellow)
            }
        }
        .padding(14)
        .background(NeonGlassCard())
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { v in
                    if v.translation.width < 0 { offset = v.translation.width }
                }
                .onEnded { v in
                    if v.translation.width < -80 {
                        withAnimation { offset = -200 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDelete() }
                    } else {
                        withAnimation { offset = 0 }
                    }
                }
        )
    }
}

// MARK: - Profile

struct ProfileView: View {
    @ObservedObject var state: GameState
    @State private var tapCount = 0
    @State private var showShareSheet = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var avatarImageData: Data? = nil
    @State private var achievementPage = 0

    let categories = ["Learning", "Quiz", "Streak", "Weekly", "XP", "Challenge", "Game", "Secret", "Social"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.electricPurple.opacity(0.2))
                            .frame(width: 110, height: 110)
                            .overlay(
                                Circle().stroke(AppTheme.accentGradient, lineWidth: 3)
                            )

                        if let data = avatarImageData, let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 70))
                                .foregroundStyle(AppTheme.accentGradient)
                        }
                    }
                    .onTapGesture {
                        tapCount += 1
                        if tapCount >= 7 {
                            state.unlockAchievement("secret_tap")
                            state.secretThemeActive.toggle()
                            Haptics.success()
                            tapCount = 0
                        }
                    }
                    .accessibilityLabel("Profile avatar, tap 7 times for secret")

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text("Change Photo")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accentGradient)
                    }
                    .onChange(of: selectedPhoto) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                avatarImageData = data
                            }
                        }
                    }

                    Text(state.userName)
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text("Level \(state.currentLevel)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accentGradient)
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        Text(state.currentLevelName)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.starYellow)
                    }
                    Text("\(state.totalXP) XP • \(state.streakDays) day streak • \(state.completedLessonCount) lessons")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.top, 60)

                SectionLabel(text: "ACHIEVEMENTS", icon: "trophy.fill")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                Haptics.light()
                                achievementPage = categories.firstIndex(of: cat) ?? 0
                            } label: {
                                Text(cat)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(categories[achievementPage] == cat ? .white : .white.opacity(0.4))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(categories[achievementPage] == cat ? AppTheme.electricPurple.opacity(0.4) : Color.white.opacity(0.05))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                let filtered = achievementCatalog.filter { $0.category == categories[achievementPage] }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(filtered) { ach in
                        AchievementSticker(achievement: ach, isUnlocked: state.isUnlocked(ach.id))
                    }
                }
                .padding(.horizontal, 20)
                .animation(.spring(response: 0.4), value: achievementPage)

                let catAchievements = filtered
                let allUnlocked = !catAchievements.isEmpty && catAchievements.allSatisfy { state.isUnlocked($0.id) }
                if allUnlocked {
                    Text("✨ PAGE COMPLETE! +50 XP bonus!")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.accentGradient)
                }

                BrutalistButton(title: "SHARE PROGRESS", icon: "square.and.arrow.up") {
                    state.unlockAchievement("share_card")
                    showShareSheet = true
                }
                .padding(.horizontal, 40)

                BrutalistButton(title: "EXPORT PDF REPORT", icon: "doc.richtext") {
                    Haptics.medium()
                    exportPDF()
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [generateShareText()])
        }
    }

    func generateShareText() -> String {
        "🚀 StarterGhoste Progress: \(state.totalXP) XP | Level \(state.currentLevel) \(state.currentLevelName) | \(state.streakDays) day streak | \(state.completedLessonCount) lessons completed!"
    }

    func exportPDF() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.lightGray
            ]

            UIColor(AppTheme.deepBg).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 612, height: 792))

            ("StarterGhoste Progress Report" as NSString).draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttr)
            let lines = [
                "Name: \(state.userName)",
                "Level: \(state.currentLevel) - \(state.currentLevelName)",
                "Total XP: \(state.totalXP)",
                "Streak: \(state.streakDays) days",
                "Sessions: \(state.totalSessionsCount)",
                "Best Score: \(state.bestQuizScore)%",
                "Lessons: \(state.completedLessonCount)/12",
                "Achievements: \(state.unlockedSet.count)/\(achievementCatalog.count)"
            ]
            for (i, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 50, y: 100 + i * 30), withAttributes: bodyAttr)
            }
        }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("StarterGhoste_Report.pdf")
        try? data.write(to: tmpURL)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            let ac = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
            root.present(ac, animated: true)
        }
    }
}

struct AchievementSticker: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if isUnlocked {
                    Circle()
                        .fill(achievement.isRare ? AppTheme.neonCyan.opacity(0.15) : AppTheme.electricPurple.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .shadow(color: achievement.isRare ? AppTheme.neonCyan.opacity(0.4) : .clear, radius: 8)
                    Image(systemName: achievement.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(achievement.isRare ?
                            AnyShapeStyle(LinearGradient(colors: [AppTheme.neonCyan, AppTheme.mintGreen], startPoint: .top, endPoint: .bottom)) :
                            AnyShapeStyle(AppTheme.accentGradient))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.15))
                }
            }

            Text(achievement.title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isUnlocked ? .white : .white.opacity(0.25))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(achievement.title): \(isUnlocked ? "Unlocked" : "Locked") - \(achievement.desc)")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Overlays

struct LevelUpOverlay: View {
    @ObservedObject var state: GameState
    @State private var scale: CGFloat = 0.3
    @State private var textOpacity: Double = 0
    @State private var typewriterText = ""
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { state.showLevelUp = false }

            if showConfetti {
                ConfettiOverlay()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 20) {
                Spacer()

                CosmoMascot(mood: .excited, size: 100)

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.accentGradient)
                    .scaleEffect(scale)
                    .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 20)

                Text("LEVEL UP!")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.accentGradient)
                    .opacity(textOpacity)

                Text(typewriterText)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.starYellow)

                Text("Level \(state.currentLevel)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(textOpacity)

                Spacer()

                BrutalistButton(title: "AWESOME!", icon: "sparkles") {
                    state.showLevelUp = false
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            showConfetti = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) { scale = 1.0 }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) { textOpacity = 1.0 }
            typewriteText(state.newLevelName)
        }
    }

    func typewriteText(_ text: String) {
        typewriterText = ""
        for (i, char) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.08) {
                typewriterText += String(char)
            }
        }
    }
}

struct DailyRewardOverlay: View {
    @ObservedObject var state: GameState
    @State private var revealed = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                CosmoMascot(mood: .happy, size: 90)

                Text("DAILY MYSTERY REWARD")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.warmGradient)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 200, height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.starYellow.opacity(glowPulse ? 0.6 : 0.2), lineWidth: 2)
                        )
                        .shadow(color: AppTheme.starYellow.opacity(glowPulse ? 0.3 : 0.1), radius: 16)

                    if revealed {
                        VStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(AppTheme.starYellow)
                            Text("+\(state.dailyRewardXP) XP")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.warmGradient)
                    }
                }

                Spacer()

                if revealed {
                    BrutalistButton(title: "CLAIM!", icon: "checkmark") {
                        state.addXP(state.dailyRewardXP)
                        state.showDailyReward = false
                    }
                    .padding(.horizontal, 40)
                } else {
                    BrutalistButton(title: "REVEAL", icon: "sparkles") {
                        Haptics.success()
                        withAnimation(.spring(response: 0.4)) { revealed = true }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever()) { glowPulse = true }
        }
    }
}

struct ConfettiOverlay: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, speed: Double, wobble: Double)] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for p in particles {
                    let elapsed = t.truncatingRemainder(dividingBy: 10)
                    let y = p.y + CGFloat(elapsed * p.speed * 80)
                    let x = p.x + sin(elapsed * p.wobble + Double(p.id)) * 30
                    let rect = CGRect(x: x.truncatingRemainder(dividingBy: size.width),
                                      y: y.truncatingRemainder(dividingBy: size.height),
                                      width: p.size, height: p.size)
                    ctx.fill(Path(rect), with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            let colors: [Color] = [AppTheme.neonCyan, AppTheme.electricPurple, AppTheme.hotPink, AppTheme.starYellow, AppTheme.mintGreen, AppTheme.warmOrange]
            let w = UIScreen.main.bounds.width
            particles = (0..<120).map { i in
                (id: i,
                 x: CGFloat.random(in: 0...w),
                 y: CGFloat.random(in: -200...0),
                 color: colors[i % colors.count],
                 size: CGFloat.random(in: 4...10),
                 speed: Double.random(in: 0.5...2.0),
                 wobble: Double.random(in: 1...4))
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.accentGradient)
                .offset(y: bounce ? -6 : 6)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever()) { bounce.toggle() }
                }

            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            if !actionTitle.isEmpty {
                BrutalistButton(title: actionTitle, icon: "arrow.counterclockwise", action: action)
                    .frame(width: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

/*
═══════════════════════════════════════════════════════════
APP STORE METADATA
═════════════════════════════════��═════════════════════════

App Name: StarterGhoste
Subtitle: Learn Space the Analog Way
Category: Education | Age Rating: 9+

Description:
🚀 Discover the cosmos through a unique vinyl-analog lens!
🎛️ Only app combining cassette-tape aesthetics with space education.
⭐ 12 deep lessons from Solar System basics to Multiverse theory
🎯 20 hand-crafted quiz questions across 3 difficulty tiers
🔥 Daily streaks with temperature-morphing visuals (ice→plasma)
🏆 20 collectible achievements including rare blue-glow weeklies
🎮 Cosmic Shooter mini-game with SpriteKit particles
📊 Rich stats: bar charts, radar, heatmaps, exportable PDF
👻 Find the secret Easter egg — tap the ghost 7 times!
Start your analog cosmos journey today.

ASO Keywords: space learning app, astronomy quiz teen, cosmos education game, star galaxy facts, space trivia game

Screenshot Concepts:
1) Dashboard hero card with streak flame + XP ring on cosmic bg
2) Quiz card-swipe in action with neon answer glow + stats charts
3) Achievement sticker book with blue-glow rare unlocks

Icon Concept A: Vinyl record disc with glowing cyan grooves + tiny stars
Icon Concept B: Ghost silhouette in neon-outlined space helmet on deep purple
*/
