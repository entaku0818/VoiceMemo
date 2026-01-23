import SwiftUI

#if DEBUG
// MARK: - Screenshot Preview Feature
struct ScreenshotPreviewView: View {
    @State private var selectedLanguage: AppLanguage?

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
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
            .fullScreenCover(item: $selectedLanguage) { language in
                FullscreenScreenshotView(language: language, onDismiss: {
                    selectedLanguage = nil
                })
            }
        }
    }
}

// MARK: - Fullscreen Screenshot View
struct FullscreenScreenshotView: View {
    let language: AppLanguage
    let onDismiss: () -> Void
    @State private var selectedTab = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(ScreenshotScreen.allCases.enumerated()), id: \.element) { index, screen in
                screenPreview(for: screen)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
enum AppLanguage: String, CaseIterable, Identifiable {
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

    var id: String { rawValue }

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

    var untitled: String {
        switch self {
        case .english: return "Untitled"
        case .japanese: return "名称未設定"
        case .german: return "Ohne Titel"
        case .spanish: return "Sin título"
        case .french: return "Sans titre"
        case .italian: return "Senza titolo"
        case .portuguese: return "Sem título"
        case .russian: return "Без названия"
        case .turkish: return "Başlıksız"
        case .vietnamese: return "Không có tiêu đề"
        case .chineseSimplified: return "未命名"
        case .chineseTraditional: return "未命名"
        }
    }

    var speedStandard: String {
        switch self {
        case .english: return "1x (Standard)"
        case .japanese: return "1x (標準)"
        case .german: return "1x (Standard)"
        case .spanish: return "1x (Estándar)"
        case .french: return "1x (Standard)"
        case .italian: return "1x (Standard)"
        case .portuguese: return "1x (Padrão)"
        case .russian: return "1x (Стандарт)"
        case .turkish: return "1x (Standart)"
        case .vietnamese: return "1x (Tiêu chuẩn)"
        case .chineseSimplified: return "1x (标准)"
        case .chineseTraditional: return "1x (標準)"
        }
    }

    var cancel: String {
        switch self {
        case .english: return "Cancel"
        case .japanese: return "キャンセル"
        case .german: return "Abbrechen"
        case .spanish: return "Cancelar"
        case .french: return "Annuler"
        case .italian: return "Annulla"
        case .portuguese: return "Cancelar"
        case .russian: return "Отменить"
        case .turkish: return "İptal"
        case .vietnamese: return "Hủy"
        case .chineseSimplified: return "取消"
        case .chineseTraditional: return "取消"
        }
    }

    var save: String {
        switch self {
        case .english: return "Save"
        case .japanese: return "保存"
        case .german: return "Speichern"
        case .spanish: return "Guardar"
        case .french: return "Enregistrer"
        case .italian: return "Salva"
        case .portuguese: return "Salvar"
        case .russian: return "Сохранить"
        case .turkish: return "Kaydet"
        case .vietnamese: return "Lưu"
        case .chineseSimplified: return "保存"
        case .chineseTraditional: return "保存"
        }
    }

    var trim: String {
        switch self {
        case .english: return "Trim"
        case .japanese: return "トリム"
        case .german: return "Trimmen"
        case .spanish: return "Recortar"
        case .french: return "Rogner"
        case .italian: return "Taglia"
        case .portuguese: return "Cortar"
        case .russian: return "Обрезать"
        case .turkish: return "Kes"
        case .vietnamese: return "Cắt"
        case .chineseSimplified: return "修剪"
        case .chineseTraditional: return "修剪"
        }
    }

    var selectedRange: String {
        switch self {
        case .english: return "Selection: "
        case .japanese: return "選択範囲: "
        case .german: return "Auswahl: "
        case .spanish: return "Selección: "
        case .french: return "Sélection: "
        case .italian: return "Selezione: "
        case .portuguese: return "Seleção: "
        case .russian: return "Выбор: "
        case .turkish: return "Seçim: "
        case .vietnamese: return "Lựa chọn: "
        case .chineseSimplified: return "选择范围: "
        case .chineseTraditional: return "選擇範圍: "
        }
    }

    var playlist: String {
        switch self {
        case .english: return "Playlist"
        case .japanese: return "プレイリスト"
        case .german: return "Wiedergabeliste"
        case .spanish: return "Lista de reproducción"
        case .french: return "Liste de lecture"
        case .italian: return "Playlist"
        case .portuguese: return "Lista de reprodução"
        case .russian: return "Плейлист"
        case .turkish: return "Çalma Listesi"
        case .vietnamese: return "Danh sách phát"
        case .chineseSimplified: return "播放列表"
        case .chineseTraditional: return "播放列表"
        }
    }

    func recordingCount(_ count: Int) -> String {
        switch self {
        case .english: return "\(count) recordings"
        case .japanese: return "\(count) 件の録音"
        case .german: return "\(count) Aufnahmen"
        case .spanish: return "\(count) grabaciones"
        case .french: return "\(count) enregistrements"
        case .italian: return "\(count) registrazioni"
        case .portuguese: return "\(count) gravações"
        case .russian: return "\(count) записей"
        case .turkish: return "\(count) kayıt"
        case .vietnamese: return "\(count) bản ghi"
        case .chineseSimplified: return "\(count) 个录音"
        case .chineseTraditional: return "\(count) 個錄音"
        }
    }

    var audioRecording: String {
        switch self {
        case .english: return "Audio Recording"
        case .japanese: return "オーディオ録音"
        case .german: return "Audioaufnahme"
        case .spanish: return "Grabación de Audio"
        case .french: return "Enregistrement Audio"
        case .italian: return "Registrazione Audio"
        case .portuguese: return "Gravação de Áudio"
        case .russian: return "Аудиозапись"
        case .turkish: return "Ses Kaydı"
        case .vietnamese: return "Ghi Âm"
        case .chineseSimplified: return "音频录音"
        case .chineseTraditional: return "音訊錄音"
        }
    }

    var more: String {
        switch self {
        case .english: return "More"
        case .japanese: return "その他"
        case .german: return "Mehr"
        case .spanish: return "Más"
        case .french: return "Plus"
        case .italian: return "Altro"
        case .portuguese: return "Mais"
        case .russian: return "Ещё"
        case .turkish: return "Daha Fazla"
        case .vietnamese: return "Thêm"
        case .chineseSimplified: return "更多"
        case .chineseTraditional: return "更多"
        }
    }

    var copy: String {
        switch self {
        case .english: return "Copy"
        case .japanese: return "コピー"
        case .german: return "Kopieren"
        case .spanish: return "Copiar"
        case .french: return "Copier"
        case .italian: return "Copia"
        case .portuguese: return "Copiar"
        case .russian: return "Копировать"
        case .turkish: return "Kopyala"
        case .vietnamese: return "Sao chép"
        case .chineseSimplified: return "复制"
        case .chineseTraditional: return "複製"
        }
    }

    var saveToFiles: String {
        switch self {
        case .english: return "Save to Files"
        case .japanese: return "\"ファイル\"に保存"
        case .german: return "In Dateien sichern"
        case .spanish: return "Guardar en Archivos"
        case .french: return "Enregistrer dans Fichiers"
        case .italian: return "Salva in File"
        case .portuguese: return "Salvar em Arquivos"
        case .russian: return "Сохранить в Файлы"
        case .turkish: return "Dosyalara Kaydet"
        case .vietnamese: return "Lưu vào Tập tin"
        case .chineseSimplified: return "存储到文件"
        case .chineseTraditional: return "儲存到檔案"
        }
    }

    var editActions: String {
        switch self {
        case .english: return "Edit Actions..."
        case .japanese: return "アクションを編集..."
        case .german: return "Aktionen bearbeiten..."
        case .spanish: return "Editar Acciones..."
        case .french: return "Modifier Actions..."
        case .italian: return "Modifica Azioni..."
        case .portuguese: return "Editar Ações..."
        case .russian: return "Редактировать действия..."
        case .turkish: return "Eylemleri Düzenle..."
        case .vietnamese: return "Chỉnh sửa Hành động..."
        case .chineseSimplified: return "编辑操作..."
        case .chineseTraditional: return "編輯動作..."
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
        .background(Color(.systemBackground))
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
                    .font(.body)
                Spacer()
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.blue)
                    .font(.title3)
                Image(systemName: "gearshape")
                    .foregroundColor(.blue)
                    .font(.title3)
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
            .padding(.bottom, 8)

            // Recording List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<4) { index in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.untitled)
                                    .font(.body)
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
                                .font(.body)
                                .foregroundColor(.secondary)
                            Image(systemName: "play.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < 3 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }

            Spacer()

            // Playback Controls
            VStack(spacing: 12) {
                Text(language.untitled)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("00:01")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    ProgressView(value: 0.05)
                        .tint(.blue)
                    Text("00:20")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 20)

                HStack(spacing: 40) {
                    Text(language.speedStandard)
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(16)

                    Image(systemName: "gobackward.10")
                        .font(.title2)

                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 64, height: 64)
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Image(systemName: "goforward.10")
                        .font(.title2)

                    Image(systemName: "repeat")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
        .background(Color(.systemBackground))
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
                    Text(language.cancel)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text(language.trim)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {}) {
                    Text(language.save)
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
                Text("\(language.selectedRange)00:05 - 01:12")
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
        .background(Color(.systemBackground))
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
                Text(language.playlist)
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
                            Text(language.recordingCount(3 + index * 2))
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
                        Text("\(language.audioRecording) · 311 KB")
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
                        Text(language.more)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    Divider()

                    HStack {
                        Text(language.copy)
                        Spacer()
                        Image(systemName: "doc.on.doc")
                    }
                    .padding()

                    Divider()

                    HStack {
                        Text(language.saveToFiles)
                        Spacer()
                        Image(systemName: "folder")
                    }
                    .padding()

                    Divider()

                    Text(language.editActions)
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
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
#Preview {
    ScreenshotPreviewView()
}
#endif
