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
        case .aiRecording:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .aiRecording),
                subtitle: language.screenshotSubtitle(for: .aiRecording),
                screen: .aiRecording,
                language: language
            ) {
                PhoneFrameView { MockAIRecordingView(language: language) }
            }
        case .useCase:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .useCase),
                subtitle: language.screenshotSubtitle(for: .useCase),
                screen: .useCase,
                language: language
            ) {
                PhoneFrameView { MockUseCaseView(language: language) }
            }
        case .timestampedTranscription:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .timestampedTranscription),
                subtitle: language.screenshotSubtitle(for: .timestampedTranscription),
                screen: .timestampedTranscription,
                language: language
            ) {
                PhoneFrameView { MockTimestampedTranscriptionView(language: language) }
            }
        case .playbackList:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .playbackList),
                subtitle: language.screenshotSubtitle(for: .playbackList),
                screen: .playbackList,
                language: language
            ) {
                PhoneFrameView { MockPlaybackListView(language: language) }
            }
        case .backgroundRecording:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .backgroundRecording),
                subtitle: language.screenshotSubtitle(for: .backgroundRecording),
                screen: .backgroundRecording,
                language: language
            ) {
                MockBackgroundRecordingView(language: language)
            }
        case .waveformEditor:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .waveformEditor),
                subtitle: language.screenshotSubtitle(for: .waveformEditor),
                screen: .waveformEditor,
                language: language
            ) {
                PhoneFrameView { MockWaveformEditorView(language: language) }
            }
        case .playlist:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .playlist),
                subtitle: language.screenshotSubtitle(for: .playlist),
                screen: .playlist,
                language: language
            ) {
                PhoneFrameView { MockPlaylistView(language: language) }
            }
        case .shareSheet:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .shareSheet),
                subtitle: language.screenshotSubtitle(for: .shareSheet),
                screen: .shareSheet,
                language: language
            ) {
                PhoneFrameView { MockShareSheetView(language: language) }
            }
        case .premium:
            ScreenshotPageView(
                caption: language.screenshotCaption(for: .premium),
                subtitle: language.screenshotSubtitle(for: .premium),
                screen: .premium,
                language: language
            ) {
                PhoneFrameView { MockPremiumView(language: language) }
            }
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

    var lockScreenDate: String {
        switch self {
        case .japanese: return "4月19日(土)"
        case .english: return "Saturday, Apr 19"
        case .german: return "Sa., 19. Apr."
        case .spanish: return "Sáb., 19 abr."
        case .french: return "Sam. 19 avr."
        case .italian: return "Sab, 19 apr"
        case .portuguese: return "Sáb, 19 abr."
        case .russian: return "Суб, 19 апр."
        case .turkish: return "Cmt, 19 Nis"
        case .vietnamese: return "T7, 19 Th4"
        case .chineseSimplified: return "4月19日 周六"
        case .chineseTraditional: return "4月19日 週六"
        }
    }

    func sampleRecordingTitle(_ index: Int) -> String {
        let englishTitles = ["Family Discussion", "Travel Talk with Friends", "Meeting Notes", "Voice Memo", "Interview"]
        let japaneseTitles = ["家族との話し合い", "友達との旅行の話", "会議メモ", "ボイスメモ", "インタビュー"]
        let germanTitles = ["Familiengespräch", "Reisegespräch mit Freunden", "Besprechungsnotizen", "Sprachnotiz", "Interview"]
        let spanishTitles = ["Discusión Familiar", "Charla de Viaje con Amigos", "Notas de Reunión", "Nota de Voz", "Entrevista"]
        let frenchTitles = ["Discussion Familiale", "Discussion de Voyage avec des Amis", "Notes de Réunion", "Mémo Vocal", "Entretien"]
        let italianTitles = ["Discussione Familiare", "Chiacchierata di Viaggio con Amici", "Note della Riunione", "Memo Vocale", "Intervista"]
        let portugueseTitles = ["Discussão Familiar", "Conversa de Viagem com Amigos", "Notas da Reunião", "Nota de Voz", "Entrevista"]
        let russianTitles = ["Семейное обсуждение", "Разговор о путешествии с друзьями", "Заметки встречи", "Голосовая заметка", "Интервью"]
        let turkishTitles = ["Aile Tartışması", "Arkadaşlarla Seyahat Sohbeti", "Toplantı Notları", "Sesli Not", "Röportaj"]
        let vietnameseTitles = ["Thảo luận gia đình", "Nói chuyện du lịch với bạn bè", "Ghi chú cuộc họp", "Ghi chú giọng nói", "Phỏng vấn"]
        let chineseSimplifiedTitles = ["家庭讨论", "与朋友的旅行谈话", "会议笔记", "语音备忘录", "采访"]
        let chineseTraditionalTitles = ["家庭討論", "與朋友的旅行談話", "會議筆記", "語音備忘錄", "採訪"]

        let titles: [String]
        switch self {
        case .english: titles = englishTitles
        case .japanese: titles = japaneseTitles
        case .german: titles = germanTitles
        case .spanish: titles = spanishTitles
        case .french: titles = frenchTitles
        case .italian: titles = italianTitles
        case .portuguese: titles = portugueseTitles
        case .russian: titles = russianTitles
        case .turkish: titles = turkishTitles
        case .vietnamese: titles = vietnameseTitles
        case .chineseSimplified: titles = chineseSimplifiedTitles
        case .chineseTraditional: titles = chineseTraditionalTitles
        }

        return index < titles.count ? titles[index] : titles[0]
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

    var recordingTitle: String {
        switch self {
        case .english: return "Recording"
        case .japanese: return "録音"
        case .german: return "Aufnahme"
        case .spanish: return "Grabación"
        case .french: return "Enregistrement"
        case .italian: return "Registrazione"
        case .portuguese: return "Gravação"
        case .russian: return "Запись"
        case .turkish: return "Kayıt"
        case .vietnamese: return "Ghi âm"
        case .chineseSimplified: return "录音"
        case .chineseTraditional: return "錄音"
        }
    }

    var readyToRecord: String {
        switch self {
        case .english: return "Ready to Record"
        case .japanese: return "録音準備完了"
        case .german: return "Aufnahmebereit"
        case .spanish: return "Listo para Grabar"
        case .french: return "Prêt à Enregistrer"
        case .italian: return "Pronto per Registrare"
        case .portuguese: return "Pronto para Gravar"
        case .russian: return "Готов к записи"
        case .turkish: return "Kayda Hazır"
        case .vietnamese: return "Sẵn sàng Ghi"
        case .chineseSimplified: return "准备录音"
        case .chineseTraditional: return "準備錄音"
        }
    }

    var recordingFiles: String {
        switch self {
        case .english: return "Recording Files"
        case .japanese: return "録音ファイル"
        case .german: return "Aufnahmedateien"
        case .spanish: return "Archivos de Grabación"
        case .french: return "Fichiers d'Enregistrement"
        case .italian: return "File di Registrazione"
        case .portuguese: return "Arquivos de Gravação"
        case .russian: return "Файлы записи"
        case .turkish: return "Kayıt Dosyaları"
        case .vietnamese: return "Tệp Ghi âm"
        case .chineseSimplified: return "录音文件"
        case .chineseTraditional: return "錄音檔案"
        }
    }

    var audioEdit: String {
        switch self {
        case .english: return "Audio Edit"
        case .japanese: return "音声編集"
        case .german: return "Audiobearbeitung"
        case .spanish: return "Edición de Audio"
        case .french: return "Édition Audio"
        case .italian: return "Modifica Audio"
        case .portuguese: return "Edição de Áudio"
        case .russian: return "Редактирование аудио"
        case .turkish: return "Ses Düzenleme"
        case .vietnamese: return "Chỉnh sửa Âm thanh"
        case .chineseSimplified: return "音频编辑"
        case .chineseTraditional: return "音訊編輯"
        }
    }

    var trimSelection: String {
        switch self {
        case .english: return "Trim Selection"
        case .japanese: return "選択範囲をトリム"
        case .german: return "Auswahl zuschneiden"
        case .spanish: return "Recortar Selección"
        case .french: return "Rogner la Sélection"
        case .italian: return "Ritaglia Selezione"
        case .portuguese: return "Aparar Seleção"
        case .russian: return "Обрезать выбранное"
        case .turkish: return "Seçimi Kırp"
        case .vietnamese: return "Cắt Lựa chọn"
        case .chineseSimplified: return "修剪选择"
        case .chineseTraditional: return "修剪選擇"
        }
    }

    var deleteSelection: String {
        switch self {
        case .english: return "Delete Selection"
        case .japanese: return "選択範囲を削除"
        case .german: return "Auswahl löschen"
        case .spanish: return "Eliminar Selección"
        case .french: return "Supprimer la Sélection"
        case .italian: return "Elimina Selezione"
        case .portuguese: return "Excluir Seleção"
        case .russian: return "Удалить выбранное"
        case .turkish: return "Seçimi Sil"
        case .vietnamese: return "Xóa Lựa chọn"
        case .chineseSimplified: return "删除选择"
        case .chineseTraditional: return "刪除選擇"
        }
    }

    func sampleDate(_ index: Int) -> String {
        switch self {
        case .english: return "2024/08/17 11:\(10 + index)"
        case .japanese: return "2024/08/17 11:\(10 + index)"
        case .german: return "17.08.2024 11:\(10 + index)"
        case .spanish: return "17/08/2024 11:\(10 + index)"
        case .french: return "17/08/2024 11:\(10 + index)"
        case .italian: return "17/08/2024 11:\(10 + index)"
        case .portuguese: return "17/08/2024 11:\(10 + index)"
        case .russian: return "17.08.2024 11:\(10 + index)"
        case .turkish: return "17.08.2024 11:\(10 + index)"
        case .vietnamese: return "17/08/2024 11:\(10 + index)"
        case .chineseSimplified: return "2024/08/17 11:\(10 + index)"
        case .chineseTraditional: return "2024/08/17 11:\(10 + index)"
        }
    }

    func createdDate(_ index: Int) -> String {
        switch self {
        case .english: return "Created: 2024/08/\(15 + index)"
        case .japanese: return "作成日: 2024/08/\(15 + index)"
        case .german: return "Erstellt: \(15 + index).08.2024"
        case .spanish: return "Creado: \(15 + index)/08/2024"
        case .french: return "Créé: \(15 + index)/08/2024"
        case .italian: return "Creato: \(15 + index)/08/2024"
        case .portuguese: return "Criado: \(15 + index)/08/2024"
        case .russian: return "Создано: \(15 + index).08.2024"
        case .turkish: return "Oluşturuldu: \(15 + index).08.2024"
        case .vietnamese: return "Tạo: \(15 + index)/08/2024"
        case .chineseSimplified: return "创建日期: 2024/08/\(15 + index)"
        case .chineseTraditional: return "建立日期: 2024/08/\(15 + index)"
        }
    }

    var statusBarDate: String {
        switch self {
        case .english: return "Friday, January 24"
        case .japanese: return "金曜日 1月 24日"
        case .german: return "Freitag, 24. Januar"
        case .spanish: return "Viernes, 24 de enero"
        case .french: return "Vendredi 24 janvier"
        case .italian: return "Venerdì 24 gennaio"
        case .portuguese: return "Sexta-feira, 24 de janeiro"
        case .russian: return "Пятница, 24 января"
        case .turkish: return "Cuma, 24 Ocak"
        case .vietnamese: return "Thứ Sáu, 24 tháng 1"
        case .chineseSimplified: return "星期五 1月24日"
        case .chineseTraditional: return "星期五 1月24日"
        }
    }

    var sampleRecordingDescription: String {
        switch self {
        case .english: return "Recorded a conversation with family"
        case .japanese: return "家族との会話を録音しました"
        case .german: return "Gespräch mit der Familie aufgenommen"
        case .spanish: return "Grabé una conversación con la familia"
        case .french: return "Enregistré une conversation avec la famille"
        case .italian: return "Registrata conversazione con la famiglia"
        case .portuguese: return "Gravei uma conversa com a família"
        case .russian: return "Записан разговор с семьей"
        case .turkish: return "Aileyle sohbet kaydedildi"
        case .vietnamese: return "Đã ghi cuộc trò chuyện với gia đình"
        case .chineseSimplified: return "录制了与家人的对话"
        case .chineseTraditional: return "錄製了與家人的對話"
        }
    }

    var aiTranscriptionLabel: String {
        switch self {
        case .english: return "Transcribing..."
        case .japanese: return "AI文字起こし中..."
        case .german: return "Transkribierung..."
        case .spanish: return "Transcribiendo..."
        case .french: return "Transcription en cours..."
        case .italian: return "Trascrizione in corso..."
        case .portuguese: return "Transcrevendo..."
        case .russian: return "Транскрибирование..."
        case .turkish: return "Transkript oluşturuluyor..."
        case .vietnamese: return "Đang chuyển văn bản..."
        case .chineseSimplified: return "AI转录中..."
        case .chineseTraditional: return "AI轉錄中..."
        }
    }

    var aiTranscriptionCaption: String {
        switch self {
        case .english: return "Record & Transcribe Instantly"
        case .japanese: return "録音してすぐAI文字起こし"
        case .german: return "Aufnehmen & sofort transkribieren"
        case .spanish: return "Graba y transcribe al instante"
        case .french: return "Enregistrez et transcrivez instantanément"
        case .italian: return "Registra e trascrivi istantaneamente"
        case .portuguese: return "Grave e transcreva instantaneamente"
        case .russian: return "Записывайте и транскрибируйте мгновенно"
        case .turkish: return "Kaydet ve anında transkript al"
        case .vietnamese: return "Ghi âm và chuyển văn bản ngay lập tức"
        case .chineseSimplified: return "录音后即刻AI转录"
        case .chineseTraditional: return "錄音後即刻AI轉錄"
        }
    }

    var useCaseCaption: String {
        switch self {
        case .english: return "For Meetings, Lectures & Interviews"
        case .japanese: return "会議・講義・インタビューに"
        case .german: return "Für Meetings, Vorlesungen & Interviews"
        case .spanish: return "Para reuniones, clases y entrevistas"
        case .french: return "Pour réunions, cours et interviews"
        case .italian: return "Per riunioni, lezioni e interviste"
        case .portuguese: return "Para reuniões, aulas e entrevistas"
        case .russian: return "Для встреч, лекций и интервью"
        case .turkish: return "Toplantılar, Dersler ve Röportajlar için"
        case .vietnamese: return "Cho cuộc họp, bài giảng và phỏng vấn"
        case .chineseSimplified: return "适用于会议、讲座和采访"
        case .chineseTraditional: return "適用於會議、講座和採訪"
        }
    }

    var timestampCaption: String {
        switch self {
        case .english: return "Timestamped Transcription"
        case .japanese: return "タイムスタンプ付き文字起こし"
        case .german: return "Transkription mit Zeitstempel"
        case .spanish: return "Transcripción con marcas de tiempo"
        case .french: return "Transcription horodatée"
        case .italian: return "Trascrizione con timestamp"
        case .portuguese: return "Transcrição com carimbo de tempo"
        case .russian: return "Транскрипция с временными метками"
        case .turkish: return "Zaman Damgalı Transkript"
        case .vietnamese: return "Phiên âm có dấu thời gian"
        case .chineseSimplified: return "带时间戳的文字转录"
        case .chineseTraditional: return "帶時間戳的文字轉錄"
        }
    }

    var transcriptionTitle: String {
        switch self {
        case .english: return "Transcription"
        case .japanese: return "文字起こし"
        case .german: return "Transkription"
        case .spanish: return "Transcripción"
        case .french: return "Transcription"
        case .italian: return "Trascrizione"
        case .portuguese: return "Transcrição"
        case .russian: return "Транскрипция"
        case .turkish: return "Transkript"
        case .vietnamese: return "Phiên âm"
        case .chineseSimplified: return "文字转录"
        case .chineseTraditional: return "文字轉錄"
        }
    }

    func useCaseSampleTitle(_ index: Int) -> String {
        let en = ["Meeting Notes", "Economics Lecture Vol.3", "Interview with Mr. Smith", "Idea Memo", "English Speaking Practice"]
        let ja = ["会議メモ", "経済学 第3回講義", "田中さんへのインタビュー", "アイデアメモ", "英語スピーキング練習"]
        let de = ["Besprechungsnotizen", "Wirtschaft Vorlesung 3", "Interview mit Herrn Müller", "Ideen-Memo", "Englisch Sprechübung"]
        let es = ["Notas de Reunión", "Clase de Economía Vol.3", "Entrevista con el Sr. García", "Memo de Ideas", "Práctica de Inglés"]
        let fr = ["Notes de Réunion", "Cours d'Économie Vol.3", "Interview avec M. Dupont", "Mémo d'Idées", "Pratique Anglais"]
        let it = ["Note della Riunione", "Lezione di Economia Vol.3", "Intervista con il Sig. Rossi", "Memo Idee", "Pratica Inglese"]
        let pt = ["Notas da Reunião", "Aula de Economia Vol.3", "Entrevista com Sr. Silva", "Memo de Ideias", "Prática de Inglês"]
        let ru = ["Заметки встречи", "Лекция по экономике №3", "Интервью с г-ном Ивановым", "Заметки идей", "Практика английского"]
        let tr = ["Toplantı Notları", "Ekonomi Dersi 3. Bölüm", "Bay Yılmaz ile Röportaj", "Fikir Notu", "İngilizce Konuşma Pratiği"]
        let vi = ["Ghi chú cuộc họp", "Bài giảng Kinh tế số 3", "Phỏng vấn Ông Nguyễn", "Ghi chú ý tưởng", "Luyện nói tiếng Anh"]
        let zhS = ["会议笔记", "经济学第3讲", "采访张先生", "创意备忘录", "英语口语练习"]
        let zhT = ["會議筆記", "經濟學第3講", "採訪張先生", "創意備忘錄", "英語口語練習"]

        let titles: [String]
        switch self {
        case .english: titles = en
        case .japanese: titles = ja
        case .german: titles = de
        case .spanish: titles = es
        case .french: titles = fr
        case .italian: titles = it
        case .portuguese: titles = pt
        case .russian: titles = ru
        case .turkish: titles = tr
        case .vietnamese: titles = vi
        case .chineseSimplified: titles = zhS
        case .chineseTraditional: titles = zhT
        }
        return index < titles.count ? titles[index] : titles[0]
    }

    var premiumScreenHeadline: String {
        switch self {
        case .english: return "Go Premium"
        case .japanese: return "プレミアムで\nもっと自由に"
        case .german: return "Jetzt Premium\nwerden"
        case .spanish: return "Hazte Premium"
        case .french: return "Passez Premium"
        case .italian: return "Passa a Premium"
        case .portuguese: return "Seja Premium"
        case .russian: return "Перейдите\nна Premium"
        case .turkish: return "Premium'a\nGeçin"
        case .vietnamese: return "Nâng cấp\nPremium"
        case .chineseSimplified: return "升级到\nPremium"
        case .chineseTraditional: return "升級到\nPremium"
        }
    }

    var premiumNoAds: String {
        switch self {
        case .english: return "No Ads"
        case .japanese: return "広告なし"
        case .german: return "Keine Werbung"
        case .spanish: return "Sin anuncios"
        case .french: return "Sans publicité"
        case .italian: return "Nessuna pubblicità"
        case .portuguese: return "Sem anúncios"
        case .russian: return "Без рекламы"
        case .turkish: return "Reklamsız"
        case .vietnamese: return "Không có quảng cáo"
        case .chineseSimplified: return "无广告"
        case .chineseTraditional: return "無廣告"
        }
    }

    var premiumOffline: String {
        switch self {
        case .english: return "Works Offline"
        case .japanese: return "オフラインでも使える"
        case .german: return "Offline verfügbar"
        case .spanish: return "Funciona sin conexión"
        case .french: return "Fonctionne hors ligne"
        case .italian: return "Funziona offline"
        case .portuguese: return "Funciona offline"
        case .russian: return "Работает офлайн"
        case .turkish: return "Çevrimdışı çalışır"
        case .vietnamese: return "Hoạt động ngoại tuyến"
        case .chineseSimplified: return "离线使用"
        case .chineseTraditional: return "離線使用"
        }
    }

    var premiumUnlimited: String {
        switch self {
        case .english: return "Unlimited Recording"
        case .japanese: return "無制限で録音"
        case .german: return "Unbegrenzte Aufnahme"
        case .spanish: return "Grabación ilimitada"
        case .french: return "Enregistrement illimité"
        case .italian: return "Registrazione illimitata"
        case .portuguese: return "Gravação ilimitada"
        case .russian: return "Без ограничений"
        case .turkish: return "Sınırsız Kayıt"
        case .vietnamese: return "Ghi âm không giới hạn"
        case .chineseSimplified: return "无限录音"
        case .chineseTraditional: return "無限錄音"
        }
    }

    var premiumICloud: String {
        switch self {
        case .english: return "iCloud Sync"
        case .japanese: return "iCloud同期"
        case .german: return "iCloud-Synchronisation"
        case .spanish: return "Sincronización iCloud"
        case .french: return "Synchronisation iCloud"
        case .italian: return "Sincronizzazione iCloud"
        case .portuguese: return "Sincronização iCloud"
        case .russian: return "Синхронизация iCloud"
        case .turkish: return "iCloud Senkronizasyonu"
        case .vietnamese: return "Đồng bộ iCloud"
        case .chineseSimplified: return "iCloud同步"
        case .chineseTraditional: return "iCloud同步"
        }
    }

    var premiumCTAButton: String {
        switch self {
        case .english: return "Start Free Trial"
        case .japanese: return "無料トライアルを開始"
        case .german: return "Kostenlos testen"
        case .spanish: return "Iniciar prueba gratuita"
        case .french: return "Démarrer l'essai gratuit"
        case .italian: return "Inizia la prova gratuita"
        case .portuguese: return "Iniciar teste gratuito"
        case .russian: return "Начать бесплатный период"
        case .turkish: return "Ücretsiz Denemeyi Başlat"
        case .vietnamese: return "Bắt đầu dùng thử miễn phí"
        case .chineseSimplified: return "开始免费试用"
        case .chineseTraditional: return "開始免費試用"
        }
    }

    func transcriptionSampleText(_ index: Int) -> String {
        let en = [
            "Today's meeting begins. First, let's review last week's progress...",
            "Sales were up 15% month-over-month, exceeding our target.",
            "Let's discuss the next project. The budget is approximately...",
            "Regarding Q4 planning, we'll start with the marketing team."
        ]
        let ja = [
            "本日の会議を始めます。まず先週の進捗について確認します...",
            "売上は前月比15%増で、目標を達成しました。",
            "次のプロジェクトについて議論します。予算はおよそ...",
            "Q4の計画を確認します。まずマーケティングチームから..."
        ]
        let de = [
            "Wir beginnen das heutige Meeting. Zuerst überprüfen wir den Fortschritt...",
            "Der Umsatz stieg um 15% gegenüber dem Vormonat und übertraf unser Ziel.",
            "Lass uns das nächste Projekt besprechen. Das Budget beträgt ca...",
            "Zur Q4-Planung beginnen wir mit dem Marketing-Team."
        ]
        let generic = [
            "The meeting begins. Reviewing last week's progress...",
            "Results exceeded targets by 15% this month.",
            "Discussing the upcoming project scope and budget...",
            "Q4 planning session with the marketing department."
        ]

        let texts: [String]
        switch self {
        case .english: texts = en
        case .japanese: texts = ja
        case .german: texts = de
        default: texts = generic
        }
        return index < texts.count ? texts[index] : texts[0]
    }

    // MARK: - Screenshot Subtitles
    func screenshotSubtitle(for screen: ScreenshotScreen) -> String {
        switch screen {
        case .playbackList:
            switch self {
            case .japanese: return "録音をすぐに確認"
            case .english: return "Review Recordings Instantly"
            case .german: return "Aufnahmen sofort prüfen"
            case .spanish: return "Revisa grabaciones al instante"
            case .french: return "Réécoutez instantanément"
            case .italian: return "Riproduci subito"
            case .portuguese: return "Ouça gravações de imediato"
            case .russian: return "Мгновенный просмотр записей"
            case .turkish: return "Kayıtları anında kontrol et"
            case .vietnamese: return "Xem lại bản ghi ngay lập tức"
            case .chineseSimplified: return "立即回听录音"
            case .chineseTraditional: return "立即回聽錄音"
            }
        case .aiRecording:
            switch self {
            case .japanese: return "話した内容を自動でテキスト化"
            case .english: return "Auto Speech-to-Text Transcription"
            case .german: return "Automatische Sprachtranskription"
            case .spanish: return "Transcripción automática de voz"
            case .french: return "Transcription automatique"
            case .italian: return "Trascrizione automatica"
            case .portuguese: return "Transcrição automática de voz"
            case .russian: return "Автоматическая транскрипция речи"
            case .turkish: return "Konuşmayı otomatik metne dönüştür"
            case .vietnamese: return "Tự động chuyển giọng nói thành văn bản"
            case .chineseSimplified: return "自动将语音转为文字"
            case .chineseTraditional: return "自動將語音轉為文字"
            }
        case .timestampedTranscription:
            switch self {
            case .japanese: return "時刻付きで内容を確認"
            case .english: return "Review Content with Timestamps"
            case .german: return "Inhalt mit Zeitstempel prüfen"
            case .spanish: return "Revisa contenido con marcas de tiempo"
            case .french: return "Consultez avec horodatage"
            case .italian: return "Rivedi con timestamp"
            case .portuguese: return "Revise com marcação de tempo"
            case .russian: return "Просмотр содержимого с метками времени"
            case .turkish: return "Zaman damgasıyla içeriği incele"
            case .vietnamese: return "Xem nội dung kèm dấu thời gian"
            case .chineseSimplified: return "带时间戳查看内容"
            case .chineseTraditional: return "帶時間戳查看內容"
            }
        case .backgroundRecording:
            switch self {
            case .japanese: return "画面を閉じても録音継続"
            case .english: return "Continues Recording with Screen Off"
            case .german: return "Aufnahme auch bei gesperrtem Bildschirm"
            case .spanish: return "Graba con la pantalla apagada"
            case .french: return "Enregistre même écran éteint"
            case .italian: return "Registra anche con schermo spento"
            case .portuguese: return "Grava com a tela bloqueada"
            case .russian: return "Запись при заблокированном экране"
            case .turkish: return "Ekran kapalıyken kayıt devam eder"
            case .vietnamese: return "Tiếp tục ghi khi tắt màn hình"
            case .chineseSimplified: return "关屏后仍继续录音"
            case .chineseTraditional: return "關屏後仍繼續錄音"
            }
        case .waveformEditor:
            switch self {
            case .japanese: return "不要な部分を簡単にカット"
            case .english: return "Easily Trim Unwanted Parts"
            case .german: return "Überflüssige Teile einfach kürzen"
            case .spanish: return "Recorta partes innecesarias fácilmente"
            case .french: return "Supprimez facilement les parties inutiles"
            case .italian: return "Ritaglia facilmente le parti non necessarie"
            case .portuguese: return "Corte partes desnecessárias com facilidade"
            case .russian: return "Легко удаляйте лишние фрагменты"
            case .turkish: return "Gereksiz kısımları kolayca kırp"
            case .vietnamese: return "Dễ dàng cắt bỏ phần không cần"
            case .chineseSimplified: return "轻松剪掉不需要的部分"
            case .chineseTraditional: return "輕鬆剪掉不需要的部分"
            }
        case .playlist:
            switch self {
            case .japanese: return "テーマ別に整理・管理"
            case .english: return "Organize & Manage by Theme"
            case .german: return "Nach Thema ordnen und verwalten"
            case .spanish: return "Organiza y gestiona por tema"
            case .french: return "Organisez et gérez par thème"
            case .italian: return "Organizza e gestisci per tema"
            case .portuguese: return "Organize e gerencie por tema"
            case .russian: return "Организуйте и управляйте по темам"
            case .turkish: return "Temaya göre düzenle ve yönet"
            case .vietnamese: return "Sắp xếp và quản lý theo chủ đề"
            case .chineseSimplified: return "按主题整理与管理"
            case .chineseTraditional: return "按主題整理與管理"
            }
        case .shareSheet:
            switch self {
            case .japanese: return "メールやメモアプリに転送"
            case .english: return "Share via Email or Notes App"
            case .german: return "Per E-Mail oder Notizen teilen"
            case .spanish: return "Envía por correo o notas"
            case .french: return "Partagez par e-mail ou notes"
            case .italian: return "Condividi via email o note"
            case .portuguese: return "Compartilhe por e-mail ou notas"
            case .russian: return "Отправьте по почте или в заметки"
            case .turkish: return "E-posta veya not uygulamasıyla paylaş"
            case .vietnamese: return "Chia sẻ qua email hoặc ghi chú"
            case .chineseSimplified: return "通过邮件或备忘录分享"
            case .chineseTraditional: return "通過郵件或備忘錄分享"
            }
        case .useCase:
            switch self {
            case .japanese: return "会議・授業・インタビューに"
            case .english: return "For Meetings, Classes & Interviews"
            case .german: return "Für Meetings, Kurse und Interviews"
            case .spanish: return "Para reuniones, clases y entrevistas"
            case .french: return "Pour réunions, cours et interviews"
            case .italian: return "Per riunioni, lezioni e interviste"
            case .portuguese: return "Para reuniões, aulas e entrevistas"
            case .russian: return "Для встреч, занятий и интервью"
            case .turkish: return "Toplantılar, dersler ve röportajlar için"
            case .vietnamese: return "Dành cho họp, học và phỏng vấn"
            case .chineseSimplified: return "适用于会议、授课和采访"
            case .chineseTraditional: return "適用於會議、授課和採訪"
            }
        case .premium:
            switch self {
            case .japanese: return "広告なし・全機能アンロック"
            case .english: return "No Ads, All Features Unlocked"
            case .german: return "Ohne Werbung, alles freigeschaltet"
            case .spanish: return "Sin anuncios, todo desbloqueado"
            case .french: return "Sans pub, tout débloqué"
            case .italian: return "Senza pubblicità, tutto sbloccato"
            case .portuguese: return "Sem anúncios, tudo desbloqueado"
            case .russian: return "Без рекламы, все функции открыты"
            case .turkish: return "Reklamsız, tüm özellikler açık"
            case .vietnamese: return "Không quảng cáo, mở khóa tất cả"
            case .chineseSimplified: return "无广告·解锁全部功能"
            case .chineseTraditional: return "無廣告·解鎖全部功能"
            }
        }
    }

    // MARK: - Screenshot Captions
    func screenshotCaption(for screen: ScreenshotScreen) -> String {
        switch screen {
        case .playbackList:
            switch self {
            case .japanese: return "録音を再生"
            case .english: return "Play Your\nRecordings"
            case .german: return "Aufnahmen\nwiedergeben"
            case .spanish: return "Reproduce tus\ngrabaciones"
            case .french: return "Lire vos\nenregistrements"
            case .italian: return "Riproduci le\nregistrazioni"
            case .portuguese: return "Reproduza suas\ngravações"
            case .russian: return "Воспроизводите\nзаписи"
            case .turkish: return "Kayıtlarınızı\noynatın"
            case .vietnamese: return "Phát lại\nbản ghi của bạn"
            case .chineseSimplified: return "播放您的\n录音文件"
            case .chineseTraditional: return "播放您的\n錄音檔案"
            }
        case .backgroundRecording:
            switch self {
            case .japanese: return "バックグラウンド\nでも録音できる"
            case .english: return "Record Even in\nBackground"
            case .german: return "Auch im\nHintergrund aufnehmen"
            case .spanish: return "Graba incluso en\nsegundo plano"
            case .french: return "Enregistre même\nen arrière-plan"
            case .italian: return "Registra anche in\nbackground"
            case .portuguese: return "Grave mesmo em\nsegundo plano"
            case .russian: return "Запись даже в\nфоновом режиме"
            case .turkish: return "Arka planda bile\nkayıt yapın"
            case .vietnamese: return "Ghi âm ngay cả\nkhi nền"
            case .chineseSimplified: return "后台也能\n继续录音"
            case .chineseTraditional: return "背景也能\n繼續錄音"
            }
        case .playlist:
            switch self {
            case .japanese: return "録音を\nプレイリストに"
            case .english: return "Organize into\nPlaylists"
            case .german: return "In Wiedergabelisten\nordnen"
            case .spanish: return "Organiza en\nlistas de reproducción"
            case .french: return "Organisez en\nlistes de lecture"
            case .italian: return "Organizza in\nplaylist"
            case .portuguese: return "Organize em\nlistas de reprodução"
            case .russian: return "Организуйте\nв плейлисты"
            case .turkish: return "Çalma listelerine\norganize edin"
            case .vietnamese: return "Sắp xếp vào\ndanh sách phát"
            case .chineseSimplified: return "整理到\n播放列表"
            case .chineseTraditional: return "整理到\n播放列表"
            }
        case .waveformEditor:
            switch self {
            case .japanese: return "音声をかんたんに\nトリミング＆編集"
            case .english: return "Easy Audio\nTrimming & Editing"
            case .german: return "Audio einfach\nschneiden & bearbeiten"
            case .spanish: return "Recorta y edita\naudio fácilmente"
            case .french: return "Rogner et éditer\nl'audio facilement"
            case .italian: return "Taglia e modifica\nl'audio facilmente"
            case .portuguese: return "Corte e edite\naudio facilmente"
            case .russian: return "Легко обрезайте\nи редактируйте аудио"
            case .turkish: return "Sesi kolayca\nkırp ve düzenle"
            case .vietnamese: return "Dễ dàng cắt\nvà chỉnh sửa âm thanh"
            case .chineseSimplified: return "轻松剪辑\n音频录音"
            case .chineseTraditional: return "輕鬆剪輯\n音訊錄音"
            }
        case .aiRecording:
            switch self {
            case .japanese: return "録音して\nすぐAI文字起こし"
            case .english: return "Record & Transcribe\nInstantly with AI"
            case .german: return "Aufnehmen &\nsofort transkribieren"
            case .spanish: return "Graba y transcribe\nal instante con IA"
            case .french: return "Enregistrez et\ntranscrivez avec l'IA"
            case .italian: return "Registra e trascrivi\nistantaneamente con AI"
            case .portuguese: return "Grave e transcreva\ncom IA"
            case .russian: return "Запись и\nтранскрипция с AI"
            case .turkish: return "Kaydet ve AI ile\nanında transkript al"
            case .vietnamese: return "Ghi âm và\nchuyển văn bản AI"
            case .chineseSimplified: return "录音后\nAI即刻转录"
            case .chineseTraditional: return "錄音後\nAI即刻轉錄"
            }
        case .useCase:
            switch self {
            case .japanese: return "会議・講義・\nインタビューに"
            case .english: return "For Meetings,\nLectures & Interviews"
            case .german: return "Für Meetings,\nVorlesungen & Interviews"
            case .spanish: return "Para reuniones,\nclases y entrevistas"
            case .french: return "Pour réunions,\ncours et interviews"
            case .italian: return "Per riunioni,\nlezioni e interviste"
            case .portuguese: return "Para reuniões,\naulas e entrevistas"
            case .russian: return "Для встреч,\nлекций и интервью"
            case .turkish: return "Toplantılar, Dersler\nve Röportajlar için"
            case .vietnamese: return "Cho họp, bài giảng\nvà phỏng vấn"
            case .chineseSimplified: return "适用于会议\n讲座和采访"
            case .chineseTraditional: return "適用於會議\n講座和採訪"
            }
        case .timestampedTranscription:
            switch self {
            case .japanese: return "タイムスタンプ付き\n文字起こし"
            case .english: return "Timestamped\nTranscription"
            case .german: return "Transkription\nmit Zeitstempel"
            case .spanish: return "Transcripción\ncon marcas de tiempo"
            case .french: return "Transcription\nhorodatée"
            case .italian: return "Trascrizione\ncon timestamp"
            case .portuguese: return "Transcrição\ncom carimbo de tempo"
            case .russian: return "Транскрипция\nс временными метками"
            case .turkish: return "Zaman Damgalı\nTranskript"
            case .vietnamese: return "Phiên âm\ncó dấu thời gian"
            case .chineseSimplified: return "带时间戳的\n文字转录"
            case .chineseTraditional: return "帶時間戳的\n文字轉錄"
            }
        case .shareSheet:
            switch self {
            case .japanese: return "録音を\n簡単に共有"
            case .english: return "Share Recordings\nEasily"
            case .german: return "Aufnahmen\neinfach teilen"
            case .spanish: return "Comparte\ngrabaciones fácilmente"
            case .french: return "Partagez\nfacilement"
            case .italian: return "Condividi\nfacilmente"
            case .portuguese: return "Compartilhe\nfacilmente"
            case .russian: return "Легко делитесь\nзаписями"
            case .turkish: return "Kayıtları\nkolayca paylaşın"
            case .vietnamese: return "Chia sẻ\nbản ghi dễ dàng"
            case .chineseSimplified: return "轻松分享\n录音文件"
            case .chineseTraditional: return "輕鬆分享\n錄音檔案"
            }
        case .premium:
            switch self {
            case .japanese: return "プレミアムで\nもっと自由に"
            case .english: return "Go Premium\nfor More Freedom"
            case .german: return "Premium für\nmehr Freiheit"
            case .spanish: return "Hazte Premium\npara más libertad"
            case .french: return "Passez Premium\npour plus de liberté"
            case .italian: return "Vai Premium\nper più libertà"
            case .portuguese: return "Seja Premium\npara mais liberdade"
            case .russian: return "Перейдите на\nPremium"
            case .turkish: return "Daha Fazlası\niçin Premium'a Geçin"
            case .vietnamese: return "Nâng cấp Premium\ncho nhiều tự do hơn"
            case .chineseSimplified: return "升级Premium\n获得更多自由"
            case .chineseTraditional: return "升級Premium\n獲得更多自由"
            }
        }
    }
}

// MARK: - Screenshot Screen Enum
enum ScreenshotScreen: String, CaseIterable {
    case aiRecording
    case useCase
    case timestampedTranscription
    case playbackList
    case backgroundRecording
    case waveformEditor
    case playlist
    case shareSheet
    case premium

    var backgroundGradient: LinearGradient {
        switch self {
        case .aiRecording:
            return LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
        case .playbackList, .timestampedTranscription:
            return LinearGradient(colors: [.indigo, .blue], startPoint: .top, endPoint: .bottom)
        case .waveformEditor, .shareSheet:
            return LinearGradient(colors: [.green, Color(red: 0, green: 0.5, blue: 0.5)], startPoint: .top, endPoint: .bottom)
        case .backgroundRecording:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.3), .blue], startPoint: .top, endPoint: .bottom)
        case .playlist, .useCase:
            return LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom)
        case .premium:
            return LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0), .orange], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Screenshot Page View (Caption + Content)
struct ScreenshotPageView<Content: View>: View {
    let caption: String
    let subtitle: String
    let screen: ScreenshotScreen
    let language: AppLanguage
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    Text(caption)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.top, 50)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity)

                    Text(subtitle)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color(white: 0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity)

                    content()
                        .padding(.horizontal, 28)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Text("🎙")
                            .font(.system(size: 16))
                        Text(language.appTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Phone Frame View (iPhone mockup wrapper)
struct PhoneFrameView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private let designWidth: CGFloat = 390
    private let designHeight: CGFloat = 844

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / designWidth
            let frameH = designHeight * scale

            ZStack(alignment: .topLeading) {
                // Phone body background + shadow
                RoundedRectangle(cornerRadius: 44 * scale)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 12 * scale, y: 4 * scale)
                    .frame(width: geo.size.width, height: frameH)

                // Scaled app content clipped to phone shape
                ZStack(alignment: .topLeading) {
                    Color.white
                    content()
                        .preferredColorScheme(.light)
                        .frame(width: designWidth, height: designHeight)
                        .scaleEffect(scale, anchor: .topLeading)
                }
                .frame(width: geo.size.width, height: frameH, alignment: .topLeading)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 44 * scale))

                // Phone border on top
                RoundedRectangle(cornerRadius: 44 * scale)
                    .stroke(Color(white: 0.75), lineWidth: 2)
                    .frame(width: geo.size.width, height: frameH)

                // Status bar + Dynamic Island overlay
                VStack(spacing: 0) {
                    HStack {
                        Text("20:53")
                            .font(.system(size: 14 * scale, weight: .semibold))
                        Spacer()
                        HStack(spacing: 4 * scale) {
                            Image(systemName: "cellularbars")
                                .font(.system(size: 11 * scale))
                            Image(systemName: "wifi")
                                .font(.system(size: 11 * scale))
                            Image(systemName: "battery.100")
                                .font(.system(size: 11 * scale))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22 * scale)
                    .padding(.top, 12 * scale)

                    // Dynamic Island
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 120 * scale, height: 32 * scale)
                        .padding(.top, 4 * scale)
                }
                .frame(width: geo.size.width)
            }
            .frame(width: geo.size.width, height: frameH)
        }
        .aspectRatio(designWidth / designHeight, contentMode: .fit)
    }
}

// MARK: - Mock Recording View
struct MockRecordingListView: View {
    let language: AppLanguage
    @State private var isRecording = true

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(language.recordingTitle)
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
                        Text(isRecording ? language.recordingText : language.readyToRecord)
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
                Text(language.recordingFiles)
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
                                    Text(language.sampleRecordingTitle(index))
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
                                    Text(language.sampleDate(index))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if index == 0 {
                                        Text(language.sampleRecordingDescription)
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
                            Text(language.sampleDate(0))
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
}

// MARK: - Mock Background Recording View
struct MockBackgroundRecordingView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            // Dynamic Island close-up — shows orange mic + waveform + timer
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.80), Color(white: 0.52), Color(white: 0.72), Color(white: 0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 290, height: 84)

                Capsule()
                    .fill(Color.black)
                    .frame(width: 268, height: 64)

                HStack(spacing: 0) {
                    Spacer().frame(width: 24)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Spacer().frame(width: 10)
                    // Waveform bars
                    HStack(alignment: .center, spacing: 2.5) {
                        ForEach([0.45, 0.75, 1.0, 0.6, 0.85, 0.5, 0.9, 0.65], id: \.self) { h in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.orange.opacity(0.85))
                                .frame(width: 3, height: CGFloat(h) * 20)
                        }
                    }
                    Spacer()
                    Text("02:47")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                    Spacer().frame(width: 16)
                }
                .frame(width: 268)
            }
            .padding(.top, 4)

            // Partial iPhone showing lock screen
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 44)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.30, blue: 0.52),
                                Color(red: 0.12, green: 0.16, blue: 0.36)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 44)
                            .stroke(Color(white: 0.35), lineWidth: 2)
                    )

                VStack(alignment: .center, spacing: 0) {
                    // Status bar
                    HStack(spacing: 0) {
                        HStack(spacing: 2) {
                            Image(systemName: "cellularbars").font(.system(size: 10))
                            Image(systemName: "wifi").font(.system(size: 10))
                        }
                        .foregroundColor(.white)
                        Spacer()
                        // Dynamic Island with mic indicator
                        ZStack {
                            Capsule()
                                .fill(Color.black)
                                .frame(width: 108, height: 30)
                            HStack(spacing: 5) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.leading, 12)
                            .frame(width: 108)
                        }
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                .frame(width: 22, height: 12)
                            HStack {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.green)
                                    .frame(width: 14, height: 8)
                                Spacer()
                            }
                            .padding(.horizontal, 2)
                            .frame(width: 22)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    // Localized date
                    Text(language.lockScreenDate)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 20)

                    // Large time (universally understood)
                    Text("13:39")
                        .font(.system(size: 88, weight: .thin))
                        .foregroundColor(.white)
                        .padding(.top, 2)

                    Spacer()

                    // Recording Live Activity banner
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                        Text(language.recordingText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("02:47")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 310)
            .clipped()
        }
        .padding(.bottom, 8)
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

                Text(language.audioEdit)
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
                                Text(language.trimSelection)
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
                                Text(language.deleteSelection)
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

                            Text(language.createdDate(index))
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

// MARK: - Mock AI Recording View
struct MockAIRecordingView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(language.recordingTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 20)

            VStack(spacing: 20) {
                // Recording Status and Timer
                VStack(spacing: 8) {
                    Text(language.recordingText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("00:02:45")
                        .font(.title.monospacedDigit())
                        .fontWeight(.bold)
                }

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
                            .frame(width: geometry.size.width * 0.65)
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(height: 20)
                .cornerRadius(10)
                .padding(.horizontal)

                // AI Transcription Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text(language.aiTranscriptionLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Text(language.transcriptionSampleText(index))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }

                        // Typing indicator
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Color.blue.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)

                Spacer()

                // Control Buttons
                HStack(spacing: 32) {
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
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

// MARK: - Mock Use Case View
struct MockUseCaseView: View {
    let language: AppLanguage

    private let useCaseColors: [Color] = [.orange, .purple, .blue, .green, .red]
    private let useCaseIcons = ["mic.fill", "graduationcap.fill", "person.fill", "lightbulb.fill", "waveform"]
    private let useCaseDurations = ["45:23", "1:23:45", "15:42", "3:21", "8:05"]

    var body: some View {
        VStack(spacing: 0) {
            // Title and Toolbar
            HStack {
                Text(language.recordingFiles)
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
                List {
                    ForEach(0..<5) { index in
                        HStack(spacing: 12) {
                            // Color icon
                            ZStack {
                                Circle()
                                    .fill(useCaseColors[index])
                                    .frame(width: 36, height: 36)
                                Image(systemName: useCaseIcons[index])
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }

                            // Memo Info
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(language.useCaseSampleTitle(index))
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(useCaseDurations[index])
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                HStack {
                                    Text(language.sampleDate(index))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)

                // Mini player
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.useCaseSampleTitle(0))
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(language.sampleDate(0))
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

                        VStack(spacing: 4) {
                            ProgressView(value: 0.25)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            HStack {
                                Text("11:21")
                                    .font(.caption)
                                    .monospacedDigit()
                                Spacer()
                                Text("45:23")
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        Button(action: {}) {
                            Image(systemName: "pause.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Mock Timestamped Transcription View
struct MockTimestampedTranscriptionView: View {
    let language: AppLanguage

    private let timestamps = ["00:00", "00:18", "00:42", "01:23"]

    var body: some View {
        VStack(spacing: 0) {
            // Title and Export button
            HStack {
                Text(language.transcriptionTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timestamps.enumerated()), id: \.offset) { index, ts in
                        HStack(alignment: .top, spacing: 12) {
                            Text(ts)
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.blue)
                                .frame(width: 44, alignment: .leading)
                                .padding(.top, 2)

                            Text(language.transcriptionSampleText(index))
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                        if index < timestamps.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
            }

            Spacer()

            // Mini player
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.useCaseSampleTitle(0))
                                .font(.headline)
                                .lineLimit(1)
                            Text(language.sampleDate(0))
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

                    VStack(spacing: 4) {
                        ProgressView(value: 0.38)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        HStack {
                            Text("00:18")
                                .font(.caption)
                                .monospacedDigit()
                            Spacer()
                            Text("45:23")
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Button(action: {}) {
                        Image(systemName: "pause.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Mock Premium View
struct MockPremiumView: View {
    let language: AppLanguage

    private let cyanTop = Color(red: 0, green: 200 / 255, blue: 224 / 255)
    private let cyanBottom = Color(red: 0, green: 110 / 255, blue: 160 / 255)
    private let gold = Color(red: 1, green: 215 / 255, blue: 0)

    private let features: [(iconName: String, keyPath: KeyPath<AppLanguage, String>) ] = [
        ("nosign", \.premiumNoAds),
        ("wifi.slash", \.premiumOffline),
        ("waveform.badge.plus", \.premiumUnlimited),
        ("icloud.fill", \.premiumICloud)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [cyanTop, cyanBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                // Crown badge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(gold.opacity(0.2))
                            .frame(width: 84, height: 84)
                        Circle()
                            .strokeBorder(gold.opacity(0.6), lineWidth: 2)
                            .frame(width: 84, height: 84)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 38))
                            .foregroundColor(gold)
                    }

                    Text("PREMIUM")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(3)
                        .foregroundColor(gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(gold.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(gold.opacity(0.5), lineWidth: 1)
                        )
                }

                Spacer().frame(height: 36)

                // Headline
                Text(language.premiumScreenHeadline)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 44)

                // Feature cards
                VStack(spacing: 16) {
                    ForEach(features, id: \.iconName) { feature in
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: feature.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(language[keyPath: feature.keyPath])
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(gold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA Button
                Text(language.premiumCTAButton)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(cyanBottom)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 52)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ScreenshotPreviewView()
}

// MARK: - JA Previews
#Preview("JA-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.japanese.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.japanese.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .japanese
    ) {
        PhoneFrameView { MockAIRecordingView(language: .japanese) }
    }
}

#Preview("JA-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.japanese.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.japanese.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .japanese
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .japanese) }
    }
}

#Preview("JA-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.japanese.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.japanese.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .japanese
    ) {
        PhoneFrameView { MockUseCaseView(language: .japanese) }
    }
}

#Preview("JA-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.japanese.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.japanese.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .japanese
    ) {
        MockBackgroundRecordingView(language: .japanese)
    }
}

// MARK: - EN Previews
#Preview("EN-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.english.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.english.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .english
    ) {
        PhoneFrameView { MockAIRecordingView(language: .english) }
    }
}

#Preview("EN-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.english.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.english.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .english
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .english) }
    }
}

#Preview("EN-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.english.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.english.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .english
    ) {
        PhoneFrameView { MockUseCaseView(language: .english) }
    }
}

#Preview("EN-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.english.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.english.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .english
    ) {
        MockBackgroundRecordingView(language: .english)
    }
}

// MARK: - DE Previews
#Preview("DE-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.german.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.german.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .german
    ) {
        PhoneFrameView { MockAIRecordingView(language: .german) }
    }
}

#Preview("DE-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.german.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.german.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .german
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .german) }
    }
}

#Preview("DE-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.german.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.german.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .german
    ) {
        PhoneFrameView { MockUseCaseView(language: .german) }
    }
}

#Preview("DE-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.german.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.german.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .german
    ) {
        MockBackgroundRecordingView(language: .german)
    }
}

// MARK: - ES Previews
#Preview("ES-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.spanish.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.spanish.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .spanish
    ) {
        PhoneFrameView { MockAIRecordingView(language: .spanish) }
    }
}

#Preview("ES-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.spanish.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.spanish.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .spanish
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .spanish) }
    }
}

#Preview("ES-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.spanish.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.spanish.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .spanish
    ) {
        PhoneFrameView { MockUseCaseView(language: .spanish) }
    }
}

#Preview("ES-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.spanish.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.spanish.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .spanish
    ) {
        MockBackgroundRecordingView(language: .spanish)
    }
}

// MARK: - FR Previews
#Preview("FR-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.french.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.french.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .french
    ) {
        PhoneFrameView { MockAIRecordingView(language: .french) }
    }
}

#Preview("FR-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.french.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.french.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .french
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .french) }
    }
}

#Preview("FR-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.french.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.french.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .french
    ) {
        PhoneFrameView { MockUseCaseView(language: .french) }
    }
}

#Preview("FR-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.french.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.french.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .french
    ) {
        MockBackgroundRecordingView(language: .french)
    }
}

// MARK: - IT Previews
#Preview("IT-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.italian.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.italian.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .italian
    ) {
        PhoneFrameView { MockAIRecordingView(language: .italian) }
    }
}

#Preview("IT-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.italian.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.italian.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .italian
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .italian) }
    }
}

#Preview("IT-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.italian.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.italian.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .italian
    ) {
        PhoneFrameView { MockUseCaseView(language: .italian) }
    }
}

#Preview("IT-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.italian.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.italian.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .italian
    ) {
        MockBackgroundRecordingView(language: .italian)
    }
}

// MARK: - PT Previews
#Preview("PT-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.portuguese.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.portuguese.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .portuguese
    ) {
        PhoneFrameView { MockAIRecordingView(language: .portuguese) }
    }
}

#Preview("PT-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.portuguese.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.portuguese.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .portuguese
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .portuguese) }
    }
}

#Preview("PT-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.portuguese.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.portuguese.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .portuguese
    ) {
        PhoneFrameView { MockUseCaseView(language: .portuguese) }
    }
}

#Preview("PT-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.portuguese.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.portuguese.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .portuguese
    ) {
        MockBackgroundRecordingView(language: .portuguese)
    }
}

// MARK: - RU Previews
#Preview("RU-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.russian.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.russian.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .russian
    ) {
        PhoneFrameView { MockAIRecordingView(language: .russian) }
    }
}

#Preview("RU-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.russian.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.russian.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .russian
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .russian) }
    }
}

#Preview("RU-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.russian.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.russian.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .russian
    ) {
        PhoneFrameView { MockUseCaseView(language: .russian) }
    }
}

#Preview("RU-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.russian.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.russian.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .russian
    ) {
        MockBackgroundRecordingView(language: .russian)
    }
}

// MARK: - TR Previews
#Preview("TR-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.turkish.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.turkish.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .turkish
    ) {
        PhoneFrameView { MockAIRecordingView(language: .turkish) }
    }
}

#Preview("TR-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.turkish.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.turkish.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .turkish
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .turkish) }
    }
}

#Preview("TR-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.turkish.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.turkish.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .turkish
    ) {
        PhoneFrameView { MockUseCaseView(language: .turkish) }
    }
}

#Preview("TR-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.turkish.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.turkish.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .turkish
    ) {
        MockBackgroundRecordingView(language: .turkish)
    }
}

// MARK: - VI Previews
#Preview("VI-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.vietnamese.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.vietnamese.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .vietnamese
    ) {
        PhoneFrameView { MockAIRecordingView(language: .vietnamese) }
    }
}

#Preview("VI-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.vietnamese.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.vietnamese.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .vietnamese
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .vietnamese) }
    }
}

#Preview("VI-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.vietnamese.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.vietnamese.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .vietnamese
    ) {
        PhoneFrameView { MockUseCaseView(language: .vietnamese) }
    }
}

#Preview("VI-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.vietnamese.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.vietnamese.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .vietnamese
    ) {
        MockBackgroundRecordingView(language: .vietnamese)
    }
}

// MARK: - ZH_HANS Previews
#Preview("ZH_HANS-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.chineseSimplified.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.chineseSimplified.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .chineseSimplified
    ) {
        PhoneFrameView { MockAIRecordingView(language: .chineseSimplified) }
    }
}

#Preview("ZH_HANS-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.chineseSimplified.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.chineseSimplified.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .chineseSimplified
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .chineseSimplified) }
    }
}

#Preview("ZH_HANS-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.chineseSimplified.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.chineseSimplified.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .chineseSimplified
    ) {
        PhoneFrameView { MockUseCaseView(language: .chineseSimplified) }
    }
}

#Preview("ZH_HANS-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.chineseSimplified.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.chineseSimplified.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .chineseSimplified
    ) {
        MockBackgroundRecordingView(language: .chineseSimplified)
    }
}

// MARK: - ZH_HANT Previews
#Preview("ZH_HANT-aiRecording") {
    ScreenshotPageView(
        caption: AppLanguage.chineseTraditional.screenshotCaption(for: .aiRecording),
        subtitle: AppLanguage.chineseTraditional.screenshotSubtitle(for: .aiRecording),
        screen: .aiRecording,
        language: .chineseTraditional
    ) {
        PhoneFrameView { MockAIRecordingView(language: .chineseTraditional) }
    }
}

#Preview("ZH_HANT-timestampedTranscription") {
    ScreenshotPageView(
        caption: AppLanguage.chineseTraditional.screenshotCaption(for: .timestampedTranscription),
        subtitle: AppLanguage.chineseTraditional.screenshotSubtitle(for: .timestampedTranscription),
        screen: .timestampedTranscription,
        language: .chineseTraditional
    ) {
        PhoneFrameView { MockTimestampedTranscriptionView(language: .chineseTraditional) }
    }
}

#Preview("ZH_HANT-useCase") {
    ScreenshotPageView(
        caption: AppLanguage.chineseTraditional.screenshotCaption(for: .useCase),
        subtitle: AppLanguage.chineseTraditional.screenshotSubtitle(for: .useCase),
        screen: .useCase,
        language: .chineseTraditional
    ) {
        PhoneFrameView { MockUseCaseView(language: .chineseTraditional) }
    }
}

#Preview("ZH_HANT-backgroundRecording") {
    ScreenshotPageView(
        caption: AppLanguage.chineseTraditional.screenshotCaption(for: .backgroundRecording),
        subtitle: AppLanguage.chineseTraditional.screenshotSubtitle(for: .backgroundRecording),
        screen: .backgroundRecording,
        language: .chineseTraditional
    ) {
        MockBackgroundRecordingView(language: .chineseTraditional)
    }
}
#endif
