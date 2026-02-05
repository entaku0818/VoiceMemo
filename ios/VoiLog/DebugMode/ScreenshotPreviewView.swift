import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var dragOffset: CGSize = .zero
    @Environment(\.dismiss) var dismiss

    private var isLastTab: Bool {
        selectedTab == ScreenshotScreen.allCases.count - 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(ScreenshotScreen.allCases.enumerated()), id: \.element) { index, screen in
                screenPreview(for: screen)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: [])
        .offset(x: isLastTab ? dragOffset.width : 0, y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Allow downward swipe from any tab
                    if value.translation.height > 0 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                    }
                    // Allow rightward swipe only on last tab
                    else if isLastTab && value.translation.width > 0 {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    // Dismiss if swiped down more than 150 points
                    if value.translation.height > 150 {
                        onDismiss()
                    }
                    // Dismiss if swiped right more than 150 points on last tab
                    else if isLastTab && value.translation.width > 150 {
                        onDismiss()
                    } else {
                        // Reset offset with animation
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
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

// MARK: - Mock Recording View
struct MockRecordingListView: View {
    let language: AppLanguage
    @State private var isRecording = true

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("録音")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 20)

            VStack(spacing: 24) {
                // Recording Status and Timer
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text(isRecording ? language.recordingText : "録音準備完了")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(isRecording ? .red : .primary)

                        Text(isRecording ? "00:05:23" : "00:00")
                            .font(.title.monospacedDigit())
                            .fontWeight(.bold)
                    }
                }

                // Audio Level Visualization (only when recording)
                if isRecording {
                    VStack(spacing: 12) {
                        // Audio Level Meter
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .yellow, .orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * 0.7)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                        }
                        .frame(height: 20)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Control Buttons
                HStack(spacing: 32) {
                    if isRecording {
                        // Stop Button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray))
                                    .frame(width: 70, height: 70)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 25, height: 25)
                            }
                        }

                        // Pause Button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "pause.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        // Record Button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Mock Playback List View
struct MockPlaybackListView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title and Toolbar
            HStack {
                Text("録音ファイル")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
            // Recording List
            List {
                ForEach(0..<5) { index in
                    HStack(spacing: 12) {
                        // Play Button
                        Button(action: {}) {
                            Image(systemName: index == 0 ? "pause.circle.fill" : "play.circle")
                                .font(.title2)
                                .foregroundColor(index == 0 ? .red : .blue)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)

                        // Memo Info
                        VStack(alignment: .leading, spacing: 6) {
                            // 1行目: タイトル + 時間長
                            HStack {
                                HStack(spacing: 4) {
                                    Text(index == 0 ? language.sampleRecordingTitle(0) : language.untitled)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Button {} label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Spacer()

                                Text(String(format: "%d:%02d", index + 1, (index * 15) % 60))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }

                            // 2行目: 日時 + メニュー
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("2024/08/17 11:\(10 + index)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if index == 0 {
                                        Text("家族との会話を録音しました")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Menu {
                                    Button(action: {}) {
                                        Label("共有", systemImage: "square.and.arrow.up")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Progress Bar (for playing item)
                            if index == 0 {
                                ProgressView(value: 0.3)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)

            // Playback Controls (bottom player)
            VStack(spacing: 0) {
                Divider()

                VStack(spacing: 8) {
                    // Title and Close
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.sampleRecordingTitle(0))
                                .font(.headline)
                                .lineLimit(1)
                            Text("2024/08/17 11:10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {}) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Progress and time
                    VStack(spacing: 4) {
                        ProgressView(value: 0.3)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                        HStack {
                            Text("0:18")
                                .font(.caption)
                                .monospacedDigit()

                            Spacer()

                            Text("1:17")
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Playback controls
                    HStack(spacing: 32) {
                        Button(action: {}) {
                            Image(systemName: "pause.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
            }
        }
    }
}

// MARK: - Mock Background Recording View
struct MockBackgroundRecordingView: View {
    let language: AppLanguage

    var body: some View {
        ZStack {
            // Lock Screen Background
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Status Bar Area
                HStack {
                    Text("9:41")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "wifi")
                        .foregroundColor(.white)
                    Image(systemName: "battery.100")
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Date and Time
                VStack(spacing: 8) {
                    Text("金曜日 1月 24日")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)

                    Text("9:41")
                        .font(.system(size: 76, weight: .thin))
                        .foregroundColor(.white)
                }

                Spacer()

                // Live Activity - Recording
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Recording indicator
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 40, height: 40)
                            Image(systemName: "waveform")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.appTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("00:05:23")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .monospacedDigit()
                        }

                        Spacer()

                        // Audio level
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.green.opacity(index < 6 ? 1.0 : 0.3))
                                    .frame(width: 3, height: CGFloat(4 + index * 2))
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.6))
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mock Waveform Editor View
struct MockWaveformEditorView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(language.cancel) {}
                    .foregroundColor(.red)
                    .frame(width: 80, alignment: .leading)

                Spacer()

                Text("音声編集")
                    .font(.headline)

                Spacer()

                Button(language.save) {}
                    .frame(width: 80, alignment: .trailing)
            }
            .padding()
            .background(Color(.systemBackground))

            ScrollView {
                VStack(spacing: 20) {
                    // Waveform Display
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )

                        // Waveform bars
                        HStack(alignment: .center, spacing: 1) {
                            ForEach(0..<80, id: \.self) { index in
                                let height = waveformHeight(for: index)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(waveformColor(for: index))
                                    .frame(width: 2, height: height)
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: 150)
                    .padding()

                    // Time Display
                    HStack {
                        ZStack {
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 30)
                            Text("00:05 / 01:17")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                        .frame(width: 120)
                    }

                    // Playback Controls
                    HStack(spacing: 32) {
                        Button(action: {}) {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }

                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 60, height: 60)
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }

                        Button(action: {}) {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical)

                    // Edit Actions
                    VStack(spacing: 16) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "scissors")
                                    .frame(width: 30)
                                Text("選択範囲をトリム")
                                Spacer()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)

                        Button(action: {}) {
                            HStack {
                                Image(systemName: "trash")
                                    .frame(width: 30)
                                Text("選択範囲を削除")
                                Spacer()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
            }
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
        // Selected range (indices 10-60)
        if index >= 10 && index <= 60 {
            return Color.blue.opacity(0.8)
        }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - Mock Playlist View
struct MockPlaylistView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title and Toolbar
            HStack {
                Text(language.playlist)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 20)

            List {
                ForEach(0..<3, id: \.self) { index in
                    HStack(alignment: .top, spacing: 16) {
                        // Playlist Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [playlistGradientColors(for: index).0, playlistGradientColors(for: index).1],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)

                            Image(systemName: "music.note.list")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(playlistName(for: index, language: language))
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(language.recordingCount(3 + index * 2))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("作成日: 2024/08/\(15 + index)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
        }
    }

    private func playlistGradientColors(for index: Int) -> (Color, Color) {
        let gradients: [(Color, Color)] = [
            (Color.blue, Color.purple),
            (Color.green, Color.teal),
            (Color.orange, Color.pink)
        ]
        return gradients[index % gradients.count]
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
        ZStack(alignment: .bottom) {
            // Background Dim
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Share Sheet Header
                VStack(spacing: 16) {
                    // File preview
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "waveform")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.sampleRecordingTitle(0))
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(language.audioRecording) • 2.1 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()

                    Divider()

                    // Share Options Row 1
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            shareOption(icon: "message.fill", title: "メッセージ", color: .green)
                            shareOption(icon: "envelope.fill", title: "メール", color: .blue)
                            shareOption(icon: "link", title: "リンク", color: .gray)
                            shareOption(icon: "square.and.arrow.up", title: "その他", color: .gray)
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                }
                .background(Color(.systemBackground))
                .cornerRadius(radius: 16, corners: [.topLeft, .topRight])

                // Action List
                VStack(spacing: 0) {
                    actionRow(icon: "doc.on.doc", title: language.copy)
                    Divider().padding(.leading, 56)
                    actionRow(icon: "folder", title: language.saveToFiles)
                    Divider().padding(.leading, 56)
                    actionRow(icon: "trash", title: "削除", color: .red)
                }
                .background(Color(.systemBackground))
                .padding(.top, 8)

                // Cancel Button
                Button(action: {}) {
                    Text(language.cancel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shareOption(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }

    private func actionRow(icon: String, title: String, color: Color = .primary) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(color)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
#Preview {
    ScreenshotPreviewView()
}

// Custom corner radius extension
#if canImport(UIKit)
extension View {
    func cornerRadius(radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif

#endif
