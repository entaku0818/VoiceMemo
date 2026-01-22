import SwiftUI

#if DEBUG
// MARK: - Screenshot Preview Feature
struct ScreenshotPreviewView: View {
    @State private var selectedLanguage: AppLanguage?
    @State private var showFullscreen = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                        showFullscreen = true
                    }) {
                        HStack {
                            Text(language.displayName)
                                .font(.headline)
                            Spacer()
                            Text(language.appTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showFullscreen) {
                if let language = selectedLanguage {
                    FullscreenScreenshotView(language: language, isPresented: $showFullscreen)
                }
            }
        }
    }
}

// MARK: - Fullscreen Screenshot View
struct FullscreenScreenshotView: View {
    let language: AppLanguage
    @Binding var isPresented: Bool
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ForEach(Array(ScreenshotScreen.allCases.enumerated()), id: \.element) { index, screen in
                    screenPreview(for: screen)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private func screenPreview(for screen: ScreenshotScreen) -> some View {
        switch screen {
        case .recordingList:
            MockRecordingListView(language: language)
        case .playbackList:
            MockPlaybackListView(language: language)
        case .backgroundRecording:
            MockBackgroundRecordingView(language: language)
        case .waveformEditor:
            MockWaveformEditorView(language: language)
        case .playlist:
            MockPlaylistView(language: language)
        case .shareSheet:
            MockShareSheetView(language: language)
        }
    }
}

// MARK: - Language Enum
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case japanese = "ja"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case portuguese = "pt-PT"
    case russian = "ru"
    case turkish = "tr"
    case vietnamese = "vi"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var displayName: String {
        switch self {
        case .english: return "EN"
        case .japanese: return "JA"
        case .german: return "DE"
        case .spanish: return "ES"
        case .french: return "FR"
        case .italian: return "IT"
        case .portuguese: return "PT"
        case .russian: return "RU"
        case .turkish: return "TR"
        case .vietnamese: return "VI"
        case .chineseSimplified: return "简"
        case .chineseTraditional: return "繁"
        }
    }

    var appTitle: String {
        switch self {
        case .english: return "Simple Recording"
        case .japanese: return "シンプル録音"
        case .german: return "Einfache Aufnahme"
        case .spanish: return "Grabación Simple"
        case .french: return "Enregistrement Simple"
        case .italian: return "Registrazione Semplice"
        case .portuguese: return "Gravação Simples"
        case .russian: return "Простая Запись"
        case .turkish: return "Basit Kayıt"
        case .vietnamese: return "Ghi Âm Đơn Giản"
        case .chineseSimplified: return "简单录音"
        case .chineseTraditional: return "簡單錄音"
        }
    }

    var editText: String {
        switch self {
        case .english: return "Edit"
        case .japanese: return "編集"
        case .german: return "Bearbeiten"
        case .spanish: return "Editar"
        case .french: return "Modifier"
        case .italian: return "Modifica"
        case .portuguese: return "Editar"
        case .russian: return "Изменить"
        case .turkish: return "Düzenle"
        case .vietnamese: return "Chỉnh sửa"
        case .chineseSimplified: return "编辑"
        case .chineseTraditional: return "編輯"
        }
    }

    var playbackText: String {
        switch self {
        case .english: return "Playback"
        case .japanese: return "再生"
        case .german: return "Wiedergabe"
        case .spanish: return "Reproducción"
        case .french: return "Lecture"
        case .italian: return "Riproduzione"
        case .portuguese: return "Reprodução"
        case .russian: return "Воспроизведение"
        case .turkish: return "Oynat"
        case .vietnamese: return "Phát lại"
        case .chineseSimplified: return "播放"
        case .chineseTraditional: return "播放"
        }
    }

    var recordingText: String {
        switch self {
        case .english: return "Recording"
        case .japanese: return "録音中"
        case .german: return "Aufnahme"
        case .spanish: return "Grabando"
        case .french: return "Enregistrement"
        case .italian: return "Registrazione"
        case .portuguese: return "Gravando"
        case .russian: return "Запись"
        case .turkish: return "Kayıt"
        case .vietnamese: return "Đang ghi"
        case .chineseSimplified: return "录音中"
        case .chineseTraditional: return "錄音中"
        }
    }

    func sampleRecordingTitle(_ index: Int) -> String {
        switch self {
        case .english:
            return index == 0 ? "Family Discussion" : "Travel Talk with Friends"
        case .japanese:
            return index == 0 ? "家族との話し合い" : "友達との旅行の話"
        case .german:
            return index == 0 ? "Familiengespräch" : "Reisegespräch mit Freunden"
        case .spanish:
            return index == 0 ? "Discusión Familiar" : "Charla de Viaje con Amigos"
        case .french:
            return index == 0 ? "Discussion Familiale" : "Discussion de Voyage avec des Amis"
        case .italian:
            return index == 0 ? "Discussione Familiare" : "Chiacchierata di Viaggio con Amici"
        case .portuguese:
            return index == 0 ? "Discussão Familiar" : "Conversa de Viagem com Amigos"
        case .russian:
            return index == 0 ? "Семейное обсуждение" : "Разговор о путешествии с друзьями"
        case .turkish:
            return index == 0 ? "Aile Tartışması" : "Arkadaşlarla Seyahat Sohbeti"
        case .vietnamese:
            return index == 0 ? "Thảo luận gia đình" : "Nói chuyện du lịch với bạn bè"
        case .chineseSimplified:
            return index == 0 ? "家庭讨论" : "与朋友的旅行谈话"
        case .chineseTraditional:
            return index == 0 ? "家庭討論" : "與朋友的旅行談話"
        }
    }
}

// MARK: - Screenshot Screen Enum
enum ScreenshotScreen: String, CaseIterable {
    case recordingList
    case playbackList
    case backgroundRecording
    case waveformEditor
    case playlist
    case shareSheet

    var shortName: String {
        switch self {
        case .recordingList: return "録音"
        case .playbackList: return "再生"
        case .backgroundRecording: return "BG"
        case .waveformEditor: return "編集"
        case .playlist: return "リスト"
        case .shareSheet: return "共有"
        }
    }

    var iconName: String {
        switch self {
        case .recordingList: return "record.circle.fill"
        case .playbackList: return "play.circle.fill"
        case .backgroundRecording: return "apps.iphone"
        case .waveformEditor: return "waveform"
        case .playlist: return "music.note.list"
        case .shareSheet: return "square.and.arrow.up"
        }
    }

    var description: String {
        switch self {
        case .recordingList: return "Recording list screen"
        case .playbackList: return "Playback list with controls"
        case .backgroundRecording: return "Background recording demo"
        case .waveformEditor: return "Waveform trim editor"
        case .playlist: return "Playlist management"
        case .shareSheet: return "Share sheet example"
        }
    }

    func headerText(for language: AppLanguage) -> String {
        switch self {
        case .recordingList:
            switch language {
            case .english: return "Easy Recording\nwith 1 Tap"
            case .japanese: return "1タップで簡単録音"
            case .german: return "Einfache Aufnahme\nmit 1 Tipp"
            case .spanish: return "Grabación Fácil\ncon 1 Toque"
            case .french: return "Enregistrement Facile\nen 1 Tap"
            case .italian: return "Registrazione Facile\ncon 1 Tocco"
            case .portuguese: return "Gravação Fácil\ncom 1 Toque"
            case .russian: return "Легкая Запись\nОдним Нажатием"
            case .turkish: return "1 Dokunuşla\nKolay Kayıt"
            case .vietnamese: return "Ghi Âm Dễ Dàng\nChỉ 1 Chạm"
            case .chineseSimplified: return "一键轻松录音"
            case .chineseTraditional: return "一鍵輕鬆錄音"
            }
        case .playbackList:
            switch language {
            case .english: return "Continuous Playback\nof Voice List"
            case .japanese: return "音声の一覧を\n連続再生"
            case .german: return "Kontinuierliche Wiedergabe\nder Sprachliste"
            case .spanish: return "Reproducción Continua\nde Lista de Voz"
            case .french: return "Lecture Continue\nde la Liste Vocale"
            case .italian: return "Riproduzione Continua\ndell'Elenco Vocale"
            case .portuguese: return "Reprodução Contínua\nda Lista de Voz"
            case .russian: return "Непрерывное Воспроизведение\nСписка Голоса"
            case .turkish: return "Ses Listesinin\nSürekli Oynatımı"
            case .vietnamese: return "Phát Liên Tục\nDanh Sách Giọng Nói"
            case .chineseSimplified: return "连续播放\n语音列表"
            case .chineseTraditional: return "連續播放\n語音列表"
            }
        case .backgroundRecording:
            switch language {
            case .english: return "Record Even in\nBackground"
            case .japanese: return "バックグラウンド\nでも録音できる"
            case .german: return "Aufnahme Auch im\nHintergrund"
            case .spanish: return "Grabar Incluso en\nSegundo Plano"
            case .french: return "Enregistrer Même en\nArrière-plan"
            case .italian: return "Registra Anche in\nBackground"
            case .portuguese: return "Gravar Mesmo em\nSegundo Plano"
            case .russian: return "Запись Даже в\nФоновом Режиме"
            case .turkish: return "Arka Planda da\nKayıt Yap"
            case .vietnamese: return "Ghi Âm Cả Khi\nỞ Nền"
            case .chineseSimplified: return "后台也能\n录音"
            case .chineseTraditional: return "背景也能\n錄音"
            }
        case .waveformEditor:
            switch language {
            case .english: return "Trim & Edit\nwith Waveform"
            case .japanese: return "波形で簡単\nトリム編集"
            case .german: return "Trimmen mit\nWellenform"
            case .spanish: return "Recortar con\nForma de Onda"
            case .french: return "Couper avec\nForme d'Onde"
            case .italian: return "Taglia con\nForma d'Onda"
            case .portuguese: return "Cortar com\nForma de Onda"
            case .russian: return "Обрезка по\nВолновой Форме"
            case .turkish: return "Dalga Formu ile\nKes"
            case .vietnamese: return "Cắt với\nDạng Sóng"
            case .chineseSimplified: return "波形剪辑\n轻松编辑"
            case .chineseTraditional: return "波形剪輯\n輕鬆編輯"
            }
        case .playlist:
            switch language {
            case .english: return "Organize with\nPlaylists"
            case .japanese: return "プレイリストで\n整理整頓"
            case .german: return "Mit Playlists\nOrganisieren"
            case .spanish: return "Organizar con\nListas de Reproducción"
            case .french: return "Organiser avec\ndes Playlists"
            case .italian: return "Organizza con\nPlaylist"
            case .portuguese: return "Organize com\nPlaylists"
            case .russian: return "Организуйте с\nПлейлистами"
            case .turkish: return "Çalma Listeleriyle\nDüzenle"
            case .vietnamese: return "Sắp Xếp với\nDanh Sách Phát"
            case .chineseSimplified: return "播放列表\n轻松整理"
            case .chineseTraditional: return "播放列表\n輕鬆整理"
            }
        case .shareSheet:
            switch language {
            case .english: return "Easy Sharing to\nOther Apps"
            case .japanese: return "他のアプリへ\n簡単シェア"
            case .german: return "Einfaches Teilen mit\nAnderen Apps"
            case .spanish: return "Compartir Fácilmente\ncon Otras Apps"
            case .french: return "Partage Facile vers\nD'autres Apps"
            case .italian: return "Condivisione Facile\ncon Altre App"
            case .portuguese: return "Compartilhamento Fácil\ncom Outros Apps"
            case .russian: return "Легкий Обмен с\nДругими Приложениями"
            case .turkish: return "Diğer Uygulamalarla\nKolay Paylaşım"
            case .vietnamese: return "Chia Sẻ Dễ Dàng\nVới Ứng Dụng Khác"
            case .chineseSimplified: return "轻松分享到\n其他应用"
            case .chineseTraditional: return "輕鬆分享到\n其他應用"
            }
        }
    }
}

// MARK: - Mock Recording List View
struct MockRecordingListView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Text(language.editText)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundColor(.blue)
            }
            .padding()

            // Title
            HStack {
                Text(language.appTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            // Recording List
            VStack(spacing: 0) {
                ForEach(0..<2) { index in
                    HStack {
                        Text(language.sampleRecordingTitle(index))
                        Spacer()
                        Text(index == 0 ? "01:17" : "01:08")
                            .foregroundColor(.secondary)
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    if index < 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding()

            Spacer()

            // Record Button
            Circle()
                .fill(Color.red)
                .frame(width: 70, height: 70)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mock Playback List View
struct MockPlaybackListView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Text(language.playbackText)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.blue)
                Image(systemName: "gearshape")
                    .foregroundColor(.blue)
            }
            .padding()

            // Title
            HStack {
                Text(language.appTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            // Recording List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<8) { index in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("名称未設定")
                                    .fontWeight(.medium)
                                Text("2024/08/17 11:\(10 + index)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("WAV  44.1 kHz/16bit/1ch")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("00:\(String(format: "%02d", 3 + index * 2))")
                                .foregroundColor(.secondary)
                            Image(systemName: "play.circle")
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .frame(height: 300)

            // Playback Controls
            VStack(spacing: 8) {
                Text("名称未設定")
                    .font(.caption)

                HStack {
                    Text("00:01")
                        .font(.caption)
                    ProgressView(value: 0.05)
                    Text("00:20")
                        .font(.caption)
                }
                .padding(.horizontal)

                HStack(spacing: 30) {
                    Text("1x (標準)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(15)

                    Image(systemName: "gobackward.10")
                        .font(.title2)

                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)

                    Image(systemName: "goforward.10")
                        .font(.title2)

                    Image(systemName: "repeat")
                        .font(.title3)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mock Background Recording View
struct MockBackgroundRecordingView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 30) {
            // Dynamic Island Mock
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.orange)
                Spacer()
            }
            .padding()
            .frame(width: 200, height: 50)
            .background(Color.black)
            .cornerRadius(25)

            // Lock Screen Mock
            VStack(spacing: 20) {
                Text("docomo")
                    .font(.caption)
                    .foregroundColor(.white)

                VStack(spacing: 4) {
                    Text("12日 (土) ☀️ 渋谷区")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("13:39")
                        .font(.system(size: 70, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.6), .blue.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(40)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mock Waveform Editor View
struct MockWaveformEditorView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: {}) {
                    Text("キャンセル")
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("トリム")
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {}) {
                    Text("保存")
                        .foregroundColor(.blue)
                }
            }
            .padding()

            Spacer()

            // Waveform
            VStack(spacing: 16) {
                // Time indicators
                HStack {
                    Text("00:05")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("01:17")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Waveform visualization
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<50, id: \.self) { index in
                        let height = waveformHeight(for: index)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(waveformColor(for: index))
                            .frame(width: 4, height: height)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal)

                // Selection handles
                HStack {
                    // Left handle
                    VStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                    .frame(width: 30, height: 80)
                    .background(Color.yellow)
                    .cornerRadius(4)

                    Spacer()

                    // Right handle
                    VStack {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                    .frame(width: 30, height: 80)
                    .background(Color.yellow)
                    .cornerRadius(4)
                }
                .padding(.horizontal, 40)

                // Selected range
                Text("選択範囲: 00:05 - 01:12")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Playback controls
            HStack(spacing: 40) {
                Image(systemName: "gobackward.10")
                    .font(.title2)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                Image(systemName: "goforward.10")
                    .font(.title2)
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [20, 35, 50, 70, 45, 80, 55, 40, 65, 90,
                                  75, 50, 85, 60, 45, 70, 55, 80, 65, 40,
                                  55, 75, 90, 60, 45, 35, 50, 70, 85, 55,
                                  40, 65, 80, 50, 35, 60, 75, 45, 70, 55,
                                  85, 60, 40, 75, 50, 65, 80, 45, 55, 35]
        return heights[index % heights.count]
    }

    private func waveformColor(for index: Int) -> Color {
        // Selected range (indices 5-45)
        if index >= 5 && index <= 45 {
            return .blue
        }
        return .gray.opacity(0.3)
    }
}

// MARK: - Mock Playlist View
struct MockPlaylistView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
            }
            .padding()

            // Title
            HStack {
                Text("プレイリスト")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            // Playlist List
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    HStack {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlistName(for: index, language: language))
                                .fontWeight(.medium)
                            Text("\(3 + index * 2) 件の録音")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()

            Spacer()

            // Tab bar mock
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "record.circle")
                    Text("録音")
                        .font(.caption2)
                }
                Spacer()
                VStack {
                    Image(systemName: "play.circle")
                    Text("再生")
                        .font(.caption2)
                }
                Spacer()
                VStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.blue)
                    Text("プレイリスト")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack {
                    Image(systemName: "gearshape")
                    Text("設定")
                        .font(.caption2)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playlistName(for index: Int, language: AppLanguage) -> String {
        let names: [[String]] = [
            ["Work Meetings", "仕事の会議", "Arbeitstreffen", "Reuniones de Trabajo"],
            ["Study Notes", "勉強メモ", "Studiennotizen", "Notas de Estudio"],
            ["Ideas", "アイデア", "Ideen", "Ideas"]
        ]
        let languageIndex: Int
        switch language {
        case .english: languageIndex = 0
        case .japanese: languageIndex = 1
        case .german: languageIndex = 2
        default: languageIndex = 0
        }
        return names[index][min(languageIndex, names[index].count - 1)]
    }
}

// MARK: - Mock Share Sheet View
struct MockShareSheetView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(.secondary)
                Text(language.appTitle)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
            .padding()

            // Recording Detail
            VStack(spacing: 12) {
                TextField("", text: .constant(language.sampleRecordingTitle(1)))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                HStack {
                    Text("2023年8月7日 9:30:15")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("00:03")
                        .foregroundColor(.secondary)
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding()

            // Share Sheet Mock
            VStack(spacing: 0) {
                // File Info
                HStack {
                    Image(systemName: "waveform")
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)

                    VStack(alignment: .leading) {
                        Text("9B1AE01F-1A38-437B...")
                            .font(.caption)
                            .lineLimit(1)
                        Text("オーディオ録音 · 311 KB")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                Divider()

                // Actions
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "ellipsis")
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        Text("その他")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    Divider()

                    HStack {
                        Text("コピー")
                        Spacer()
                        Image(systemName: "doc.on.doc")
                    }
                    .padding()

                    Divider()

                    HStack {
                        Text("\"ファイル\"に保存")
                        Spacer()
                        Image(systemName: "folder")
                    }
                    .padding()

                    Divider()

                    Text("アクションを編集...")
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    ScreenshotPreviewView()
}
#endif
